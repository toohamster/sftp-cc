# 第 2 章：项目规划与设计

> "如果你不能简单地描述它，你就没有真正理解它。" — Albert Einstein

本章你将学到：
- 如何从痛点出发进行需求分析
- 功能边界的界定方法（做什么 vs 不做什么）
- 模块化功能设计技巧
- 目录结构的最佳实践
- 配置文件的设计原则
- 触发词设计的方法论
- 技术选型的评估框架

---

## 2.1 需求分析

### 2.1.1 从痛点出发

好的软件始于真实的问题，而非技术本身。让我们记录开发 sftp-cc 的初衷：

#### 问题场景

```
场景：使用 Claude Code 进行 Web 项目开发

1. 开发者在本地使用 Claude Code 编写代码
2. Claude 修改了 src/user/controller.php
3. 需要到测试服务器验证功能
4. 手动操作：
   - 打开终端
   - ssh 登录测试服务器
   - git pull 拉取最新代码
   - 或者用 scp 上传修改的文件
5. 重复步骤 3-4 每次 Claude 修改代码后
```

#### 现有解决方案的不足

| 方案 | 优点 | 缺点 |
|------|------|------|
| PhpStorm SFTP | 自动同步、配置简单 | 需要购买 License、离开 Claude 环境 |
| 手动 scp | 无需额外工具 | 效率低、容易遗漏文件 |
| git + ssh | 标准流程 | 步骤繁琐、需要在服务器操作 |
| rsync 脚本 | 可自动化 | 需要编写和维护脚本 |

#### 机会点

```
如果 Claude Code 有一个 Skill 可以：
- 听懂"同步代码到服务器"这样的自然语言
- 自动检测哪些文件被修改了
- 只上传变更的文件（增量）
- 自动处理 SSH 密钥和权限

那将大大提升开发效率。
```

### 2.1.2 用户画像

在开始设计之前，明确谁会使用这个 Skill：

#### 主要用户：初级开发者小张

```
背景：2 年 PHP 开发经验
使用场景：
  - 日常在本地开发，需要部署到测试服务器验证
  - 每天部署 10-20 次
  - 对 Shell 脚本不熟悉
痛点：
  - 每次部署都要重复相同的命令
  - 有时会忘记上传某些文件
  - 配置 SSH 密钥时经常出错
期望：
  - 一句话完成部署
  - 自动处理配置和密钥
```

#### 次要用户：资深工程师 Lisa

```
背景：5 年 DevOps 经验
使用场景：
  - 同时管理多个项目的部署
  - 需要精细控制部署行为
  - 希望集成到现有工作流
痛点：
  - 每个项目的配置方式不一致
  - 需要查看详细的部署日志
期望：
  - 统一的配置格式
  - 详细的日志和错误信息
  - 支持自定义排除规则
```

### 2.1.3 需求清单

将用户需求转化为功能需求，并标注优先级：

#### 核心需求（Must Have）⭐⭐⭐

| 编号 | 需求 | 验收标准 |
|------|------|----------|
| M1 | 上传文件到服务器 | 能够将本地文件上传到指定 SFTP 服务器 |
| M2 | 增量上传 | 只上传变更的文件，而非全部重新上传 |
| M3 | 配置文件管理 | 有统一的配置文件存储连接信息 |
| M4 | 错误处理 | 连接失败、文件不存在等情况有明确提示 |
| M5 | 排除文件支持 | 可以配置哪些文件/目录不上传 |

#### 重要需求（Should Have）⭐⭐

| 编号 | 需求 | 验收标准 |
|------|------|----------|
| S1 | 私钥自动绑定 | 自动扫描并绑定项目中的 SSH 私钥 |
| S2 | 权限修正 | 自动将私钥权限设置为 600 |
| S3 | 指定文件上传 | 可以单独上传某个或某几个文件 |
| S4 | 预览模式 | 在实际上传前显示将执行的操作 |

#### 可选需求（Nice to Have）⭐

| 编号 | 需求 | 验收标准 |
|------|------|----------|
| N1 | 多语言支持 | 支持英文、中文、日文三种语言输出 |
| N2 | 指定目录上传 | 可以上传整个指定目录 |
| N3 | 删除同步 | 可选同步删除远程已删除的文件 |

### 2.1.4 功能边界

明确**不做什么**与明确**做什么**同样重要。

