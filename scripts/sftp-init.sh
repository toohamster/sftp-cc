#!/bin/bash
# sftp-init.sh — Initialize SFTP configuration
# Create .claude/sftp-cc/ directory and generate sftp-config.json
# Supports interactive mode and command-line arguments
# Zero external dependencies, pure shell

set -euo pipefail

# Locate project root directory
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SFTP_CC_DIR="$PROJECT_ROOT/.claude/sftp-cc"
CONFIG_FILE="$SFTP_CC_DIR/sftp-config.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[init]${NC} $*"; }
warn()  { echo -e "${YELLOW}[init]${NC} $*"; }
error() { echo -e "${RED}[init]${NC} $*" >&2; }
step()  { echo -e "${CYAN}[init]${NC} $*"; }

# Pure shell JSON tools
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
PORT=""
USERNAME=""
REMOTE_PATH=""
LANGUAGE=""
PRIVATE_KEY=""
INTERACTIVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --host)      HOST="$2";        shift 2 ;;
        --port)      PORT="$2";        shift 2 ;;
        --username)  USERNAME="$2";    shift 2 ;;
        --remote-path) REMOTE_PATH="$2"; shift 2 ;;
        --language)  LANGUAGE="$2";    shift 2 ;;
        --private-key) PRIVATE_KEY="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: sftp-init.sh [OPTIONS]"
            echo ""
            echo "Interactive mode (no arguments):"
            echo "  Run without arguments to enter interactive mode"
            echo ""
            echo "Options:"
            echo "  --host HOST           SFTP server address"
            echo "  --port PORT           SFTP port (default: 22)"
            echo "  --username USER       Login username"
            echo "  --remote-path PATH    Remote target path"
            echo "  --language LANG       Language: en, zh, ja (default: en)"
            echo "  --private-key PATH    Path to SSH private key (will copy to .claude/sftp-cc/)"
            echo "  -h, --help            Show this help"
            exit 0
            ;;
        *)
            error "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# Check if running in interactive mode (no arguments provided)
if [ -z "$HOST" ] && [ -z "$PORT" ] && [ -z "$USERNAME" ] && [ -z "$REMOTE_PATH" ] && [ -z "$LANGUAGE" ] && [ -z "$PRIVATE_KEY" ]; then
    INTERACTIVE=true
fi

# Create directory
mkdir -p "$SFTP_CC_DIR"

# Create config file if not exists
if [ -f "$CONFIG_FILE" ]; then
    warn "Config file already exists: $CONFIG_FILE"
    echo ""
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
    info "Configuration file created: $CONFIG_FILE"
fi

# Interactive mode
if [ "$INTERACTIVE" = true ]; then
    echo ""
    step "Interactive configuration setup"
    echo ""
    echo "Enter your SFTP server information (press Enter for defaults)"
    echo ""

    # Read host
    read -p "SFTP server address (host): " HOST
    while [ -z "$HOST" ]; do
        warn "Host is required"
        read -p "SFTP server address (host): " HOST
    done

    # Read port
    read -p "SFTP port [22]: " PORT_INPUT
    PORT="${PORT_INPUT:-22}"

    # Read username
    read -p "Login username: " USERNAME
    while [ -z "$USERNAME" ]; do
        warn "Username is required"
        read -p "Login username: " USERNAME
    done

    # Read remote path
    read -p "Remote target path: " REMOTE_PATH
    while [ -z "$REMOTE_PATH" ]; do
        warn "Remote path is required"
        read -p "Remote target path: " REMOTE_PATH
    done

    # Read language
    echo ""
    echo "Select language:"
    echo "  1) English (en)"
    echo "  2) 中文 (zh)"
    echo "  3) 日本語 (ja)"
    read -p "Language [1]: " LANG_INPUT
    case "${LANG_INPUT:-1}" in
        1|en) LANGUAGE="en" ;;
        2|zh) LANGUAGE="zh" ;;
        3|ja) LANGUAGE="ja" ;;
        *) LANGUAGE="en" ;;
    esac

    # Read private key path
    echo ""
    read -p "SSH private key path (e.g., ~/.ssh/id_rsa, or leave empty to skip): " PRIVATE_KEY_INPUT
    if [ -n "$PRIVATE_KEY_INPUT" ]; then
        # Expand tilde
        PRIVATE_KEY="${PRIVATE_KEY_INPUT/#\~/$HOME}"
    fi
    echo ""
