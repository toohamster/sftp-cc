# sftp-cc-toomaster

通用 SFTP 上传工具，Claude Code Plugin。支持增量上传、私钥自动绑定与权限修正。

## 为什么做这个工具

以前使用 PhpStorm 开发项目时，内置的 SFTP 扩展会自动将新增、修改、删除的文件同步到开发服务器上，体验非常顺畅。切换到 Claude Code 之后，失去了这个能力——每次 Claude 修改了代码，都需要手动到测试服务器上拉取，效率大打折扣。为了解决这个问题，我写了这个工具，让 Claude Code 也能一句话完成代码同步：只需说 "把代码同步到服务器" 就搞定了。

## 安装

### 方式一：Plugin Marketplace（推荐）

```bash
# 添加 marketplace
/plugin marketplace add https://github.com/toohamster/sftp-cc-toomaster

# 安装插件
/plugin install sftp-cc-toomaster@sftp-cc-toomaster
```

### 方式二：手动安装

```bash
# 克隆仓库
git clone https://github.com/toohamster/sftp-cc-toomaster.git

# 安装到目标项目
bash sftp-cc-toomaster/install.sh /path/to/your-project
```

手动安装后的目录结构：
```
your-project/
├── .claude/
│   ├── skills/
│   │   └── sftp-cc-toomaster/
│   │       ├── skill.md
│   │       └── scripts/
│   └── sftp-cc/
│       ├── sftp-config.json    ← 服务器配置
│       └── id_rsa              ← 你的私钥
```

## 配置

### 命令行快速配置

```bash
# Plugin Marketplace 安装后
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-init.sh \
  --host your-server.com \
  --username deploy \
  --remote-path /var/www/html

# 手动安装后
bash .claude/skills/sftp-cc-toomaster/scripts/sftp-init.sh \
  --host your-server.com \
  --username deploy \
  --remote-path /var/www/html
```

### 直接编辑 JSON

编辑 `.claude/sftp-cc/sftp-config.json`：

```json
{
  "host": "your-server.com",
  "port": 22,
  "username": "deploy",
  "remote_path": "/var/www/html",
  "local_path": ".",
  "private_key": "",
  "excludes": [".git", ".claude", "node_modules", ".env", ".DS_Store"]
}
```

### 放置私钥

```bash
cp ~/.ssh/id_rsa .claude/sftp-cc/
```

私钥会被自动检测、自动绑定到配置、自动修正权限为 600。

支持的私钥格式：`id_rsa`, `id_ed25519`, `id_ecdsa`, `*.pem`, `*.key`

## 使用

在 Claude Code 中用自然语言触发：

- "把代码同步到服务器"
- "上传 src/ 目录到远程"
- "部署最新代码"
- "把 index.php 传到服务器上"

也可直接调用脚本：

```bash
# 增量上传（默认，仅变更文件）
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh

# 增量上传 + 删除远程已删除的文件
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh --delete

# 全量上传整个项目
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh --full

# 上传指定文件
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh src/index.php

# 上传指定目录
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh -d src/

# 预览模式
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh -n
```

### 增量上传原理

- 每次成功上传后，记录当前 git commit hash 到 `.claude/sftp-cc/.last-push`
- 下次上传时，通过 `git diff` 对比上次推送点，仅上传变更/新增的文件
- 同时检测暂存区变更、工作区变更和未跟踪的新文件
- 首次上传或记录丢失时自动回退为全量上传
- 使用 `--full` 可强制全量上传
- 使用 `--delete` 可同步删除远程服务器上本地已删除的文件（默认不删，避免误操作）

## 依赖

- `sftp` — SSH 文件传输（系统自带）
- `git` — 用于定位项目根目录
- **无需 jq**，纯 shell 实现 JSON 解析

## 安全说明

- `.claude/sftp-cc/` 目录包含私钥和服务器信息，已自动加入 `.gitignore`
- 私钥权限会被自动修正为 `600`
