# 字体配置指南

## 必需字体

### CJK 字体（中日文）

| 用途 | 字体名 | Ubuntu 包名 | macOS 包名 |
|------|--------|-------------|------------|
| 中文正文 | Noto Serif CJK SC | fonts-noto-cjk | 系统自带 |
| 中文代码 | Noto Sans Mono CJK SC | fonts-noto-cjk | 系统自带 |
| 日文正文 | Noto Serif CJK JP | fonts-noto-cjk | 系统自带 |
| 日文代码 | Noto Sans Mono CJK JP | fonts-noto-cjk | 系统自带 |

### 英文字体（可选）

| 用途 | 字体名 | Ubuntu 包名 |
|------|--------|-------------|
| 正文 | Noto Serif | fonts-noto-core |
| 代码 | Noto Sans Mono | fonts-noto-mono |

## 安装命令

### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install -y fonts-noto-cjk
```

### macOS
```bash
# CJK 字体系统自带，无需安装
# 验证字体是否存在
fc-list | grep "Noto"
```

### Windows (WSL)
```bash
# 在 WSL2 中安装
sudo apt-get install -y fonts-noto-cjk
```

## pandoc 配置示例

### 中文 PDF
```bash
pandoc input.md -o output.pdf \
  --pdf-engine=xelatex \
  -V mainfont="Noto Serif CJK SC" \
  -V monofont="Noto Sans Mono CJK SC"
```

### 日文 PDF
```bash
pandoc input.md -o output.pdf \
  --pdf-engine=xelatex \
  -V mainfont="Noto Serif CJK JP" \
  -V monofont="Noto Sans Mono CJK JP"
```

### 多语言混排
```bash
# 使用 SC 字体作为主字体，日文会自动 fallback
pandoc input.md -o output.pdf \
  --pdf-engine=xelatex \
  -V mainfont="Noto Serif CJK SC" \
  -V monofont="Noto Sans Mono CJK SC"
```

## 字体验证

```bash
# 列出所有 Noto 字体
fc-list | grep "Noto"

# 检查特定字体
fc-match "Noto Serif CJK SC"
fc-match "Noto Sans Mono CJK SC"
```

## 常见问题

### Q: 字体安装后仍无法使用
**A**: 更新字体缓存
```bash
fc-cache -fv
```

### Q: macOS 提示字体不存在
**A**: macOS 字体名可能不同，尝试：
```bash
# 查找实际字体名
fc-list :lang=zh | head -10
```
