# 第 1 章：认识 Claude Code Skill

> "最好的工具是那些让你忘记它存在的工具。" — Alan Kay

本章你将学到：
- Claude Code Skill 是什么以及它能解决什么问题
- Plugin 架构的核心组件和工作原理
- 如何搭建完整的开发环境
- 亲手编写你的第一个 Hello World Skill

---

## 1.1 什么是 Claude Code Skill

### 1.1.1 Skill 的诞生背景

在软件开发的历史上，每一次开发体验的革新都带来了生产力的飞跃：

```
命令行 IDE (Vi/Emacs) → 图形 IDE (VS Code) → AI 辅助编码 (Claude Code)
       ↓                      ↓                        ↓
  纯文本编辑            可视化 + 插件              自然语言交互
```

Claude Code 是 Anthropic 推出的 CLI 编程助手，而 **Skill** 是它的插件系统。与传统的 IDE 插件不同，Skill 通过**自然语言触发**，让你可以用说话的方式调用自动化功能。

### 1.1.2 Skill 的正式定义

**Claude Code Skill** 是一个基于 Markdown 的插件定义格式，它告诉 Claude：
1. **何时触发** — 用户说什么话时应该调用这个 Skill
2. **如何执行** — 触发后运行什么脚本或命令
3. **提供什么能力** — Skill 能完成的具体功能

用代码来表达，一个 Skill 至少包含：
````markdown
---
name: my-skill
description: 我的第一个 Skill
---

# My Skill

当用户说 "你好" 时，执行：
```bash
echo "Hello, World!"
```
````

### 1.1.3 Skill 能做什么

Skill 的能力边界几乎等同于你的 Shell 能做的事情。以下是一些实际应用场景：

#### 文件操作类
| Skill | 触发词示例 | 用途 |
|-------|-----------|------|
| SFTP 上传 | "同步代码到服务器" | 将本地代码部署到远程服务器 |
| 文件同步 | "把配置同步到测试环境" | 多环境配置文件同步 |
| 备份工具 | "备份当前数据库" | 定时备份重要数据 |

#### 代码处理类
| Skill | 触发词示例 | 用途 |
|-------|-----------|------|
| 代码格式化 | "格式化这个文件" | 统一代码风格 |
| 批量重命名 | "把所有 .jsx 改成 .tsx" | 大规模文件重命名 |
| API 生成器 | "生成用户 CRUD API" | 根据模板生成代码 |

#### 外部集成类
| Skill | 触发词示例 | 用途 |
|-------|-----------|------|
| GitHub 操作 | "创建一个新的 release" | 调用 GitHub API |
| 部署通知 | "通知团队部署完成" | 发送 Slack/钉钉消息 |
| 文档生成 | "生成 API 文档" | 调用文档生成工具 |

### 1.1.4 与其他插件系统的对比

理解 Skill 的定位，最好的方式是与其他系统对比：

#### vs VS Code 扩展

| 对比维度 | Claude Code Skill | VS Code 扩展 |
|----------|-------------------|--------------|
| **触发方式** | 自然语言对话 | 点击按钮/快捷键/命令面板 |
| **开发语言** | Markdown + Shell/Python | TypeScript/JavaScript |
| **学习曲线** | 低（会写文档就会开发） | 高（需要理解 VS Code API） |
| **分发方式** | Git 仓库 URL | VS Code Marketplace |
| **运行环境** | Claude Code CLI | VS Code 渲染进程 |
| **调试方式** | 查看脚本输出 | DevTools + 断点调试 |
| **典型开发时间** | 30 分钟 | 数天到数周 |

**何时选择 Skill**：
- ✅ 需要快速实现自动化脚本
- ✅ 功能可以通过命令行完成
- ✅ 希望用自然语言触发

**何时选择 VS Code 扩展**：
- ✅ 需要 UI 界面交互
- ✅ 需要深度集成 VS Code 功能（如调试器、终端）
- ✅ 需要复杂的用户配置界面

#### vs JetBrains Plugin

| 对比维度 | Claude Code Skill | JetBrains Plugin |
|----------|-------------------|------------------|
| **开发复杂度** | 文档格式 | Java/Kotlin + 复杂 API |
| **跨 IDE 兼容** | 是（只要有 Claude Code） | 否（每个 IDE 单独开发） |
| **用户获取成本** | `/plugin add <url>` | Marketplace 搜索安装 |

### 1.1.5 实际案例：sftp-cc 的诞生

