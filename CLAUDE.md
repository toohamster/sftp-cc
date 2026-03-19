# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

sftp-cc-toomaster 是一个 Claude Code Plugin，提供通用 SFTP 上传能力。支持通过 Plugin Marketplace 安装，也支持手动安装。

## Architecture

```
sftp-cc-toomaster/
├── .claude-plugin/
│   └── marketplace.json            # Marketplace 目录（插件信息 + 自托管分发）
├── skills/
│   └── sftp-cc-toomaster/
│       └── SKILL.md                # Skill 定义（YAML frontmatter + 指令）
├── scripts/
│   ├── sftp-push.sh                # 核心上传脚本（sftp batch mode）
│   ├── sftp-init.sh                # 初始化配置（创建 sftp-config.json）
│   ├── sftp-keybind.sh             # 私钥自动绑定 + chmod 600
│   └── sftp-copy-id.sh             # 部署 SSH 公钥到服务器（用户在本机终端运行）
├── templates/
│   └── sftp-config.example.json    # 配置模板
├── skill.md                        # Skill 定义（手动安装兼容）
└── install.sh                      # 手动安装脚本（非 marketplace 场景）
```

**Plugin 安装后**：plugin 缓存到 `~/.claude/plugins/marketplaces/`，SKILL.md 中通过 `${CLAUDE_PLUGIN_ROOT}` 引用脚本路径。配置和私钥始终在用户项目的 `.claude/sftp-cc/`。

## Key Design Decisions

- 所有脚本通过 `git rev-parse --show-toplevel` 定位用户项目根目录
- 私钥自动绑定：扫描 `.claude/sftp-cc/` 下的 id_rsa/id_ed25519/*.pem/*.key，自动写入 config
- SSH 公钥部署：通过 `sftp-copy-id.sh` 脚本，用户在本机终端运行（支持交互式密码输入）
- 推送整个项目时用 `find` + excludes 生成文件列表，再构建 sftp batch 文件
- 纯 shell 解析 JSON（grep/sed），零外部依赖
- 同时维护两套安装方式：Plugin Marketplace（SKILL.md）和手动安装（skill.md + install.sh）

## Testing Changes

```bash
# 验证 plugin 结构
claude plugin validate .

# 测试手动安装
bash install.sh /tmp/test-project

# 测试 dry-run push
bash scripts/sftp-push.sh -n
```
