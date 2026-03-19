# sftp-cc-toomaster

[中文文档](README_CN.md)

A universal SFTP upload tool for Claude Code. Supports incremental upload, automatic private key binding, and permission correction.

**Zero external dependencies** — pure shell implementation, only requires system-built-in `sftp`, `git`, `grep`, `sed`.

## Why

When using PhpStorm, the built-in SFTP extension automatically syncs every file change to the dev server — create, modify, or delete, it just works seamlessly. After switching to Claude Code, that ability was lost. Every time Claude made changes to the code, I had to manually pull them on the test server. That friction really slowed things down. So I built this tool to bring that auto-sync experience into Claude Code — just say "sync code to server" and it's done.

## Installation

### Option 1: Plugin Marketplace (Recommended)

```bash
# Add marketplace
/plugin marketplace add https://github.com/toohamster/sftp-cc-toomaster

# Install plugin
/plugin install sftp-cc-toomaster@sftp-cc-toomaster
```

### Option 2: Manual Installation

```bash
# Clone repository
git clone https://github.com/toohamster/sftp-cc-toomaster.git

# Install to your project
bash sftp-cc-toomaster/install.sh /path/to/your-project
```

## Configuration

### Step 1: Initialize server config

```bash
# After Plugin Marketplace installation
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-init.sh \
  --host your-server.com \
  --username deploy \
  --remote-path /var/www/html

# After manual installation
bash .claude/skills/sftp-cc-toomaster/scripts/sftp-init.sh \
  --host your-server.com \
  --username deploy \
  --remote-path /var/www/html
```

### Step 2: Deploy SSH public key to server

**Option A: Run in your native terminal (recommended)**

Open your terminal and run:
```bash
# Plugin installation
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-copy-id.sh

# Manual installation
bash .claude/skills/sftp-cc-toomaster/scripts/sftp-copy-id.sh
```

**Option B: Use ssh-copy-id directly**
```bash
# Find your public key (usually ~/.ssh/id_ed25519.pub or ~/.ssh/id_rsa.pub)
ssh-copy-id -i ~/.ssh/id_ed25519.pub username@your-server.com
```

**Option C: Manual deployment**
```bash
# Copy public key content
cat ~/.ssh/id_ed25519.pub | pbcopy  # macOS
# or
cat ~/.ssh/id_ed25519.pub | xclip -selection clipboard  # Linux

# SSH to server and paste into authorized_keys
ssh username@your-server.com
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys  # paste your public key
chmod 600 ~/.ssh/authorized_keys
```

This one-time setup enables password-less SSH authentication for SFTP uploads.

### Step 3: Place your private key

```bash
cp ~/.ssh/id_rsa .claude/sftp-cc/
```

**Private key auto-binding:**

- If you place the key **before** running `sftp-init.sh` → auto-binding happens automatically
- If you place the key **after** running `sftp-init.sh` → bind it manually:

  **Option A: Let Claude do it (recommended)**

  Just tell Claude in your project:
  > "bind SFTP private key"

  **Option B: Run the script directly**

  ```bash
  # Plugin installation
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-keybind.sh

  # Manual installation
  bash .claude/skills/sftp-cc-toomaster/scripts/sftp-keybind.sh
  ```

The key will be auto-detected, auto-bound to the config, and permissions auto-corrected to `600`.

Supported key formats: `id_rsa`, `id_ed25519`, `id_ecdsa`, `*.pem`, `*.key`

## Usage

Trigger via natural language in Claude Code:

- "sync code to server"
- "upload files to server"
- "deploy code to server"
- "sftp upload"
- "sftp sync"

**Note**: "push" will NOT trigger this skill to avoid conflicts with `git push`.

You can also call scripts directly:

```bash
# Incremental upload (default, only changed files)
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh

# Incremental upload + delete remote files that were deleted locally
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh --delete

# Full upload (all files)
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh --full

# Upload specific files
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh src/index.php

# Upload a specific directory
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh -d src/

# Dry-run (preview only)
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh -n
```

## Incremental Upload

- After each successful upload, the current git commit hash is saved to `.claude/sftp-cc/.last-push`
- On the next upload, `git diff` detects changes since the last upload — only modified/new files are uploaded
- Detects staged changes, unstaged changes, and untracked new files
- Falls back to full upload on first run or when the marker is missing
- Use `--full` to force a full upload
- Use `--delete` to sync-delete remote files that were deleted locally (off by default to prevent accidents)

## Dependencies

- `sftp` — SSH file transfer (system built-in)
- `git` — project root detection and incremental change detection
- **No jq required** — pure shell JSON parsing

## Security

- `.claude/sftp-cc/` directory contains private keys and server info, automatically added to `.gitignore`
- Private key permissions are auto-corrected to `600`

## License

[MIT](LICENSE)
