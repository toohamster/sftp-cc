# 第 7 章：发布与分发

> "好的软件需要好的分发渠道。" — 开源软件格言

本章你将学到：
- Plugin Marketplace 架构和工作原理
- marketplace.json 完整字段详解
- SemVer 语义化版本管理规范
- GitHub HTTP API 发布流程
- 完整的自动化发布脚本
- 多语言 README 编写指南
- 持续集成（GitHub Actions）配置
- Plugin 安装和验证方法
- Release Notes 编写技巧

---

## 7.1 Plugin Marketplace 架构

### 7.1.1 Claude Code Plugin 生态系统

```
┌─────────────────────────────────────────────────────────┐
│              Claude Code Plugin 生态                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  开发者                          用户                    │
│    │                              │                     │
│    │  1. 创建 Plugin               │                     │
│    │     (marketplace.json +      │                     │
│    │      SKILL.md + scripts)     │                     │
│    │         ↓                    │                     │
│    │  2. 发布到 GitHub            │                     │
│    │         ↓                    │                     │
│    │  3. 提交到 Marketplace       │                     │
│    │                              │                     │
│    │                              │  4. 发现 Plugin     │
│    │                              │     /plugin search  │
│    │                              │         ↓           │
│    │                              │  5. 安装 Plugin     │
│    │                              │ /plugin marketplace │
│    │                              │         ↓           │
│    │                              │  6. 使用 Skill      │
│    │                              │  自然语言触发       │
│    │                              │                     │
└─────────────────────────────────────────────────────────┘
```

### 7.1.2 两种安装方式对比

#### 方式 1：Plugin Marketplace 安装

```bash
# 从 GitHub 仓库安装
/plugin marketplace add https://github.com/toohamster/sftp-cc

# 安装后位置
~/.claude/plugins/marketplaces/sftp-cc/

# 目录结构
~/.claude/plugins/marketplaces/sftp-cc/
├── .claude-plugin/
│   └── marketplace.json
├── skills/
│   └── sftp-cc/
│       └── SKILL.md
├── scripts/
│   ├── sftp-init.sh
│   ├── sftp-push.sh
│   └── ...
└── README.md
```

**优点**：
- ✅ 自动更新（插件系统自动同步）
- ✅ 统一管理（所有插件在一个目录）
- ✅ 版本控制（可以回退到旧版本）
- ✅ 发现性好（通过 Marketplace 浏览）

**缺点**：
- ❌ 需要推送到 GitHub
- ❌ 旧版本 Claude 可能不支持
- ❌ 需要 network 访问

#### 方式 2：手动安装

```bash
# 运行安装脚本
bash install.sh /path/to/target-project

# 或直接复制文件
cp -r skill.md target-project/.claude/skills/sftp-cc/
cp -r scripts/ target-project/.claude/skills/sftp-cc/

# 安装后位置
target-project/.claude/skills/sftp-cc/

# 目录结构
target-project/
├── .claude/
│   ├── skills/
│   │   └── sftp-cc/
│   │       ├── skill.md
│   │       └── scripts/
│   │           ├── sftp-init.sh
│   │           └── ...
│   └── sftp-cc/
│       └── sftp-config.json  # 用户配置
└── src/
    └── ...
```

**优点**：
- ✅ 本地即可安装
- ✅ 兼容旧版本
- ✅ 项目级别隔离（每个项目独立配置）
- ✅ 不需要 GitHub

**缺点**：
- ❌ 不会自动更新
- ❌ 每个项目需要单独安装
- ❌ 配置分散

### 7.1.3 安装方式选择指南

```
选择流程图：

需要多项目共享配置？
    │
    ├── 是 → Plugin 安装
    │
    └── 否
        │
        需要项目独立配置？
        │
        ├── 是 → 手动安装
        │
        └── 否
            │
            使用 GitHub？
            │
            ├── 是 → Plugin 安装
            │
            └── 否 → 手动安装
```

---

## 7.2 marketplace.json 详解

