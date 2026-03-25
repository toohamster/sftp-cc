# GFM to PDF 实战手册

## 问题记录与解决方案

本手册记录了使用 pandoc 将 GitHub Flavored Markdown (GFM) 转换为 PDF 过程中遇到的所有问题及解决方案。

---

## 问题 1：列表渲染为内联文本

### 现象
PDF 中编号列表显示为：
```
1. 何时触发 — 用户说什么 2. 如何执行 — 触发后 3. 提供什么能力
```

### 原因
pandoc 遵循 CommonMark 规范，**紧凑列表**（无空行）会被渲染为段落内联文本。

**GFM 规范**允许紧凑列表：
```markdown
1. 第一项
2. 第二项
```

**CommonMark/pandoc** 要求宽松列表：
```markdown
1. 第一项

2. 第二项
```

### 解决方案
使用 `gfm2pdf.sh` 脚本预处理，自动在列表项之间添加空行。

---

## 问题 2：YAML 解析错误

### 现象
```
Error parsing markdown file: YAML parse exception
```

### 原因
多个 markdown 文件合并后，每个文件末尾的 `---` 产生多个 YAML 分隔符冲突。

### 解决方案
合并时用 `sed` 移除内部分隔符：
```bash
cat file1.md file2.md | sed '/^---$/d' > combined.md
```

---

## 问题 3：PDF 生成多余标题页

### 现象
PDF 首页只显示书名和作者，正文从第 2 页开始。

### 原因
使用 `-V titlepage` 和 `-V title/author` 参数配合 `documentclass=report` 会自动生成标题页。

### 解决方案
```bash
# 使用 --metadata 而非 -V
pandoc input.md -o output.pdf \
  --metadata title="书名" \
  --metadata author="作者"
```

---

## 问题 4：代码块不显示 CJK 字符

### 现象
PDF 中代码块的中文显示为方框或乱码。

### 原因
未指定 `monofont`，pandoc 使用默认等宽字体（不支持 CJK）。

### 解决方案
```bash
pandoc input.md -o output.pdf \
  -V mainfont="Noto Serif CJK SC" \
  -V monofont="Noto Sans Mono CJK SC"
```

---

## 问题 5：任务列表格式丢失

### 现象
GFM 任务列表 `[x]` 在 PDF 中显示为普通文本。

### 解决方案
`gfm2pdf.sh` 脚本自动转换：
- `[x]` → `✅`
- `[ ]` → `⬜`

---

## 最佳实践

### 1. 源文件保持 GFM 规范
- 紧凑列表（无空行）— GitHub 网页显示友好
- 不为了 PDF 修改源文件格式
- 使用预处理脚本转换

### 2. 临时文件处理
- 预处理输出到临时目录
- 生成 PDF 后删除临时文件
- 不污染源文件

### 3. 字体配置
- 中文：Noto Serif CJK SC
- 日文：Noto Serif CJK JP
- 代码：Noto Sans Mono CJK *

---

## 完整工作流程

```bash
# 1. 转换 GFM → pandoc 格式
bash scripts/gfm2pdf.sh docs/input /tmp/gfm2pdf

# 2. 合并文件
bash scripts/combine-md.sh /tmp/gfm2pdf /tmp/book.md

# 3. 生成 PDF
pandoc /tmp/book.md \
  -o output.pdf \
  --pdf-engine=xelatex \
  -V mainfont="Noto Serif CJK SC" \
  -V monofont="Noto Sans Mono CJK SC"

# 4. 清理
rm -rf /tmp/gfm2pdf /tmp/book.md
```
