---
name: sftp-cc
description: 通用 SFTP 上传工具，通过自然语言触发，将本地项目文件上传到远程服务器。支持增量上传、私钥自动绑定与权限修正。
---

# SFTP Push Skill — sftp-cc

> 通用 SFTP 上传工具，支持私钥自动绑定与权限修正。

## When to trigger this Skill / 什么时候触发此 Skill

**SFTP 上传/部署类**:
- "sync code to server", "upload to server", "upload files to server"
- "deploy code", "deploy to server", "send files to server"
- "sftp upload", "sftp sync", "sftp transfer"
- "同步代码到服务器"、"上传到服务器"、"上传文件到服务器"
- "部署代码"、"把文件传到服务器上"
- "sftp 上传"、"sftp 同步"
- "サーバーに同期する", "サーバーにアップロードする", "デプロイする"

**私钥绑定类**:
- "bind sftp private key", "bind ssh key", "sftp keybind"
- "绑定 SFTP 私钥"、"绑定私钥"、"自动绑定私钥"
- "秘密鍵をバインドする", "SSH 鍵をバインドする"
- "sftp-keybind"

**Important / 注意**：Do NOT treat "push" as a trigger — it conflicts with git push. Only trigger when the user explicitly mentions SFTP or server upload/sync/deploy. 不要将 "push"、"推送" 视为触发条件，避免与 git push 冲突。

## 配置文件位置

- **配置文件**: `<项目根目录>/.claude/sftp-cc/sftp-config.json`
- **私钥存放**: `<项目根目录>/.claude/sftp-cc/` 目录下
- **脚本位置**: `${CLAUDE_PLUGIN_ROOT}/scripts/`

## sftp-config.json 格式

```json
{
  "host": "服务器地址",
  "port": 22,
  "username": "用户名",
  "remote_path": "/远程/目标/路径",
  "local_path": ".",
  "private_key": "",
  "excludes": [".git", ".claude", "node_modules", ".env", ".DS_Store"]
}
```

- `private_key` 字段会被 keybind 脚本自动填充，无需手动配置
- `local_path` 默认为 `.`（项目根目录）
- `excludes` 定义推送整个项目时排除的目录/文件

## 可用脚本

### 1. sftp-init.sh — 初始化配置
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-init.sh \
  --host example.com \
  --port 22 \
  --username deploy \
  --remote-path /var/www/html
```
- 创建 `.claude/sftp-cc/` 目录和 `sftp-config.json`
- 自动调用 keybind 绑定私钥
- 参数可选，也可事后编辑 JSON 文件

### 2. sftp-copy-id.sh — 部署 SSH 公钥到服务器

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-copy-id.sh
```
- 从配置读取服务器信息（host, username）
- 自动查找公钥文件（优先使用项目私钥对应的 .pub 文件，否则使用系统默认）
- 调用 `ssh-copy-id` 将公钥添加到服务器的 `~/.ssh/authorized_keys`
- 支持密码交互式登录（需在本地终端运行）

**首次配置推荐流程：**
1. 运行 `sftp-init.sh` 配置服务器信息
2. 在**本地终端**运行 `sftp-copy-id.sh` 部署公钥（输入一次密码）
3. 运行 `sftp-keybind.sh` 绑定私钥（如果私钥已放入 `.claude/sftp-cc/`）
4. 运行 `sftp-push.sh` 上传文件

### 3. sftp-keybind.sh — 私钥自动绑定
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-keybind.sh
```
- 扫描 `.claude/sftp-cc/` 下的私钥文件（id_rsa, id_ed25519, *.pem, *.key）
- 自动 `chmod 600` 修正权限
- 自动更新 `sftp-config.json` 的 `private_key` 字段

### 3. sftp-push.sh — 上传文件（默认增量）
```bash
# 增量上传（默认，仅上传变更文件）
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh

# 增量上传 + 同步删除远程已删除的文件
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh --delete

# 全量上传整个项目
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh --full

# 上传指定文件
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh src/index.php config.php

# 上传指定目录
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh -d src/

# 预览模式（不实际上传）
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh -n

# 详细输出
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh -v
```

## 首次使用引导流程

当用户首次请求 SFTP 操作时，按以下步骤引导：

1. **检查配置是否存在**: 查看 `.claude/sftp-cc/sftp-config.json` 是否存在
2. **如果不存在**: 询问用户服务器信息（host, username, remote_path），然后运行 `sftp-init.sh`
3. **部署公钥到服务器**: 在本地终端运行 `sftp-copy-id.sh`（需要输入服务器密码）
4. **检查私钥**: 查看 `.claude/sftp-cc/` 下是否有私钥文件
5. **如果没有私钥**: 提示用户将私钥文件放入 `.claude/sftp-cc/` 目录
6. **执行上传**: 运行 `sftp-push.sh` 完成上传

## 操作注意事项

- 每次上传前会自动运行 keybind 检查私钥状态
- **默认增量上传**：通过 git diff 检测变更，仅上传修改/新增的文件；首次上传或无历史记录时自动回退全量
- **远程删除**：默认不删除远程文件，加 `--delete` 参数才会同步删除本地已删除的文件
- 增量记录保存在 `.claude/sftp-cc/.last-push`，记录上次推送的 commit hash
- 如果配置不完整，脚本会报错并提示缺少的字段
- `.claude/sftp-cc/` 目录应加入 `.gitignore`（包含敏感的私钥和服务器信息）
- 所有脚本仅依赖 `sftp` 命令，无需安装 jq 等额外工具
- 推送整个项目时使用 `sftp` batch mode，按 excludes 规则过滤文件
