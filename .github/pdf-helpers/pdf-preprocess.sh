#!/bin/bash
# pdf-preprocess.sh - Prepare markdown files for PDF generation
#
# This script processes markdown files to fix formatting issues
# that affect PDF output but should not modify the original source files.
#
# Usage: ./pdf-preprocess.sh <input-dir> <output-dir>
#
# Issues fixed:
# - Add blank line before first list item (if preceded by text)
# - Add blank lines between consecutive numbered list items
# - Add blank lines between consecutive bullet list items

set -euo pipefail

INPUT_DIR="${1:-.}"
OUTPUT_DIR="${2:-/tmp/pdf-preprocess}"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Process each markdown file
find "$INPUT_DIR" -name "*.md" -type f | while read -r file; do
    # Get relative path
    rel_path="${file#$INPUT_DIR/}"
    output_file="$OUTPUT_DIR/$rel_path"

    # Create output directory structure
    mkdir -p "$(dirname "$output_file")"

    # Process the file using perl for better regex support
    perl -e '
        use strict;
        use warnings;

        my @lines;
        my $prev_was_list = 0;
        my $prev_was_text = 0;

        while (my $line = <STDIN>) {
            my $is_numbered = $line =~ /^[0-9]+\. /;
            my $is_bullet = $line =~ /^[-*+] /;
            my $is_list = $is_numbered || $is_bullet;
            my $is_empty = $line =~ /^\s*$/;
            my $is_heading = $line =~ /^#{1,6} /;
            my $is_code_fence = $line =~ /^`{3,}/;
            my $is_table = $line =~ /^\|/;
            my $is_blockquote = $line =~ /^>/;

            # Add blank line before first list item if preceded by text
            if ($is_list && !$prev_was_list && $prev_was_text) {
                push @lines, "\n";
            }

            # Add blank line between consecutive list items
            if ($is_list && $prev_was_list) {
                push @lines, "\n";
            }

            push @lines, $line;

            # Update state
            $prev_was_list = $is_list;
            $prev_was_text = !$is_empty && !$is_heading && !$is_code_fence && !$is_table && !$is_blockquote && !$is_list;
            $prev_was_text = 0 if $is_empty;  # Reset text flag on empty line
        }

        print @lines;
    ' < "$file" > "$output_file"

    echo "Processed: $rel_path"
done

echo "Preprocessing complete. Output in: $OUTPUT_DIR"