让我分享一个真实案例。sftp-cc 是一个 SFTP 上传工具，它的诞生源于一个简单痛点：

> "当我在 Claude Code 中修改代码后，需要手动到测试服务器拉取代码，效率很低。"

从想法到可用的 Skill，整个过程只用了 2 小时：
1. **设计触发词**（10 分钟）：确定 "sync code to server"、"同步代码到服务器" 等触发语
2. **编写 SKILL.md**（20 分钟）：定义 Skill 结构和执行逻辑
3. **开发脚本**（60 分钟）：sftp-push.sh 实现上传逻辑
4. **测试调试**（30 分钟）：在 Claude 对话框中测试触发

这个案例告诉我们：**Skill 开发的核心是脚本能力，而非插件框架本身。**

---

## 1.2 Claude Code Plugin 架构

### 1.2.1 完整目录结构解析

一个完整的 Plugin 项目结构如下：

```
my-plugin/
├── .claude-plugin/
│   └── marketplace.json      # Plugin 元数据（用于 Marketplace 分发）
├── skills/
│   └── my-skill/
│       └── SKILL.md          # Skill 定义文件（核心）
├── scripts/
│   ├── deploy.sh             # 部署脚本
│   ├── backup.py             # Python 脚本（也可以）
│   └── utils/
│       └── helpers.sh        # 工具函数库
├── templates/
│   └── config.example.json   # 配置文件模板
└── README.md                 # 使用说明
```

### 1.2.2 marketplace.json 详解

这是 Plugin 在 Marketplace 中的"身份证"：

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "sftp-cc",
  "description": "Universal SFTP upload tool for Claude Code",
  "owner": {
    "name": "toohamster"
  },
  "plugins": [
    {
      "name": "sftp-cc",
      "description": "支持增量上传的 SFTP 工具",
      "source": "./",
      "strict": false,
      "skills": [
        "./skills/sftp-cc"
      ]
    }
  ]
}
```

**字段详解**：

| 字段 | 必填 | 说明 | 示例 |
|------|------|------|------|
| `$schema` | 是 | JSON Schema 验证 | 指向官方 schema |
| `name` | 是 | Plugin 唯一标识 | `sftp-cc` |
| `description` | 是 | 出现在 Marketplace 列表 | 简洁描述功能 |
| `owner.name` | 是 | 作者/组织名称 | GitHub 用户名 |
| `plugins[].source` | 是 | 源码根目录（相对路径） | `./` 表示当前目录 |
| `plugins[].strict` | 否 | 严格模式（安全限制） | `false` 允许脚本执行 |
| `plugins[].skills` | 是 | Skill 目录数组 | 可包含多个 Skill |

### 1.2.3 SKILL.md 深度解析

SKILL.md 是 Skill 的灵魂，它由三部分组成：

````markdown
---
name: sftp-cc
description: 通用 SFTP 上传工具
---

# 标题和简介

## 触发词定义

当用户说以下内容时触发：
- "sync code to server"
- "同步代码到服务器"

## 执行指引

执行以下脚本：
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh
```
````

**详细结构说明**（第 3 章会深入讲解）：

| 部分 | 位置 | 作用 |
|------|------|------|
| YAML Frontmatter | 文件开头 `---` 之间 | 定义元数据 |
| Markdown 正文 | YAML 之后 | 人类可读的说明 |
| 触发词 | 正文特定章节 | 匹配用户输入 |
| 执行脚本 | 正文特定章节 | 实际执行的命令 |

### 1.2.4 ${CLAUDE_PLUGIN_ROOT} 变量机制

这是新手最容易困惑的地方，让我们彻底搞懂它。

#### 变量注入原理

```
┌─────────────────────────────────────────────────────────┐
│  Claude Code 执行流程                                    │
├─────────────────────────────────────────────────────────┤
│  1. 用户输入："同步代码到服务器"                          │
│  2. Claude 识别意图，匹配到 sftp-cc Skill               │
│  3. 加载 SKILL.md                                        │
│  4. 注入环境变量：                                       │
│     ${CLAUDE_PLUGIN_ROOT} → ~/.claude/plugins/.../sftp-cc/ │
│  5. 执行脚本：bash ${CLAUDE_PLUGIN_ROOT}/scripts/...   │
│  6. 输出结果给 Claude                                    │
└─────────────────────────────────────────────────────────┘
```

#### 路径解析示例

假设你的 Plugin 安装在：
- Plugin 安装路径：`~/.claude/plugins/marketplaces/sftp-cc/`

