#!/bin/bash
# sftp-copy-id.sh — Deploy public key to server
# Add local public key to remote server's ~/.ssh/authorized_keys
# Supports password interactive login

set -euo pipefail

# Locate project root directory
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SFTP_CC_DIR="$PROJECT_ROOT/.claude/sftp-cc"
CONFIG_FILE="$SFTP_CC_DIR/sftp-config.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Initialize language from config
source "$SCRIPT_DIR/i18n.sh"
init_lang "$CONFIG_FILE"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[copy-id]${NC} $*"; }
warn()  { echo -e "${YELLOW}[copy-id]${NC} $*"; }
error() { echo -e "${RED}[copy-id]${NC} $*" >&2; }
step()  { echo -e "${CYAN}[copy-id]${NC} $*"; }

# Pure shell JSON tools
json_get() {
    local file="$1" key="$2" default="${3:-}"
    local val
    val=$(grep "\"$key\"" "$file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    if [ -z "$val" ] || [ "$val" = "null" ]; then
        echo "$default"
    else
        echo "$val"
    fi
}

# Check config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    error "$(printf "$MSG_CONFIG_MISSING" "$CONFIG_FILE")"
    error "$MSG_RUN_INIT_FIRST"
    exit 1
fi

# Read config
HOST=$(json_get "$CONFIG_FILE" "host")
USERNAME=$(json_get "$CONFIG_FILE" "username")
PRIVATE_KEY=$(json_get "$CONFIG_FILE" "private_key")

# Validate required config
MISSING=()
[ -z "$HOST" ]     && MISSING+=("host")
[ -z "$USERNAME" ] && MISSING+=("username")

if [ ${#MISSING[@]} -gt 0 ]; then
    error "$(printf "$MSG_CONFIG_INCOMPLETE" "${MISSING[*]}")"
    error "$(printf "$MSG_EDIT_CONFIG" "$CONFIG_FILE")"
    exit 1
fi

# Determine public key path
PUB_KEY=""

# 1. Prefer public key corresponding to project private key
if [ -n "$PRIVATE_KEY" ] && [ -f "${PRIVATE_KEY}.pub" ]; then
    PUB_KEY="${PRIVATE_KEY}.pub"
    info "$(printf "$MSG_USING_PROJECT_PUBKEY" "$PUB_KEY")"
# 2. Try system default public key
elif [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    PUB_KEY="$HOME/.ssh/id_ed25519.pub"
    info "$(printf "$MSG_USING_SYSTEM_PUBKEY" "$PUB_KEY")"
elif [ -f "$HOME/.ssh/id_rsa.pub" ]; then
    PUB_KEY="$HOME/.ssh/id_rsa.pub"
    info "$(printf "$MSG_USING_SYSTEM_PUBKEY" "$PUB_KEY")"
else
    error "$MSG_NO_PUBKEY_FOUND"
    error "$MSG_GENERATE_KEYPAIR"
    exit 1
fi

# Check ssh-copy-id command
if ! command -v ssh-copy-id &>/dev/null; then
    error "$MSG_NEED_SSH_COPY_ID"
    exit 1
fi

step "$(printf "$MSG_DEPLOYING_TO" "$USERNAME@$HOST")"
info "$(printf "$MSG_PUBKEY_FILE" "$PUB_KEY")"
warn "$MSG_ENTER_PASSWORD"
echo ""

# Execute ssh-copy-id (it will prompt for password)
ssh-copy-id -i "$PUB_KEY" "$USERNAME@$HOST"

info "$MSG_PUBKEY_DEPLOYED"
info ""
info "$MSG_COPY_ID_NEXT_STEPS"
info "  1. $MSG_STEP_COPY_PRIVATE_KEY"
info "  2. $(printf "$MSG_STEP_BIND_KEY" "$SCRIPT_DIR")"
info "  3. $(printf "$MSG_STEP_PUSH_FILES" "$SCRIPT_DIR")"
info ""
info "$MSG_OR_TELL_CLAUDE"
