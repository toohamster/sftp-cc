# Chapter 7: Publishing and Distribution

> "Software is like entropy: It is difficult to grasp, weighs nothing, and obeys the Second Law of Thermodynamics; i.e., it always increases." — Norman Augustine

In this chapter, you will learn:
- Plugin Marketplace architecture and requirements
- `marketplace.json` configuration (all fields explained)
- Semantic Versioning (SemVer) specification
- Creating GitHub Releases via API
- Automated release workflow (git → tag → release)
- Multi-language README structure
- Plugin validation before publishing
- Distribution strategies

---

## 7.1 Plugin Marketplace Architecture

### 7.1.1 How the Marketplace Works

The Claude Code Plugin Marketplace is a curated collection of Skills that users can browse and install. Here's how it works:

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Developer     │  →  │  GitHub Repo     │  →  │   Marketplace   │
│   (You)         │     │  (Your Code)     │     │   (Index)       │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                                        ↓
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   User          │  ←  │  Plugin Cache    │  ←  │   Install       │
│   (Installs)    │     │  (~/.claude/)    │     │   Command       │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

### 7.1.2 Installation Flow

When a user installs your plugin:

1. **User runs install command:**
   ```bash
   /plugin marketplace add https://github.com/toohamster/sftp-cc
   ```

2. **Claude Code fetches repository:**
   - Clones to `~/.claude/plugins/marketplaces/sftp-cc/`
   - Reads `.claude-plugin/marketplace.json`
   - Validates structure

3. **Plugin is registered:**
   - Skills in `skills/` directory are loaded
   - Available via natural language triggers

4. **User can now use your Skill:**
   ```
   User: "Sync code to server"
   Claude: [Executes sftp-push.sh]
   ```

### 7.1.3 Required Directory Structure

```
sftp-cc/
├── .claude-plugin/
│   └── marketplace.json    # REQUIRED for marketplace
├── skills/
│   └── sftp-cc/
│       └── SKILL.md        # REQUIRED skill definition
├── scripts/
│   ├── sftp-push.sh        # Your executable scripts
│   ├── sftp-init.sh
│   └── sftp-keybind.sh
├── templates/
│   └── sftp-config.example.json
├── README.md               # Documentation (highly recommended)
└── LICENSE                 # License file (recommended)
```

**Required vs Optional:**

| File/Directory | Required | Purpose |
|----------------|----------|---------|
| `.claude-plugin/marketplace.json` | **Yes** | Marketplace metadata |
| `skills/<name>/SKILL.md` | **Yes** | Skill definition |
| `scripts/` | No | External scripts (can use inline) |
| `README.md` | No (Recommended) | User documentation |
| `LICENSE` | No (Recommended) | License information |
| `templates/` | No | Configuration templates |

---

## 7.2 marketplace.json Configuration

### 7.2.1 Complete Example

```json
{
  "name": "sftp-cc",
  "description": "Universal SFTP upload tool for Claude Code. Sync code to remote servers with natural language commands.",
  "author": "toohamster",
  "version": "1.2.0",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/toohamster/sftp-cc.git"
  },
  "homepage": "https://github.com/toohamster/sftp-cc",
  "keywords": [
    "sftp",
    "upload",
    "sync",
    "deployment",
    "ssh",
    "file-transfer"
  ],
  "engines": {
    "claude-code": ">=1.0.0"
  },
  "categories": [
    "productivity",
    "deployment",
    "file-operations"
  ]
}
```

### 7.2.2 Field-by-Field Explanation

#### `name` (Required)
- **Type:** String
- **Format:** lowercase, hyphens allowed
- **Purpose:** Unique identifier for your plugin

```json
{
  "name": "sftp-cc"  // ✓ Good
}

{
  "name": "SFTP CC"  // ✗ Bad: spaces, uppercase
}
```

#### `description` (Required)
- **Type:** String
- **Max Length:** 200 characters
- **Purpose:** Shown in marketplace listing

```json
{
  "description": "Universal SFTP upload tool for Claude Code. Sync code to remote servers with natural language commands."
}
```

**Tips:**
- Start with what it does
- Include key benefit
- Keep it concise

#### `author` (Recommended)
- **Type:** String
- **Format:** Your name or GitHub username

