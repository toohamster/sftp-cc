# 第 3 章：编写第一个 Skill

> "文档即代码，代码即文档。" — 现代软件开发理念

本章你将学到：
- SKILL.md 的完整结构和每个部分的作用
- YAML Frontmatter 的必填字段和可选字段
- 触发词设计的 advanced 技巧
- 如何让 Claude 正确理解并执行脚本
- 编写用户友好的首次使用引导
- Skill 调试和验证方法
- 实战：从零编写一个完整的 Skill

---

## 3.1 SKILL.md 完整结构

### 3.1.1  Anatomy of SKILL.md

SKILL.md 是一个特殊的 Markdown 文件，它由三个核心部分组成：

```
┌─────────────────────────────────────────────────────────┐
│                    SKILL.md 结构                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌───────────────────────────────────────────────────┐ │
│  │  Part 1: YAML Frontmatter（元数据）               │ │
│  │  ---                                              │ │
│  │  name: sftp-cc                                    │ │
│  │  description: 通用 SFTP 上传工具                   │ │
│  │  ---                                              │ │
│  └───────────────────────────────────────────────────┘ │
│                                                         │
│  ┌───────────────────────────────────────────────────┐ │
│  │  Part 2: 触发词定义（Intent Triggers）            │ │
│  │  ## When to trigger this Skill                    │ │
│  │  - "sync code to server"                          │ │
│  │  - "同步代码到服务器"                              │ │
│  └───────────────────────────────────────────────────┘ │
│                                                         │
│  ┌───────────────────────────────────────────────────┐ │
│  │  Part 3: 执行指引（Execution Instructions）       │ │
│  │  ## 可用脚本                                       │ │
│  │  ```bash                                          │ │
│  │  bash ${CLAUDE_PLUGIN_ROOT}/scripts/...          │ │
│  │  ```                                              │ │
│  └───────────────────────────────────────────────────┘ │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 3.1.2 完整示例解析

让我们逐行分析一个生产级的 SKILL.md：

````markdown
---
name: sftp-cc
description: 通用 SFTP 上传工具，通过自然语言触发，将本地项目文件上传到远程服务器。支持增量上传、私钥自动绑定与权限修正。
---
````

**YAML Frontmatter 解析**：
- `name`: Skill 的唯一标识符，用于内部引用
- `description`: 出现在 Skill 列表中的描述，影响用户是否选择使用

```markdown
# SFTP Push Skill — sftp-cc

> 通用 SFTP 上传工具，支持私钥自动绑定与权限修正。
```

**标题和简介**：
- H1 标题：人类可读的 Skill 名称
- 引用块：一句话简介，快速说明核心价值

```markdown
## When to trigger this Skill / 什么时候触发此 Skill

**SFTP 上传/部署类**:
- "sync code to server", "upload to server", "upload files to server"
- "deploy code", "deploy to server", "send files to server"
- "sftp upload", "sftp sync", "sftp transfer"
- "同步代码到服务器"、"上传到服务器"、"上传文件到服务器"
- "部署代码"、"把文件传到服务器上"
- "sftp 上传"、"sftp 同步"
```

**触发词分组设计**：
- 按语义分组（上传类、绑定类、初始化类）
- 多语言覆盖（英文、中文、日文）
- 同义词覆盖（sync/upload/deploy 都表示上传）

```markdown
**私钥绑定类**:
- "bind sftp private key", "bind ssh key", "sftp keybind"
- "绑定 SFTP 私钥"、"绑定私钥"、"自动绑定私钥"
- "秘密鍵をバインドする", "SSH 鍵をバインドする"
- "sftp-keybind"
```

```markdown
**Important / 注意**：Do NOT treat "push" as a trigger — it conflicts with git push.
Only trigger when the user explicitly mentions SFTP or server upload/sync/deploy.
不要将 "push"、"推送" 视为触发条件，避免与 git push 冲突。
```

**负向约束（Negative Constraints）**：
- 明确告诉 Claude **不要**做什么
- 使用双语（英文 + 中文）确保理解
- 解释原因（与 git push 冲突）

```markdown
## 配置文件位置