#### 不做的事情（Non-Goals）

| 功能 | 为什么不做 | 替代方案 |
|------|-----------|----------|
| 下载文件 | 单向同步已满足 90% 场景 | 直接用 sftp/scp |
| 实时监听文件变化 | 增加复杂度，与 Skill 模式不符 | 使用 IDE 插件 |
| 多服务器同时部署 | 配置复杂，使用场景少 | 多次执行或自定义脚本 |
| 版本回滚 | 超出 SFTP 范围 | 使用 Git 管理版本 |
| 文件比较/合并 | 功能过于复杂 | 使用 diff 工具 |
| 图形界面 | Skill 基于自然语言交互 | 不需要 UI |

#### 边界决策框架

当面临是否添加新功能的决策时，使用以下框架：

```
1. 核心用户使用频率？
   - 每天使用 → 考虑添加
   - 每周使用 → 谨慎评估
   - 偶尔使用 → 暂不添加

2. 实现复杂度？
   - 简单（< 4 小时） → 可以考虑
   - 中等（4-16 小时） → 需要充分理由
   - 复杂（> 16 小时） → 除非核心需求

3. 是否偏离核心价值？
   - 直接支持核心目标 → 优先
   - 间接支持 → 评估
   - 无关或分散 → 拒绝
```

### 2.1.5 用户故事

用用户故事的形式描述需求：

````markdown
作为 开发者
我想要 告诉 Claude"同步代码到服务器"
以便于 自动将修改的代码上传到测试服务器

作为 开发者
我想要 只上传变更的文件
以便于 节省上传时间

作为 开发者
我想要 自动处理 SSH 密钥
以便于 不需要手动配置权限

作为 开发者
我想要 配置哪些文件不上传
以便于 排除 .git、node_modules 等目录
````

---

## 2.2 功能设计

### 2.2.1 核心功能模块

将系统分解为独立的模块，每个模块有单一职责：

```
┌─────────────────────────────────────────────────────────┐
│                      sftp-cc                            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │  配置初始化   │  │   私钥绑定    │  │   公钥部署    │ │
│  │  sftp-init   │  │  sftp-keybind│  │ sftp-copy-id │ │
│  │              │  │              │  │              │ │
│  │ 创建配置目录 │  │ 扫描私钥文件 │  │ 部署公钥到   │ │
│  │ 生成配置文件 │  │ 修正文件权限 │  │ 服务器       │ │
│  │ 交互式配置   │  │ 更新配置文件 │  │              │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │              文件上传（核心）                     │  │
│  │                  sftp-push                       │  │
│  │                                                  │  │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐   │  │
│  │  │ 增量上传   │  │ 全量上传   │  │ 指定上传   │   │  │
│  │  └───────────┘  └───────────┘  └───────────┘   │  │
│  │                                                  │  │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐   │  │
│  │  │ 预览模式   │  │ 详细日志   │  │ 错误恢复   │   │  │
│  │  └───────────┘  └───────────┘  └───────────┘   │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │                  工具库                          │  │
│  │  i18n.sh  │  json.sh  │  logger.sh  │  utils.sh │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 2.2.2 模块职责详解

#### 模块 1：配置初始化 (sftp-init.sh)

```
职责：
  - 创建 .claude/sftp-cc/ 配置目录
  - 生成 sftp-config.json 配置文件
  - 支持交互式和命令行两种配置方式

输入：
  - --host: 服务器地址
  - --port: 端口号
  - --username: 用户名
  - --remote-path: 远程路径
  - --language: 语言设置

输出：
  - 成功的配置创建消息
  - 错误提示（如参数缺失）

异常处理：
  - 配置文件已存在 → 警告并跳过
  - 目录创建失败 → 报错退出
```

#### 模块 2：私钥绑定 (sftp-keybind.sh)

```
职责：
  - 扫描 .claude/sftp-cc/ 目录下的私钥文件
  - 自动修正私钥权限为 600
  - 将私钥路径写入配置文件

支持的私钥文件：
  - id_rsa, id_ed25519, id_ecdsa, id_dsa
  - *.pem, *.key

输入：
  - 无（自动扫描）

输出：
  - 找到的私钥路径
  - 权限修正结果
  - 错误提示（未找到私钥）

异常处理：
  - 多个私钥 → 使用第一个匹配的
  - 无权限修正 → 报错提示
