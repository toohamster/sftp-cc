# Chapter 2: Project Planning and Design

> "If you can't describe it simply, you haven't truly understood it." — Albert Einstein

In this chapter, you will learn:
- How to conduct requirements analysis starting from pain points
- Methods for defining functional boundaries (what to do vs. what NOT to do)
- Modular functional design techniques
- Best practices for directory structure
- Configuration file design principles
- Trigger word design methodology
- Technology selection evaluation framework

---

## 2.1 Requirements Analysis

### 2.1.1 Starting from Pain Points

Good software starts with real problems, not technology itself. Let's document the original motivation for developing sftp-cc:

#### Problem Scenario

```
Scenario: Web project development using Claude Code

1. Developer writes code locally using Claude Code
2. Claude modifies src/user/controller.php
3. Need to verify functionality on test server
4. Manual operations:
   - Open terminal
   - SSH login to test server
   - git pull to fetch latest code
   - Or use scp to upload modified files
5. Repeat steps 3-4 every time Claude modifies code
```

**Time Cost Analysis**:

| Activity | Time per occurrence | Daily frequency | Total time/day |
|----------|--------------------|-----------------|----------------|
| Manual deployment | 2-3 minutes | 15 times | 30-45 minutes |
| Context switching | 1 minute | 15 times | 15 minutes |
| **Total wasted time** | | | **45-60 minutes** |

#### Existing Solutions and Their Limitations

| Solution | Pros | Cons |
|----------|------|------|
| **PhpStorm SFTP** | Auto-sync, simple config | Requires license, leaves Claude environment |
| **Manual scp** | No extra tools needed | Low efficiency, easy to miss files |
| **git + ssh** | Standard workflow | Cumbersome steps, requires server operations |
| **rsync scripts** | Automatable | Requires script writing and maintenance |

#### Opportunity Point

```
If a Claude Code Skill could:
- Understand natural language like "sync code to server"
- Automatically detect which files were modified
- Only upload changed files (incremental)
- Automatically handle SSH keys and permissions

That would greatly improve development efficiency.
```

### 2.1.2 User Personas

Before starting the design, clarify who will use this Skill:

#### Primary User: Junior Developer Alex

```
Background: 2 years PHP development experience
Daily Tasks:
  - Develops locally, needs to deploy to test server for verification
  - Deploys 10-20 times per day
  - Not familiar with Shell scripting
Pain Points:
  - Repeats the same commands every deployment
  - Sometimes forgets to upload certain files
  - Often makes mistakes configuring SSH keys
Expectations:
  - Complete deployment with one sentence
  - Automatic handling of configuration and keys
```

#### Secondary User: Senior Engineer Lisa

```
Background: 5 years DevOps experience
Daily Tasks:
  - Manages deployments for multiple projects
  - Needs fine-grained control over deployment behavior
  - Wants to integrate into existing workflow
Pain Points:
  - Inconsistent configuration methods across projects
  - Needs to view detailed deployment logs
Expectations:
  - Unified configuration format
  - Detailed logs and error messages
  - Support for custom exclusion rules
```

### 2.1.3 Requirements List

Transform user requirements into functional requirements with priority labels:

#### Must Have (Core Requirements)

| ID | Requirement | Priority | Description |
|----|-------------|----------|-------------|
| R1 | Upload files to server | ⭐⭐⭐ | Core functionality |
| R2 | Incremental upload | ⭐⭐⭐ | Only upload changed files |
| R3 | Automatic private key binding | ⭐⭐ | Simplify configuration |
| R4 | Permission correction (chmod 600) | ⭐⭐ | Fix private key permissions |
| R5 | Configuration file management | ⭐⭐ | Store server connection info |

#### Should Have (Important Enhancements)

| ID | Requirement | Priority | Description |
|----|-------------|----------|-------------|
| R6 | Multi-language support | ⭐ | Support English, Chinese, Japanese |
| R7 | Preview mode | ⭐ | Show what would be uploaded |
| R8 | Exclude file patterns | ⭐ | Skip .git, node_modules, etc. |

#### Nice to Have (Future Enhancements)

| ID | Requirement | Priority | Description |
|----|-------------|----------|-------------|
| R9 | Full upload option | ⭐ | Upload all files regardless of changes |
| R10 | Specific file upload | ⭐ | Upload a single file on demand |
| R11 | Directory upload | ⭐ | Upload a specific directory |

### 2.1.4 Functional Boundaries

Equally important is defining what NOT to do:

**Out of Scope**:
- ❌ Download files from server (one-way sync only)
- ❌ Real-time file change monitoring
- ❌ Multi-server simultaneous deployment
- ❌ Remote file editing
- ❌ Version control operations (git push/pull)

**Rationale**:

```
Why not download?
→ Adds complexity, most users only need upload
→ Can be added later if there's demand

Why not real-time monitoring?
→ Requires background processes
→ Increases resource consumption
→ Conflicts with IDE file watchers

Why not multi-server?
→ Adds configuration complexity
→ Most users deploy to one server at a time
→ Can be achieved by running multiple times
```

---

## 2.2 Functional Design

### 2.2.1 Core Function Modules

Decompose the system into independent modules:

```
sftp-cc
├── Configuration Initialization (sftp-init.sh)
│   ├── Create directory structure
│   ├── Generate config file from template
│   └── Accept command-line parameters
│
├── Private Key Binding (sftp-keybind.sh)
│   ├── Scan for private key files
│   ├── Fix permissions (chmod 600)
│   └── Update config file
│
├── Public Key Deployment (sftp-copy-id.sh)
│   ├── Find local public key
│   ├── Deploy to server's authorized_keys
│   └── Handle interactive password input
│
└── File Upload (sftp-push.sh)
    ├── Check configuration
    ├── Detect changed files
    ├── Generate SFTP batch commands
    └── Execute upload via sftp
```

### 2.2.2 Upload Mode Design

Design multiple upload modes to meet different needs:

| Mode | Command | Description | Use Case |
|------|---------|-------------|----------|
| **Incremental Upload** | `sftp-push.sh` | Default, only upload changes | Daily development |
| **Full Upload** | `sftp-push.sh --full` | Upload all files | First deployment |
| **Specific File** | `sftp-push.sh file.php` | Upload specified file | Quick fix deployment |
| **Specific Directory** | `sftp-push.sh -d src/` | Upload specified directory | Module deployment |
| **Preview Mode** | `sftp-push.sh -n` | Show only, do not execute | Verify before actual upload |

### 2.2.3 Incremental Detection Logic

The core of incremental upload is detecting changed files:

```bash
# Change Detection Algorithm

1. Check for last upload record
   └─→ If no record → Full upload (first time)

2. If record exists, detect changes:
   a) Committed changes since last upload
      git diff --name-only --diff-filter=ACMR <last_hash> HEAD

   b) Staged changes
      git diff --cached --name-only --diff-filter=ACMR

   c) Working directory modifications
      git diff --name-only --diff-filter=ACMR

   d) Untracked files
      git ls-files --others --exclude-standard

3. Merge and deduplicate file list
4. Filter by exclude patterns
5. Generate upload list
```

**File Status Codes** (git --diff-filter):

| Code | Meaning | Include in Upload |
|------|---------|-------------------|
| A | Added | ✅ Yes |
| C | Copied | ✅ Yes |
| M | Modified | ✅ Yes |
| R | Renamed | ✅ Yes |
| D | Deleted | ⚠️ Optional (--delete flag) |

### 2.2.4 Error Handling Design

Design error handling for various scenarios:

```
Error Scenarios:

1. Configuration File Missing
   └─→ Prompt user to run sftp-init.sh

2. Private Key Not Found
   └─→ Scan common locations, prompt user to place key

3. SFTP Connection Failed
   └─→ Display connection parameters, suggest verification

4. Upload Failed (Partial)
   └─→ Report which files failed, allow retry

5. Remote Directory Not Writable
   └─→ Suggest permission fix command
```

---

## 2.3 Directory Structure Planning

### 2.3.1 Final Structure

The complete sftp-cc project structure:

```
sftp-cc/
├── .claude-plugin/
│   └── marketplace.json        # Plugin marketplace configuration
│
├── skills/
│   └── sftp-cc/
│       └── SKILL.md            # Skill definition (Plugin installation)
│
├── scripts/
│   ├── sftp-init.sh            # Initialize configuration
│   ├── sftp-keybind.sh         # Private key binding
│   ├── sftp-copy-id.sh         # Public key deployment
│   ├── sftp-push.sh            # File upload (core)
│   └── i18n.sh                 # Internationalization support
│
├── templates/
│   └── sftp-config.example.json # Configuration template
│
├── skill.md                     # Skill definition (Manual installation)
├── install.sh                   # Manual installation script
│
├── README.md                    # English documentation
├── README_CN.md                 # Chinese documentation
├── README_JP.md                 # Japanese documentation
│
├── SPEC.md                      # Technical specifications
└── CLAUDE.md                    # Development guide
```

### 2.3.2 Two Installation Methods

Support both Plugin Marketplace and manual installation:

| Installation Method | Path | Pros | Cons |
|--------------------|------|------|------|
| **Plugin Installation** | `~/.claude/plugins/marketplaces/sftp-cc/` | Auto-update, recommended | Requires Claude Code plugin support |
| **Manual Installation** | `.claude/skills/sftp-cc/` (in project) | Compatible with older versions | Manual updates required |

**Installation Flow Comparison**:

```
Plugin Installation:
1. /plugin marketplace add <url>
2. /plugin install sftp-cc
3. Done! ✅

Manual Installation:
1. git clone <repo>
2. bash install.sh /path/to/project
3. Done! ✅
```

### 2.3.3 User Project Structure

After installation, user's project looks like:

```
user-project/
├── .claude/
│   ├── skills/
│   │   └── sftp-cc/              # Manual installation
│   │       ├── skill.md
│   │       └── scripts/
│   └── sftp-cc/                  # Configuration and keys
│       ├── sftp-config.json      # Server configuration
│       └── id_ed25519            # Private key (user placed)
│
├── src/                          # User's project files
├── .git/
└── ...
```

---

## 2.4 Configuration File Design

### 2.4.1 sftp-config.json Format

Design a clear, extensible JSON configuration:

```json
{
  "host": "example.com",
  "port": 22,
  "username": "deploy",
  "remote_path": "/var/www/html",
  "local_path": ".",
  "private_key": "",
  "language": "en",
  "excludes": [".git", ".claude", "node_modules", ".env", ".DS_Store"]
}
```

### 2.4.2 Field Specifications

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `host` | string | Yes | - | SFTP server address |
| `port` | number | No | 22 | SFTP port |
| `username` | string | Yes | - | Login username |
| `remote_path` | string | Yes | - | Remote target directory |
| `local_path` | string | No | "." | Local source directory |
| `private_key` | string | No | "" | Private key path (auto-filled) |
| `language` | string | No | "en" | Interface language |
| `excludes` | array | No | See above | Excluded files/directories |

### 2.4.3 Configuration Template

Provide a template for easy setup:

```json
{
  "host": "",
  "port": 22,
  "username": "",
  "remote_path": "",
  "local_path": ".",
  "private_key": "",
  "language": "en",
  "excludes": [
    ".git",
    ".claude",
    "node_modules",
    ".env",
    ".DS_Store",
    "*.log",
    "vendor/"
  ]
}
```

---

## 2.5 Trigger Word Design

### 2.5.1 Trigger Word Categories

Design trigger words for different scenarios:

#### SFTP Upload/Deploy Category

```
English:
- "sync code to server"
- "upload to server"
- "deploy code"
- "push to server" (with SFTP context)
- "sftp upload"

Chinese:
- "同步代码到服务器"
- "上传到服务器"
- "部署代码"
- "sftp 上传"

Japanese:
- "サーバーに同期する"
- "デプロイする"
- "sftp アップロード"
```

#### Private Key Binding Category

```
English:
- "bind sftp private key"
- "bind ssh key"
- "auto-bind private key"

Chinese:
- "绑定 SFTP 私钥"
- "绑定私钥"
- "自动绑定私钥"

Japanese:
- "秘密鍵をバインドする"
- "SSH 鍵をバインドする"
```

#### Configuration Initialization Category

```
English:
- "initialize sftp config"
- "setup sftp"
- "create sftp configuration"

Chinese:
- "初始化 SFTP 配置"
- "配置 SFTP"

Japanese:
- "SFTP 設定を初期化"
- "SFTP 設定"
```

### 2.5.2 Words That Should NOT Trigger

Avoid false triggers with common commands:

```
❌ "push" alone — Conflicts with git push
❌ "sync" alone — May trigger during git sync
❌ "deploy" without context — Could mean other deployment methods
```

### 2.5.3 Trigger Word Best Practices

| Principle | Description | Example |
|-----------|-------------|---------|
| **Natural Language** | Use what users actually say | ✅ "sync code to server" vs ❌ "execute_sftp_upload" |
| **Multi-language** | Cover target user languages | English + Chinese + Japanese |
| **Avoid Ambiguity** | Be specific, avoid conflicts | ✅ "sftp push" vs ❌ "push" |
| **Context Matters** | Consider surrounding words | "push to sftp server" is clear |

---

## 2.6 Technology Selection

### 2.6.1 Why Choose Shell

Evaluate scripting language options:

| Criterion | Shell | Python | Node.js |
|-----------|-------|--------|---------|
| **External Dependencies** | None (system built-in) | Requires pip install | Requires npm install |
| **System Compatibility** | All Unix-like systems | May need installation | May need installation |
| **Development Difficulty** | Low | Medium | Medium |
| **Execution Speed** | Fast | Medium | Medium |
| **Learning Curve** | Gentle | Moderate | Moderate |
| **Distribution Complexity** | Simple | Complex | Complex |

### 2.6.2 Zero External Dependencies Principle

Stick to system built-in commands:

```
Allowed Commands:
- sftp (OpenSSH package, standard on most systems)
- git (standard developer tool)
- grep, sed, awk (standard text processing)
- find, stat, chmod (standard file operations)

Not Allowed:
- jq (requires separate installation)
- Python scripts (requires Python installation)
- curl/wget (use sftp instead for file transfer)
```

