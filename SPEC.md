# SPEC.md — sftp-cc-toomaster 技术规格说明

## 概述

sftp-cc-toomaster 是一个 Claude Code Plugin，提供通用 SFTP 上传能力。通过自然语言触发，将本地项目文件上传到远程服务器。支持增量上传、私钥自动绑定、权限修正、远程文件删除。

兼容 Claude Code Plugin Marketplace 规范，同时保留手动安装方式。

**零外部依赖**，纯 shell 实现，仅需系统自带的 `sftp`、`git`、`grep`、`sed`。

---

## Plugin Marketplace 规范

### plugin.json

```json
{
  "name": "sftp-cc-toomaster",
  "description": "通用 SFTP 上传工具，支持增量上传、私钥自动绑定与权限修正。零外部依赖。",
  "version": "1.0.0"
}
```

### marketplace.json

```json
{
  "name": "sftp-cc-toomaster",
  "owner": { "name": "xuyimu" },
  "plugins": [{
    "name": "sftp-cc-toomaster",
    "source": ".",
    "description": "..."
  }]
}
```

### SKILL.md

位于 `skills/sftp-cc-toomaster/SKILL.md`，带 YAML frontmatter：
```yaml
---
name: sftp-cc-toomaster
description: 通用 SFTP 上传工具...
---
```

脚本路径使用 `${CLAUDE_PLUGIN_ROOT}/scripts/` 变量，Plugin 安装后自动解析为缓存目录。

### 安装命令

```
/plugin marketplace add your-username/sftp-cc-toomaster
/plugin install sftp-cc-toomaster@sftp-cc-toomaster
```

---

## 目录结构

### 仓库（Plugin 包）

```
sftp-cc-toomaster/
├── .claude-plugin/
│   ├── plugin.json                     # Plugin 清单
│   └── marketplace.json                # Marketplace 目录（自托管分发）
├── skills/
│   └── sftp-cc-toomaster/
│       └── SKILL.md                    # Skill 定义（YAML frontmatter，Plugin 格式）
├── scripts/
│   ├── sftp-push.sh                    # 上传核心脚本
│   ├── sftp-init.sh                    # 初始化配置
│   └── sftp-keybind.sh                 # 私钥自动绑定 + 权限修正
├── templates/
│   └── sftp-config.example.json        # 配置模板
├── skill.md                            # Skill 定义（旧格式，手动安装兼容）
├── install.sh                          # 手动安装脚本
├── CLAUDE.md
├── README.md
└── SPEC.md                             # 本文件
```

### Plugin Marketplace 安装后

Plugin 缓存到 `~/.claude/plugins/cache/`，SKILL.md 中通过 `${CLAUDE_PLUGIN_ROOT}` 引用脚本。

用户项目中仅存储运行时数据：
```
target-project/
├── .claude/
│   └── sftp-cc/                        # 运行时数据（已加入 .gitignore）
│       ├── sftp-config.json            # 连接配置
│       ├── <private_key>               # 用户私钥
│       └── .last-push                  # 增量推送记录
```

### 手动安装后

```
target-project/
├── .claude/
│   ├── skills/
│   │   └── sftp-cc-toomaster/
│   │       ├── skill.md                # Skill 指令
│   │       └── scripts/
│   │           ├── sftp-push.sh
│   │           ├── sftp-init.sh
│   │           └── sftp-keybind.sh
│   └── sftp-cc/                        # 运行时数据（已加入 .gitignore）
│       ├── sftp-config.json
│       ├── <private_key>
│       └── .last-push
```

---

## 配置文件

### sftp-config.json

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `host` | string | `""` | SFTP 服务器地址（必填） |
| `port` | number | `22` | SFTP 端口 |
| `username` | string | `""` | 登录用户名（必填） |
| `remote_path` | string | `""` | 远程目标目录（必填） |
| `local_path` | string | `"."` | 本地源目录（相对项目根目录） |
| `private_key` | string | `""` | 私钥绝对路径（由 keybind 自动填充） |
| `excludes` | array | 见下方 | 全量/增量上传时排除的文件和目录 |