### 7.2.1 完整结构

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "sftp-cc",
  "description": "Universal SFTP upload tool for Claude Code. Supports incremental upload, private key auto-binding, and permission correction.",
  "owner": {
    "name": "toohamster",
    "email": "optional@example.com",
    "url": "https://github.com/toohamster"
  },
  "license": "MIT",
  "homepage": "https://github.com/toohamster/sftp-cc",
  "repository": {
    "type": "git",
    "url": "https://github.com/toohamster/sftp-cc.git"
  },
  "keywords": [
    "sftp",
    "upload",
    "deploy",
    "ssh",
    "file-transfer"
  ],
  "version": "2.2.0",
  "plugins": [
    {
      "name": "sftp-cc",
      "description": "Universal SFTP upload tool with incremental upload, private key auto-binding. Zero external dependencies.",
      "source": "./",
      "strict": false,
      "skills": [
        "./skills/sftp-cc"
      ],
      "commands": [
        {
          "name": "sftp-push",
          "description": "Upload files to SFTP server"
        },
        {
          "name": "sftp-keybind",
          "description": "Bind SSH private key"
        }
      ]
    }
  ]
}
```

### 7.2.2 字段详解表

#### 顶层字段

| 字段 | 类型 | 必填 | 说明 | 示例 |
|------|------|------|------|------|
| `$schema` | string | 是 | JSON Schema 验证 URL | `https://anthropic.com/...` |
| `name` | string | 是 | Plugin 唯一标识 | `sftp-cc` |
| `description` | string | 是 | Plugin 描述（Marketplace 列表显示） | 简短描述功能 |
| `owner` | object | 是 | 作者信息 | 见下 |
| `license` | string | 否 | 开源协议 | `MIT`, `Apache-2.0` |
| `homepage` | string | 否 | 项目主页 URL | GitHub 仓库地址 |
| `repository` | object | 否 | 代码仓库信息 | 见下 |
| `keywords` | array | 否 | 搜索关键词 | `["sftp", "upload"]` |
| `version` | string | 否 | 当前版本 | `2.2.0` |
| `plugins` | array | 是 | Plugin 配置数组 | 见下 |

#### owner 字段

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `name` | string | 是 | 作者名称（GitHub 用户名） |
| `email` | string | 否 | 联系邮箱 |
| `url` | string | 否 | 个人主页 |

#### repository 字段

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `type` | string | 是 | 仓库类型 | `git` |
| `url` | string | 是 | 仓库 URL |

#### plugins[].commands 字段（可选）

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `name` | string | 是 | 命令名称 |
| `description` | string | 否 | 命令描述 |

### 7.2.3 字段验证

```bash
# 验证 JSON 格式
jq '.' .claude-plugin/marketplace.json > /dev/null && echo "JSON 格式正确"

# 验证必需字段
validate_marketplace() {
    local file=".claude-plugin/marketplace.json"
    local errors=()

    # 检查必需字段
    for field in name description owner plugins; do
        if ! jq -e ".$field" "$file" > /dev/null 2>&1; then
            errors+=("缺少必需字段：$field")
        fi
    done

    # 检查 $schema
    if ! jq -e '."$schema"' "$file" > /dev/null 2>&1; then
        errors+=("缺少 \$schema 字段")
    fi

    # 报告结果
    if [ ${#errors[@]} -gt 0 ]; then
        echo "验证失败:"
        for err in "${errors[@]}"; do
            echo "  - $err"
        done
        return 1
    fi

    echo "验证通过"
    return 0
}
```

---

## 7.3 版本管理

### 7.3.1 SemVer 语义化版本规范

```
版本格式：MAJOR.MINOR.PATCH
         主版本号。次版本号。修订号

示例：v2.1.3
     │ │ └─ Patch: Bug 修复
     │ └─── Minor: 新功能
     └───── Major: 破坏性变更
```

#### 版本号递增规则

| 变更类型 | 递增 | 示例 | 说明 |
|----------|------|------|------|
| 破坏性变更 | MAJOR+1 | v1.0.0 → v2.0.0 | 删除 API、修改触发词 |
| 新功能 | MINOR+1 | v2.1.0 → v2.2.0 | 新增功能、向后兼容 |
| Bug 修复 | PATCH+1 | v2.1.0 → v2.1.1 | 修复问题、文档更新 |
| 预发布版本 | -alpha.1 | v2.0.0-alpha.1 | 测试版本 |
| 预发布版本 | -beta.1 | v2.0.0-beta.1 | 测试版本 |
| 预发布版本 | -rc.1 | v2.0.0-rc.1 | 候选版本 |