```json
{
  "author": "toohamster"
}
```

#### `version` (Required)
- **Type:** String
- **Format:** Semantic Version (SemVer) - See Section 7.3

```json
{
  "version": "1.2.0"  // MAJOR.MINOR.PATCH
}
```

#### `license` (Recommended)
- **Type:** String
- **Format:** SPDX license identifier

```json
{
  "license": "MIT"     // ✓ Common
}

{
  "license": "Apache-2.0"  // ✓ Also common
}

{
  "license": "ISC"     // ✓ Also valid
}
```

**Common Licenses:**

| License | Identifier | Use Case |
|---------|------------|----------|
| MIT | `MIT` | Permissive, simple |
| Apache 2.0 | `Apache-2.0` | Permissive, patent protection |
| ISC | `ISC` | Permissive, similar to MIT |
| GPL 3.0 | `GPL-3.0` | Copyleft (viral) |

#### `repository` (Recommended)
- **Type:** Object
- **Purpose:** Link to source code

```json
{
  "repository": {
    "type": "git",
    "url": "https://github.com/toohamster/sftp-cc.git"
  }
}
```

#### `homepage` (Recommended)
- **Type:** String
- **Purpose:** Project homepage/documentation

```json
{
  "homepage": "https://github.com/toohamster/sftp-cc"
}
```

#### `keywords` (Optional)
- **Type:** Array of strings
- **Purpose:** Help users find your plugin

```json
{
  "keywords": [
    "sftp",
    "upload",
    "sync",
    "deployment",
    "ssh",
    "file-transfer"
  ]
}
```

#### `engines` (Optional)
- **Type:** Object
- **Purpose:** Specify Claude Code version requirements

```json
{
  "engines": {
    "claude-code": ">=1.0.0"
  }
}
```

**Version Specifiers:**

| Specifier | Meaning |
|-----------|---------|
| `>=1.0.0` | Version 1.0.0 or higher |
| `^1.0.0` | Compatible with 1.x.x (>=1.0.0, <2.0.0) |
| `~1.0.0` | Approximately 1.0.x (>=1.0.0, <1.1.0) |
| `1.0.0` | Exactly version 1.0.0 |

#### `categories` (Optional)
- **Type:** Array of strings
- **Purpose:** Group related plugins

```json
{
  "categories": [
    "productivity",
    "deployment",
    "file-operations"
  ]
}
```

**Common Categories:**
- `productivity` - Workflow improvements
- `file-operations` - File manipulation
- `deployment` - Deployment tools
- `code-generation` - Code creation
- `testing` - Testing utilities
- `documentation` - Docs generation
- `integration` - External services

### 7.2.3 Validation

Validate your `marketplace.json` before publishing:

```bash
# Check JSON syntax
jq . .claude-plugin/marketplace.json

# Or use Python
python3 -m json.tool .claude-plugin/marketplace.json

# Verify required fields exist
jq 'has("name") and has("description") and has("version")' .claude-plugin/marketplace.json
# Should return: true
```

---

## 7.3 Semantic Versioning (SemVer)

### 7.3.1 SemVer Specification

Semantic Versioning 2.0.0 (SemVer) is a versioning scheme that conveys meaning about the changes in a release.

**Format:** `MAJOR.MINOR.PATCH`

```
1.2.3
│ │ │
│ │ └─ PATCH: Bug fixes (backward compatible)
│ └─── MINOR: New features (backward compatible)
└───── MAJOR: Breaking changes
```

### 7.3.2 When to Increment Each

#### PATCH Version (`1.0.0` → `1.0.1`)

Increment for backward-compatible bug fixes:

- Fix a bug in existing functionality
- Security patches
- Performance improvements (no API changes)
- Documentation updates

**Examples:**
```
1.0.0 → 1.0.1  # Fixed null pointer in JSON parser
1.0.0 → 1.0.1  # Security patch for credential handling
1.0.0 → 1.0.1  # Fixed typo in error message
```

#### MINOR Version (`1.0.0` → `1.1.0`)

Increment for backward-compatible new features:

- New Skills or scripts
- New configuration options (with defaults)
- Extended functionality (doesn't break existing)

**Examples:**
```
1.0.0 → 1.1.0  # Added dry-run mode (-n flag)
1.0.0 → 1.1.0  # Added Japanese language support
1.0.0 → 1.1.0  # New script: sftp-copy-id.sh
```

#### MAJOR Version (`1.0.0` → `2.0.0`)

Increment for breaking changes:

- Removing or renaming Skills
- Changing configuration file format (breaking existing configs)
- Changing script behavior in incompatible ways
- Removing deprecated features

**Examples:**
```
1.0.0 → 2.0.0  # Changed config file format
1.0.0 → 2.0.0  # Removed deprecated "push" trigger word
1.0.0 → 2.0.0  # Changed default remote_path behavior
```

### 7.3.3 Version Number Examples

| From | To | Change Type | Reason |
|------|-----|-------------|--------|
| 1.0.0 | 1.0.1 | PATCH | Bug fix in upload logic |
| 1.0.1 | 1.1.0 | MINOR | Added verbose mode |
| 1.1.0 | 1.1.1 | PATCH | Fixed verbose mode output |
| 1.1.1 | 1.2.0 | MINOR | Added Japanese i18n |
| 1.2.0 | 2.0.0 | MAJOR | Changed config schema |
| 2.0.0 | 2.0.1 | PATCH | Migration script fix |

### 7.3.4 Pre-release and Build Metadata

**Pre-release versions** (alpha, beta, RC):

```
1.0.0-alpha.1    # First alpha
1.0.0-alpha.2    # Second alpha
1.0.0-beta.1     # First beta
1.0.0-rc.1       # First release candidate
1.0.0-rc.2       # Second release candidate
1.0.0            # Final release
```

**Build metadata:**

```
1.0.0+20240101   # Build date
1.0.0+abc1234    # Commit hash
1.0.0-beta.1+abc1234  # Pre-release with build
```

**Note:** Build metadata is ignored in version precedence.

---

## 7.4 GitHub Release Automation

### 7.4.1 Why Automate Releases?

Manual releases are error-prone:
- ❌ Forget to create tag
- ❌ Wrong commit for tag
- ❌ Inconsistent release notes
- ❌ Missing files in release

Automated releases are:
- ✅ Consistent
- ✅ Repeatable
- ✅ Traceable
- ✅ Fast

### 7.4.2 GitHub API Overview

GitHub provides REST API for creating releases:

**Endpoints used:**

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/git/refs` | POST | Create tag reference |
| `/releases` | POST | Create release |
| `/repos/{owner}/{repo}` | GET | Get repository info |

**Authentication:**
- Use Personal Access Token (PAT) or OAuth token
- Scope required: `repo` (full control of private repositories)

### 7.4.3 Getting Your GitHub Token

#### Method 1: From Git Credentials

If you've authenticated git:

```bash
GITHUB_TOKEN=$(echo "url=https://github.com" | git credential fill | grep password | cut -d= -f2)
```

#### Method 2: From Environment Variable

```bash
# Add to ~/.zshrc or ~/.bashrc
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"

# Then use in scripts
echo $GITHUB_TOKEN
```

#### Method 3: Create Personal Access Token

1. Go to GitHub → Settings → Developer settings → Personal access tokens
2. Click "Generate new token (classic)"
3. Select scope: `repo` (full control)
4. Generate and copy token
5. Store securely (password manager, `~/.netrc`, etc.)

### 7.4.4 Creating a Tag via API

**Step 1: Get latest commit hash**

```bash
COMMIT_HASH=$(git rev-parse HEAD)
echo "Latest commit: $COMMIT_HASH"
```

**Step 2: Calculate new version**

```bash
# Get last tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v1.0.0")

# Extract version numbers
LAST_MAJOR=$(echo "$LAST_TAG" | sed 's/v\([0-9]*\)\.[0-9]*\.[0-9]*/\1/')
LAST_MINOR=$(echo "$LAST_TAG" | sed 's/v[0-9]*\.\([0-9]*\)\.[0-9]*/\1/')
LAST_PATCH=$(echo "$LAST_TAG" | sed 's/v[0-9]*\.[0-9]*\.\([0-9]*\)/\1/')

# Increment PATCH version
NEW_PATCH=$((LAST_PATCH + 1))
NEW_TAG="v${LAST_MAJOR}.${LAST_MINOR}.${NEW_PATCH}"

echo "New version: $NEW_TAG"
```

**Step 3: Create tag reference**

```bash
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/toohamster/sftp-cc/git/refs \
  -d "{\"ref\":\"refs/tags/$NEW_TAG\",\"sha\":\"$COMMIT_HASH\"}"
```

**Response (success):**
```json
{
  "ref": "refs/tags/v1.2.1",
  "object": {
    "sha": "abc123...",
    "type": "commit"
  }
}
```

### 7.4.5 Creating a Release via API

```bash
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/toohamster/sftp-cc/releases \
  -d "{
    \"tag_name\": \"$NEW_TAG\",
    \"target_commitish\": \"$COMMIT_HASH\",
    \"name\": \"$NEW_TAG - Release\",
    \"body\": \"## Changes\\n\\n- Feature 1\\n- Feature 2\\n- Bug fixes\\n\\n**Full Changelog**: https://github.com/toohamster/sftp-cc/compare/$LAST_TAG...$NEW_TAG\",
    \"draft\": false,
    \"prerelease\": false
  }"