- **配置文件**: `<项目根目录>/.claude/sftp-cc/sftp-config.json`
- **私钥存放**: `<项目根目录>/.claude/sftp-cc/` 目录下
- **脚本位置**: `${CLAUDE_PLUGIN_ROOT}/scripts/`

**注意**：`${CLAUDE_PLUGIN_ROOT}` 是 Claude Code 注入的 Skill 内部变量，仅在 Skill 上下文中有效。
执行脚本时，Claude 会自动将其解析为插件根目录路径（如 `~/.claude/plugins/marketplaces/sftp-cc/`）。
```

**路径说明**：
- 明确所有相关文件的位置
- 特别说明变量注入机制
- 使用代码块突出路径

```markdown
## 可用脚本

### 1. sftp-init.sh — 初始化配置
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-init.sh \
  --host example.com \
  --port 22 \
  --username deploy \
  --remote-path /var/www/html
```

### 2. sftp-keybind.sh — 私钥自动绑定
**当用户请求绑定私钥时，执行此脚本。**
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-keybind.sh
```

### 3. sftp-push.sh — 上传文件
```bash
# 增量上传（默认）
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh

# 全量上传
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh --full
```
```

**脚本执行指引**：
- 每个脚本都有独立的章节
- **关键技巧**：添加明确的执行条件说明
- 展示常用参数组合

````markdown
## 首次使用引导流程

当用户首次请求 SFTP 操作时，按以下步骤引导：

1. **检查配置是否存在**: 查看 `.claude/sftp-cc/sftp-config.json` 是否存在
2. **如果不存在**: 询问用户服务器信息，然后运行 `sftp-init.sh`
3. **部署公钥到服务器**: 在本地终端运行 `sftp-copy-id.sh`
4. **检查私钥**: 查看 `.claude/sftp-cc/` 下是否有私钥文件
5. **执行上传**: 运行 `sftp-push.sh`
````

**用户引导流程**：
- 分步骤说明（1, 2, 3...）
- 每步都有明确的检查点
- 包含故障排查指引

---

## 3.2 YAML Frontmatter 详解

### 3.2.1 必填字段

```yaml
---
name: sftp-cc
description: 通用 SFTP 上传工具
---
```

#### name 字段

| 属性 | 说明 |
|------|------|
| 类型 | string |
| 必填 | 是 |
| 格式 | 小写字母 + 连字符 |
| 长度 | 建议不超过 20 字符 |
| 唯一性 | 在 Marketplace 中必须唯一 |

**命名最佳实践**：

```yaml
# ✅ 好的命名
name: sftp-cc           # 简洁、有意义
name: github-helper     # 清晰的功能描述
name: db-backup         # 动词 + 名词结构

# ❌ 差的命名
name: MyCoolSkill       # 驼峰命名（不符合约定）
name: sftp_cc_toomaster # 下划线分隔（不推荐）
name: skill-1           # 无意义
```

#### description 字段

| 属性 | 说明 |
|------|------|
| 类型 | string |
| 必填 | 是 |
| 长度 | 建议 20-100 字符 |
| 位置 | 出现在 Skill 列表 |

**撰写技巧**：

```yaml
# ✅ 好的描述
description: 通用 SFTP 上传工具，通过自然语言触发，将本地项目文件上传到远程服务器
# 包含：是什么 + 如何触发 + 核心功能

description: 自动备份数据库到云存储，支持定时任务和增量备份
# 包含：功能 + 特性

# ❌ 差的描述
description: 一个工具  # 太简短，信息量不足
description: 这是一个非常强大的、功能丰富的、业界领先的 SFTP 上传工具，支持多种协议...  # 太长，营销语言
```

### 3.2.2 可选字段（未来扩展）

虽然当前版本只要求 name 和 description，但了解可能的扩展字段有帮助：

```yaml
---
name: sftp-cc
description: 通用 SFTP 上传工具

# 未来可能支持的字段
version: 2.2.0              # Skill 版本
author: toohamster          # 作者
license: MIT                # 开源协议
tags:                       # 标签（用于搜索）
  - sftp
  - upload
  - deploy
homepage: https://github.com/toohamster/sftp-cc  # 项目主页
---
```

### 3.2.3 YAML 语法检查

常见的 YAML 错误及避免方法：

```yaml
# ❌ 错误：冒号后缺少空格
---
name:sftp-cc
description:通用 SFTP 上传工具
---