#### 版本递增决策树

```
这次发布包含什么？
    │
    ├── 破坏性变更（删除功能、修改 API）
    │       └──→ MAJOR 版本 +1
    │
    ├── 新功能（新增功能、新增触发词）
    │       └──→ MINOR 版本 +1
    │
    └── Bug 修复/文档更新
            └──→ PATCH 版本 +1
```

### 7.3.2 版本号管理脚本

```bash
#!/bin/bash
# version.sh — 版本管理工具

set -euo pipefail

# 获取当前最新版本
get_current_version() {
    git describe --tags --abbrev=0 2>/dev/null || echo "v2.0.0"
}

# 解析版本号
parse_version() {
    local version="$1"
    # 去掉 v 前缀
    version="${version#v}"
    echo "$version"
}

# 计算下一个版本号
next_version() {
    local current="$1"
    local type="${2:-patch}"  # major, minor, patch

    current=$(parse_version "$current")

    local major minor patch
    IFS='.' read -r major minor patch <<< "$current"

    case "$type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
    esac

    echo "v$major.$minor.$patch"
}

# 使用示例
CURRENT=$(get_current_version)
echo "当前版本：$CURRENT"

NEW_PATCH=$(next_version "$CURRENT" "patch")
echo "下一个 PATCH 版本：$NEW_PATCH"

NEW_MINOR=$(next_version "$CURRENT" "minor")
echo "下一个 MINOR 版本：$NEW_MINOR"

NEW_MAJOR=$(next_version "$CURRENT" "major")
echo "下一个 MAJOR 版本：$NEW_MAJOR"
```

### 7.3.3 CHANGELOG.md 规范

````markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.2.0] - 2024-01-15

### Added
- 新增 --delete 参数，支持同步删除远程文件
- 新增日语触发词支持

### Changed
- 优化增量检测逻辑，提高准确性

### Fixed
- 修复 JSON 解析在特殊字符下失败的问题
- 修复私钥路径包含空格时的问题

## [2.1.1] - 2024-01-10

### Fixed
- 修复 README 中的拼写错误

## [2.1.0] - 2024-01-08

### Added
- 新增私钥自动绑定功能
- 新增 sftp-keybind.sh 脚本

## [2.0.0] - 2024-01-01

### Changed
- 重命名为 sftp-cc（原 sftp-cc-toomaster）
- 重构目录结构

### Removed
- 移除已废弃的兼容模式
````

---

## 7.4 GitHub HTTP API 发布

### 7.4.1 API 端点详解

#### 创建 Git Tag

```http
POST /repos/{owner}/{repo}/git/refs
Host: api.github.com
Authorization: Bearer {token}
Accept: application/vnd.github.v3+json

{
  "ref": "refs/tags/v1.0.0",
  "sha": "commit_hash_here"
}
```

**响应**：
```json
{
  "ref": "refs/tags/v1.0.0",
  "url": "https://api.github.com/repos/owner/repo/git/refs/tags/v1.0.0",
  "object": {
    "sha": "commit_hash_here",
    "type": "commit",
    "url": "..."
  }
}
```

#### 创建 Release

```http
POST /repos/{owner}/{repo}/releases
Host: api.github.com
Authorization: Bearer {token}
Accept: application/vnd.github.v3+json

{
  "tag_name": "v1.0.0",
  "target_commitish": "main",
  "name": "v1.0.0 - First Release",
  "body": "Release notes here...",
  "draft": false,
  "prerelease": false
}
```

**响应**：
```json
{
  "id": 123456,
  "tag_name": "v1.0.0",
  "name": "v1.0.0 - First Release",
  "html_url": "https://github.com/owner/repo/releases/tag/v1.0.0",
  "created_at": "2024-01-15T12:00:00Z",
  ...
}
```

### 7.4.2 完整发布脚本