fi

# Fill in user-provided values
[ -n "$HOST" ]        && json_set "$CONFIG_FILE" "host" "$HOST"
[ -n "$PORT" ] && [ "$PORT" != "22" ]   && json_set_num "$CONFIG_FILE" "port" "$PORT"
[ -n "$USERNAME" ]    && json_set "$CONFIG_FILE" "username" "$USERNAME"
[ -n "$REMOTE_PATH" ] && json_set "$CONFIG_FILE" "remote_path" "$REMOTE_PATH"
[ -n "$LANGUAGE" ]    && json_set "$CONFIG_FILE" "language" "$LANGUAGE"

# Handle private key
if [ -n "$PRIVATE_KEY" ]; then
    # Expand tilde
    PRIVATE_KEY="${PRIVATE_KEY/#\~/$HOME}"

    if [ -f "$PRIVATE_KEY" ]; then
        # Copy private key to .claude/sftp-cc/
        KEY_FILENAME="$(basename "$PRIVATE_KEY")"
        TARGET_KEY="$SFTP_CC_DIR/$KEY_FILENAME"

        if [ -f "$TARGET_KEY" ]; then
            warn "Private key already exists at $TARGET_KEY, skipping copy"
        else
            cp "$PRIVATE_KEY" "$TARGET_KEY"
            chmod 600 "$TARGET_KEY"
            info "Private key copied to $TARGET_KEY"
            PRIVATE_KEY="$TARGET_KEY"
        fi
    else
        warn "Private key file not found: $PRIVATE_KEY"
        warn "You can place the private key in $SFTP_CC_DIR/ later"
    fi
fi

# Update private_key in config if we have a valid path
if [ -n "$PRIVATE_KEY" ] && [ -f "$PRIVATE_KEY" ]; then
    json_set "$CONFIG_FILE" "private_key" "$PRIVATE_KEY"
fi

# Auto-bind private key (only if not already provided)
if [ -z "$PRIVATE_KEY" ] || [ ! -f "$PRIVATE_KEY" ]; then
    step "Checking private key binding..."
    KEYBIND_SCRIPT="$SCRIPT_DIR/sftp-keybind.sh"
    if [ -f "$KEYBIND_SCRIPT" ]; then
        bash "$KEYBIND_SCRIPT" || true
    fi
fi

# Check config integrity
MISSING_FIELDS=()
[ -z "$(grep '"host"' "$CONFIG_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/')" ] && MISSING_FIELDS+=("host")
[ -z "$(grep '"username"' "$CONFIG_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/')" ] && MISSING_FIELDS+=("username")
[ -z "$(grep '"remote_path"' "$CONFIG_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/')" ] && MISSING_FIELDS+=("remote_path")

if [ ${#MISSING_FIELDS[@]} -gt 0 ]; then
    warn "Missing required fields: ${MISSING_FIELDS[*]}"
    warn "Please edit $CONFIG_FILE to complete configuration"
fi

echo ""
info "Initialization complete!"
echo ""

# Show next steps based on config status
PRIVATE_KEY_IN_CONFIG="$(grep '"private_key"' "$CONFIG_FILE" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/')"

if [ ${#MISSING_FIELDS[@]} -eq 0 ]; then
    echo "Next steps:"
    echo "  1. Run: bash $SCRIPT_DIR/sftp-copy-id.sh (deploy public key to server)"
    if [ -n "$PRIVATE_KEY_IN_CONFIG" ] && [ -f "$PRIVATE_KEY_IN_CONFIG" ]; then
        echo "  2. Private key is ready: $PRIVATE_KEY_IN_CONFIG"
        echo "  3. Tell Claude: \"sync code to server\""
    else
        echo "  2. Place your SSH private key in: $SFTP_CC_DIR/"
        echo "  3. Tell Claude: \"sync code to server\""
    fi
else
    echo "Please edit $CONFIG_FILE to fill in server information"
fi

echo ""