# ✅ 正确
---
name: sftp-cc
description: 通用 SFTP 上传工具
---
```

```yaml
# ❌ 错误：缩进不一致
---
name: sftp-cc
  description: 通用 SFTP 上传工具
---

# ✅ 正确
---
name: sftp-cc
description: 通用 SFTP 上传工具
---
```

```yaml
# ❌ 错误：特殊字符未转义
---
description: 使用 ${VAR} 变量
---

# ✅ 正确
---
description: '使用 ${VAR} 变量'  # 使用引号包裹
---
```

---

## 3.3 触发词设计高级技巧

### 3.3.1 触发词分层设计

将触发词分为三个层次，覆盖不同用户表达习惯：

```
层次 1：直接命令（Explicit Commands）
- "sync code to server"
- "上传代码"
- "デプロイして"

层次 2：场景描述（Scenario Description）
- "我需要把代码传到测试服务器"
- "测试环境需要更新代码了"
- "让服务器上的代码和本地一致"

层次 3：问题表述（Problem Statement）
- "服务器上的代码是旧的"
- "如何部署到测试环境？"
- "测试服务器没同步"
```

**实战应用**：

```markdown
## 触发词

**直接命令**:
- "sync code to server"
- "上传代码到服务器"

**场景描述**:
- "把刚才修改的代码传到服务器"
- "部署到测试环境验证一下"

**问题表述**:
- "服务器代码不是最新的"
- "怎么更新测试服务器的代码？"
```

### 3.3.2 语义扩展技巧

对于核心触发词，进行语义扩展以覆盖更多表达：

#### 同义词扩展

```
核心词：sync（同步）
扩展：synchronize, update, mirror, replicate

核心词：upload（上传）
扩展：push, send, transfer, deploy

核心词：server（服务器）
扩展：remote, production, staging, host
```

#### 句型变换

```
主动语态：
- "Sync code to server"
- "Upload files"

被动语态：
- "Code needs to be synced"
- "Files should be uploaded"

疑问句：
- "Can you sync the code?"
- "How do I upload files?"

祈使句：
- "Please sync the code"
- "Let's upload the changes"
```

### 3.3.3 避免触发词冲突

#### 与 Git 命令的冲突

```markdown
# ❌ 会冲突的触发词
- "push"          → git push
- "commit"        → git commit
- "pull"          → git pull

# ✅ 明确区分的触发词
- "sftp push"     → 明确是 SFTP
- "push to server"→ 明确目标是服务器
- "upload files"  → 与 Git 无关
```

#### 与系统命令的冲突

```markdown
# ❌ 会冲突的触发词
- "ls"            → 列出文件
- "cd"            → 切换目录
- "cat"           → 查看文件

# ✅ 解决方案
使用完整表达而非命令缩写：
- "list files" 而非 "ls"
- "change directory" 而非 "cd"
```

### 3.3.4 多语言触发词设计

#### 英文触发词

```markdown
**核心触发词**:
- "sync code to server"
- "upload to server"
- "deploy code"

**变体表达**:
- "sync changes"
- "push updates"
- "send files"
```

#### 中文触发词

```markdown
**核心触发词**:
- "同步代码到服务器"
- "上传到服务器"
- "部署代码"

**变体表达**:
- "同步一下代码"
- "把文件传上去"
- "发布到服务器"
```

#### 日文触发词

```markdown
**核心触发词**:
- "サーバーに同期する"
- "コードをデプロイする"
- "アップロード"

**变体表达**:
- "変更を同期"
- "サーバーに送信"
```

---

## 3.4 脚本执行指引

### 3.4.1 为什么需要明确的执行指引？

Claude 是一个 AI 模型，它需要明确的指示来理解何时执行哪个脚本。

**问题场景**：

```
用户："绑定 SFTP 私钥"

没有明确指引时 Claude 的思考：
1. 用户想要绑定私钥
2. 但是应该执行哪个脚本？
3. sftp-init.sh? sftp-push.sh? sftp-keybind.sh?
4. 不确定，可能需要询问用户
```

**解决后**：

```markdown
### sftp-keybind.sh — 私钥自动绑定

