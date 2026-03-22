# Chapter 4: Script Development

> "Simplicity is the soul of efficiency." — Austin Freeman

In this chapter, you will learn:
- Complete script structure template
- Pure Shell JSON parsing (zero external dependencies)
- Comprehensive error handling patterns
- Temporary file management best practices
- Full sftp-keybind.sh code walkthrough

---

## 4.1 Standard Script Structure

### 4.1.1 Recommended Template

Every production-ready script should follow this structure:

```bash
#!/bin/bash
# Script Name: Description of functionality
# Usage: How to run this script
# Author: Your name
# License: MIT

set -euo pipefail

# ============================================================================
# Global Variables
# ============================================================================
readonly VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"

# ============================================================================
# Color Definitions
# ============================================================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'  # No Color

# ============================================================================
# Logging Functions
# ============================================================================
info()  { echo -e "${GREEN}[$SCRIPT_NAME]${NC} $*"; }
warn()  { echo -e "${YELLOW}[$SCRIPT_NAME]${NC} $*" >&2; }
error() { echo -e "${RED}[$SCRIPT_NAME]${NC} $*" >&2; }

# ============================================================================
# Core Functions
# ============================================================================
check_dependencies() {
    # Check for required commands
    :
}

process_config() {
    # Process configuration file
    :
}

main_logic() {
    # Main business logic
    :
}

# ============================================================================
# Argument Parsing
# ============================================================================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "$SCRIPT_NAME version $VERSION"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# Help Message
# ============================================================================
show_help() {
    cat << HELP
Usage: $SCRIPT_NAME [OPTIONS]

Description:
  Brief description of what this script does.

Options:
  -h, --help      Show this help message
  -v, --version   Show version information

Examples:
  $SCRIPT_NAME
  $SCRIPT_NAME --help
HELP
}

# ============================================================================
# Entry Point
# ============================================================================
main() {
    parse_args "$@"
    check_dependencies
    main_logic
}

main "$@"
```

### 4.1.2 Why This Structure

| Section | Purpose | Why Important |
|---------|---------|---------------|
| Shebang (`#!/bin/bash`) | Specifies interpreter | Ensures correct shell |
| `set -euo pipefail` | Strict error handling | Catches bugs early |
| Global variables | Constants and paths | Avoids magic strings |
| Color definitions | Consistent output | Professional appearance |
| Logging functions | Structured messages | Easy debugging |
| Core functions | Business logic | Modular, testable |
| Argument parsing | CLI interface | User-friendly |
| Help message | Documentation | Self-documenting |
| Entry point | Clear execution flow | Easy to understand |

---

## 4.2 set Command Options Explained

### 4.2.1 Recommended Settings

```bash
set -euo pipefail
```

| Option | Effect | Example |
|--------|--------|---------|
| `-e` | Exit on error | `false` → Script exits |
| `-u` | Error on undefined variable | `echo $UNDEFINED` → Error |
| `-o pipefail` | Pipeline fails if any command fails | `true \| false` → Returns 1 |

### 4.2.2 Detailed Examples

#### Option -e: Exit on Error

```bash
set -e

command_that_fails  # Script exits here
echo "This won't run"  # Never reached
```

**When to disable temporarily:**
```bash
# Allow command to fail
if ! some_command; then
    warn "Command failed, continuing..."
fi

# Or use || true
optional_command || true
```

#### Option -u: Undefined Variable Error

```bash
set -u

echo "$MISSING_VAR"  # Error: unbound variable

# Correct: provide default
echo "${MISSING_VAR:-default_value}"
```

#### Option -o pipefail: Pipeline Error Handling

```bash
set -o pipefail

# Without pipefail: returns 0 (success of 'true')
true | false | true
echo $?  # 0 without pipefail

# With pipefail: returns 1 (failure of 'false')
true | false | true
echo $?  # 1 with pipefail
```

### 4.2.3 Debug Options

For debugging, add these temporarily:

```bash
set -x  # Print every command before executing
set -v  # Print every line as read
```

**Example output:**
```bash
set -x
HOST="example.com"
# Output: + HOST=example.com
```

---

## 4.3 Pure Shell JSON Parsing

### 4.3.1 Why Not jq?

| Criterion | jq | Pure Shell |
|-----------|----|------------|
| External dependency | Required | None |
| Installation | apt/yum/brew needed | Built-in |
| System compatibility | May not exist | All Unix systems |
| Learning curve | New syntax | Uses existing knowledge |
| Performance | Fast | Adequate for config files |

