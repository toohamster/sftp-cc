# sftp-cc-toomaster

[English Documentation](README.md) | [日本語ドキュメント](README_JP.md)

通用 SFTP 上传工具，Claude Code Plugin。支持增量上传、私钥自动绑定与权限修正。

## 多语言支持

本工具支持 **英文（English）**、**中文** 和 **日文（日本語）**。

语言设置可在交互式初始化时完成，或编辑配置文件修改。

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

### 第一步：初始化服务器配置

**方式 A：交互式模式（推荐）**

无参数运行，进入交互式配置：

```bash
# Plugin 安装后
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-init.sh

# 手动安装后
bash .claude/skills/sftp-cc-toomaster/scripts/sftp-init.sh
```

脚本会依次询问：
- SFTP 服务器地址
- SFTP 端口（默认：22）
- 登录用户名
- 远程目标路径
- 语言选择（English / 中文 / 日本語）
- SSH 私钥路径（可选，例如 `~/.ssh/id_rsa`）

如果私钥文件存在，会自动复制到 `.claude/sftp-cc/` 目录。

**方式 B：命令行参数**

```bash
# Plugin 安装后
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-init.sh \
  --host your-server.com \
  --username deploy \
  --remote-path /var/www/html \
  --language ja \
  --private-key ~/.ssh/id_rsa

# 手动安装后
bash .claude/skills/sftp-cc-toomaster/scripts/sftp-init.sh \
  --host your-server.com \
  --username deploy \
  --remote-path /var/www/html \
  --language ja \
  --private-key ~/.ssh/id_rsa
```

### 第二步：部署 SSH 公钥到服务器

**方式 A：在本机终端运行（推荐）**

打开终端运行：
```bash
# Plugin 安装后
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-copy-id.sh

# 手动安装后
bash .claude/skills/sftp-cc-toomaster/scripts/sftp-copy-id.sh
```

**方式 B：直接使用 ssh-copy-id**
```bash
# 找到公钥（通常在 ~/.ssh/id_ed25519.pub 或 ~/.ssh/id_rsa.pub）
ssh-copy-id -i ~/.ssh/id_ed25519.pub username@your-server.com
```

**方式 C：手动部署**
```bash
# 复制公钥内容
cat ~/.ssh/id_ed25519.pub | pbcopy  # macOS
# 或
cat ~/.ssh/id_ed25519.pub | xclip -selection clipboard  # Linux

# SSH 登录服务器并粘贴到 authorized_keys
ssh username@your-server.com
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys  # 粘贴公钥内容
chmod 600 ~/.ssh/authorized_keys
```

这是一次性操作，完成后即可使用无密码 SSH 认证进行 SFTP 上传。

### 第三步：放置私钥

```bash
cp ~/.ssh/id_rsa .claude/sftp-cc/
```

**私钥自动绑定说明：**

- 如果在运行 `sftp-init.sh` **之前**放入私钥 → 会自动绑定，无需额外操作
- 如果在运行 `sftp-init.sh` **之后**才放入私钥 → 手动绑定：

  **方式 A：让 Claude 执行（推荐）**

  在项目目录中对 Claude 说：
  > "绑定 SFTP 私钥"

  **方式 B：直接运行脚本**

  ```bash
  # Plugin 安装后
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-keybind.sh

  # 手动安装后
  bash .claude/skills/sftp-cc-toomaster/scripts/sftp-keybind.sh
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