```bash
#!/bin/bash
# release.sh — 自动化发布脚本
# 支持 MAJOR/MINOR/PATCH 三种版本类型

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[info]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $*" >&2; }
error() { echo -e "${RED}[error]${NC} $*" >&2; }

# 配置
REPO_OWNER="toohamster"
REPO_NAME="sftp-cc"

# 解析参数
VERSION_TYPE="patch"  # 默认 PATCH 版本
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --major)
            VERSION_TYPE="major"
            shift
            ;;
        --minor)
            VERSION_TYPE="minor"
            shift
            ;;
        --patch)
            VERSION_TYPE="patch"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --major     发布 MAJOR 版本（破坏性变更）"
            echo "  --minor     发布 MINOR 版本（新功能）"
            echo "  --patch     发布 PATCH 版本（Bug 修复，默认）"
            echo "  --dry-run   预览模式，不实际发布"
            echo "  -h, --help  显示帮助"
            exit 0
            ;;
        *)
            error "未知参数：$1"
            exit 1
            ;;
    esac
done

# 检查是否有未提交的更改
check_clean_working_tree() {
    if [ -n "$(git status --porcelain)" ]; then
        error "工作目录有未提交的更改"
        error "请先提交或暂存更改"
        exit 1
    fi
}

# 检查是否在 main 分支
check_main_branch() {
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD)
    if [ "$branch" != "main" ]; then
        warn "当前不在 main 分支（当前：$branch）"
        read -p "是否继续？(y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# 获取 GitHub Token
get_github_token() {
    local token
    token=$(echo "url=https://github.com" | git credential fill 2>/dev/null | grep password | cut -d= -f2)

    if [ -z "$token" ]; then
        # 尝试从环境变量获取
        token="${GITHUB_TOKEN:-}"
    fi

    if [ -z "$token" ]; then
        error "无法获取 GitHub Token"
        error "请设置 GITHUB_TOKEN 环境变量或使用 git credential"
        exit 1
    fi

    echo "$token"
}

# 计算新版本号
calculate_new_version() {
    local current="$1"
    local type="$2"

    # 去掉 v 前缀
    current="${current#v}"

    local major minor patch
    IFS='.' read -r major minor patch <<< "$current"

    case "$type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
    esac

    echo "v$major.$minor.$patch"
}

# 创建 Git Tag
create_tag() {
    local tag="$1"
    local commit="$2"
    local token="$3"

    local response
    response=$(curl -s -X POST \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/git/refs" \
        -d "{\"ref\":\"refs/tags/$tag\",\"sha\":\"$commit\"}")

    # 检查是否成功
    if echo "$response" | grep -q '"message"'; then
        local message
        message=$(echo "$response" | jq -r '.message')
        error "创建 Tag 失败：$message"
        return 1
    fi

    info "Tag 创建成功：$tag"
    return 0
}

# 创建 GitHub Release
create_release() {
    local tag="$1"
    local commit="$2"
    local token="$3"

    local release_name="$tag - Release"
    local release_body="Release $tag

## 变更内容

详见 [CHANGELOG.md](https://github.com/$REPO_OWNER/$REPO_NAME/blob/main/CHANGELOG.md)

## 安装

\`\`\`bash
/plugin marketplace add https://github.com/$REPO_OWNER/$REPO_NAME
\`\`\`
"

    local response
    response=$(curl -s -X POST \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases" \
        -d "{
            \"tag_name\": \"$tag\",
            \"target_commitish\": \"$commit\",
            \"name\": \"$release_name\",
            \"body\": $(echo "$release_body" | jq -Rs '.'),
            \"draft\": false,
            \"prerelease\": false
        }")

    # 检查是否成功
    if echo "$response" | grep -q '"message"'; then
        local message
        message=$(echo "$response" | jq -r '.message')
        error "创建 Release 失败：$message"
        return 1
    fi

    local release_url
    release_url=$(echo "$response" | jq -r '.html_url')
    info "Release 创建成功：$release_url"
    return 0
}

# 主流程
main() {
    info "开始发布流程..."
    echo ""

    # 1. 预检查
    info "步骤 1/7: 预检查"
    check_clean_working_tree
    check_main_branch
    info "✓ 预检查通过"
    echo ""

    # 2. 获取当前版本
    info "步骤 2/7: 获取版本信息"
    local current_version
    current_version=$(git describe --tags --abbrev=0 2>/dev/null || echo "v2.0.0")
    info "当前版本：$current_version"

    local new_version
    new_version=$(calculate_new_version "$current_version" "$VERSION_TYPE")
    info "新版本：$new_version (类型：$VERSION_TYPE)"
    echo ""

    # 3. 获取 commit hash
    info "步骤 3/7: 获取当前 commit"
    local commit_hash
    commit_hash=$(git rev-parse HEAD)
    info "Commit: $commit_hash"
    echo ""

    # 4. 获取 Token
    info "步骤 4/7: 获取 GitHub Token"
    local github_token
    github_token=$(get_github_token)
    info "✓ Token 已获取"
    echo ""

    # 5. 用户确认
    info "步骤 5/7: 用户确认"
    echo "即将发布:"
    echo "  版本：$new_version"
    echo "  类型：$VERSION_TYPE"
    echo "  Commit: $commit_hash"
    echo ""

    if $DRY_RUN; then
        info "[预览模式] 跳过实际发布"
        exit 0
    fi

    read -p "确认发布 $new版本？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "已取消"
        exit 0
    fi
    echo ""

    # 6. 创建 Tag
    info "步骤 6/7: 创建 Git Tag"
    if ! create_tag "${new_version#v}" "$commit_hash" "$github_token"; then
        exit 1
    fi
    echo ""

    # 7. 创建 Release
    info "步骤 7/7: 创建 GitHub Release"
    if ! create_release "$new_version" "$commit_hash" "$github_token"; then
        exit 1
    fi
    echo ""

    info "发布完成！"
    info "查看 Release: https://github.com/$REPO_OWNER/$REPO_NAME/releases/tag/$new_version"
}

main "$@"
```