```

#### 模块 3：公钥部署 (sftp-copy-id.sh)

```
职责：
  - 将本地 SSH 公钥部署到远程服务器
  - 支持密码交互式输入

输入：
  - 从配置文件读取服务器信息

输出：
  - 部署状态
  - 错误提示

异常处理：
  - 公钥不存在 → 提示生成
  - 服务器拒绝 → 提示检查密码
```

#### 模块 4：文件上传 (sftp-push.sh)

```
职责：
  - 核心上传功能
  - 增量检测
  - 批量上传

输入：
  - 可选：文件列表
  - 可选：--full（全量）
  - 可选：-n（预览）
  - 可选：-d（目录）

输出：
  - 上传进度
  - 成功/失败状态
  - 详细日志（--verbose）

异常处理：
  - 连接失败 → 重试或报错
  - 文件不存在 → 跳过并警告
  - 权限不足 → 报错退出
```

### 2.2.3 上传模式设计

详细设计各种上传模式：

#### 模式 1：增量上传（默认）

```bash
# 命令
sftp-push.sh

# 行为
1. 读取 .last-push 文件中的上次提交 hash
2. 计算从上次提交到现在的变更
3. 只上传变更的文件
4. 更新 .last-push 文件

# 适用场景
- 日常开发部署
- 小改动频繁
```

#### 模式 2：全量上传

```bash
# 命令
sftp-push.sh --full

# 行为
1. 忽略 .last-push 文件
2. 扫描项目所有文件
3. 上传所有非排除的文件
4. 更新 .last-push 文件

# 适用场景
- 首次部署
- .last-push 文件丢失
- 不确定状态时
```

#### 模式 3：指定文件上传

```bash
# 命令
sftp-push.sh file1.php file2.php

# 行为
1. 检查指定文件是否存在
2. 上传列出的文件
3. 不更新 .last-push 文件

# 适用场景
- 紧急修复单个文件
- 调试特定问题
```

#### 模式 4：指定目录上传

```bash
# 命令
sftp-push.sh -d src/controllers/

# 行为
1. 检查指定目录是否存在
2. 递归上传整个目录
3. 不更新 .last-push 文件

# 适用场景
- 修改了整个模块
- 新功能的完整目录
```

#### 模式 5：预览模式

```bash
# 命令
sftp-push.sh -n

# 行为
1. 执行所有检测逻辑
2. 显示将执行的操作
3. 不实际上传

# 适用场景
- 确认将上传哪些文件
- 调试配置问题
```

### 2.2.4 增量检测逻辑详解

这是核心功能，让我们深入理解：

#### 变更来源

```
变更文件来源
├── 已提交的变更 (committed changes)
│   └── git diff <last_hash> HEAD
│
├── 暂存区变更 (staged changes)
│   └── git diff --cached
│
├── 工作区修改 (working directory changes)
│   └── git diff
│
└── 未跟踪文件 (untracked files)
    └── git ls-files --others --exclude-standard
```

#### 文件状态分类

```bash
# Git 文件状态过滤器
# A - Added（新增）
# C - Copied（复制）
# M - Modified（修改）
# R - Renamed（重命名）
# D - Deleted（删除）