### 4.3.2 JSON Parsing Functions

Complete implementation for sftp-config.json:

```bash
# ============================================================================
# JSON Parsing Functions (Pure Shell, No jq)
# ============================================================================

# Read string value from JSON file
# Usage: json_get <file> <key> [default]
json_get() {
    local file="$1"
    local key="$2"
    local default="${3:-}"
    local val
    
    # Handle both "key": "value" and "key": "value", formats
    val=$(grep "\"$key\"" "$file" 2>/dev/null | head -1 | \
          sed 's/.*: *"\([^"]*\)".*/\1/' | \
          tr -d ',')
    
    # Return default if empty or null
    if [ -z "$val" ] || [ "$val" = "null" ]; then
        echo "$default"
    else
        echo "$val"
    fi
}

# Read number value from JSON file
# Usage: json_get_num <file> <key> [default]
json_get_num() {
    local file="$1"
    local key="$2"
    local default="${3:-0}"
    local val
    
    val=$(grep "\"$key\"" "$file" 2>/dev/null | head -1 | \
          sed 's/.*: *\([0-9]*\).*/\1/' | \
          tr -d ',')
    
    echo "${val:-$default}"
}

# Read boolean value from JSON file
# Usage: json_get_bool <file> <key> [default]
json_get_bool() {
    local file="$1"
    local key="$2"
    local default="${3:-false}"
    local val
    
    val=$(grep "\"$key\"" "$file" 2>/dev/null | head -1 | \
          sed 's/.*: *\(true\|false\).*/\1/')
    
    echo "${val:-$default}"
}

# Read array from JSON file
# Usage: json_get_array <file> <key>
# Outputs one item per line
json_get_array() {
    local file="$1"
    local key="$2"
    
    # Extract array content and parse items
    sed -n '/"'"$key"'"[[:space:]]*:/,/]/p' "$file" 2>/dev/null | \
        grep '"' | \
        grep -v "\"$key\"" | \
        sed 's/.*"\([^"]*\)".*/\1/' | \
        tr -d ','
}

# Write string value to JSON file
# Usage: json_set <file> <key> <value>
json_set() {
    local file="$1"
    local key="$2"
    local value="$3"
    local tmp
    
    tmp=$(mktemp)
    
    # Escape special characters in value
    local escaped_value
    escaped_value=$(printf '%s\n' "$value" | sed 's/[&/\]/\\&/g')
    
    sed "s|\"$key\": *\"[^\"]*\"|\"$key\": \"$escaped_value\"|" "$file" > "$tmp"
    mv "$tmp" "$file"
}
```

### 4.3.3 Usage Examples

```bash
CONFIG_FILE=".claude/sftp-cc/sftp-config.json"

# Read string values
HOST=$(json_get "$CONFIG_FILE" "host")
USERNAME=$(json_get "$CONFIG_FILE" "username")
REMOTE_PATH=$(json_get "$CONFIG_FILE" "remote_path")

# Read number with default
PORT=$(json_get_num "$CONFIG_FILE" "port" "22")

# Read array
while IFS= read -r exclude; do
    [ -n "$exclude" ] && EXCLUDES+=("$exclude")
done < <(json_get_array "$CONFIG_FILE" "excludes")

# Update value
json_set "$CONFIG_FILE" "private_key" "$PRIVATE_KEY_PATH"
```

### 4.3.4 How It Works

```
Input JSON:
{
  "host": "example.com",
  "port": 22,
  "excludes": [".git", "node_modules"]
}

Step 1: grep "\"host\""
Result:   "host": "example.com",

Step 2: sed 's/.*: *"\([^"]*\)".*/\1/'
Result: example.com

Step 3: tr -d ','
Result: example.com
```

---

## 4.4 Error Handling Patterns

### 4.4.1 Parameter Validation

```bash
validate_config() {
    local missing=()
    
    [ -z "$HOST" ]        && missing+=("host")
    [ -z "$PORT" ]        && missing+=("port")
    [ -z "$USERNAME" ]    && missing+=("username")
    [ -z "$REMOTE_PATH" ] && missing+=("remote_path")
    
    if [ ${#missing[@]} -gt 0 ]; then
        error "Configuration incomplete, missing fields: ${missing[*]}"
        error "Please edit config file: $CONFIG_FILE"
        exit 1
    fi
}
```

### 4.4.2 Command Existence Check

```bash
check_dependencies() {
    local missing=()
    
    for cmd in sftp git grep sed; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required commands: ${missing[*]}"
        error "Please install missing commands and try again."
        exit 1
    fi
    
    info "All dependencies satisfied."
}
```