**当用户请求绑定私钥时，执行此脚本。**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-keybind.sh
```
```

现在 Claude 知道：
1. "绑定私钥" → 执行 sftp-keybind.sh
2. 不需要询问用户
3. 直接执行

### 3.4.2 执行指引的编写格式

#### 标准格式

```markdown
### 脚本名称 — 功能简述

**当用户 <条件> 时，执行此脚本。**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/脚本名称.sh
```

功能说明：
- 功能点 1
- 功能点 2
- 功能点 3

常用参数：
- `--full` - 全量模式
- `-n` - 预览模式
```

#### 完整示例

```markdown
### sftp-push.sh — 文件上传

**当用户请求上传文件、同步代码到服务器时，执行此脚本。**

```bash
# 默认：增量上传
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh

# 全量上传
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh --full

# 预览模式
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh -n
```

功能说明：
- 检测自上次上传后的文件变更
- 只上传变更的文件（增量）
- 支持全量上传和指定文件上传
- 预览模式可查看所有将执行的操作

常用参数：
- `--full` - 全量上传所有文件
- `-n` / `--dry-run` - 预览模式，不实际上传
- `-d DIR` - 上传指定目录
- `--delete` - 同步删除远程已删除的文件
```

### 3.4.3 多脚本触发逻辑

当一个 Skill 有多个脚本时，需要明确触发条件：

```markdown
## 脚本触发对应关系

| 用户指令 | 执行脚本 | 说明 |
|---------|----------|------|
| "同步代码到服务器" | sftp-push.sh | 上传文件 |
| "绑定私钥" | sftp-keybind.sh | 绑定 SSH 密钥 |
| "初始化配置" | sftp-init.sh | 创建配置文件 |
| "部署公钥" | sftp-copy-id.sh | 部署到服务器 |
```

### 3.4.4 参数传递说明

#### 固定参数

```markdown
执行时始终传递这些参数：
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-init.sh \
  --host $HOST \
  --port 22 \
  --username $USERNAME
```
```

#### 条件参数

````markdown
如果用户请求全量上传，添加 `--full` 参数：
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh --full
```
````

#### 用户输入参数

```markdown
如果用户指定了文件，将文件路径作为参数：
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh file1.php file2.php
```
```

---

## 3.5 用户引导流程设计

### 3.5.1 为什么需要引导流程？

首次使用 Skill 的用户可能不知道：
1. 需要配置什么
2. 配置文件在哪里
3. 第一步做什么
4. 遇到问题怎么办

引导流程帮助 Claude 系统地帮助用户完成设置。

### 3.5.2 引导流程的编写

#### 标准格式

````markdown
## 首次使用引导

当用户首次请求 <功能> 时，按以下步骤引导：

1. **检查 <条件 1>**: <检查方法>
2. **如果 <条件 1 不满足>**: <操作>
3. **检查 <条件 2>**: <检查方法>
4. **执行 <操作>**: <命令>
````

#### 完整示例

```markdown
## 首次使用 SFTP 引导流程

当用户首次请求 SFTP 操作时，按以下步骤引导：

**步骤 1：检查配置**
- 查看 `.claude/sftp-cc/sftp-config.json` 是否存在
- 如果不存在，进入步骤 2
- 如果存在，跳到步骤 4

**步骤 2：初始化配置**
- 询问用户以下信息：
  - SFTP 服务器地址
  - 登录用户名
  - 远程目标路径
- 运行 `sftp-init.sh` 创建配置

**步骤 3：部署公钥**
- 指导用户在本地终端运行 `sftp-copy-id.sh`
- 这需要输入服务器密码

**步骤 4：检查私钥**
- 查看 `.claude/sftp-cc/` 下是否有私钥文件
- 如果没有，指导用户放置私钥
- 运行 `sftp-keybind.sh` 绑定私钥

**步骤 5：执行上传**
- 运行 `sftp-push.sh` 上传文件
- 或使用触发词让 Claude 自动执行
```

### 3.5.3 错误处理引导