# 上传时使用 ACMR
# 排除 D（删除）因为删除的文件不需要上传
```

#### 完整检测流程

```bash
collect_changed_files() {
    # 1. 检查是否有上次推送记录
    if [ ! -f ".last-push" ]; then
        # 首次上传，返回空（触发全量）
        return 0
    fi

    # 2. 获取上次提交的 hash
    last_hash=$(head -1 .last-push)

    # 3. 验证 hash 是否有效
    if ! git cat-file -t "$last_hash" &>/dev/null; then
        # commit 已失效（如 rebase 后）
        warn "上次推送记录失效，将执行全量上传"
        return 0
    fi

    # 4. 收集各类变更
    changed_list=$(mktemp)

    # 4.1 已提交的变更
    git diff --name-only --diff-filter=ACMR "$last_hash" HEAD \
        >> "$changed_list"

    # 4.2 暂存区变更
    git diff --cached --name-only --diff-filter=ACMR \
        >> "$changed_list"

    # 4.3 工作区修改
    git diff --name-only --diff-filter=ACMR \
        >> "$changed_list"

    # 4.4 未跟踪文件
    git ls-files --others --exclude-standard \
        >> "$changed_list"

    # 5. 去重
    sort -u "$changed_list" -o "$changed_list"

    # 6. 应用排除规则
    filtered_list=$(mktemp)
    while read -r file; do
        if ! is_excluded "$file"; then
            echo "$file" >> "$filtered_list"
        fi
    done < "$changed_list"

    # 7. 输出结果
    cat "$filtered_list"

    # 8. 清理临时文件
    rm -f "$changed_list" "$filtered_list"
}
```

#### 边界情况处理

| 情况 | 处理方式 |
|------|----------|
| 首次上传（无 .last-push） | 返回空，触发全量上传 |
| .last-push 的 commit 失效 | 警告用户，触发全量上传 |
| 文件已删除 | 如果是远程删除，需要 --delete 参数 |
| 文件被排除 | 在过滤阶段跳过 |
| 文件不在本地 | 跳过并警告 |

---

## 2.3 目录结构规划

### 2.3.1 完整目录结构

```
sftp-cc/
│
├── .claude-plugin/               # Plugin 配置目录
│   └── marketplace.json          # Marketplace 元数据
│
├── skills/
│   └── sftp-cc/
│       └── SKILL.md              # Skill 定义（Plugin 安装）
│
├── scripts/
│   ├── sftp-init.sh              # 配置初始化
│   ├── sftp-keybind.sh           # 私钥绑定
│   ├── sftp-copy-id.sh           # 公钥部署
│   ├── sftp-push.sh              # 文件上传（核心）
│   └── i18n.sh                   # 多语言支持
│
├── templates/
│   └── sftp-config.example.json  # 配置文件模板
│
├── skill.md                      # Skill 定义（手动安装兼容）
├── install.sh                    # 手动安装脚本
│
├── README.md                     # 英文文档
├── README_CN.md                  # 中文文档
├── README_JP.md                  # 日文文档
│
├── CLAUDE.md                     # 开发指南（给贡献者）
└── LICENSE                       # 开源协议
```

### 2.3.2 目录设计规范

#### 命名约定

| 类型 | 规范 | 示例 |
|------|------|------|
| 目录名 | 小写 + 连字符 | `sftp-cc`, `.claude-plugin` |
| 脚本文件 | 小写 + 连字符 + .sh | `sftp-push.sh` |
| 配置文件 | 小写 + 连字符 + .json | `sftp-config.json` |
| 文档文件 | 大写 + 下划线或连字符 | `README.md`, `CLAUDE.md` |
| 模板文件 | 名称 + .example + 扩展名 | `config.example.json` |

#### 文件组织原则

1. **按功能分组**
```
scripts/
├── 配置相关    # sftp-init.sh
├── 密钥相关    # sftp-keybind.sh, sftp-copy-id.sh
└── 上传相关    # sftp-push.sh
```

2. **配置与代码分离**
```
templates/          # 配置模板
scripts/            # 执行代码
```

3. **文档分层**
```
README.md           # 用户文档（安装、使用）
CLAUDE.md           # 开发者文档（内部规范）
SPEC.md             # 技术规格（设计细节）
```

### 2.3.3 两种安装方式

#### Plugin 安装（推荐）

```
安装位置：
  ~/.claude/plugins/marketplaces/sftp-cc/

安装命令：
  /plugin marketplace add https://github.com/toohamster/sftp-cc

优点：
  ✓ 自动更新
  ✓ 统一管理
  ✓ 版本控制

缺点：
  ✗ 需要推送到 GitHub
  ✗ 旧版本可能不支持
```

#### 手动安装（兼容）

```
安装位置：
  <项目根目录>/.claude/skills/sftp-cc/

安装命令：
  bash install.sh /path/to/project

优点：
  ✓ 本地即可安装
  ✓ 兼容旧版本
  ✓ 项目级别隔离

缺点：
  ✗ 不会自动更新
  ✗ 每个项目需要单独安装