### 4.4.3 File Existence Checks

```bash
# Configuration file
if [ ! -f "$CONFIG_FILE" ]; then
    error "Configuration file not found: $CONFIG_FILE"
    error "Run 'sftp-init.sh' to initialize configuration."
    exit 1
fi

# Private key file
if [ ! -f "$PRIVATE_KEY" ]; then
    error "Private key not found: $PRIVATE_KEY"
    error "Please place your private key in .claude/sftp-cc/"
    exit 1
fi

# Directory existence
if [ ! -d "$LOCAL_PATH" ]; then
    error "Local directory not found: $LOCAL_PATH"
    exit 1
fi
```

### 4.4.4 Command Execution Result Check

```bash
# Check exit code
if ! sftp "$SFTP_TARGET" < "$batch_file"; then
    error "SFTP upload failed"
    exit 1
fi

# Capture and check exit code
sftp "$SFTP_TARGET" < "$batch_file"
rc=$?
if [ $rc -ne 0 ]; then
    error "SFTP upload failed (exit code: $rc)"
    exit $rc
fi

# Check output for errors
output=$(some_command 2>&1)
rc=$?
if [ $rc -ne 0 ]; then
    error "Command failed: $output"
    exit $rc
fi
```

---

## 4.5 Temporary File Management

### 4.5.1 Creating Temporary Files

```bash
# Simple temp file
tmp_file=$(mktemp)

# Temp file with prefix
batch_file=$(mktemp -t sftp-batch.XXXXXX)

# Temp directory
temp_dir=$(mktemp -d)
```

### 4.5.2 Cleanup with trap

```bash
# Track all temp files
TEMP_FILES=()

cleanup() {
    for f in "${TEMP_FILES[@]}"; do
        [ -f "$f" ] && rm -f "$f"
    done
    [ -n "$temp_dir" ] && [ -d "$temp_dir" ] && rm -rf "$temp_dir"
}

# Register cleanup on EXIT, INT, TERM
trap cleanup EXIT INT TERM

# Create temp files and track them
batch_file=$(mktemp); TEMP_FILES+=("$batch_file")
changed_list=$(mktemp); TEMP_FILES+=("$changed_list")
```

### 4.5.3 Best Practices

| Practice | Example | Why |
|----------|---------|-----|
| Always clean up | `trap cleanup EXIT` | Prevents temp file accumulation |
| Use unique names | `mktemp -t prefix.XXXXXX` | Avoids conflicts |
| Delete after use | `rm -f "$tmp_file"` immediately after | Minimizes window |
| Check existence | `[ -f "$f" ] && rm -f "$f"` | Prevents errors |

---

## 4.6 Full Example: sftp-keybind.sh

### 4.6.1 Complete Script

```bash
#!/bin/bash
# sftp-keybind.sh — Private key auto-binding and permission correction
# Usage: bash sftp-keybind.sh
set -euo pipefail

# ============================================================================
# Global Variables
# ============================================================================
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
readonly SFTP_CC_DIR="$PROJECT_ROOT/.claude/sftp-cc"
readonly CONFIG_FILE="$SFTP_CC_DIR/sftp-config.json"

# ============================================================================
# Color Definitions
# ============================================================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# ============================================================================
# Logging Functions
# ============================================================================
info()  { echo -e "${GREEN}[keybind]${NC} $*"; }
warn()  { echo -e "${YELLOW}[keybind]${NC} $*" >&2; }
error() { echo -e "${RED}[keybind]${NC} $*" >&2; }

# ============================================================================
# JSON Helper Functions
# ============================================================================
json_get() {
    local file="$1" key="$2" default="${3:-}"
    local val
    val=$(grep "\"$key\"" "$file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    echo "${val:-$default}"
}

json_set() {
    local file="$1" key="$2" value="$3"
    local tmp
    tmp=$(mktemp)
    sed "s|\"$key\": *\"[^\"]*\"|\"$key\": \"$value\"|" "$file" > "$tmp"
    mv "$tmp" "$file"
}

# ============================================================================
# Main Logic
# ============================================================================
main() {
    # Check if config file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Read existing private_key setting
    local current_key
    current_key=$(json_get "$CONFIG_FILE" "private_key")
    
    # If already configured and file exists, just fix permissions
    if [ -n "$current_key" ] && [ -f "$current_key" ]; then
        local perms
        perms=$(stat -f "%Lp" "$current_key" 2>/dev/null || stat -c "%a" "$current_KEY" 2>/dev/null || echo "unknown")
        
        if [ "$perms" != "600" ]; then
            chmod 600 "$current_key"
            info "Fixed private key permissions: $current_key -> 600"
        else
            info "Private key already bound with correct permissions: $current_key"
        fi
        exit 0
    fi
    
    # Scan for private key files
    local key_patterns=("id_rsa" "id_ed25519" "id_ecdsa" "id_dsa" "*.pem" "*.key")
    local found_key=""
    
    for pattern in "${key_patterns[@]}"; do
        while IFS= read -r -d '' keyfile; do
            # Skip public keys
            [[ "$keyfile" == *.pub ]] && continue
            # Skip config files
            [[ "$(basename "$keyfile")" == "sftp-config"* ]] && continue
            [[ "$(basename "$keyfile")" == *"example"* ]] && continue
            
            found_key="$keyfile"
            break 2
        done < <(find "$SFTP_CC_DIR" -maxdepth 1 -name "$pattern" -print0 2>/dev/null)
    done
    
    # No key found
    if [ -z "$found_key" ]; then
        warn "No private key found in: $SFTP_CC_DIR"
        warn "Supported files: ${key_patterns[*]}"
        warn "Please place your private key in: $SFTP_CC_DIR"
        exit 1
    fi
    
    # Fix permissions and update config
    chmod 600 "$found_key"
    info "Fixed private key permissions: $found_key -> 600"
    
    json_set "$CONFIG_FILE" "private_key" "$found_key"
    info "Bound private key: $found_key"
    info "Configuration updated: $CONFIG_FILE"
}

main "$@"
```