那么在 SKILL.md 中：
````markdown
${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh
````

实际会被解析为：
```bash
~/.claude/plugins/marketplaces/sftp-cc/scripts/sftp-push.sh
```

#### 常见误区

**误区 1**：以为在 Shell 中也能用
```bash
# 错误：在普通 Shell 中，变量为空
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh
# 实际执行：bash /scripts/sftp-push.sh （路径错误）

# 正确：使用绝对路径
bash ~/.claude/plugins/marketplaces/sftp-cc/scripts/sftp-push.sh
```

**误区 2**：以为是运行时动态获取
```markdown
<!-- 错误理解：以为Claude会执行命令获取路径 -->
${CLAUDE_PLUGIN_ROOT} = $(git rev-parse --show-toplevel)

<!-- 正确理解：静态替换，在加载时完成 -->
${CLAUDE_PLUGIN_ROOT} → /path/to/plugin
```

### 1.2.5 scripts/ 目录最佳实践

#### 脚本组织方式

```
scripts/
├── main.sh                 # 主入口脚本
├── utils/
│   ├── logger.sh           # 日志工具
│   ├── json.sh             # JSON 解析工具
│   └── validator.sh        # 参数验证
├── commands/
│   ├── upload.sh           # 上传命令
│   ├── sync.sh             # 同步命令
│   └── status.sh           # 状态检查
└── i18n/
    ├── en.sh               # 英文消息
    ├── zh.sh               # 中文消息
    └── ja.sh               # 日文消息
```

#### 脚本可移植性考虑

```bash
#!/bin/bash
# 好的实践：兼容性检查

# 检查 Bash 版本
if [[ ${BASH_VERSION%%.*} -lt 4 ]]; then
    echo "需要 Bash 4.0+" >&2
    exit 1
fi

# 检查必需命令
for cmd in git sftp grep sed; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "缺少命令：$cmd" >&2
        exit 1
    fi
done
```

---

## 1.3 Skill 工作原理

### 1.3.1 完整的执行时序

让我们用 sftp-cc 为例，看看从用户输入到文件上传完成的完整流程：

```
用户                         Claude Code                      系统
 │                              │                              │
 ├──"同步代码到服务器"─────────→│                              │
 │                              │                              │
 │                              │ 1. NLU 意图识别              │
 │                              │    → SFTP_UPLOAD             │
 │                              │                              │
 │                              │ 2. Skill 匹配                │
 │                              │    → sftp-cc                 │
 │                              │                              │
 │                              │ 3. 加载 SKILL.md             │
 │                              │    → 解析 YAML               │
 │                              │    → 注入变量                │
 │                              │                              │
 │                              │ 4. 执行脚本 ────────────────→│
 │                              │    bash sftp-push.sh         │
 │                              │                              │
 │                              │ ←─────────────────────────── │
 │                              │    脚本输出（stdout/stderr）  │
 │                              │                              │
 │ ←──────────────────────────  │                              │
 │    "已上传 15 个文件到服务器"    │                              │
 │                              │                              │
```

### 1.3.2 意图识别机制

Claude 如何理解"同步代码到服务器"是要调用 SFTP Skill？

#### 触发词匹配策略

SKILL.md 中定义的触发词会被用于意图匹配：

````markdown
**触发词**:
- "sync code to server"
- "同步代码到服务器"
- "サーバーにコードを同期する"
````

Claude 的 NLU（自然语言理解）模块会：
1. **分词和词性标注**：将句子分解为有意义的单元
2. **语义分析**：识别核心动词（sync/同步）和目标（server/服务器）
3. **意图分类**：映射到预定义的意图类别
4. **Skill 匹配**：找到最匹配的 Skill

#### 提高匹配准确率的方法

1. **覆盖多种表达方式**
```markdown
- "sync code to server"      # 标准表达
- "upload changes"           # 变体
- "deploy to staging"        # 场景化表达
- "把代码同步到服务器"        # 中文
```

2. **避免歧义**
```markdown
<!-- 不好：太泛化 -->
- "push"                     # 可能与 git push 冲突

<!-- 更好：明确上下文 -->
- "sftp push"                # 明确是 SFTP
- "push to server"           # 明确目标
```

3. **提供否定示例**（在文档中说明）
```markdown
**不会触发的情况**:
- "git push" — 这是 Git 操作
- "push notification" — 这是推送通知
```

### 1.3.3 脚本执行环境

了解脚本在哪里运行很重要：

#### 运行位置
- **执行环境**：用户本地机器的 Shell
- **工作目录**：用户当前项目的根目录
- **权限**：当前用户的权限

#### 环境变量
除了 `${CLAUDE_PLUGIN_ROOT}`，脚本还可以访问：

| 变量 | 说明 |
|------|------|
| `PWD` | 当前工作目录 |
| `HOME` | 用户主目录 |
| `PATH` | 可执行文件搜索路径 |
| `USER` | 当前用户名 |

#### 输出处理

```bash
# 标准输出 → Claude 读取
echo "上传完成"

# 错误输出 → Claude 也会读取（用于调试）
echo "错误：配置不存在" >&2

# 建议：使用颜色区分
echo -e "\033[0;32m[info]\033[0m 上传完成"
echo -e "\033[0;31m[error]\033[0m 配置不存在" >&2
```

---

## 1.4 开发环境准备

### 1.4.1 安装 Claude Code

#### macOS（推荐）
```bash
# 使用 Homebrew
brew install claude-code

# 验证安装
claude --version
```

#### Linux
```bash
# 使用 npm（需要 Node.js 16+）
npm install -g @anthropic-ai/claude-code

# 验证安装
claude --version
```

#### Windows（WSL）
```bash
# 在 WSL2 中安装
# 1. 安装 Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# 2. 安装 Claude Code
npm install -g @anthropic-ai/claude-code
```

### 1.4.2 认证配置

首次使用需要登录：
```bash
claude login
```

这会打开浏览器，使用 Anthropic 账户登录。登录成功后会返回一个认证 token。

#### 认证文件位置
| 系统 | 路径 |
|------|------|
| macOS | `~/.claude/.claude-token` |
| Linux | `~/.claude/.claude-token` |
| Windows | `%USERPROFILE%\.claude\.claude-token` |

### 1.4.3 验证安装

运行以下命令确保一切正常：
```bash
# 检查版本
claude --version

# 检查登录状态
claude whoami

# 测试对话
claude "Hello, can you help me with a coding task?"
```

### 1.4.4 创建第一个项目

#### 项目初始化
```bash
# 创建项目目录
mkdir -p ~/projects/my-first-skill
cd ~/projects/my-first-skill

# 创建基本结构
mkdir -p .claude-plugin skills/hello-skill scripts
```

#### 初始化 Git（推荐）
```bash
git init
git checkout -b main

# 创建 .gitignore
cat > .gitignore << 'EOF'
# 敏感信息
*.key
*.pem
.env
.claude-token

# 临时文件
tmp/
*.log
EOF

git add .gitignore
git commit -m "Initial commit"
```

---

## 1.5 实战演练：Hello World Skill

让我们动手创建第一个可以运行的 Skill。

### 1.5.1 创建 marketplace.json

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "hello-skill",
  "description": "My first Claude Code Skill",
  "owner": {
    "name": "your-name"
  },
  "plugins": [
    {
      "name": "hello-skill",
      "description": "A simple hello world skill",
      "source": "./",
      "strict": false,
      "skills": ["./skills/hello-skill"]
    }
  ]
}
```

### 1.5.2 创建 SKILL.md

````markdown
---
name: hello-skill
description: 一个简单的打招呼 Skill
---

# Hello World Skill

这是我的第一个 Claude Code Skill。

## 触发词

当用户说以下内容时触发：
- "hello"
- "你好"
- "こんにちは"
- "打个招呼"
- "测试一下"

## 执行脚本

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/hello.sh
```
````

