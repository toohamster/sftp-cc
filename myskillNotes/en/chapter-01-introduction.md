# Chapter 1: Introduction to Claude Code Skill

> "The best tools are the ones you forget exist." — Alan Kay

In this chapter, you will learn:
- What Claude Code Skill is and what problems it solves
- Core components and working principles of Plugin architecture
- How to set up a complete development environment
- Write your first Hello World Skill hands-on

---

## 1.1 What is Claude Code Skill

### 1.1.1 Background: The Birth of Skill

In the history of software development, every innovation in development experience has brought productivity leaps:

```
Command-line IDE (Vi/Emacs) → GUI IDE (VS Code) → AI-assisted coding (Claude Code)
         ↓                          ↓                        ↓
    Plain text editing      Visualization + Plugins    Natural language interaction
```

Claude Code is a CLI programming assistant launched by Anthropic, and **Skill** is its plugin system. Unlike traditional IDE plugins, Skills are **triggered by natural language**, allowing you to call automation functions by simply speaking.

### 1.1.2 Formal Definition of Skill

**Claude Code Skill** is a Markdown-based plugin definition format that tells Claude:
1. **When to trigger** — What the user says to invoke this Skill
2. **How to execute** — What scripts or commands to run after triggering
3. **What capabilities to provide** — Specific functions the Skill can complete

Expressed in code, a Skill at minimum contains:

````markdown
---
name: my-skill
description: My First Skill
---

# My Skill

When user says "hello", execute:
```bash
echo "Hello, World!"
```
````

### 1.1.3 What Skills Can Do

The capability boundary of Skills is almost equivalent to what your Shell can do. Here are some practical application scenarios:

#### File Operations
| Skill | Trigger Example | Purpose |
|-------|----------------|---------|
| SFTP Upload | "Sync code to server" | Deploy local code to remote server |
| File Sync | "Sync config to test environment" | Multi-environment config synchronization |
| Backup Tool | "Backup current database" | Schedule backups of important data |

#### Code Processing
| Skill | Trigger Example | Purpose |
|-------|----------------|---------|
| Code Formatting | "Format this file" | Unify code style |
| Batch Rename | "Change all .jsx to .tsx" | Large-scale file renaming |
| API Generator | "Generate user CRUD API" | Generate code from templates |

#### External Integration
| Skill | Trigger Example | Purpose |
|-------|----------------|---------|
| GitHub Operations | "Create a new release" | Call GitHub API |
| Deployment Notification | "Notify team deployment complete" | Send Slack/DingTalk messages |
| Documentation Generation | "Generate API documentation" | Call documentation generation tools |

### 1.1.4 Comparison with Other Plugin Systems

To understand Skill's positioning, the best approach is to compare with other systems:

#### vs VS Code Extensions

| Dimension | Claude Code Skill | VS Code Extension |
|-----------|-------------------|-------------------|
| **Trigger Method** | Natural language conversation | Button click / keyboard shortcut / command palette |
| **Development Language** | Markdown + Shell/Python | TypeScript/JavaScript |
| **Learning Curve** | Low (write docs = develop) | High (need to understand VS Code API) |
| **Distribution** | Git repository URL | VS Code Marketplace |
| **Runtime Environment** | Claude Code CLI | VS Code renderer process |
| **Debugging Method** | View script output | DevTools + breakpoint debugging |
| **Typical Development Time** | 30 minutes | Days to weeks |

**When to Choose Skill**:
- ✅ Need to quickly implement automation scripts
- ✅ Functionality can be completed via command line
- ✅ Want to trigger with natural language

**When to Choose VS Code Extension**:
- ✅ Need UI interface interaction
- ✅ Need deep VS Code feature integration (debugger, terminal)
- ✅ Need complex user configuration interface

#### vs JetBrains Plugins

| Dimension | Claude Code Skill | JetBrains Plugin |
|-----------|-------------------|------------------|
| Development Language | Markdown + Shell | Java/Kotlin |
| IDE Compatibility | Cross-IDE (via Claude Code) | Specific IDE (IntelliJ, PyCharm, etc.) |
| Distribution Complexity | Simple (Git URL) | Complex (JetBrains Marketplace) |

---

## 1.2 Claude Code Plugin Architecture

### 1.2.1 Directory Structure

A complete Claude Code Plugin has the following basic structure:

```
my-plugin/
├── .claude-plugin/
│   └── marketplace.json    # Marketplace configuration (for distribution)
├── skills/
│   └── my-skill/
│       └── SKILL.md        # Skill definition (CORE)
├── scripts/
│   └── my-script.sh        # Execution script
└── README.md               # Documentation
```

**Directory Purposes**:

| Directory/File | Purpose | Required |
|----------------|---------|----------|
| `.claude-plugin/marketplace.json` | Plugin marketplace configuration | For distribution |
| `skills/<skill-name>/SKILL.md` | Skill definition file | **Required** |
| `scripts/` | Executable scripts | Optional (can use inline) |
| `README.md` | Documentation | Recommended |

### 1.2.2 Core Components

#### 1. SKILL.md — The Heart of Skill

SKILL.md is the core definition file for the Skill, containing:

````markdown
---
name: skill-name
description: Brief description of what your skill does
---

# Skill Name

## When to trigger

List of trigger words and phrases...

## What it does

Description of functionality...

## How to execute

Script execution instructions...
```

**Key Elements**:
- **YAML Frontmatter**: Metadata at the top (between `---`)
- **Trigger Words**: Phrases that activate the Skill
- **Execution Logic**: What happens when triggered

#### 2. ${CLAUDE_PLUGIN_ROOT} Variable

```markdown
**Important**: ${CLAUDE_PLUGIN_ROOT} is an internal Skill variable injected by Claude Code

- Only valid in Skill context
- Automatically resolved to plugin root directory path at runtime
- Example: `~/.claude/plugins/marketplaces/my-plugin/`
```

**How Variable Injection Works**:

```
User triggers Skill
       ↓
Claude Code loads SKILL.md
       ↓
Claude Code injects ${CLAUDE_PLUGIN_ROOT} with actual path
       ↓
Script executes with resolved path
```

#### 3. scripts/ Directory

The scripts/ directory stores executable scripts:

- **Supported Languages**: Shell, Python, Ruby, Node.js, etc.
- **Access Method**: Via `${CLAUDE_PLUGIN_ROOT}/scripts/`
- **Best Practice**: Keep scripts modular and well-documented

**Example Script Structure**:

```bash
#!/bin/bash
# my-script.sh — Brief description

set -euo pipefail

# Your logic here
echo "Hello from Skill!"
```

---

## 1.3 How Skill Works

### 1.3.1 Trigger Flow

The complete Skill execution flow:

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐     ┌──────────┐     ┌────────┐
│ User Input  │  →  │  Claude     │  →  │   Match     │  →  │  Load    │  →  │Execute │
│ "Sync code" │     │  Recognizes │     │   Triggers  │     │ SKILL.md │     │ Script │
└─────────────┘     │  Intent     │     └─────────────┘     └──────────┘     └────────┘
                    └──────────────┘
```

**Step-by-Step Breakdown**:

| Step | Action | Description |
|------|--------|-------------|
| 1 | User Input | User types or speaks a phrase |
| 2 | Intent Recognition | Claude analyzes the intent |
| 3 | Trigger Matching | Match against defined trigger words |
| 4 | Load SKILL.md | Load the Skill definition file |
| 5 | Execute Script | Run the specified script or command |

### 1.3.2 Variable Injection Mechanism

Let's trace through a complete example:

```
User says: "Sync code to server"
  ↓
Claude recognizes SFTP upload intent
  ↓
Finds matching Skill (sftp-cc)
  ↓
Loads SKILL.md, injects ${CLAUDE_PLUGIN_ROOT}
  ↓
Executes: bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh
  ↓
Script runs with actual path: bash ~/.claude/plugins/marketplaces/sftp-cc/scripts/sftp-push.sh
```

### 1.3.3 Common Questions (FAQ)

#### Q1: Why is ${CLAUDE_PLUGIN_ROOT} empty when I execute with bash directly?

**A**: `${CLAUDE_PLUGIN_ROOT}` is **only injected by Claude Code in Skill context**. When executing directly in shell, you need to use absolute path:

```bash
# ❌ Wrong: Direct execution, variable is empty
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh
# Error: bash: /scripts/sftp-push.sh: No such file or directory

# ✅ Correct: Use absolute path
bash ~/.claude/plugins/marketplaces/sftp-cc/scripts/sftp-push.sh
```

#### Q2: How do I debug my Skill?

**A**: Use these debugging approaches:

1. **Add echo statements** in your scripts:
   ```bash
   echo "[DEBUG] Starting upload..." >&2
   ```

2. **Check Claude Code output** in the terminal

