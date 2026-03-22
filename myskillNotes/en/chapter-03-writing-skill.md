# Chapter 3: Writing Your First Skill

> "The only way to learn is by doing." — Programming Proverb

In this chapter, you will learn:
- Complete SKILL.md structure and format
- YAML frontmatter field explanations
- Trigger word writing techniques
- Script execution instructions
- How to write a first runnable Skill

---

## 3.1 SKILL.md Complete Structure

### 3.1.1 Full Example

Here's a complete SKILL.md example from sftp-cc:

````markdown
---
name: sftp-cc
description: Universal SFTP upload tool, triggered by natural language, uploads local project files to remote server. Supports incremental upload, automatic private key binding and permission correction.
---

# SFTP Push Skill — sftp-cc

> Universal SFTP upload tool with automatic private key binding and permission correction.

## When to Trigger This Skill

**SFTP Upload/Deploy Category**:
- "sync code to server", "upload to server", "upload files to server"
- "deploy code", "deploy to server", "send files to server"
- "sftp upload", "sftp sync", "sftp transfer"
- "同步代码到服务器", "上传到服务器", "上传文件到服务器"
- "部署代码", "把文件传到服务器上"
- "sftp 上传", "sftp 同步"

**Private Key Binding Category**:
- "bind sftp private key", "bind ssh key", "sftp keybind"
- "绑定 SFTP 私钥", "绑定私钥", "自动绑定私钥"
- "秘密鍵をバインドする", "SSH 鍵をバインドする"

**After Triggering**:
- Upload triggers → Execute `sftp-push.sh`
- Private key binding → Execute `sftp-keybind.sh`

**Important**: Do NOT treat "push" as a trigger — it conflicts with git push.
Only trigger when user explicitly mentions SFTP or server upload/sync/deploy.

## Configuration File Location

- **Config File**: `<project-root>/.claude/sftp-cc/sftp-config.json`
- **Private Key Storage**: In `<project-root>/.claude/sftp-cc/` directory
- **Script Location**: `${CLAUDE_PLUGIN_ROOT}/scripts/`

**Note**: `${CLAUDE_PLUGIN_ROOT}` is an internal Skill variable injected by Claude Code, only valid in Skill context.

## Available Scripts

### 1. sftp-init.sh — Initialize Configuration
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-init.sh \
  --host example.com \
  --port 22 \
  --username deploy \
  --remote-path /var/www/html
```

### 2. sftp-keybind.sh — Private Key Binding
**Execute when user requests private key binding:**
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-keybind.sh
```
- Scans `.claude/sftp-cc/` for private key files
- Automatically fixes permissions (chmod 600)
- Updates `private_key` field in sftp-config.json

### 3. sftp-push.sh — Upload Files
```bash
# Incremental upload (default)
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh

# Full upload
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh --full

# Preview mode
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh -n
```

## First-Time User Guide

When user first requests SFTP operation:

1. **Check if config exists**: Look for `.claude/sftp-cc/sftp-config.json`
2. **If not exists**: Ask for server info, then run `sftp-init.sh`
3. **Deploy public key**: Run `sftp-copy-id.sh` on local terminal
4. **Check private key**: Look in `.claude/sftp-cc/` for key files
5. **Execute upload**: Run `sftp-push.sh`
````

### 3.1.2 Structure Breakdown

```
SKILL.md Structure:
│
├── YAML Frontmatter (required)
│   ├── name: Skill identifier
│   └── description: Shown in plugin list
│
├── Title (H1)
│   └── Clear, descriptive name
│
├── Brief Description (blockquote)
│   └── One-sentence summary
│
├── Trigger Section
│   ├── When to trigger
│   ├── Trigger word categories
│   └── What happens after trigger
│
├── Configuration Section
│   ├── Config file location
│   ├── Important notes
│   └── Variable explanations
│
├── Scripts Section
│   ├── Available scripts
│   ├── Usage examples
│   └── Execution conditions
│
└── User Guide Section
    ├── First-time flow
    └── Common operations
```

---

## 3.2 YAML Frontmatter Deep Dive

### 3.2.1 Required Fields

Every SKILL.md must have YAML frontmatter:

```yaml
---
name: my-skill-name
description: A brief description of what your skill does
---
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Skill identifier (lowercase, hyphens) |
| `description` | string | Yes | Shown in plugin list |

### 3.2.2 Naming Best Practices

```yaml
# Good names ✅
name: sftp-cc
name: weather-skill
name: github-deploy