```markdown
## 常见问题处理

**问题 1：配置文件不存在**
```
症状：错误提示 "Configuration file not found"
解决：
1. 运行 `bash scripts/sftp-init.sh`
2. 按提示填写服务器信息
```

**问题 2：私钥权限错误**
```
症状：错误提示 "Permissions 0644 for 'id_rsa' are too open"
解决：
1. 运行 `bash scripts/sftp-keybind.sh`
2. 脚本会自动修正权限为 600
```

**问题 3：SFTP 连接失败**
```
症状：错误提示 "Connection refused" 或 "Connection timed out"
解决：
1. 检查服务器地址和端口是否正确
2. 检查网络连接
3. 确认服务器 SSH 服务运行中
```
```

---

## 3.6 调试与验证

### 3.6.1 验证 SKILL.md 语法

#### 检查 YAML Frontmatter

```bash
# 查看前 5 行（YAML 部分）
head -5 skills/sftp-cc/SKILL.md

# 验证 YAML 格式（需要 yq 工具）
yq eval '.' skills/sftp-cc/SKILL.md
```

#### 检查 Markdown 格式

```bash
# 使用 markdownlint（需要安装）
markdownlint skills/sftp-cc/SKILL.md

# 或使用 prettier
npx prettier --check skills/sftp-cc/SKILL.md
```

### 3.6.2 测试触发词

#### 本地测试流程

```
1. 安装 Plugin
   /plugin marketplace add /path/to/sftp-cc

2. 在 Claude Code 中测试触发词
   用户：同步代码到服务器

3. 观察是否正确触发 Skill 并执行脚本

4. 如果不触发：
   - 检查触发词是否在 SKILL.md 中定义
   - 检查 Plugin 是否正确安装
   - 重新加载 Plugin
```

#### 测试用例清单

| 触发词 | 预期脚本 | 测试结果 |
|--------|----------|----------|
| "sync code to server" | sftp-push.sh | ⬜ |
| "同步代码到服务器" | sftp-push.sh | ⬜ |
| "绑定私钥" | sftp-keybind.sh | ⬜ |
| "初始化配置" | sftp-init.sh | ⬜ |
| "push" | 不触发 | ⬜ |

### 3.6.3 调试技巧

#### 添加调试输出

在脚本中添加详细输出帮助调试：

```bash
#!/bin/bash
# 在脚本开头添加
echo "[DEBUG] CLAUDE_PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT}"
echo "[DEBUG] PWD=$PWD"
echo "[DEBUG] CONFIG_FILE=$CONFIG_FILE"
```

#### 验证变量注入

```bash
# 测试脚本是否能正确解析路径
bash -x ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh 2>&1 | head -20
```

---

## 3.7 实战：从零编写 Skill

### 3.7.1 场景设定

假设我们要创建一个 Weather Skill，可以查询天气：

```
功能：查询指定城市的天气
触发词："天气怎么样"、"what's the weather"
脚本：weather.sh（调用 wttr.in API）
```

### 3.7.2 步骤 1：创建目录结构

```bash
mkdir -p my-weather-skill/{.claude-plugin,skills/weather,scripts,templates}
cd my-weather-skill
```

### 3.7.3 步骤 2：创建 marketplace.json

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "weather-skill",
  "description": "Query weather information via natural language",
  "owner": {
    "name": "your-name"
  },
  "plugins": [
    {
      "name": "weather-skill",
      "description": "Weather query Skill",
      "source": "./",
      "strict": false,
      "skills": ["./skills/weather"]
    }
  ]
}
```

### 3.7.4 步骤 3：创建 SKILL.md

````markdown
---
name: weather-skill
description: Query weather information via natural language
---

# Weather Skill

通过自然语言查询天气信息。

## When to trigger this Skill

**天气查询类**:
- "what's the weather", "weather forecast", "how's the weather"
- "天气怎么样", "今天天气", "查一下天气"
- "天気は？", "予報"

**执行脚本**:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/weather.sh [城市名]
```

如果用户没有指定城市，默认查询北京。

## 配置说明

配置文件（可选）：`<项目根目录>/.claude/weather-skill/config.json`

```json
{
  "default_city": "Beijing",
  "unit": "metric"
}
```

## 首次使用

