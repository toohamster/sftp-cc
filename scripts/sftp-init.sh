#!/bin/bash
# sftp-init.sh — Initialize SFTP configuration
# Create .claude/sftp-cc/ directory and generate sftp-config.json
# Zero external dependencies, pure shell

set -euo pipefail

# Locate project root directory
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SFTP_CC_DIR="$PROJECT_ROOT/.claude/sftp-cc"
CONFIG_FILE="$SFTP_CC_DIR/sftp-config.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Initialize language (use English as default for init, config may not exist yet)
source "$SCRIPT_DIR/i18n.sh"
init_lang "$CONFIG_FILE"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[init]${NC} $*"; }
warn()  { echo -e "${YELLOW}[init]${NC} $*"; }
error() { echo -e "${RED}[init]${NC} $*" >&2; }

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

json_set() {
    local file="$1" key="$2" value="$3"
    local tmp
    tmp=$(mktemp)
    sed "s|\"$key\": *\"[^\"]*\"|\"$key\": \"$value\"|" "$file" > "$tmp"
    mv "$tmp" "$file"
}

json_set_num() {
    local file="$1" key="$2" value="$3"
    local tmp
    tmp=$(mktemp)
    sed "s|\"$key\": *[0-9][0-9]*|\"$key\": $value|" "$file" > "$tmp"
    mv "$tmp" "$file"
}

# Parse arguments
HOST=""
PORT="22"
USERNAME=""
REMOTE_PATH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --host)      HOST="$2";        shift 2 ;;
        --port)      PORT="$2";        shift 2 ;;
        --username)  USERNAME="$2";    shift 2 ;;
        --remote-path) REMOTE_PATH="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: sftp-init.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --host HOST           SFTP server address"
            echo "  --port PORT           SFTP port (default: 22)"
            echo "  --username USER       Login username"
            echo "  --remote-path PATH    Remote target path"
            echo "  -h, --help            Show this help"
            exit 0
            ;;
        *) error "$(printf "$MSG_UNKNOWN_PARAMETER" "$1")"; exit 1 ;;
    esac
done

# Create directory
mkdir -p "$SFTP_CC_DIR"
info "$(printf "$MSG_CONFIG_DIR_CREATED" "$SFTP_CC_DIR")"

# Create config file
if [ -f "$CONFIG_FILE" ]; then
    warn "$(printf "$MSG_CONFIG_FILE_EXISTS" "$CONFIG_FILE")"
else
    # Try to copy from template
    TEMPLATE=""
    POSSIBLE_TEMPLATES=(
        "$SCRIPT_DIR/../templates/sftp-config.example.json"
        "$PROJECT_ROOT/.claude/skills/sftp-cc-toomaster/templates/sftp-config.example.json"
    )
    for t in "${POSSIBLE_TEMPLATES[@]}"; do
        if [ -f "$t" ]; then
            TEMPLATE="$t"
            break
        fi
    done

    if [ -n "$TEMPLATE" ]; then
        cp "$TEMPLATE" "$CONFIG_FILE"
    else
        # Inline default config
        cat > "$CONFIG_FILE" <<'JSONEOF'
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
    ".DS_Store"
  ]
}
JSONEOF
    fi
    info "$(printf "$MSG_CONFIG_FILE_CREATED" "$CONFIG_FILE")"
fi

# Fill in user-provided values
[ -n "$HOST" ]        && json_set "$CONFIG_FILE" "host" "$HOST"
[ -n "$USERNAME" ]    && json_set "$CONFIG_FILE" "username" "$USERNAME"
[ -n "$REMOTE_PATH" ] && json_set "$CONFIG_FILE" "remote_path" "$REMOTE_PATH"
[ "$PORT" != "22" ]   && json_set_num "$CONFIG_FILE" "port" "$PORT"

if [ -n "$HOST" ] || [ -n "$USERNAME" ] || [ -n "$REMOTE_PATH" ]; then
    info "$MSG_CONFIG_FIELDS_UPDATED"
fi

# Auto-bind private key
KEYBIND_SCRIPT="$SCRIPT_DIR/sftp-keybind.sh"
if [ -f "$KEYBIND_SCRIPT" ]; then
    bash "$KEYBIND_SCRIPT" || true
fi

# Check config integrity
MISSING_FIELDS=()
[ -z "$(json_get "$CONFIG_FILE" "host")" ]        && MISSING_FIELDS+=("host")
[ -z "$(json_get "$CONFIG_FILE" "username")" ]    && MISSING_FIELDS+=("username")
[ -z "$(json_get "$CONFIG_FILE" "remote_path")" ] && MISSING_FIELDS+=("remote_path")

if [ ${#MISSING_FIELDS[@]} -gt 0 ]; then
    warn "$(printf "$MSG_MISSING_FIELDS" "${MISSING_FIELDS[*]}")"
    warn "$(printf "$MSG_EDIT_CONFIG" "$CONFIG_FILE")"
fi

info "$MSG_INIT_COMPLETE"
echo ""
info "$MSG_NEXT_STEPS"
echo "  1. $(printf "$MSG_STEP_EDIT_CONFIG" "$CONFIG_FILE")"
echo "  2. $(printf "$MSG_STEP_PLACE_KEY" "$SFTP_CC_DIR/")"
echo "  3. $MSG_STEP_TELL_CLAUDE"