# Bad names ❌
name: MySkill  # No spaces, use hyphens
name: SFTP_CC  # Use lowercase
name: sftp-cc-plugin-v2-final  # Keep it simple
```

### 3.2.3 Description Writing Tips

```yaml
# Good descriptions ✅
description: Universal SFTP upload tool for deploying code to servers
description: Get current weather for any city worldwide
description: Deploy to GitHub Pages with one command

# Bad descriptions ❌
description: My skill  # Too vague
description: This is a skill that does many things including...  # Too long
description: The best skill ever created  # Not descriptive
```

**Formula for good descriptions**:
```
[What it does] + [How it's triggered] + [Key benefit]

Example:
"Universal SFTP upload tool, triggered by natural language, 
 uploads local project files to remote server."
```

---

## 3.3 Trigger Word Design Techniques

### 3.3.1 Characteristics of Good Trigger Words

| Characteristic | Description | Example |
|----------------|-------------|---------|
| **Natural Language** | What users actually say | ✅ "sync code to server" vs ❌ "execute_sftp" |
| **Multi-language** | Cover target languages | English + Chinese + Japanese |
| **Unambiguous** | Clear meaning, no conflicts | ✅ "sftp upload" vs ❌ "push" |
| **Context-rich** | Include relevant context | "deploy code to server" |

### 3.3.2 Trigger Word Categories

Organize trigger words by functionality:

````markdown
## When to Trigger

**Category 1: Upload/Deploy**
- Related trigger words...

**Category 2: Configuration**
- Related trigger words...

**Category 3: Key Management**
- Related trigger words...
````

### 3.3.3 Semantic Expansion Techniques

For each core function, list variations:

```
Core: "sync to server"

Variations:
- "sync code to server"
- "sync files to server"
- "sync my project to server"
- "upload to server"
- "deploy to server"
- "push to server"

Multi-language:
- Chinese: "同步到服务器"
- Japanese: "サーバーに同期する"
```

### 3.3.4 Avoiding False Triggers

Identify and exclude ambiguous terms:

```markdown
**Important Notes:**

Do NOT trigger on:
- "push" alone — Conflicts with git push
- "sync" alone — May trigger during git operations
- "deploy" without server context

Only trigger when:
- User explicitly mentions SFTP or server
- Context clearly indicates file upload
```

---

## 3.4 Script Path Explanation

### 3.4.1 Understanding ${CLAUDE_PLUGIN_ROOT}

```markdown
**Important**: ${CLAUDE_PLUGIN_ROOT} is an internal Skill variable

- Injected by Claude Code at runtime
- Only valid in Skill context
- Resolves to plugin root directory path
- Example: `~/.claude/plugins/marketplaces/sftp-cc/`
```

### 3.4.2 Correct Usage Examples

```markdown
✅ Correct:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/process.py
```

❌ Wrong (in shell directly):
```bash
# Variable is empty in direct shell execution
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh
# Error: bash: /scripts/sftp-push.sh: No such file or directory
```

### 3.4.3 Common Mistakes

| Mistake | Problem | Solution |
|---------|---------|----------|
| Using in shell directly | Variable not injected | Use absolute path |
| Forgetting to quote | Path with spaces fails | Quote: "${CLAUDE_PLUGIN_ROOT}" |
| Hard-coding paths | Breaks on different systems | Always use variable |

---

## 3.5 Adding Clear Execution Instructions

### 3.5.1 When to Execute Each Script

For each script, specify when it should run:

```markdown
### sftp-keybind.sh — Private Key Binding

**Execute when user requests:**
- "bind private key"
- "fix ssh key permissions"
- "auto-bind my key"

**What it does:**
1. Scans for private key files
2. Fixes permissions (chmod 600)
3. Updates configuration file
```

### 3.5.2 Trigger-Action Mapping Table

Create a clear mapping for Claude:

```markdown
## Trigger-Action Mapping

| User Request | Script to Execute |
|--------------|-------------------|
| "Sync code to server" | `sftp-push.sh` |
| "Upload these files" | `sftp-push.sh file1 file2` |
| "Bind my private key" | `sftp-keybind.sh` |
| "Initialize SFTP config" | `sftp-init.sh` |
| "Deploy public key" | `sftp-copy-id.sh` |
```

---

## 3.6 User Guide Design

### 3.6.1 First-Time Flow

Design a clear onboarding path:

```markdown
## First-Time Setup Guide

When user first requests SFTP operation:

**Step 1: Check Configuration**
- Look for `.claude/sftp-cc/sftp-config.json`
- If missing → Initialize with `sftp-init.sh`

**Step 2: Place Private Key**
- Put `id_rsa` or `id_ed25519` in `.claude/sftp-cc/`
- Skill auto-binds with `sftp-keybind.sh`

**Step 3: Deploy Public Key** (One-time)
- Run `sftp-copy-id.sh` on local terminal
- Enter server password when prompted

**Step 4: Start Using**
- Say "sync code to server"
- Files uploaded! ✅
```

### 3.6.2 Error Handling Guidance

Tell Claude how to handle errors:

```markdown
## Error Handling

**Configuration Missing:**
→ Prompt: "SFTP configuration not found. Run 'initialize SFTP config' to set up."

**Private Key Not Found:**
→ Prompt: "No private key found. Please place id_rsa or id_ed25519 in .claude/sftp-cc/"

**Connection Failed:**
→ Prompt: "SFTP connection failed. Verify server address and credentials."

**Upload Failed:**
→ Report specific failed files, suggest retry
```

---

## 3.7 Debugging Tips

### 3.7.1 Validating SKILL.md Syntax

```bash
# Check YAML frontmatter
head -5 skills/sftp-cc/SKILL.md

# Verify structure
cat skills/sftp-cc/SKILL.md | head -50
```

### 3.7.2 Testing Trigger Words

```
Local Test Flow:
1. Install Plugin: /plugin marketplace add <path>
2. In Claude Code, say trigger word
3. Observe if Skill triggers correctly
4. If not: Check trigger word list
```

### 3.7.3 Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Skill doesn't trigger | Trigger word not defined | Add to SKILL.md |
| Variable not resolved | Running outside Skill context | Use absolute path |
| Script not found | Wrong path in SKILL.md | Check ${CLAUDE_PLUGIN_ROOT} |

---

## Chapter Summary

### Key Concepts

| Concept | Description |
|---------|-------------|
| **YAML Frontmatter** | Required metadata at top of SKILL.md |
| **Trigger Words** | Natural language phrases that activate Skill |
| **${CLAUDE_PLUGIN_ROOT}** | Internal variable, auto-resolved at runtime |
| **Execution Instructions** | Clear guidance on when to run each script |

### What You've Learned

- ✅ Complete SKILL.md structure and format
- ✅ YAML frontmatter required fields
- ✅ Trigger word design techniques
- ✅ Script path explanation best practices
- ✅ User guide design principles

---

## Exercises

### Exercise 3-1: Write Your First SKILL.md

Create a SKILL.md for a simple Skill:

```markdown
1. Choose a simple function (e.g., weather, greeting)
2. Write YAML frontmatter
3. List 5+ trigger words
4. Add script execution instructions
5. Test in Claude Code
```

### Exercise 3-2: Analyze Existing SKILL.md

1. Open `skills/sftp-cc/SKILL.md`
2. Identify each section
3. Note trigger word patterns
4. Understand execution flow

### Exercise 3-3: Improve Trigger Words

Take a basic trigger word and expand it:
- Start: "upload"
- Expand to: 10+ variations in 3 languages

---

## Extended Resources

### Official Documentation
- [Claude Code SKILL.md Format](https://docs.anthropic.com/claude-code/)
- [Plugin Marketplace Guide](https://claude.ai/marketplace)

### YAML Reference
- [YAML Specification](https://yaml.org/spec/)
- [Learn YAML in 5 minutes](https://www.codeproject.com/Articles/1214409/Learn-YAML-in-five-minutes)

### Next Steps
- Chapter 4: Script Development
- Chapter 5: Internationalization (i18n)

---

## Next Chapter Preview

**Chapter 4: Script Development**

In Chapter 4, we dive into script development:
- Complete script structure template
- Pure Shell JSON parsing (no jq dependency)
- Comprehensive error handling
- Temporary file management
- Full sftp-keybind.sh code walkthrough

By the end of Chapter 4, you'll be able to write robust Shell scripts for your Skills!

---

## About this Book

**First Edition (Digital), March 2026**

**Author**: [toohamster](https://github.com/toohamster)
**License**: Electronic version: MIT License | Print/Commercial: All Rights Reserved
**Source**: [github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

See [LICENSE](../../LICENSE) and [About Author](../authors.md) for details.

