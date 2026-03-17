# sftp-cc-toomaster

[中文文档](README_CN.md)

A universal SFTP upload tool for Claude Code. Supports incremental upload, automatic private key binding, and permission correction.

**Zero external dependencies** — pure shell implementation, only requires system-built-in `sftp`, `git`, `grep`, `sed`.

## Installation

### Option 1: Plugin Marketplace (Recommended)

```bash
# Add marketplace
/plugin marketplace add toohamster/sftp-cc-toomaster

# Install plugin
/plugin install sftp-cc-toomaster@sftp-cc-toomaster
```

### Option 2: Manual Installation

```bash
git clone <repo-url> sftp-cc-toomaster
bash /path/to/sftp-cc-toomaster/install.sh /path/to/your-project
```

## Configuration

### Quick Setup via CLI

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-init.sh \
  --host your-server.com \
  --username deploy \
  --remote-path /var/www/html
```

### Edit JSON Directly

Edit `.claude/sftp-cc/sftp-config.json`:

```json
{
  "host": "your-server.com",
  "port": 22,
  "username": "deploy",
  "remote_path": "/var/www/html",
  "local_path": ".",
  "private_key": "",
  "excludes": [".git", ".claude", "node_modules", ".env", ".DS_Store"]
}
```

### Place Your Private Key

```bash
cp ~/.ssh/id_rsa .claude/sftp-cc/
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
