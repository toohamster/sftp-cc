# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

sftp-cc 是一个 Claude Code Plugin，提供通用 SFTP 上传能力。支持通过 Plugin Marketplace 安装，也支持手动安装。

**多语言支持 (i18n)**：支持英语 (en)、中文 (zh)、日语 (ja)。语言配置存储在 `.claude/sftp-cc/sftp-config.json` 的 `language` 字段。

## Architecture

```
sftp-cc/
├── .claude-plugin/
│   └── marketplace.json            # Marketplace 目录（插件信息 + 自托管分发）
├── skills/
│   └── sftp-cc/
│       └── SKILL.md                # Skill 定义（YAML frontmatter + 指令）
├── scripts/
│   ├── sftp-push.sh                # 核心上传脚本（sftp batch mode）
│   ├── sftp-init.sh                # 初始化配置（创建 sftp-config.json）
│   ├── sftp-keybind.sh             # 私钥自动绑定 + chmod 600
│   ├── sftp-copy-id.sh             # 部署 SSH 公钥到服务器（用户在本机终端运行）
│   └── i18n.sh                     # 国际化工具（支持 en/zh/ja 三语言）
├── templates/
│   └── sftp-config.example.json    # 配置模板
├── skill.md                        # Skill 定义（手动安装兼容）
├── install.sh                      # 手动安装脚本（支持 --language 选项）
├── README.md                       # 英文文档
├── README_CN.md                    # 中文文档
└── README_JP.md                    # 日文文档
```

**Plugin 安装后**：plugin 缓存到 `~/.claude/plugins/marketplaces/`，SKILL.md 中通过 `${CLAUDE_PLUGIN_ROOT}` 引用脚本路径。配置和私钥始终在用户项目的 `.claude/sftp-cc/`。

## Key Design Decisions

- 所有脚本通过 `git rev-parse --show-toplevel` 定位用户项目根目录
- 私钥自动绑定：扫描 `.claude/sftp-cc/` 下的 id_rsa/id_ed25519/*.pem/*.key，自动写入 config
- SSH 公钥部署：通过 `sftp-copy-id.sh` 脚本，用户在本机终端运行（支持交互式密码输入）
- 推送整个项目时用 `find` + excludes 生成文件列表，再构建 sftp batch 文件
- 纯 shell 解析 JSON（grep/sed），零外部依赖
- 同时维护两套安装方式：Plugin Marketplace（SKILL.md）和手动安装（skill.md + install.sh）
- i18n 采用变量式多语言方案（$MSG_XXX），非 gettext，零外部依赖

## Testing Changes

```bash
# 验证 plugin 结构
claude plugin validate .

# 测试手动安装
bash install.sh /tmp/test-project

# 测试 dry-run push
bash scripts/sftp-push.sh -n
```

## 操作规范

### 发布 GitHub Release

**当用户说 "提交打标签和发布" 时，自动执行以下完整流程（无需确认）：**

```bash
# 1. 提交所有更改
git add -A
git commit -m "feat: description

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"

# 2. 推送代码
git push origin main

# 3. 创建并推送 tag（自动递增版本号）
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v2.0.0")
# 从 v2.1.0 → v2.2.0 (minor 版本 +1)
NEW_TAG=$(echo "$LAST_TAG" | awk -F. '{print $1"."$2"."$3+1}')
git tag "$NEW_TAG"
git push origin "$NEW_TAG"

# 4. 从 git credential 获取 GitHub Token
GITHUB_TOKEN=$(echo "url=https://github.com" | git credential fill | grep password | cut -d= -f2)

# 5. 获取最新 commit hash
COMMIT_HASH=$(git rev-parse HEAD)

# 6. 使用 curl 创建 GitHub Release（JSON body 避免使用反引号）
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/toohamster/sftp-cc/releases \
  -d "{\"tag_name\":\"$NEW_TAG\",\"target_commitish\":\"$COMMIT_HASH\",\"name\":\"$NEW_TAG - Release\",\"body\":\"Release $NEW_TAG\",\"draft\":false,\"prerelease\":false}"
```

**注意：**
- JSON body 中禁止使用反引号 `` ` `` — 会被 bash 解析为命令替换
- 使用 `git credential fill` 获取 token，而不是从 remote URL 提取
- 版本号自动递增：从上一个 tag 的 minor 版本 +1
