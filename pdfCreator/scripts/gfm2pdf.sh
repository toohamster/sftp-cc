#!/bin/bash
# gfm2pdf.sh - Convert GFM Markdown to PDF-ready format
#
# This script converts GitHub Flavored Markdown (GFM) to a format
# compatible with pandoc PDF generation, especially for CJK languages.
#
# Usage: ./gfm2pdf.sh <input-dir> <output-dir>
#
# Features:
# - Compact lists → Spacious lists (add blank lines)
# - Task lists →普通 lists ([x] → ✅, [ ] → ⬜)
# - Strikethrough → Italic (~~text~~ → *text*)
# - Preserves code blocks without modification
# - Supports Chinese, Japanese, English markdown files
#
# Requirements:
# - perl (for regex processing)
# - pandoc + xelatex + Noto CJK fonts (for PDF generation)

set -euo pipefail

INPUT_DIR="${1:-.}"
OUTPUT_DIR="${2:-/tmp/gfm2pdf}"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Process each markdown file
find "$INPUT_DIR" -name "*.md" -type f | while read -r file; do
    # Get relative path
    rel_path="${file#$INPUT_DIR/}"
    output_file="$OUTPUT_DIR/$rel_path"

    # Create output directory structure
    mkdir -p "$(dirname "$output_file")"

    # Process with perl for robust regex handling
    perl -e '
        use strict;
        use warnings;

        my @lines;
        my $prev_was_list = 0;
        my $prev_was_text = 0;
        my $in_code_block = 0;

        while (my $line = <STDIN>) {
            # Track code blocks - skip processing inside code
            if ($line =~ /^```+/) {
                $in_code_block = !$in_code_block;
                push @lines, $line;
                next;
            }

            if ($in_code_block) {
                push @lines, $line;
                next;
            }

            # === GFM Conversion Rules ===

            # 1. Task lists: [x] → ✅ [Completed], [ ] → ⬜
            my $is_task_list = $line =~ /^(\s*)[-*+]\s+\[[ x]\]\s*/;
            if ($is_task_list) {
                $line =~ s/^(\s*)[-*+]\s+\[x\]\s*/$1- ✅ /gm;
                $line =~ s/^(\s*)[-*+]\s+\[ \]\s*/$1- ⬜ /gm;
            }

            # 2. Strikethrough: ~~text~~ → *text*
            while ($line =~ s/~~([^~]+)~~/*$1*/g) {}

            # === List Format Detection ===

            my $is_numbered = $line =~ /^[0-9]+\. /;
            my $is_bullet = $line =~ /^[-*+] / && !$is_task_list;
            my $is_list = $is_numbered || $is_bullet;
            my $is_empty = $line =~ /^\s*$/;
            my $is_heading = $line =~ /^#{1,6} /;
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

            # Update state flags
            $prev_was_list = $is_list;
            $prev_was_text = !$is_empty && !$is_heading &&
                            !$is_table && !$is_blockquote && !$is_list;
            $prev_was_text = 0 if $is_empty;
        }

        print @lines;
    ' < "$file" > "$output_file"

    echo "Processed: $rel_path"
done

echo "GFM2PDF preprocessing complete. Output in: $OUTPUT_DIR"