---

## 7.5 多语言 README 编写

### 7.5.1 README 结构模板

#### README.md（英文主文档）

```markdown
# sftp-cc

> Universal SFTP upload tool for Claude Code

[![Version](https://img.shields.io/github/v/tag/toohamster/sftp-cc)](https://github.com/toohamster/sftp-cc/releases)
[![License](https://img.shields.io/github/license/toohamster/sftp-cc)](LICENSE)

## Features

- **Incremental Upload**: Only upload changed files, save time
- **Auto Key Binding**: Automatically find and bind SSH private key
- **Permission Correction**: Auto-fix private key permissions (chmod 600)
- **Multi-language**: Support English, Chinese, and Japanese
- **Zero Dependencies**: Pure shell, no external tools required

## Installation

### Method 1: Plugin Marketplace (Recommended)

```bash
/plugin marketplace add https://github.com/toohamster/sftp-cc
```

### Method 2: Manual Installation

```bash
git clone https://github.com/toohamster/sftp-cc.git
cd sftp-cc
bash install.sh /path/to/your/project
```

## Quick Start

### 1. Initialize Configuration

```bash
bash scripts/sftp-init.sh \
  --host example.com \
  --port 22 \
  --username deploy \
  --remote-path /var/www/html
```

### 2. Place SSH Private Key

Copy your SSH private key to `.claude/sftp-cc/`:

```bash
cp ~/.ssh/id_rsa .claude/sftp-cc/
```

### 3. Sync Code

Just tell Claude:

```
Sync code to server
```

## Usage

### Trigger Words

| Trigger | Action |
|---------|--------|
| "sync code to server" | Upload changed files |
| "bind private key" | Bind SSH key |
| "initialize config" | Create configuration |

### Command Line

```bash
# Incremental upload (default)
bash scripts/sftp-push.sh

# Full upload
bash scripts/sftp-push.sh --full

# Preview mode
bash scripts/sftp-push.sh -n