```

### 2.3.4 安装后目录结构

```
target-project/
├── .claude/
│   ├── skills/
│   │   └── sftp-cc/              # 手动安装时
│   │       ├── skill.md
│   │       └── scripts/
│   │           ├── sftp-init.sh
│   │           ├── sftp-push.sh
│   │           └── ...
│   │
│   └── sftp-cc/                  # 配置和数据目录
│       ├── sftp-config.json      # 用户配置
│       ├── .last-push            # 上传记录
│       └── id_rsa                # 私钥文件
│
└── ...项目文件
```

---

## 2.4 配置文件设计

### 2.4.1 配置文件格式选择

#### 为什么选择 JSON？

| 格式 | 优点 | 缺点 | 选择理由 |
|------|------|------|----------|
| JSON | 标准格式、易解析 | 不支持注释 | ✅ Shell 可用 grep/sed 解析 |
| YAML | 支持注释、可读性好 | 需要解析器 | ❌ 外部依赖 |
| INI | 简单 | 不支持嵌套 | ❌ 功能有限 |
| .env | 简单 | 仅 key=value | ❌ 不适合复杂配置 |

### 2.4.2 配置文件完整示例

```json
{
  "host": "example.com",
  "port": 22,
  "username": "deploy",
  "remote_path": "/var/www/html",
  "local_path": ".",
  "private_key": "",
  "language": "en",
  "excludes": [
    ".git",
    ".claude",
    "node_modules",
    ".env",
    ".DS_Store",
    "*.log"
  ]
}
```

### 2.4.3 字段详解

#### 连接配置（必填）

| 字段 | 类型 | 必填 | 说明 | 示例 |
|------|------|------|------|------|
| `host` | string | 是 | SFTP 服务器地址 | `example.com` |
| `username` | string | 是 | 登录用户名 | `deploy` |
| `remote_path` | string | 是 | 远程目标路径 | `/var/www/html` |

#### 连接配置（可选）

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `port` | number | 22 | SFTP 端口 |
| `local_path` | string | "." | 本地源目录（相对路径） |
| `private_key` | string | "" | 私钥路径（自动填充） |

#### 行为配置

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `language` | string | "en" | 输出语言（en/zh/ja） |
| `excludes` | array | 见下 | 排除的文件/目录模式 |

#### 默认排除规则

```json
"excludes": [
  ".git",           // Git 仓库
  ".claude",        // Claude 配置
  "node_modules",   // Node.js 依赖
  ".env",           // 环境变量（可能包含敏感信息）
  ".DS_Store",      // macOS 系统文件
  "*.log"           // 日志文件
]
```

### 2.4.4 配置验证

#### 必需字段检查

```bash
validate_config() {
    local config_file="$1"
    local missing=()

    # 检查 host
    local host=$(grep '"host"' "$config_file" | sed 's/.*: *"\([^"]*\)".*/\1/')
    [ -z "$host" ] && missing+=("host")

    # 检查 username
    local username=$(grep '"username"' "$config_file" | sed 's/.*: *"\([^"]*\)".*/\1/')
    [ -z "$username" ] && missing+=("username")

    # 检查 remote_path
    local remote_path=$(grep '"remote_path"' "$config_file" | sed 's/.*: *"\([^"]*\)".*/\1/')
    [ -z "$remote_path" ] && missing+=("remote_path")

    # 返回结果
    if [ ${#missing[@]} -gt 0 ]; then
        echo "配置不完整，缺少字段：${missing[*]}"
        return 1
    fi
    return 0
}
```

#### 值验证

```bash
# 端口范围验证
if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    error "端口必须在 1-65535 之间"
    exit 1
fi

# 路径格式验证
if [[ "$remote_path" != /* ]]; then
    warn "远程路径建议使用绝对路径"
fi
```

### 2.4.5 配置管理最佳实践

#### 1. 不要将配置文件提交到 Git

```bash
# .gitignore
.claude/sftp-cc/sftp-config.json
.claude/sftp-cc/*.key
.claude/sftp-cc/*.pem
```

#### 2. 提供配置模板

```bash
# templates/sftp-config.example.json
{
  "host": "填写服务器地址",
  "port": 22,
  "username": "填写用户名",
  "remote_path": "填写远程路径"
}
```

#### 3. 使用交互式配置

```bash
# 运行初始化脚本
bash scripts/sftp-init.sh

# 按提示输入配置
# SFTP server address (host): example.com
# Login username: deploy
# Remote target path: /var/www/html
```

---

## 2.5 触发词设计

### 2.5.1 触发词设计原则

#### 原则 1：自然语言

```
✅ 好的触发词
- "sync code to server"    # 用户会说的话
- "上传代码"               # 自然的中文表达
- "デプロイして"          # 自然的日文表达

❌ 差的触发词
- "execute_sftp_upload"   # 像函数名，不像人话
- "调用 sftp 推送功能"      # 太正式
```

#### 原则 2：避免歧义

```
❌ "push"
  问题：可能与 git push 冲突

✅ "sftp push" / "push to server"
  改进：添加上下文，明确是 SFTP 操作
```

#### 原则 3：多语言覆盖

```
英文触发词 → 中文触发词 → 日文触发词
     ↓              ↓           ↓
"sync code"   "同步代码"   "コードを同期"
```

### 2.5.2 触发词分类设计

#### SFTP 上传类触发词

````markdown
**英文**:
- "sync code to server"
- "upload to server"
- "deploy code"
- "push to server"
- "sftp upload"

**中文**:
- "同步代码到服务器"
- "上传到服务器"
- "部署代码"
- "把文件传到服务器上"
- "sftp 上传"

**日文**:
- "サーバーに同期する"
- "コードをデプロイする"
- "アップロード"
````

#### 私钥绑定类触发词

````markdown
**英文**:
- "bind sftp private key"
- "bind ssh key"
- "sftp keybind"

**中文**:
- "绑定 SFTP 私钥"
- "绑定私钥"
- "自动绑定私钥"

**日文**:
- "秘密鍵をバインドする"
- "SSH 鍵をバインドする"
````

#### 配置初始化类触发词

````markdown
**英文**:
- "initialize sftp config"
- "setup sftp"
- "configure sftp"

**中文**:
- "初始化 SFTP 配置"
- "配置 SFTP"
- "设置 SFTP"
````

### 2.5.3 触发词测试清单

在发布前，测试以下触发词：

| 触发词 | 预期行为 | 测试结果 |
|--------|----------|----------|
| "sync code to server" | 触发上传 | ⬜ |
| "同步代码到服务器" | 触发上传 | ⬜ |
| "push" | 不触发 | ⬜ |
| "git push" | 不触发 | ⬜ |
| "绑定私钥" | 触发 keybind | ⬜ |

---

## 2.6 技术选型

### 2.6.1 脚本语言对比

#### 完整对比表

| 对比项 | Shell | Python | Node.js |
|--------|-------|--------|---------|
| **外部依赖** | 无（系统自带） | 需要 pip + 虚拟环境 | 需要 npm + node_modules |
| **系统兼容性** | 所有 Unix 系统 | 需要安装 Python | 需要安装 Node.js |
| **JSON 解析** | grep/sed（需手动实现） | 内置 json 模块 | 内置 JSON 对象 |
| **错误处理** | 退出码 | try/catch | try/catch |
| **开发效率** | 中等 | 高 | 高 |
| **执行速度** | 快 | 中等 | 中等 |
| **学习曲线** | 低（基础）到高（高级） | 低 | 中等 |
| **适合场景** | 系统脚本、自动化 | 复杂逻辑、数据处理 | Web 相关、前端工具 |

### 2.6.2 为什么选择 Shell

#### 决策矩阵

```
评估维度           权重    Shell    Python    Node.js
外部依赖           30%     100       60        60
系统兼容           25%     100       70        70
开发效率           20%     70        100       90
执行速度           15%     90        70        70
维护成本           10%     80        80        80
───────────────────────────────────────────────
加权总分           100%    88.5      75        71.5
```

#### 核心理由

1. **零外部依赖原则**
```bash
# Shell：直接运行
bash sftp-push.sh

# Python：可能需要
pip install -r requirements.txt

# Node.js：需要
npm install
```

2. **系统兼容性**
```bash
# 任何 Unix 系统都有
$ which bash
/bin/bash

# Python 可能没有
$ which python3
# (可能无输出)

# Node.js 通常需要安装
$ which node
# (可能无输出)
```

3. **SFTP 原生命令支持**
```bash
# Shell 可以直接使用 sftp
sftp -b batch_file user@host

# Python/Node.js 需要额外库
# Python: import paramiko
# Node.js: import ssh2-sftp-client
```

### 2.6.3 Shell 的实现限制与解决方案

#### 限制 1：JSON 解析

```bash
# 问题：没有内置 JSON 支持

# 解决方案：使用 grep + sed
json_get() {
    local file="$1" key="$2"
    grep "\"$key\"" "$file" | sed 's/.*: *"\([^"]*\)".*/\1/'
}

# 使用
host=$(json_get "config.json" "host")
```

#### 限制 2：数组操作

```bash
# 问题：Bash 3 不支持关联数组

# 解决方案：使用索引数组或字符串
excludes=(".git" ".claude" "node_modules")

for ex in "${excludes[@]}"; do
    # 处理每个排除项
done
```

#### 限制 3：错误处理

```bash
# 问题：没有 try/catch

# 解决方案：使用 set 和 trap
set -euo pipefail

trap 'error_handler ${LINENO}' ERR

error_handler() {
    echo "Error at line $1"
}
```

### 2.6.4 零外部依赖原则

#### 什么是外部依赖？

```
外部依赖 = 需要额外安装的命令或库

✅ 内部命令（可用）
- bash 内置命令：echo, read, test, [[ ]]
- POSIX 标准命令：grep, sed, awk, find, sort

❌ 外部依赖（避免）
- jq（JSON 处理）
- python3（如果作为依赖）
- 任何需要安装的工具
```

#### 实现对照表

| 功能 | 外部依赖方案 | 零依赖方案 |
|------|-------------|-----------|
| JSON 解析 | `jq '.host'` | `grep + sed` |
| HTTP 请求 | `curl` | 无（或用 Python） |
| 文件同步 | `rsync` | `sftp` |
| 日志颜色 | `tput` | ANSI 转义码 |

#### 为什么重要？

```
场景：用户在新的服务器上运行 Skill

有外部依赖：
  1. 发现缺少 jq
  2. 需要安装：apt-get install jq
  3. 可能没有权限安装
  4. → Skill 无法运行

零外部依赖：
  1. 直接运行
  2. → Skill 正常工作
```

---

## 2.7 实战练习

### 练习 2-1：设计你自己的 Skill

选择一个你想实现的功能，完成以下设计：

#### 需求分析模板

```markdown
## 问题场景
描述你遇到的问题...

## 用户画像
谁会使用这个 Skill？他们的痛点是什么？

## 需求清单
| 需求 | 优先级 | 说明 |
|------|--------|------|
| ...  | ⭐⭐⭐   | ...  |

## 功能边界
### 做什么
- ...

### 不做什么
- ...
```

### 练习 2-2：设计配置文件

为你设计的 Skill 创建配置文件模板：

```json
{
  "//_comment": "复制此模板并填写"
}
```

---

## 2.8 本章总结

### 核心知识点回顾

| 概念 | 关键点 |
|------|--------|
| 需求分析 | 从真实痛点出发，明确用户画像 |
| 功能边界 | 明确不做什么与做什么同样重要 |
| 模块设计 | 单一职责，模块独立 |
| 目录结构 | 按功能分组，配置与代码分离 |
| 配置文件 | JSON 格式，零外部依赖解析 |
| 触发词设计 | 自然语言、无歧义、多语言覆盖 |
| 技术选型 | Shell = 零依赖 + 高兼容性 |

### 设计检查清单

在开始编码前，确认：

- [ ] 明确了目标用户和痛点
- [ ] 列出了优先级需求清单
- [ ] 定义了功能边界（做/不做）
- [ ] 设计了模块结构和职责
- [ ] 规划了目录结构
- [ ] 设计了配置文件格式
- [ ] 列出了触发词列表
- [ ] 完成了技术选型论证

---

## 2.9 延伸阅读

### 需求工程
- 《软件需求》- Karl Wiegers
- 《用户故事地图》- Jeff Patton

### 架构设计
- 《代码整洁之道》- Robert C. Martin
- 《设计模式》- Gang of Four

### 技术写作
- 《技术文档写作实践》

---

## 下一章预告

第 3 章将带你**编写第一个 Skill**：
- YAML Frontmatter 详解
- SKILL.md 完整结构
- 触发词编写技巧
- 脚本执行指引
- 第一个可运行的 Skill

---

## 关于本书

**第一版（数字版）, 2026 年 3 月**

**作者**：[toohamster](https://github.com/toohamster)
**授权**：电子版 MIT License，纸质版/商业版 © All Rights Reserved
**源码**：[github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

详细说明请参阅 [LICENSE](../../LICENSE) 和 [关于作者](../authors.md)

---