### 1.5.3 创建执行脚本

```bash
#!/bin/bash
# scripts/hello.sh

# 颜色定义
GREEN='\033[0;32m'
NC='\033[0m'

# 打招呼
echo -e "${GREEN}[hello]${NC} Hello, World!"
echo -e "${GREEN}[hello]${NC} 你好，世界！"
echo -e "${GREEN}[hello]${NC} こんにちは！"
echo ""
echo "恭喜你！你的第一个 Skill 已经可以运行了！"
```

#### 添加执行权限
```bash
chmod +x scripts/hello.sh
```

### 1.5.4 安装和测试

#### 方法 1：从本地目录安装
```bash
# 在 Claude Code 中
/plugin marketplace add ~/projects/my-first-skill
```

#### 方法 2：从 GitHub 安装（推送到 GitHub 后）
```bash
# 推送代码
git remote add origin https://github.com/your-user/hello-skill.git
git push -u origin main

# 在 Claude Code 中
/plugin marketplace add https://github.com/your-user/hello-skill
```

#### 测试触发
在 Claude Code 对话框中：
```
你：你好

Claude: [调用 hello-skill Skill]

[hello] Hello, World!
[hello] 你好，世界！
[hello] こんにちは！

恭喜你！你的第一个 Skill 已经可以运行了！
```