# Upload specific files
bash scripts/sftp-push.sh file1.php file2.php
```

## Configuration

Edit `.claude/sftp-cc/sftp-config.json`:

```json
{
  "host": "example.com",
  "port": 22,
  "username": "deploy",
  "remote_path": "/var/www/html",
  "language": "en",
  "excludes": [".git", "node_modules"]
}
```

## Troubleshooting

### Private key permissions error

```bash
bash scripts/sftp-keybind.sh
```

### Skill not triggering

1. Check if Plugin is installed: `/plugin list`
2. Reinstall Plugin: `/plugin marketplace remove sftp-cc` then re-add

## License

MIT
```

#### README_CN.md（中文文档）

````markdown
# sftp-cc

> 通用的 Claude Code SFTP 上传工具

## 功能特性

- **增量上传**: 只上传变更文件，节省时间
- **私钥自动绑定**: 自动查找并绑定 SSH 私钥
- **权限修正**: 自动修正私钥权限 (chmod 600)
- **多语言支持**: 支持英文、中文、日文
- **零外部依赖**: 纯 Shell 实现，无需额外工具

## 安装方法

### 方法 1: Plugin Marketplace（推荐）

```bash
/plugin marketplace add https://github.com/toohamster/sftp-cc
```

### 方法 2: 手动安装

```bash
git clone https://github.com/toohamster/sftp-cc.git
cd sftp-cc
bash install.sh /path/to/your/project
```

## 快速开始

### 1. 初始化配置

```bash
bash scripts/sftp-init.sh \
  --host example.com \
  --port 22 \
  --username deploy \
  --remote-path /var/www/html
```

### 2. 放置 SSH 私钥

```bash
cp ~/.ssh/id_rsa .claude/sftp-cc/
```

### 3. 同步代码

告诉 Claude：

```
同步代码到服务器
```

## 配置说明

编辑 `.claude/sftp-cc/sftp-config.json`:

```json
{
  "host": "example.com",
  "port": 22,
  "username": "deploy",
  "remote_path": "/var/www/html",
  "language": "zh",
  "excludes": [".git", "node_modules"]
}
```

## 常见问题

### 私钥权限错误

```bash
bash scripts/sftp-keybind.sh
```

## 许可证

MIT
````

### 7.5.2 多语言维护技巧

```bash
# 脚本：检查多语言 README 同步
# check-readme-sync.sh

#!/bin/bash

# 提取各 README 的章节标题
extract_sections() {
    local file="$1"
    grep '^## ' "$file" | sed 's/^## //'
}

echo "=== README.md (English) ==="
extract_sections README.md

echo ""
echo "=== README_CN.md (中文) ==="
extract_sections README_CN.md

echo ""
echo "=== README_JP.md (日本語) ==="
extract_sections README_JP.md
```

---

## 7.6 持续集成配置

