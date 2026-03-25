# pdfCreator

GFM (GitHub Flavored Markdown) to PDF converter with multi-language support (Chinese, Japanese, English).

## Features

- ✅ Converts GFM syntax to PDF-ready format
- ✅ Supports Chinese, Japanese, English mixed content
- ✅ Automatic list formatting for pandoc compatibility
- ✅ Task list conversion ([x] → ✅)
- ✅ CJK font support (Noto Serif/Sans Mono)
- ✅ GitHub Actions integration ready

## Quick Start

### 1. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install -y pandoc texlive-xetex fonts-noto-cjk

# macOS
brew install pandoc basictex
```

### 2. Convert Markdown to PDF

```bash
# Step 1: Convert GFM to PDF-ready format
bash scripts/gfm2pdf.sh docs/input /tmp/gfm2pdf

# Step 2: Combine markdown files
bash scripts/combine-md.sh /tmp/gfm2pdf /tmp/book.md

# Step 3: Generate PDF
pandoc /tmp/book.md \
  -o output.pdf \
  --pdf-engine=xelatex \
  -V mainfont="Noto Serif CJK SC" \
  -V monofont="Noto Sans Mono CJK SC" \
  --metadata title="My Book" \
  --metadata author="Author"

# Step 4: Cleanup
rm -rf /tmp/gfm2pdf /tmp/book.md
```

## Directory Structure

```
pdfCreator/
├── README.md                 # This file
├── docs/
│   ├── spec.md               # Specification document
│   ├── handbook.md           # Practical handbook (problem solving)
│   └── fonts.md              # Font configuration guide
├── scripts/
│   ├── gfm2pdf.sh            # Core GFM to PDF converter
│   └── combine-md.sh         # Markdown combiner
├── templates/
│   └── workflow-example.yml  # GitHub Actions template
└── examples/
    └── sample-config.json    # Configuration example
```

## Documentation

| Document | Description |
|----------|-------------|
| [docs/spec.md](docs/spec.md) | Full specification and quick start guide |
| [docs/handbook.md](docs/handbook.md) | Problem solving and best practices |
| [docs/fonts.md](docs/fonts.md) | Font installation and configuration |

## Scripts

### gfm2pdf.sh

Converts GFM markdown to pandoc-compatible format:

- Compact lists → Spacious lists (adds blank lines)
- Task lists `[x]` → ✅
- Strikethrough `~~text~~` → *text*
- Preserves code blocks unchanged

```bash
bash scripts/gfm2pdf.sh <input-dir> <output-dir>
```

### combine-md.sh

Combines multiple markdown files into one book:

```bash
bash scripts/combine-md.sh <input-dir> <output-file> [language]
```

## GitHub Actions Integration

Copy `templates/workflow-example.yml` to your `.github/workflows/` directory and adjust paths for your project.

```yaml
name: Generate PDF from Markdown
on:
  push:
    branches: [main]
jobs:
  build-pdf:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # ... see workflow-example.yml for full config
```

## Supported Languages

| Language | Font | Example |
|----------|------|---------|
| Chinese (Simplified) | Noto Serif CJK SC | 中文测试 |
| Japanese | Noto Serif CJK JP | 日本語テスト |
| English | Noto Serif (fallback) | English test |

## Author

**Name**: toohamster
**GitHub**: [@toohamster](https://github.com/toohamster)

## License

MIT License