```

**Response (success):**
```json
{
  "id": 123456789,
  "tag_name": "v1.2.1",
  "name": "v1.2.1 - Release",
  "html_url": "https://github.com/toohamster/sftp-cc/releases/tag/v1.2.1",
  "created_at": "2024-01-01T00:00:00Z"
}
```

### 7.4.6 Complete Release Script

```bash
#!/bin/bash
# scripts/release.sh
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m'

info() { echo -e "${GREEN}[$SCRIPT_NAME]${NC} $*"; }
error() { echo -e "${RED}[$SCRIPT_NAME] ERROR:${NC} $*" >&2; }

# Get GitHub token
GITHUB_TOKEN=$(echo "url=https://github.com" | git credential fill | grep password | cut -d= -f2)
if [ -z "$GITHUB_TOKEN" ]; then
    error "Failed to get GitHub token"
    exit 1
fi

# Repository info
REPO_OWNER="toohamster"
REPO_NAME="sftp-cc"

# Get latest commit
COMMIT_HASH=$(git rev-parse HEAD)
info "Latest commit: $COMMIT_HASH"

# Get last tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v1.0.0")
info "Last tag: $LAST_TAG"

# Calculate new version (increment PATCH)
LAST_MAJOR=$(echo "$LAST_TAG" | sed 's/v\([0-9]*\)\.[0-9]*\.[0-9]*/\1/')
LAST_MINOR=$(echo "$LAST_TAG" | sed 's/v[0-9]*\.\([0-9]*\)\.[0-9]*/\1/')
LAST_PATCH=$(echo "$LAST_TAG" | sed 's/v[0-9]*\.[0-9]*\.\([0-9]*\)/\1/')
NEW_PATCH=$((LAST_PATCH + 1))
NEW_TAG="v${LAST_MAJOR}.${LAST_MINOR}.${NEW_PATCH}"

info "Creating new tag: $NEW_TAG"

# Create tag
TAG_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/git/refs \
  -d "{\"ref\":\"refs/tags/$NEW_TAG\",\"sha\":\"$COMMIT_HASH\"}")

if echo "$TAG_RESPONSE" | grep -q '"ref"'; then
    info "Tag created: $NEW_TAG"
else
    error "Failed to create tag: $TAG_RESPONSE"
    exit 1
fi

# Generate changelog (commits since last tag)
CHANGELOG=$(git log "$LAST_TAG"..HEAD --pretty=format:"- %s" | head -20)
if [ -z "$CHANGELOG" ]; then
    CHANGELOG="- Initial release"
fi

# Create release
RELEASE_DATA=$(cat <<EOF
{
  "tag_name": "$NEW_TAG",
  "target_commitish": "$COMMIT_HASH",
  "name": "$NEW_TAG - Release",
  "body": "## What's Changed\n\n$CHANGELOG\n\n**Full Changelog**: https://github.com/$REPO_OWNER/$REPO_NAME/compare/$LAST_TAG...$NEW_TAG",
  "draft": false,
  "prerelease": false
}
EOF
)