### 2.6.3 JSON Parsing Without jq

Implement JSON parsing using only Shell:

```bash
# Read string value from JSON
json_get() {
    local file="$1" key="$2" default="${3:-}"
    local val
    val=$(grep "\"$key\"" "$file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    echo "${val:-$default}"
}

# Read number value from JSON
json_get_num() {
    local file="$1" key="$2" default="${3:-0}"
    local val
    val=$(grep "\"$key\"" "$file" 2>/dev/null | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
    echo "${val:-$default}"
}

# Usage:
HOST=$(json_get "$CONFIG_FILE" "host")
PORT=$(json_get_num "$CONFIG_FILE" "port" "22")
```

**How It Works**:

```
Input JSON:
{"host": "example.com", "port": 22}

Step 1: grep "\"host\""
Result: {"host": "example.com", "port": 22}

Step 2: sed 's/.*: *"\([^"]*\)".*/\1/'
Result: example.com

Step 3: Return value
Result: HOST="example.com"
```

---

## 2.7 User Workflow Design

### 2.7.1 First-Time User Flow

Design a smooth onboarding experience:

```
Step 1: Install Plugin
├─ /plugin marketplace add https://github.com/toohamster/sftp-cc
└─ /plugin install sftp-cc

Step 2: Initialize Configuration
├─ User says: "Initialize SFTP config"
├─ Skill runs: sftp-init.sh
└─ Creates: .claude/sftp-cc/sftp-config.json

Step 3: Place Private Key
├─ User places: id_ed25519 or id_rsa in .claude/sftp-cc/
└─ Skill auto-binds and fixes permissions

Step 4: Deploy Public Key (One-time)
├─ User runs: sftp-copy-id.sh (on local terminal)
└─ Deploys public key to server

Step 5: Start Using
├─ User says: "Sync code to server"
└─ Files uploaded! ✅
```

### 2.7.2 Daily Workflow

Typical daily usage pattern:

```
Developer writes code with Claude
        ↓
Modifies files locally
        ↓
Says: "Sync to server"
        ↓
Skill detects changes (incremental)
        ↓
Uploads only changed files
        ↓
Confirmation: "Upload complete! 5 files synced."
        ↓
Continue development
```

---

## Chapter Summary

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Requirements Analysis** | Start from pain points, define user personas |
| **Functional Boundaries** | Clearly define what NOT to do |
| **Modular Design** | Break into independent, testable modules |
| **Configuration Design** | JSON format with sensible defaults |
| **Trigger Words** | Natural language, multi-language, unambiguous |

### What You've Learned

- ✅ How to analyze requirements from pain points
- ✅ How to define functional boundaries
- ✅ Modular functional design techniques
- ✅ Directory structure best practices
- ✅ Configuration file design principles
- ✅ Trigger word design methodology
- ✅ Technology selection evaluation

---

## Exercises

### Exercise 2-1: Design Your Own Skill

Choose a function you want to implement and complete the following design:

#### Requirements Analysis Template

```markdown
## Problem Scenario
[Describe the problem you're solving]

## User Personas
- Primary User: [Who will use this most?]
- Secondary User: [Who else might use it?]

## Requirements List
| Requirement | Priority | Description |
|-------------|----------|-------------|
|             |          |             |

## Functional Boundaries
**Out of Scope:**
- 
- 

## Trigger Words
- English: 
- Chinese: 
- Japanese: 
```

### Exercise 2-2: Analyze an Existing Skill

1. Browse the [Plugin Marketplace](https://claude.ai/marketplace)
2. Choose one Skill
3. Analyze its:
   - Target users
   - Core requirements
   - Trigger word design
   - Configuration approach

---

## Extended Resources

### Requirements Analysis
- "User Stories Applied" by Mike Cohn
- "Inspired" by Marty Cagan

### System Design
- "Designing Data-Intensive Applications" by Martin Kleppmann
- "Clean Architecture" by Robert C. Martin

### Configuration Design
- [12factor.net - Config](https://12factor.net/config)
- JSON specification: [RFC 8259](https://tools.ietf.org/html/rfc8259)

---

## Next Chapter Preview

**Chapter 3: Writing Your First Skill**

In Chapter 3, we'll write the first Skill from scratch:
- YAML frontmatter detailed explanation
- Complete SKILL.md structure
- Trigger word writing techniques
- Script execution instructions
- First runnable Skill

By the end of Chapter 3, you'll have your first working Skill!

---

## About this Book

**First Edition (Digital), March 2026**

**Author**: [toohamster](https://github.com/toohamster)
**License**: Electronic version: MIT License | Print/Commercial: All Rights Reserved
**Source**: [github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

See [LICENSE](../../LICENSE) and [About Author](../authors.md) for details.

---