### 7.6.1 GitHub Actions 工作流

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  validate:
    name: Validate Plugin
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'

      - name: Install Claude Code
        run: npm install -g @anthropic-ai/claude-code

      - name: Validate Plugin Structure
        run: claude plugin validate .

  lint:
    name: Lint Scripts
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install ShellCheck
        run: apt-get update && apt-get install -y shellcheck

      - name: Run ShellCheck
        run: shellcheck scripts/*.sh

  test:
    name: Run Tests
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run Unit Tests
        run: bash tests/test-unit.sh

      - name: Run Integration Tests
        run: bash tests/test-integration.sh
```

### 7.6.2 自动发布工作流

```yaml
# .github/workflows/release.yml
name: Release

on:
  workflow_dispatch:
    inputs:
      version_type:
        description: 'Version type (major/minor/patch)'
        required: true
        default: 'patch'
        type: choice
        options:
          - major
          - minor
          - patch

jobs:
  release:
    name: Create Release
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # 获取所有 tag

      - name: Get current version
        id: version
        run: |
          CURRENT=$(git describe --tags --abbrev=0 2>/dev/null || echo "v2.0.0")
          CURRENT_NUM=${CURRENT#v}

          IFS='.' read -r major minor patch <<< "$CURRENT_NUM"

          case "${{ github.event.inputs.version_type }}" in
            major)
              major=$((major + 1))
              minor=0
              patch=0
              ;;
            minor)
              minor=$((minor + 1))
              patch=0
              ;;
            patch)
              patch=$((patch + 1))
              ;;
          esac

          NEW_VERSION="v$major.$minor.$patch"
          echo "current=$CURRENT" >> $GITHUB_OUTPUT
          echo "new=$NEW_VERSION" >> $GITHUB_OUTPUT

      - name: Get commit hash
        id: commit
        run: echo "hash=$(git rev-parse HEAD)" >> $GITHUB_OUTPUT

      - name: Create Git Tag
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.git.createRef({
              owner: context.repo.owner,
              repo: context.repo.repo,
              ref: 'refs/tags/${{ steps.version.outputs.new }}',
              sha: '${{ steps.commit.outputs.hash }}'
            })

      - name: Create Release
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.repos.createRelease({
              owner: context.repo.owner,
              repo: context.repo.repo,
              tag_name: '${{ steps.version.outputs.new }}',
              name: '${{ steps.version.outputs.new }} - Release',
              body: `Release ${{ steps.version.outputs.new }}

## Changes

See [CHANGELOG.md](https://github.com/${context.repo.owner}/${context.repo.repo}/blob/main/CHANGELOG.md)

## Installation

\`\`\`bash
/plugin marketplace add https://github.com/${context.repo.owner}/${context.repo.repo}
\`\`\``,
              draft: false,
              prerelease: false
            })

      - name: Update CHANGELOG
        run: |
          echo "## ${{ steps.version.outputs.new }} - $(date +%Y-%m-%d)" >> CHANGELOG.md
          echo "" >> CHANGELOG.md
          echo "### Changed" >> CHANGELOG.md
          echo "- Release ${{ steps.version.outputs.new }}" >> CHANGELOG.md
          echo "" >> CHANGELOG.md

      - name: Commit CHANGELOG
        uses: stefanzweifel/git-auto-commit-action@v5
        with:
          commit_message: "docs: update CHANGELOG for ${{ steps.version.outputs.new }}"
          file_pattern: CHANGELOG.md
```

---

## 7.7 本章总结

### 核心知识点回顾

| 概念 | 关键点 |
|------|--------|
| Plugin 安装 | marketplace.json + SKILL.md + scripts |
| marketplace.json | name, description, owner, plugins 必填 |
| SemVer | MAJOR.MINOR.PATCH，破坏性变更升 MAJOR |
| GitHub API | 创建 Tag 和 Release 两个步骤 |
| 发布脚本 | 预检查→计算版本→创建 Tag→创建 Release |
| 多语言 README | 结构一致、内容同步更新 |
| GitHub Actions | 自动验证、自动发布 |

### 发布检查清单

在发布前确认：

- [ ] 所有测试通过
- [ ] CHANGELOG.md 已更新
- [ ] README 多语言文档已同步
- [ ] marketplace.json version 已更新
- [ ] 代码已提交并推送到 main 分支
- [ ] 上一个 Release 已创建

---

## 7.8 练习与实践

### 基础练习

**练习 7-1**：完善 marketplace.json
- 添加所有可选字段
- 验证 JSON 格式

**练习 7-2**：编写 CHANGELOG
- 按照 Keep a Changelog 格式
- 记录所有历史版本

### 进阶练习

**练习 7-3**：创建发布脚本
- 实现完整的 release.sh
- 支持 MAJOR/MINOR/PATCH

**练习 7-4**：配置 GitHub Actions
- 创建 CI 工作流
- 创建自动发布工作流

### 实践项目

为你的 Skill 完成一次完整发布：
1. 创建 CHANGELOG.md
2. 更新 marketplace.json
3. 运行发布脚本
4. 验证 Release 已创建
5. 测试 Plugin 安装

---

## 下一章预告

第 8 章将介绍**进阶技巧与最佳实践**：
- 性能优化技巧
- 安全最佳实践
- 代码组织规范
- 用户反馈处理
- 故障排查清单
- 扩展开发方向
- 学习资源推荐

---

## 关于本书

**第一版（数字版）, 2026 年 3 月**

**作者**：[toohamster](https://github.com/toohamster)
**授权**：电子版 MIT License，纸质版/商业版 © All Rights Reserved
**源码**：[github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

详细说明请参阅 [LICENSE](../../LICENSE) 和 [关于作者](../authors.md)

---