直接询问天气即可，例如：
- "今天天气怎么样？"
- "what's the weather in Tokyo?"
````

### 3.7.5 步骤 4：创建 weather.sh 脚本

```bash
#!/bin/bash
# weather.sh — Query weather from wttr.in API

set -euo pipefail

# 获取城市参数（默认北京）
CITY="${1:-Beijing}"

# 调用 wttr.in API
# format=3 返回简洁格式
curl "wttr.in/$CITY?format=3"

# 输出示例：
# Beijing: 🌤 +25°C
```

### 3.7.6 步骤 5：测试

```bash
# 添加执行权限
chmod +x scripts/weather.sh

# 本地测试
bash scripts/weather.sh Tokyo
# 输出：Tokyo: ☀️ +28°C

# 安装 Plugin 测试
/plugin marketplace add /path/to/my-weather-skill

# 在 Claude Code 中测试
# 用户：今天天气怎么样？
# Claude: [调用 weather-skill]
# Beijing: 🌤 +25°C
```

---

## 3.8 常见问题解答

### Q1: Skill 不触发怎么办？

**排查步骤**：
1. 检查触发词是否在 SKILL.md 中定义
2. 确认 Plugin 已正确安装：`/plugin list`
3. 重新安装 Plugin：`/plugin marketplace remove <name>` 然后重新 add
4. 检查触发词是否太泛化（如单个词 "push"）

### Q2: 如何调试脚本执行？

**方法**：
```bash
# 在脚本开头添加 set -x
#!/bin/bash
set -x

# 或在执行时添加
bash -x script.sh
```

### Q3: ${CLAUDE_PLUGIN_ROOT} 为空怎么办？

**原因**：这个变量只在 Skill 上下文中由 Claude 注入。

**解决**：
- 在 Skill 中使用时会自动注入，无需担心
- 直接在 Shell 中测试时使用绝对路径

### Q4: 多个脚本如何选择执行？

**方法**：
1. 在 SKILL.md 中明确每个脚本的触发条件
2. 使用加粗强调：**当用户请求 X 时，执行此脚本**
3. 提供触发词 - 脚本对应关系表

---

## 3.9 本章总结

### 核心知识点回顾

| 概念 | 关键点 |
|------|--------|
| YAML Frontmatter | name（唯一标识）、description（列表展示） |
| 触发词设计 | 分层设计、语义扩展、避免冲突 |
| 执行指引 | 明确条件、完整命令、参数说明 |
| 用户引导 | 分步骤、检查点、故障处理 |
| 调试验证 | 语法检查、触发测试、日志输出 |

### SKILL.md 检查清单

在发布前确认：

- [ ] YAML Frontmatter 格式正确
- [ ] name 和 description 已填写
- [ ] 触发词覆盖多种表达
- [ ] 触发词避免与常见命令冲突
- [ ] 每个脚本有明确的执行条件
- [ ] 提供完整的使用示例
- [ ] 包含首次使用引导
- [ ] 包含常见问题处理

---

## 3.10 练习与实践

### 基础练习

**练习 3-1**：修改 Weather Skill
- 添加日文触发词
- 添加默认城市配置

**练习 3-2**：添加错误处理
- 当 API 返回错误时的处理
- 当网络不可用时的提示

### 进阶练习

**练习 3-3**：创建 Backup Skill
- 触发词："backup project"、"备份项目"
- 功能：将项目目录打包备份到指定位置
- 支持增量备份

### 实践项目

创建一个对你实际工作有用的 Skill，包含：
- 完整的 SKILL.md
- 至少 3 个脚本
- 多语言触发词
- 用户引导流程

---

## 下一章预告

第 4 章将带你进行**脚本开发实战**：
- Shell 脚本结构模板
- 纯 Shell JSON 解析（不依赖 jq）
- 完善的错误处理
- 临时文件管理
- 实战：sftp-keybind.sh 完整代码解析

---

## 关于本书

**第一版（数字版）, 2026 年 3 月**

**作者**：[toohamster](https://github.com/toohamster)
**授权**：电子版 MIT License，纸质版/商业版 © All Rights Reserved
**源码**：[github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

详细说明请参阅 [LICENSE](../../LICENSE) 和 [关于作者](../authors.md)

---