3. **Test scripts independently** before integrating with Skill

#### Q3: Can I use Python instead of Shell?

**A**: Yes! Any scripting language works:

````markdown
Execute:
```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/my-script.py
```
````

---

## 1.4 Development Environment Setup

### 1.4.1 Install Claude Code

Choose one of the following installation methods:

#### macOS (Homebrew)
```bash
brew install claude-code
```

#### npm (Cross-platform)
```bash
npm install -g @anthropic-ai/claude-code
```

#### Verify Installation
```bash
claude --version
# Expected output: claude-code x.x.x
```

### 1.4.2 Directory Preparation

Create your first Skill project:

````bash
# Create project directory
mkdir my-first-skill
cd my-first-skill

# Create basic structure
mkdir -p .claude-plugin skills/hello-world scripts

# Create SKILL.md
cat > skills/hello-world/SKILL.md << 'EOF'
---
name: hello-world
description: My First Skill — Says hello when you greet it
---

# Hello World Skill

## When to trigger

When user says:
- "hello"
- "hi"
- "hey there"
- "你好"
- "こんにちは"

## Execute

```bash
echo "Hello! Welcome to Claude Code Skill development!"
```
EOF

# Test your Skill
claude
# Then say: "hello"
````

### 1.4.3 Your First Running Skill

After setup, test your Skill:

1. **Start Claude Code**:
   ```bash
   claude
   ```

2. **Say the trigger phrase**:
   ```
   User: hello
   
   Claude: Hello! Welcome to Claude Code Skill development!
   ```

3. **Congratulations!** You just created your first Skill!

---

## 1.5 Best Practices for Beginners

### 1.5.1 Start Simple

Begin with a simple "Hello World" Skill:
- Single trigger word
- Single echo command
- No complex logic

### 1.5.2 Test Incrementally

Build and test step by step:
1. Test script independently first
2. Add SKILL.md wrapper
3. Test in Claude Code

### 1.5.3 Document as You Go

Good documentation helps:
- Explain what your Skill does
- List all trigger words
- Provide usage examples

---

## Chapter Summary

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Skill** | Claude Code's plugin system, triggered by natural language |
| **SKILL.md** | Core definition file with YAML frontmatter |
| **${CLAUDE_PLUGIN_ROOT}** | Internal variable, auto-resolved at runtime |
| **Trigger Words** | Phrases that activate your Skill |

### What You've Learned

- ✅ What Claude Code Skill is and its purpose
- ✅ Plugin architecture: SKILL.md, scripts/, marketplace.json
- ✅ How variable injection works
- ✅ How to set up development environment
- ✅ Created your first Hello World Skill

---

## Exercises

### Exercise 1-1: Customize Hello World

Modify your Hello World Skill to:
- Add more trigger words in your native language
- Display a personalized message
- Include the current date/time

### Exercise 1-2: Create a Weather Skill

Create a simple weather skill that:
- Triggers on "weather" or "what's the weather"
- Displays a mock weather report
- Uses `curl` to fetch real weather data (optional)

Example:
```bash
curl wttr.in?format=3
```

### Exercise 1-3: Explore Existing Skills

- Browse the [Plugin Marketplace](https://claude.ai/marketplace)
- Study 2-3 existing Skills
- Note their trigger word patterns

---

## Extended Resources

### Official Documentation
- [Claude Code Documentation](https://docs.anthropic.com/claude-code/)
- [Plugin Marketplace](https://claude.ai/marketplace)

### Example Projects
- [sftp-cc](https://github.com/toohamster/sftp-cc) — SFTP upload tool (this book's companion project)
- [More examples](https://github.com/topics/claude-code-skill)

### Further Reading
- "Advanced Bash-Scripting Guide" — Deep dive into Shell scripting
- "Writing Secure Code" — Security best practices

---

## Next Chapter Preview

**Chapter 2: Project Planning and Design**

In Chapter 2, we'll dive into project planning and design:
- Requirements analysis from pain points
- Functional boundary definition (what to do vs. what NOT to do)
- Directory structure best practices
- Configuration file design principles

By the end of Chapter 2, you'll complete the full design document for sftp-cc project.

---

## About this Book

**First Edition (Digital), March 2026**

**Author**: [toohamster](https://github.com/toohamster)
**License**: Electronic version: MIT License | Print/Commercial: All Rights Reserved
**Source**: [github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

See [LICENSE](../../LICENSE) and [About Author](../authors.md) for details.

---