RELEASE_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases \
  -d "$RELEASE_DATA")

if echo "$RELEASE_RESPONSE" | grep -q '"tag_name"'; then
    RELEASE_URL=$(echo "$RELEASE_RESPONSE" | grep -o '"html_url":"[^"]*"' | cut -d'"' -f4)
    info "Release created: $RELEASE_URL"
else
    error "Failed to create release: $RELEASE_RESPONSE"
    exit 1
fi

info "Release $NEW_TAG published successfully!"
```

### 7.4.7 One-Command Release

Combine commit, push, and release:

```bash
#!/bin/bash
# scripts/commit-and-release.sh
set -euo pipefail

# Usage: ./commit-and-release.sh "feat: add new feature"

if [ -z "${1:-}" ]; then
    echo "Usage: $0 \"commit message\""
    exit 1
fi

COMMIT_MSG="$1"

# Commit
git add -A
git commit -m "$COMMIT_MSG

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"

# Push
git push origin main

# Release
bash scripts/release.sh
```

**Usage:**
```bash
./commit-and-release.sh "feat: add dry-run mode"
```

---

## 7.5 Multi-language README

### 7.5.1 Directory Structure

```
sftp-cc/
├── README.md           # English (default)
├── README_CN.md        # Simplified Chinese
├── README_JP.md        # Japanese
├── README_ES.md        # Spanish (optional)
└── README_DE.md        # German (optional)
```

### 7.5.2 English README.md Structure

````markdown
# sftp-cc

Universal SFTP upload tool for Claude Code.

## Features

- 🚀 One-command upload to remote server
- 🔄 Incremental sync (only changed files)
- 🔐 Auto-binding SSH private key
- 🌍 Multi-language support (EN/ZH/JA)

## Installation

```bash
/plugin marketplace add https://github.com/toohamster/sftp-cc
```

## Quick Start

1. Place your private key in `.claude/sftp-cc/`
2. Run initialization:
   ```bash
   bash scripts/sftp-init.sh --host example.com --username deploy --remote-path /var/www
   ```
3. Upload code:
   ```
   User: "Sync code to server"
   ```

## Configuration

Edit `.claude/sftp-cc/sftp-config.json`:

```json
{
  "host": "example.com",
  "port": 22,
  "username": "deploy",
  "remote_path": "/var/www"
}
```

## Usage

| Command | Description |
|---------|-------------|
| `bash scripts/sftp-push.sh` | Upload changed files |
| `bash scripts/sftp-push.sh -n` | Preview mode |
| `bash scripts/sftp-push.sh --full` | Full upload |
| `bash scripts/sftp-init.sh` | Initialize config |

## Other Languages

- [中文](README_CN.md)
- [日本語](README_JP.md)

## License

MIT License
````

### 7.5.3 Chinese README_CN.md Structure

````markdown
# sftp-cc

通用的 Claude Code SFTP 上传工具。

## 功能特性

- 🚀 一键上传到远程服务器
- 🔄 增量同步（仅上传变更文件）
- 🔐 自动绑定 SSH 私钥
- 🌍 多语言支持（中/英/日）

## 安装

```bash
/plugin marketplace add https://github.com/toohamster/sftp-cc
```

## 快速开始

1. 将私钥放入 `.claude/sftp-cc/` 目录
2. 初始化配置：
   ```bash
   bash scripts/sftp-init.sh --host example.com --username deploy --remote-path /var/www
   ```
3. 上传代码：
   ```
   User: "同步代码到服务器"
   ```

## 配置说明

编辑 `.claude/sftp-cc/sftp-config.json`：

```json
{
  "host": "example.com",
  "port": 22,
  "username": "deploy",
  "remote_path": "/var/www"
}
```

## 使用命令

| 命令 | 说明 |
|------|------|
| `bash scripts/sftp-push.sh` | 上传变更文件 |
| `bash scripts/sftp-push.sh -n` | 预览模式 |
| `bash scripts/sftp-push.sh --full` | 全量上传 |
| `bash scripts/sftp-init.sh` | 初始化配置 |

## 其他语言

- [English](README.md)
- [日本語](README_JP.md)

## 授权

MIT License
````

### 7.5.4 Japanese README_JP.md Structure

````markdown
# sftp-cc

Claude Code 用の汎用 SFTP アップロードツール

## 機能

- 🚀 ワンコマンドでリモートサーバーにアップロード
- 🔄 増分同期（変更ファイルのみ）
- 🔐 SSH 秘密鍵の自動バインド
- 🌍 多言語サポート（英語/中国語/日本語）

## インストール

```bash
/plugin marketplace add https://github.com/toohamster/sftp-cc
```

## クイックスタート

1. 秘密鍵を `.claude/sftp-cc/` に配置
2. 初期化：
   ```bash
   bash scripts/sftp-init.sh --host example.com --username deploy --remote-path /var/www
   ```
3. アップロード：
   ```
   User: "サーバーに同期する"
   ```

## 設定

`.claude/sftp-cc/sftp-config.json` を編集：

```json
{
  "host": "example.com",
  "port": 22,
  "username": "deploy",
  "remote_path": "/var/www"
}
```

## 使い方

| コマンド | 説明 |
|----------|------|
| `bash scripts/sftp-push.sh` | 変更ファイルをアップロード |
| `bash scripts/sftp-push.sh -n` | プレビューモード |
| `bash scripts/sftp-push.sh --full` | フルアップロード |
| `bash scripts/sftp-init.sh` | 設定を初期化 |

## 他の言語

- [English](README.md)
- [中文](README_CN.md)

## ライセンス

MIT License
````

### 7.5.5 Language Links

Each README should link to others:

````markdown
## Other Languages

| Language | Link |
|----------|------|
| English | [README.md](README.md) |
| 中文 | [README_CN.md](README_CN.md) |
| 日本語 | [README_JP.md](README_JP.md) |
````

---

## 7.6 Plugin Validation

### 7.6.1 Pre-publish Checklist

Before publishing, verify:

```bash
# 1. Validate marketplace.json
jq . .claude-plugin/marketplace.json > /dev/null && echo "✓ JSON valid"

