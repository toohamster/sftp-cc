# 第 3 章：编写第一个 Skill

## 3.1 SKILL.md 结构

### 完整示例
```markdown
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

**私钥绑定类**:
- "bind sftp private key", "bind ssh key", "sftp keybind"
- "绑定 SFTP 私钥"、"绑定私钥"、"自动绑定私钥"
- "秘密鍵をバインドする", "SSH 鍵をバインドする"
- "sftp-keybind"

**触发后操作**：
- 上传类触发词 → 执行 `sftp-push.sh`
- 私钥绑定类触发词 → 执行 `sftp-keybind.sh`

**Important / 注意**：Do NOT treat "push" as a trigger — it conflicts with git push.
Only trigger when the user explicitly mentions SFTP or server upload/sync/deploy.
不要将 "push"、"推送" 视为触发条件，避免与 git push 冲突。

## 配置文件位置

- **配置文件**: `<项目根目录>/.claude/sftp-cc/sftp-config.json`
- **私钥存放**: `<项目根目录>/.claude/sftp-cc/` 目录下
- **脚本位置**: `${CLAUDE_PLUGIN_ROOT}/scripts/`

**注意**：`${CLAUDE_PLUGIN_ROOT}` 是 Claude Code 注入的 Skill 内部变量，仅在 Skill 上下文中有效。
执行脚本时，Claude 会自动将其解析为插件根目录路径（如 `~/.claude/plugins/marketplaces/sftp-cc/`）。

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

## 首次使用引导流程

当用户首次请求 SFTP 操作时，按以下步骤引导：

1. **检查配置是否存在**: 查看 `.claude/sftp-cc/sftp-config.json` 是否存在
2. **如果不存在**: 询问用户服务器信息，然后运行 `sftp-init.sh`
3. **部署公钥到服务器**: 在本地终端运行 `sftp-copy-id.sh`
4. **检查私钥**: 查看 `.claude/sftp-cc/` 下是否有私钥文件
5. **执行上传**: 运行 `sftp-push.sh`
```

---

## 3.2 YAML Frontmatter

### 必填字段
```yaml
---
name: sftp-cc
description: 通用 SFTP 上传工具...
---
```

| 字段 | 说明 | 示例 |
|------|------|------|
| name | Skill 名称 | `sftp-cc` |
| description | Skill 描述，出现在 Skill 列表中 | 通用 SFTP 上传工具... |

### 命名建议
- 使用小写字母和连字符
- 简短易记（不超过 20 字符）
- 避免与现有 Skill 重名

---

## 3.3 触发词设计技巧

### 好的触发词特征
1. **自然语言**：用户会说的话
   - ✅ "sync code to server"
   - ❌ "execute_sftp_upload"

2. **多语言覆盖**：英文、中文、日文
   ```
   - "sync code to server"          # 英文
   - "同步代码到服务器"              # 中文
   - "サーバーに同期する"            # 日文
   ```

3. **避免歧义**：
   - ❌ "push" — 与 git push 冲突
   - ✅ "sftp push" — 明确是 SFTP

### 触发词分组
```markdown
**SFTP 上传/部署类**:
- ...

**私钥绑定类**:
- ...

**配置初始化类**:
- ...
```

---

## 3.4 脚本路径说明

### 正确写法
```markdown
**脚本位置**: `${CLAUDE_PLUGIN_ROOT}/scripts/`

**注意**：`${CLAUDE_PLUGIN_ROOT}` 是 Claude Code 注入的 Skill 内部变量，仅在 Skill 上下文中有效。
执行脚本时，Claude 会自动将其解析为插件根目录路径。
```

### 常见错误
```markdown
# 错误：没有说明变量含义
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh

# 正确：添加说明
**注意**：变量由 Claude Code 自动注入，执行时解析
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh
```

---

## 3.5 添加明确的操作指引

### 问题场景
用户说 "绑定 SFTP 私钥"，但 Claude 不知道执行哪个脚本。

### 解决方案
在对应脚本章节添加明确说明：

```markdown
### 3. sftp-keybind.sh — 私钥自动绑定

**当用户请求绑定私钥时，执行此脚本。**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-keybind.sh
```
- 扫描 `.claude/sftp-cc/` 下的私钥文件
- 自动 `chmod 600` 修正权限
- 自动更新 `sftp-config.json` 的 `private_key` 字段
```

### 触发对应关系表
```markdown
## 技能触发对应关系

| 用户指令 | 执行脚本 |
|---------|---------|
| "同步代码到服务器" | `sftp-push.sh` |
| "绑定私钥" | `sftp-keybind.sh` |
| "初始化配置" | `sftp-init.sh` |
```

---

## 3.6 调试技巧

### 验证 SKILL.md 语法
```bash
# 检查 YAML frontmatter
head -5 skills/sftp-cc/SKILL.md

# 验证 markdown 格式
cat skills/sftp-cc/SKILL.md | head -50
```

### 测试触发词
1. 安装 Plugin
2. 在 Claude Code 中说触发词
3. 观察是否正确触发

### 常见问题

**Q: Skill 不触发**
- 检查触发词是否在 SKILL.md 中定义
- 重新安装 Plugin：`/plugin marketplace remove sftp-cc` 然后重新 add

**Q: 变量 ${CLAUDE_PLUGIN_ROOT} 未解析**
- 确认是在 Claude Code 对话框中执行
- 直接在 shell 中执行时需要用绝对路径

---

## 本章小结

- SKILL.md 包含 YAML frontmatter 和触发词定义
- 触发词要自然、多语言、无歧义
- 添加明确的脚本执行指引
- ${CLAUDE_PLUGIN_ROOT} 需要特别说明

## 下一章

第 4 章将带你进行脚本开发实战。
