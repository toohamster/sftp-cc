#!/bin/bash
# combine-md.sh - Combine multiple markdown files into one book
#
# Usage: ./combine-md.sh <input-dir> <output-file> [language]
#
# Arguments:
#   input-dir   - Directory containing README.md, authors.md, chapter-*.md
#   output-file - Output combined markdown file
#   language    - Language code: en, zh-cn, ja (default: en)
#
# Example:
#   ./combine-md.sh ./myskillNotes/en ./output/book.md en

set -euo pipefail

INPUT_DIR="${1:-.}"
OUTPUT_FILE="${2:-combined.md}"
LANGUAGE="${3:-en}"

# Remove internal --- separators from README and authors, keep one before chapters
{
    # README.md (remove internal ---)
    if [ -f "$INPUT_DIR/README.md" ]; then
        sed '/^---$/d' "$INPUT_DIR/README.md"
        echo ""
    fi

    # authors.md (optional, remove internal ---)
    if [ -f "$INPUT_DIR/authors.md" ]; then
        sed '/^---$/d' "$INPUT_DIR/authors.md"
        echo ""
    fi

    # Chapter separator
    echo "---"
    echo ""

    # Chapter files (sorted)
    for chapter in $(ls "$INPUT_DIR"/chapter-*.md 2>/dev/null | sort -V); do
        cat "$chapter"
        echo ""
    done
} > "$OUTPUT_FILE"

echo "Combined book written to: $OUTPUT_FILE"
