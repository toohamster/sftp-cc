# GFM to PDF 通用方案规范

## 方案概述

本方案将 GitHub Flavored Markdown (GFM) 转换为 PDF，支持中文、日文、英文多语言。

### 设计原则

1. **源文件保持 GFM 规范** — GitHub 网页浏览友好
2. **预处理转换** — 不修改源文件，使用临时文件
3. **多语言支持** — 中日英混排正确显示

### 架构图

```
┌─────────────────────────────────────────────────────────────┐
│ 输入：GFM Markdown                                          │
│ - 支持中文、日文、英文                                       │
│ - 支持表格、任务列表、删除线等 GFM 语法                       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ 步骤 1: gfm2pdf.sh 转换                                       │
│ - 紧凑列表 → 宽松列表                                        │
│ - 任务列表 → 普通列表                                        │
│ - 删除线 → 斜体                                              │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ 步骤 2: combine-md.sh 合并                                    │
│ - 合并 README + 章节                                         │
│ - 移除内部分隔符                                             │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ 步骤 3: pandoc + xelatex 生成 PDF                            │
│ - 使用 Noto CJK 字体                                          │
│ - 支持多语言混排                                             │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ 输出：PDF 文档                                                │
└─────────────────────────────────────────────────────────────┘
```

---

## 快速开始

### 1. 安装依赖

```bash
# Ubuntu/Debian
sudo apt-get install -y pandoc texlive-xetex fonts-noto-cjk

# macOS
brew install pandoc basictex
```

### 2. 目录结构

```
my-project/
├── docs/
│   ├── README.md
│   ├── chapter-01.md
│   └── chapter-02.md
├── pdfCreator/
│   ├── scripts/
│   │   ├── gfm2pdf.sh
│   │   └── combine-md.sh
│   └── templates/
│       └── workflow-example.yml
└── output/
```

### 3. 生成 PDF

```bash
# 转换 GFM
bash pdfCreator/scripts/gfm2pdf.sh docs /tmp/gfm2pdf

# 合并文件
bash pdfCreator/scripts/combine-md.sh /tmp/gfm2pdf /tmp/book.md

# 生成 PDF
pandoc /tmp/book.md \
  -o output/book.pdf \
  --pdf-engine=xelatex \
  -V documentclass=report \
  -V geometry:margin=1in \
  -V mainfont="Noto Serif CJK SC" \
  -V monofont="Noto Sans Mono CJK SC" \
  --metadata title="My Book" \
  --metadata author="Author"

# 清理
rm -rf /tmp/gfm2pdf /tmp/book.md
```

---

## 脚本说明

### gfm2pdf.sh

**功能**：GFM → pandoc 友好格式转换

**转换规则**：
| GFM 语法 | 转换后 |
|----------|--------|
| 紧凑列表 | 宽松列表（添加空行） |
| [x] 任务列表 | ✅ |
| [ ] 任务列表 | ⬜ |
| ~~删除线~~ | *斜体* |
| 代码块 | 保持不变 |

**用法**：
```bash
./gfm2pdf.sh <input-dir> <output-dir>
```

### combine-md.sh

**功能**：合并多个 markdown 文件为一本书

**用法**：
```bash
./combine-md.sh <input-dir> <output-file> [language]
```

---

## 配置选项

### PDF 页面设置

```bash
-V documentclass=report    # 文档类
-V geometry:margin=1in     # 页边距
-V papersize:a4paper       # 纸张大小（可选）
```

### 字体设置

```bash
# 中文
-V mainfont="Noto Serif CJK SC"
-V monofont="Noto Sans Mono CJK SC"

# 日文
-V mainfont="Noto Serif CJK JP"
-V monofont="Noto Sans Mono CJK JP"
```

### 元数据

```bash
--metadata title="书名"
--metadata author="作者"
--metadata date="2026 年 3 月"
```

---

## GitHub Actions 集成

使用 `templates/workflow-example.yml` 作为模板，复制到 `.github/workflows/` 并根据项目结构调整路径。

---

## 参考资源

- [CommonMark 规范](https://spec.commonmark.org/)
- [GitHub Flavored Markdown](https://github.github.com/gfm/)
- [pandoc 用户指南](https://pandoc.org/MANUAL.html)
- [Noto CJK 字体](https://github.com/google/noto-cjk)