**excludes 默认值**：`[".git", ".claude", "node_modules", ".env", ".DS_Store"]`

### .last-push

增量推送标记文件，内容为两行：
- 第 1 行：上次推送成功时的 git commit hash
- 第 2 行：上次推送的 Unix 时间戳

---

## 脚本规格

### install.sh

**用途**：将 Skill 安装到目标项目。

```
bash install.sh [TARGET_PROJECT_PATH]
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `TARGET_PROJECT_PATH` | `.`（当前目录） | 目标项目路径 |

**行为**：
1. 创建 `.claude/skills/sftp-cc-toomaster/scripts/` 目录
2. 创建 `.claude/sftp-cc/` 目录
3. 复制 `skill.md` 和 `scripts/*.sh` 到 skill 目录
4. 从模板创建 `sftp-config.json`（不覆盖已有）
5. 将 `.claude/sftp-cc/` 追加到 `.gitignore`（不重复追加）

---

### sftp-init.sh

**用途**：初始化 SFTP 配置。

```
bash sftp-init.sh [OPTIONS]
```

| 选项 | 说明 |
|------|------|
| `--host HOST` | SFTP 服务器地址 |
| `--port PORT` | SFTP 端口（默认 22） |
| `--username USER` | 登录用户名 |
| `--remote-path PATH` | 远程目标路径 |
| `-h, --help` | 显示帮助 |

**行为**：
1. 创建 `.claude/sftp-cc/` 目录
2. 从模板创建 `sftp-config.json`（不覆盖已有）
3. 将命令行参数写入配置对应字段
4. 自动调用 `sftp-keybind.sh` 绑定私钥
5. 检查并报告缺失的必填字段（host, username, remote_path）

---

### sftp-keybind.sh

**用途**：私钥自动绑定与权限修正。

```
bash sftp-keybind.sh
```

**私钥扫描模式**（按优先级）：`id_rsa`, `id_ed25519`, `id_ecdsa`, `id_dsa`, `*.pem`, `*.key`

**行为**：
1. 若 `sftp-config.json` 中 `private_key` 已指向有效文件 → 仅修正权限为 `600`
2. 否则扫描 `.claude/sftp-cc/` 下的私钥文件（跳过 `.pub`、`sftp-config*`、`*example*`）
3. 找到第一个匹配的私钥 → `chmod 600` → 写入 `sftp-config.json` 的 `private_key` 字段
4. 未找到 → 输出警告，exit 1

---

### sftp-push.sh

**用途**：SFTP 上传核心脚本。默认增量上传。

```
bash sftp-push.sh [OPTIONS] [FILES...]
```

| 选项 | 说明 |
|------|------|
| `-f, --full` | 全量上传（忽略增量记录，上传所有文件） |
| `--delete` | 同步删除远程已在本地删除的文件（默认不删） |
| `-d, --dir DIR` | 上传指定目录 |
| `-n, --dry-run` | 仅预览，不实际上传 |
| `-v, --verbose` | 显示详细输出 |
| `-h, --help` | 显示帮助 |

**四种运行模式**：

| 模式 | 触发条件 | 说明 |
|------|----------|------|
| 增量上传 | 无参数（默认） | 基于 git diff 仅上传变更文件 |
| 全量上传 | `--full` | 扫描全部文件上传，忽略增量记录 |
| 指定文件 | `sftp-push.sh file1 file2` | 上传指定文件 |
| 指定目录 | `-d dirname/` | 上传指定目录（`put -r`） |

**增量检测逻辑**（按顺序收集，去重合并）：

| 步骤 | git 命令 | 检测内容 |
|------|----------|----------|
| 1 | `git diff --name-only --diff-filter=ACMR <last_hash> HEAD` | 已提交的变更 |
| 2 | `git diff --cached --name-only --diff-filter=ACMR` | 暂存区变更 |
| 3 | `git diff --name-only --diff-filter=ACMR` | 工作区未暂存修改 |
| 4 | `git ls-files --others --exclude-standard` | 未跟踪的新文件（未 git add） |

- 首次上传（无 `.last-push` 文件）自动回退全量
- `.last-push` 中 commit hash 失效时自动回退全量

**远程删除逻辑**（仅 `--delete` 启用时）：

| 步骤 | git 命令 | 检测内容 |
|------|----------|----------|
| 1 | `git diff --name-only --diff-filter=D <last_hash> HEAD` | 已提交的删除 |
| 2 | `git diff --cached --name-only --diff-filter=D` | 暂存区删除 |
| 3 | `git diff --name-only --diff-filter=D` | 工作区删除 |

- 通过 sftp batch 的 `-rm` 命令删除远程文件（`-` 前缀表示失败不中断）
- 未启用 `--delete` 时仅输出提示，不执行删除

**执行流程**：
1. 调用 `sftp-keybind.sh` 检查私钥
2. 读取 `sftp-config.json` 配置
3. 验证必填字段
4. 收集文件列表（增量/全量）
5. 生成 sftp batch 文件（`-mkdir` 创建目录 + `put` 上传 + 可选 `-rm` 删除）
6. 执行 `sftp -b <batch_file>` 上传
7. 成功后写入 `.last-push` 记录推送点（dry-run 不写入）

**sftp 连接选项**：
```
sftp -P <port> -i <private_key> \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -b <batch_file> user@host
```

---

## Skill 触发规则

**触发关键词**：同步到服务器、上传到服务器、部署代码、sftp 上传、sftp 同步

**不触发**："push"、"推送" — 避免与 git push 冲突

**首次使用引导**：
1. 检查 `.claude/sftp-cc/sftp-config.json` 是否存在
2. 不存在 → 询问服务器信息 → 运行 `sftp-init.sh`
3. 检查私钥文件是否存在
4. 不存在 → 提示用户放入 `.claude/sftp-cc/`
5. 执行 `sftp-push.sh`

---

## JSON 解析实现

纯 shell 实现，不依赖 jq。适用于本项目的扁平单层 JSON 结构。

| 函数 | 用途 | 实现 |
|------|------|------|
| `json_get file key [default]` | 读取字符串值 | `grep` + `sed` |
| `json_get_num file key [default]` | 读取数字值 | `grep` + `sed` |
| `json_get_array file key` | 读取数组（每行一个元素） | `sed -n` 范围匹配 |
| `json_set file key value` | 设置字符串值 | `sed` + 临时文件（兼容 macOS/Linux） |
| `json_set_num file key value` | 设置数字值 | `sed` + 临时文件 |

---

## 安全设计

| 措施 | 说明 |
|------|------|
| `.claude/sftp-cc/` 加入 `.gitignore` | 私钥和服务器配置不进入版本控制 |
| 私钥自动 `chmod 600` | 防止权限过宽导致 SSH 拒绝连接 |
| `--delete` 默认关闭 | 远程删除必须显式启用，避免误删 |
| `-rm`（带 `-` 前缀） | sftp batch 中删除失败不中断整体上传 |
| `StrictHostKeyChecking=no` | 自动接受服务器指纹（适用于 CI/自动化场景） |

---

## 系统要求

| 依赖 | 来源 | 用途 |
|------|------|------|
| `bash` | 系统自带 | 脚本执行（兼容 bash 3+，支持 macOS 自带版本） |
| `sftp` | 系统自带（OpenSSH） | SFTP 文件传输 |
| `git` | 需安装 | 项目根目录定位、增量变更检测 |
| `grep` / `sed` | 系统自带 | JSON 解析 |
| `find` | 系统自带 | 全量模式文件扫描 |
| `mktemp` | 系统自带 | 临时文件创建 |