### 1.5.5 调试技巧

#### 查看 Skill 日志
```bash
# 查看 Plugin 安装状态
/plugin list

# 移除并重新安装
/plugin marketplace remove hello-skill
/plugin marketplace add ~/projects/my-first-skill
```

#### 脚本调试
```bash
# 在脚本开头添加调试模式
#!/bin/bash
set -x  # 打印执行的每一行

# ... 你的代码 ...
```

---

## 1.6 本章总结

### 核心知识点回顾

| 概念 | 关键点 |
|------|--------|
| Skill 是什么 | 基于 Markdown 的插件定义，通过自然语言触发 |
| 核心文件 | SKILL.md（定义）、marketplace.json（分发）、脚本（执行） |
| 变量机制 | ${CLAUDE_PLUGIN_ROOT} 在 Skill 上下文中自动注入 |
| 触发流程 | 用户输入 → 意图识别 → Skill 匹配 → 脚本执行 |
| 开发环境 | Claude Code CLI + 文本编辑器 + Git |

### 关键术语表

| 术语 | 英文 | 说明 |
|------|------|------|
| Skill | Skill | Claude Code 的插件单元 |
| Plugin | Plugin | 包含一个或多个 Skill 的完整包 |
| Marketplace | Marketplace | Plugin 分发平台 |
| 触发词 | Trigger phrase | 激活 Skill 的用户输入 |
| YAML Frontmatter | YAML Frontmatter | SKILL.md 开头的元数据 |

### 最佳实践清单

- [ ] 触发词要覆盖多种自然语言表达
- [ ] 脚本要有完善的错误处理
- [ ] 使用颜色区分日志级别
- [ ] 在 SKILL.md 中明确说明${CLAUDE_PLUGIN_ROOT}
- [ ] 使用 Git 管理版本

---

## 1.7 习题与实践项目

### 基础练习

**练习 1-1**：修改 Hello World
- 在 hello.sh 中添加用户的名字
- 根据当前时间输出不同的问候语（早上好/下午好/晚上好）

**练习 1-2**：多一个触发词
- 添加 "say hi" 作为触发词
- 测试是否能正确触发

### 进阶练习

**练习 1-3**：创建 Weather Skill
- 目标：创建一个查询天气的 Skill
- 要求：
  - 触发词："天气怎么样"、"what's the weather"
  - 脚本：调用天气 API（如 wttr.in）
  - 输出：格式化天气信息

参考答案：
```bash
#!/bin/bash
# scripts/weather.sh
CITY="${1:-Beijing}"
curl "wttr.in/$CITY?format=3"
```

### 实践项目

**项目 1-1**：个人工具 Skill
- 目标：解决你自己的一个实际需求
- 示例：
  - 快速备份脚本
  - 项目初始化模板
  - 常用命令封装

提交方式：
1. 创建 GitHub 仓库
2. 实现完整功能
3. 编写 README 说明

---

## 1.8 延伸资源

### 官方文档
- [Claude Code 官方文档](https://docs.anthropic.com/claude-code/)
- [Plugin Marketplace](https://claude.ai/marketplace)

### 示例项目
- [sftp-cc](https://github.com/toohamster/sftp-cc) - 本书配套项目
- [更多示例](https://github.com/topics/claude-code-skill)

### 进阶阅读
- 《Advanced Bash-Scripting Guide》- 深入学习 Shell 脚本
- 《Writing Secure Code》- 安全编程实践

---

## 下一章预告

第 2 章将带你进行**项目规划与设计**：
- 如何从痛点出发进行需求分析
- 功能边界的界定（做什么 vs 不做什么）
- 目录结构的最佳实践
- 配置文件的设计原则

在第 2 章结束时，你将完成 sftp-cc 项目的完整设计文档。

---

## 关于本书

**第一版（数字版）, 2026 年 3 月**

**作者**：[toohamster](https://github.com/toohamster)
**授权**：电子版 MIT License，纸质版/商业版 © All Rights Reserved
**源码**：[github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

详细说明请参阅 [LICENSE](../../LICENSE) 和 [关于作者](../authors.md)

---