# 2. Check required fields
jq -e '.name and .description and .version' .claude-plugin/marketplace.json > /dev/null && echo "✓ Required fields present"

# 3. Verify SKILL.md exists
[ -f "skills/sftp-cc/SKILL.md" ] && echo "✓ SKILL.md exists"

# 4. Check scripts are executable
[ -x "scripts/sftp-push.sh" ] && echo "✓ Scripts executable"

# 5. Validate JSON in templates
jq . templates/sftp-config.example.json > /dev/null && echo "✓ Template valid"

# 6. Run ShellCheck on scripts
shellcheck scripts/*.sh && echo "✓ ShellCheck passed"

# 7. Test installation locally
bash install.sh /tmp/test-project && echo "✓ Installation works"
```

### 7.6.2 Claude Plugin Validator

Use Claude's built-in validator:

```bash
claude plugin validate .
```

**Expected output:**
```
✓ marketplace.json is valid
✓ SKILL.md found and properly formatted
✓ All scripts are executable
✓ Plugin structure is correct
```

### 7.6.3 Test Installation Flow

```bash
# Create test project
mkdir -p /tmp/test-sftp-cc
cd /tmp/test-sftp-cc
git init

# Install your plugin (manual method)
bash /path/to/sftp-cc/install.sh .

# Verify structure
tree -a .claude/

# Test skill
claude
# Say: "hello" or "sync code"
```

---

## 7.7 Distribution Strategies

### 7.7.1 GitHub-Only Distribution

Simplest approach - host on GitHub:

```bash
# Users install with:
/plugin marketplace add https://github.com/toohamster/sftp-cc
```

**Pros:**
- ✅ Free hosting
- ✅ Built-in version control
- ✅ Issues and PRs for feedback
- ✅ Release management

**Cons:**
- ❌ Requires GitHub account
- ❌ Users need GitHub access

### 7.7.2 Self-hosted Distribution

Host plugin files on your own server:

```
your-domain.com/
└── sftp-cc/
    ├── .claude-plugin/
    │   └── marketplace.json
    └── skills/
        └── sftp-cc/
            └── SKILL.md
```

**Users install with:**
```bash
/plugin marketplace add https://your-domain.com/sftp-cc
```

**Requirements:**
- HTTPS enabled server
- Static file hosting
- CORS headers (if needed)

### 7.7.3 Private/Internal Distribution

For internal team use:

```bash
# Clone to internal server
git clone git@github.com:your-org/sftp-cc-internal.git

# Team members install with:
/plugin marketplace add /path/to/internal/sftp-cc
```

Or use internal git server:
```bash
/plugin marketplace add git@internal-server:tools/sftp-cc.git
```

### 7.7.4 Version Pinning

For stable deployments, pin to specific version:

```bash
# Install specific tag
/plugin marketplace add https://github.com/toohamster/sftp-cc@v1.2.0

# Or specific branch
/plugin marketplace add https://github.com/toohamster/sftp-cc@stable
```

---

## Chapter Summary

### Key Concepts

| Concept | Description | Example |
|---------|-------------|---------|
| `marketplace.json` | Plugin metadata | Name, version, license |
| SemVer | Version numbering | `1.2.3` = MAJOR.MINOR.PATCH |
| GitHub API | Create releases programmatically | `POST /releases` |
| Release automation | Commit → Tag → Release | One-command workflow |
| Multi-language README | Documentation in multiple languages | README.md, README_CN.md |
| Plugin validation | Pre-publish checklist | JSON, structure, scripts |
| Distribution channels | How users get your plugin | GitHub, self-hosted, internal |

### Publishing Checklist

- [ ] `marketplace.json` has all required fields
- [ ] `SKILL.md` exists and is properly formatted
- [ ] All scripts pass ShellCheck
- [ ] README.md is complete
- [ ] LICENSE file is included
- [ ] Tests pass locally
- [ ] Version number is incremented
- [ ] GitHub Release is created
- [ ] Plugin validates successfully

---

## Exercises

### Exercise 7-1: Create Your marketplace.json

Create a complete `marketplace.json` for your Skill:

1. Create `.claude-plugin/` directory
2. Create `marketplace.json` with all fields:
   - name, description, version
   - author, license
   - repository, homepage
   - keywords, categories
3. Validate with `jq`:
   ```bash
   jq . .claude-plugin/marketplace.json
   ```

### Exercise 7-2: Write a Release Script

Create `scripts/release.sh`:

1. Get GitHub token from credentials
2. Calculate new version number
3. Create tag via GitHub API
4. Generate changelog from git log
5. Create release via GitHub API
6. Print release URL on success

Test with a dry-run (add `--dry-run` flag).

### Exercise 7-3: Create Multi-language README

Add international documentation:

1. Write English `README.md`
2. Create `README_CN.md` (Chinese)
3. Create `README_JP.md` (Japanese)
4. Add language links in each file
5. Test by viewing in browser

---

## Extended Resources

### GitHub API Documentation
- [GitHub REST API](https://docs.github.com/en/rest)
- [Creating Releases](https://docs.github.com/en/rest/releases/releases)
- [Git References API](https://docs.github.com/en/rest/git/refs)

### Semantic Versioning
- [SemVer 2.0.0 Specification](https://semver.org/)
- [Semantic Versioning Explained](https://blog.npmjs.org/post/617484925549558784/semantic-versioning)

### Plugin Examples
- [sftp-cc Repository](https://github.com/toohamster/sftp-cc)
- [Claude Code Plugin Marketplace](https://claude.ai/marketplace)

### Further Reading
- "Writing Great Release Notes" - Keep a Changelog
- "GitHub Actions for CI/CD" - Automate your workflow
- "Open Source Licensing" - Choose a license

---

## Next Chapter Preview

**Chapter 8: Advanced Topics and Best Practices**

In Chapter 8, we'll cover advanced topics:
- Performance optimization techniques
- Security best practices (avoid command injection)
- Code organization and naming conventions
- Advanced error handling with `trap`
- Troubleshooting common issues
- Real-world case studies
- Performance profiling

By the end of Chapter 8, you'll write production-ready Skills!

---

## About this Book

**First Edition (Digital), March 2026**

**Author**: [toohamster](https://github.com/toohamster)
**License**: Electronic version: MIT License | Print/Commercial: All Rights Reserved
**Source**: [github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

See [LICENSE](../../LICENSE) and [About Author](../authors.md) for details.

---