### 4.6.2 Execution Flow

```
1. Determine project root using git
   └─→ PROJECT_ROOT="$(git rev-parse --show-toplevel)"

2. Check config file exists
   └─→ If not: error and exit

3. Read existing private_key setting
   └─→ If set and file exists: just fix permissions

4. Scan for private key files
   └─→ Check: id_rsa, id_ed25519, *.pem, *.key
   └─→ Skip: .pub files, config files

5. If key found:
   └─→ Fix permissions (chmod 600)
   └─→ Update config file
   └─→ Success!

6. If no key found:
   └─→ Warn user where to place key
   └─→ Exit with code 1
```

---

## Chapter Summary

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Script Structure** | Standard template with clear sections |
| **set Options** | `-euo pipefail` for strict error handling |
| **JSON Parsing** | Pure Shell with grep/sed, no jq needed |
| **Error Handling** | Validate early, fail fast |
| **Temp File Management** | mktemp + trap for cleanup |

### What You've Learned

- ✅ Complete script structure template
- ✅ set command options and their effects
- ✅ Pure Shell JSON parsing implementation
- ✅ Error handling patterns
- ✅ Temporary file management best practices
- ✅ Full working script (sftp-keybind.sh)

---

## Exercises

### Exercise 4-1: Create Script Template

Create a new script using the template:
1. Copy the standard structure
2. Add your script name and description
3. Implement check_dependencies()
4. Add basic argument parsing

### Exercise 4-2: Implement JSON Parser

Test JSON parsing functions:
1. Create a test JSON file
2. Implement json_get() and json_get_num()
3. Test with various JSON formats
4. Handle edge cases (null, missing keys)

### Exercise 4-3: Write a Utility Script

Create a simple utility script:
- Reads a configuration file
- Validates required fields
- Performs a simple action
- Handles errors gracefully

---

## Extended Resources

### Shell Scripting
- "Advanced Bash-Scripting Guide" — Comprehensive reference
- "Bash Cookbook" — Practical recipes
- [ShellCheck](https://www.shellcheck.net/) — Static analysis tool

### Error Handling
- "Writing Robust Bash Scripts" — Best practices guide
- set command options: `help set` in bash

---

## Next Chapter Preview

**Chapter 5: Internationalization (i18n)**

In Chapter 5, we implement multi-language support:
- Why multi-language matters
- Variable-based i18n solution design
- Complete i18n.sh implementation
- Using i18n in your scripts
- Supporting English, Chinese, and Japanese

By the end of Chapter 5, your Skills will speak your users' language!

---

## About this Book

**First Edition (Digital), March 2026**

**Author**: [toohamster](https://github.com/toohamster)
**License**: Electronic version: MIT License | Print/Commercial: All Rights Reserved
**Source**: [github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

See [LICENSE](../../LICENSE) and [About Author](../authors.md) for details.

---
