# 动手写 Claude Code Skill

> 基于 sftp-cc 项目开发经验的实战指南

**副标题**：从零开始构建你的第一个 Claude Code Plugin

---

## 多语言版本

| 语言 | 版本 | 链接 |
|------|------|------|
| 中文 | 简体中文 | [中文版](README.md) |
| English | English | [English Version](../en/README.md) |
| 日本語 | Japanese | [日本語版](../ja/README.md) |

---

## 本书目标

通过开发一个完整的 SFTP 上传工具（sftp-cc），带你掌握 Claude Code Skill 的开发全流程：
- 理解 Claude Code Plugin 架构
- 掌握 SKILL.md 编写技巧
- 学会多语言支持（i18n）
- 发布到 Plugin Marketplace

---

## 章节概览

| 章节 | 标题 | 核心内容 |
|------|------|----------|
| 第 1 章 | [认识 Claude Code Skill](chapter-01-introduction.md) | Plugin 架构、SKILL.md 结构、${CLAUDE_PLUGIN_ROOT} 变量解析 |
| 第 2 章 | [项目规划与设计](chapter-02-planning.md) | 需求分析、功能设计、目录结构规划 |
| 第 3 章 | [编写第一个 Skill](chapter-03-writing-skill.md) | SKILL.md 触发词设计、YAML frontmatter 配置 |
| 第 4 章 | [脚本开发实战](chapter-04-script-development.md) | Shell 脚本编写、JSON 解析、错误处理 |
| 第 5 章 | [多语言支持 (i18n)](chapter-05-internationalization.md) | 三语言方案设计、变量式多语言实现 |
| 第 6 章 | [调试与测试](chapter-06-debugging-and-testing.md) | 本地测试、Plugin 安装验证、问题排查 |
| 第 7 章 | [发布与分发](chapter-07-publishing-and-distribution.md) | GitHub Release、Marketplace 配置、版本管理 |
| 第 8 章 | [进阶与最佳实践](chapter-08-advanced-topics.md) | 常见问题、性能优化、用户反馈处理 |

---

## 开始阅读

**推荐顺序**：从第 1 章开始，按顺序阅读和实践。

也可以根据你的需求跳转到特定章节：
- 已有 Skill 想优化？→ 直接阅读 [第 5 章 (i18n)](chapter-05-internationalization.md)、[第 6 章 (调试)](chapter-06-debugging-and-testing.md)
- 准备发布？→ 跳转到 [第 7 章 (发布)](chapter-07-publishing-and-distribution.md)

---

## 前置要求

- 基础 Shell 脚本知识
- 了解 Git 基本操作
- 有 Claude Code 使用经验

---

## 项目源码

本书配套项目：https://github.com/toohamster/sftp-cc

```bash
# 克隆示例项目
git clone https://github.com/toohamster/sftp-cc.git

# 安装 Plugin
/plugin marketplace add https://github.com/toohamster/sftp-cc
```

---

## 关于作者

![Author Photo](https://avatars.githubusercontent.com/u/16458414?s=100&u=7fd7d3827bd4824339e1ee5bf098fb78725728ec&v=4)

**toohamster** - GitHub: [@toohamster](https://github.com/toohamster)

本书基于作者在开发 sftp-cc（Claude Code SFTP 上传工具）过程中的实战经验编写，包含大量真实踩坑记录。

详细说明请参阅 [关于作者](authors.md)

---

## 授权协议

### 电子版（GitHub 仓库）
**第一版（数字版）, 2026 年 3 月**

根据 [MIT License](../LICENSE) 授权。

- ✅ 免费阅读、复制、修改
- ✅ 个人学习使用
- ✅ 在 GitHub 等平台分享

### 纸制版/商业版
© 2026 toohamster. All Rights Reserved.

本图书的纸质版及商业电子版受版权法保护。未经出版者书面许可，
不得以任何形式复制或传播本书的任何部分。

---

© 2026 toohamster
