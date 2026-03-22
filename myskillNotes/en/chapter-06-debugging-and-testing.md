# Chapter 6: Debugging and Testing

> "Debugging is twice as hard as writing the code in the first place. Therefore, if you write the code as cleverly as possible, you are, by definition, not smart enough to debug it." — Brian W. Kernighan

In this chapter, you will learn:
- Shell script debugging basics (`set` command options)
- Log level design and implementation
- Verbose mode for detailed output
- Temporary file management with `trap`
- Error handling patterns and validation
- Testing methods (unit, integration, dry-run)
- Real-world debugging case studies
- Tools for verification

---

## 6.1 Shell Script Debugging Basics

### 6.1.1 The `set` Command

The `set` command is your first line of defense against bugs. It controls shell behavior and helps catch errors early.

#### Recommended Production Settings

```bash
#!/bin/bash
set -euo pipefail
```

**What Each Option Does:**

| Option | Full Name | Description |
|--------|-----------|-------------|
| `-e` | `errexit` | Exit immediately when a command exits with non-zero status |
| `-u` | `nounset` | Error when using undefined variables |
| `-o pipefail` | `pipefail` | Pipeline fails if **any** command in it fails |
| `-x` | `xtrace` | Print every command before executing (debug mode) |
| `-v` | `verbose` | Print every line as it's read |

#### Understanding `-e` (errexit)

Without `-e`, scripts continue even after commands fail:

```bash
#!/bin/bash
# Without -e
rm /nonexistent_file  # Fails silently
echo "Continuing..."  # Still runs!

# With -e
set -e
rm /nonexistent_file  # Script exits immediately
echo "This never runs"  # Never reached
```

#### Understanding `-u` (nounset)

Undefined variables cause subtle bugs:

```bash
#!/bin/bash
# Without -u
echo "$UNDEFINED_VAR"  # Prints empty string, continues

# With -u
set -u
echo "$UNDEFINED_VAR"  # Error: unbound variable
```

**Fix:** Provide default values:
```bash
echo "${UNDEFINED_VAR:-default_value}"
```

#### Understanding `-o pipefail`

Pipelines hide failures without `pipefail`:

```bash
#!/bin/bash
# Without pipefail
cat nonexistent.txt | grep "pattern"  # cat fails, grep succeeds
echo $?  # Returns 0 (success) - WRONG!

# With pipefail
set -o pipefail
cat nonexistent.txt | grep "pattern"
echo $?  # Returns 1 (failure) - CORRECT!
```

#### Debug Mode: `-x` (xtrace)

Print every command with expanded variables:

```bash
#!/bin/bash
set -x

name="World"
echo "Hello, $name"

# Output:
# + name=World
# + echo 'Hello, World'
# Hello, World
```

**Enable temporarily for debugging:**
```bash
bash -x script.sh  # Run with debug trace
```

### 6.1.2 Combining Options

**Development mode** (maximum debugging):
```bash
set -euxo pipefail
```

**Production mode** (strict but quiet):
```bash
set -euo pipefail
```

**Debug specific section:**
```bash
#!/bin/bash
set -euo pipefail

# Normal code
echo "Starting..."

# Enable debug for tricky section
set -x
complex_operation
set +x  # Disable debug

# Continue normal
echo "Done"
```

---

## 6.2 Log Level Design

### 6.2.1 Why Logging Matters

Good logs answer:
- What happened?
- When did it happen?
- What was the context?
- What went wrong (if anything)?

### 6.2.2 Four-Level Log System

```bash
#!/bin/bash

# Color Definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'  # No Color

# Script Name (for log prefix)
readonly SCRIPT_NAME="$(basename "$0")"

# Log Functions
info()  { echo -e "${GREEN}[$SCRIPT_NAME]${NC} $*"; }
warn()  { echo -e "${YELLOW}[$SCRIPT_NAME] WARNING:${NC} $*" >&2; }
error() { echo -e "${RED}[$SCRIPT_NAME] ERROR:${NC} $*" >&2; }
debug() { echo -e "${BLUE}[$SCRIPT_NAME] DEBUG:${NC} $*" >&2; }
```

### 6.2.3 Log Level Usage

| Level | When to Use | Example |
|-------|-------------|---------|
| `info` | Normal operation messages | "Upload complete: 5 files" |
| `warn` | Non-fatal issues | "Config file not found, using defaults" |
| `error` | Fatal errors (to stderr) | "SFTP connection failed" |
| `debug` | Detailed internal state | "Processing file: /path/to/file.php" |

### 6.2.4 Usage in Practice

```bash
#!/bin/bash
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

info()  { echo -e "${GREEN}[$SCRIPT_NAME]${NC} $*"; }
warn()  { echo -e "${YELLOW}[$SCRIPT_NAME] WARNING:${NC} $*" >&2; }
error() { echo -e "${RED}[$SCRIPT_NAME] ERROR:${NC} $*" >&2; }

# Main logic
main() {
    info "Starting upload process..."

    if [ ! -f "config.json" ]; then
        warn "Config file not found, using defaults"
    fi

    if ! upload_files; then
        error "Upload failed!"
        exit 1
    fi

    info "Upload complete!"
}

main
```

**Sample Output:**
```
[sftp-push.sh] Starting upload process...
[sftp-push.sh] WARNING: Config file not found, using defaults
[sftp-push.sh] Upload complete!
```

---

## 6.3 Verbose Mode

### 6.3.1 Adding a Debug Switch

Allow users to enable detailed output:

```bash
#!/bin/bash
set -euo pipefail

# Default: quiet mode
VERBOSE=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

# Debug function (only outputs when VERBOSE=true)
debug() {
    if $VERBOSE; then
        echo -e "\033[0;34m[DEBUG]\033[0m $*" >&2
    fi
}

# Usage
debug "Config file: $CONFIG_FILE"
debug "Target host: $HOST"
```

### 6.3.2 Conditional Debug Execution

Run extra checks only in verbose mode:

```bash
if $VERBOSE; then
    debug "Checking environment..."
    debug "  PATH: $PATH"
    debug "  PWD: $(pwd)"
    debug "  User: $(whoami)"
fi
```

### 6.3.3 Environment Variable Override

Allow environment to enable verbose mode:

```bash
# Check environment variable first
VERBOSE="${VERBOSE:-false}"

# Command-line argument overrides
if [[ "${1:-}" == "-v" ]] || [[ "${1:-}" == "--verbose" ]]; then
    VERBOSE=true
fi
```

**Usage:**
```bash
# Enable via environment
VERBOSE=true ./sftp-push.sh

# Enable via argument
./sftp-push.sh --verbose
```

---

## 6.4 Temporary File Management

### 6.4.1 Creating Temp Files Safely

Never use predictable names like `/tmp/myscript.tmp`:

```bash
# DANGEROUS - predictable name
tmp_file="/tmp/my-script-$$.tmp"  # Race condition risk!

# SAFE - use mktemp
tmp_file=$(mktemp)              # /tmp/tmp.XXXXXXXXXX
tmp_dir=$(mktemp -d)            # /tmp/tmp.XXXXXXXXXX/
```

### 6.4.2 mktemp Options

| Option | Description | Example Output |
|--------|-------------|----------------|
| (none) | Create temp file | `/tmp/tmp.Xk9jL2mN3p` |
| `-d` | Create temp directory | `/tmp/tmp.Xk9jL2mN3p/` |
| `-t prefix` | Named temp file | `/tmp/myapp.Xk9jL2mN3p` |
| `--suffix .ext` | Add suffix | `/tmp/tmp.Xk9jL2mN3p.log` |

### 6.4.3 Cleanup with trap

Always clean up temp files, even on error:

```bash
#!/bin/bash
set -euo pipefail

# Create temp files
tmp_file=$(mktemp)
batch_file=$(mktemp)

# Cleanup function
cleanup() {
    rm -f "$tmp_file" "$batch_file"
}

# Register cleanup (runs on EXIT, INT, TERM)
trap cleanup EXIT

# Your code here
echo "Processing..." > "$tmp_file"
# Script exits (normally or via error)
# → cleanup() runs automatically
```

### 6.4.4 trap Signal Handling

Handle different exit scenarios:

```bash
#!/bin/bash

cleanup() {
    info "Cleaning up temporary files..."
    rm -f "$tmp_file"
}

error_handler() {
    local line_no=$1
    error "Script failed at line $line_no"
}

# Cleanup on normal exit
trap cleanup EXIT

# Cleanup on Ctrl+C (INT) or kill (TERM)
trap cleanup INT TERM

# Error handler (only with set -e)
trap 'error_handler ${LINENO}' ERR
```

### 6.4.5 Complete Example

```bash
#!/bin/bash
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"

# Temp files
changed_files=""
batch_file=""

cleanup() {
    [ -n "$changed_files" ] && rm -f "$changed_files"
    [ -n "$batch_file" ] && rm -f "$batch_file"
}
trap cleanup EXIT

# Create temp files
changed_files=$(mktemp)
batch_file=$(mktemp)

# Use them
git diff --name-only > "$changed_files"
build_sftp_batch "$changed_files" > "$batch_file"

# Cleanup happens automatically
```

---

## 6.5 Error Handling Patterns

### 6.5.1 Parameter Validation

Check required parameters early:

```bash
validate_params() {
    local missing=()

    [ -z "${HOST:-}" ] && missing+=("host")
    [ -z "${PORT:-}" ] && missing+=("port")
    [ -z "${USERNAME:-}" ] && missing+=("username")
    [ -z "${REMOTE_PATH:-}" ] && missing+=("remote_path")

    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required configuration: ${missing[*]}"
        error "Please run initialization first:"
        error "  bash scripts/sftp-init.sh"
        exit 1
    fi
}
```

### 6.5.2 Command Existence Check

Verify required commands are available:

```bash
check_dependencies() {
    local deps=("sftp" "git" "grep" "sed" "mktemp")
    local missing=()

    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required commands: ${missing[*]}"
        exit 1
    fi
}
```

### 6.5.3 File Existence Check

Verify critical files exist before proceeding:

```bash
check_files() {
    if [ ! -f "$CONFIG_FILE" ]; then
        error "Configuration file not found: $CONFIG_FILE"
        error "Run initialization first:"
        error "  bash scripts/sftp-init.sh"
        exit 1
    fi

    if [ ! -f "$PRIVATE_KEY" ]; then
        error "Private key not found: $PRIVATE_KEY"
        error "Place your private key in:"
        error "  .claude/sftp-cc/"
        error "Supported formats: id_rsa, id_ed25519, *.pem, *.key"
        exit 1
    fi

    if [ ! -r "$PRIVATE_KEY" ]; then
        error "Cannot read private key: $PRIVATE_KEY"
        error "Check file permissions:"
        error "  chmod 600 $PRIVATE_KEY"
        exit 1
    fi
}
```

### 6.5.4 Graceful Error Recovery

Some errors can be recovered from:

```bash
upload_file() {
    local file="$1"
    local max_retries=3
    local retry=0

    while [ $retry -lt $max_retries ]; do
        if sftp_put "$file"; then
            return 0
        fi

        retry=$((retry + 1))
        warn "Upload failed, retrying ($retry/$max_retries)..."
        sleep 1
    done

    error "Failed to upload $file after $max_retries attempts"
    return 1
}
```

### 6.5.5 Exit Codes Convention

Use standard exit codes:

```bash
# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_CONFIG_ERROR=2
readonly EXIT_CONNECTION_ERROR=3
readonly EXIT_PERMISSION_ERROR=4

# Usage
if [ ! -f "$CONFIG_FILE" ]; then
    error "Config not found"
    exit $EXIT_CONFIG_ERROR
fi

if ! sftp_connect; then
    error "Connection failed"
    exit $EXIT_CONNECTION_ERROR
fi

exit $EXIT_SUCCESS
```

---

## 6.6 Testing Methods

### 6.6.1 Dry-run Mode (Preview Mode)

Show what **would** happen without actually doing it:

```bash
#!/bin/bash
set -euo pipefail

DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

# Main logic
files_to_upload=($(find . -name "*.php" -type f))
count=${#files_to_upload[@]}

if $DRY_RUN; then
    info "[DRY-RUN] Would upload $count files:"
    for file in "${files_to_upload[@]}"; do
        echo "  - $file"
    done
    exit 0
fi

# Actually execute
for file in "${files_to_upload[@]}"; do
    sftp_put "$file"
done
```

**Usage:**
```bash
# Preview first
./sftp-push.sh --dry-run

# Then execute
./sftp-push.sh
```

### 6.6.2 Unit Testing Scripts

Test individual functions in isolation:

```bash
#!/bin/bash
# test-json-parser.sh

source scripts/json-parser.sh  # Source functions to test

# Test helper
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    if [ "$expected" = "$actual" ]; then
        echo "✓ PASS: $test_name"
    else
        echo "✗ FAIL: $test_name"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        exit 1
    fi
}

# Create test file
cat > /tmp/test-config.json <<EOF
{
    "host": "example.com",
    "port": 22,
    "username": "testuser"
}
EOF

# Test json_get function
result=$(json_get /tmp/test-config.json "host")
assert_equals "example.com" "$result" "json_get returns host"

result=$(json_get /tmp/test-config.json "port")
assert_equals "22" "$result" "json_get returns port"

result=$(json_get /tmp/test-config.json "missing" "default")
assert_equals "default" "$result" "json_get returns default"

# Cleanup
rm -f /tmp/test-config.json

echo "All tests passed!"
```

### 6.6.3 Integration Testing

Test the complete workflow:

```bash
#!/bin/bash
# test-integration.sh
set -euo pipefail

readonly TEST_DIR=$(mktemp -d)
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

echo "=== Integration Test ==="
echo "Test directory: $TEST_DIR"

# Setup test project
cd "$TEST_DIR"
git init
echo "test" > test.txt
git add .
git commit -m "Initial commit"

# Run initialization
info "Testing initialization..."
bash "$SCRIPT_DIR/scripts/sftp-init.sh" \
    --host "test.example.com" \
    --username "testuser" \
    --remote-path "/var/www"

# Verify config created
if [ -f ".claude/sftp-cc/sftp-config.json" ]; then
    echo "✓ Config file created"
else
    echo "✗ Config file NOT created"
    exit 1
fi

# Verify keybind script
info "Testing keybind..."
touch .claude/sftp-cc/id_rsa
chmod 600 .claude/sftp-cc/id_rsa
bash "$SCRIPT_DIR/scripts/sftp-keybind.sh"

# Verify private_key is set in config
if grep -q '"private_key":' .claude/sftp-cc/sftp-config.json; then
    echo "✓ Private key bound"
else
    echo "✗ Private key NOT bound"
    exit 1
fi

echo "=== All Integration Tests Passed ==="
```

### 6.6.4 Mocking External Services

Test without real SFTP server:

```bash
#!/bin/bash
# Create a mock sftp command

mkdir -p /tmp/mock-bin

cat > /tmp/mock-bin/sftp <<'EOF'
#!/bin/bash
echo "[MOCK SFTP] Connection to: $*"
echo "[MOCK SFTP] Upload successful"
exit 0
EOF

chmod +x /tmp/mock-bin/sftp

# Add to PATH (takes precedence over real sftp)
export PATH="/tmp/mock-bin:$PATH"

# Now run your tests
./sftp-push.sh
```

---

## 6.7 Debugging Real-World Cases

### 6.7.1 Case Study: Variable Not Expanding

**Problem:** Script fails silently when uploading files.

**Investigation:**
```bash
# Enable debug mode
set -x

# Run script
./sftp-push.sh

# Output shows:
# + sftp_batch_file=
# + sftp -b '' user@host
```

**Root Cause:** Variable was empty due to typo.

**Fix:**
```bash
# Wrong
sftp_batch_file=$(mktemp)
# ... later ...
sftp -b "$sftp_batchfie" "$SFTP_TARGET"  # Typo!

# Correct
sftp -b "$sftp_batch_file" "$SFTP_TARGET"
```

### 6.7.2 Case Study: Pipe Failure Hidden

**Problem:** Script reports success even when files aren't uploaded.

**Investigation:**
```bash
# Without pipefail
cat files.txt | grep "\.php$" | xargs -I{} sftp_put "{}"
echo "Exit code: $?"  # Returns 0 even if sftp_put fails!
```

**Fix:**
```bash
set -o pipefail

# Now pipeline fails if any command fails
cat files.txt | grep "\.php$" | xargs -I{} sftp_put "{}"
echo "Exit code: $?"  # Returns correct error code
```

### 6.7.3 Case Study: Undefined Variable

**Problem:** Script works sometimes, fails other times.

**Investigation:**
```bash
set -u  # Enable strict variable checking

# Error appears:
# ./script.sh: line 42: HOST: unbound variable
```

**Root Cause:** Config file sometimes missing `host` field.

**Fix:**
```bash
# Use default or error explicitly
HOST=$(json_get "$CONFIG_FILE" "host")
if [ -z "$HOST" ]; then
    error "Host not configured"
    exit 1
fi
```

### 6.7.4 Case Study: Temp File Left Behind

**Problem:** `/tmp` fills up with temp files after repeated runs.

**Investigation:**
```bash
ls -la /tmp/tmp.*
# Shows dozens of files from script
```

**Root Cause:** `trap cleanup EXIT` not registered.

**Fix:**
```bash
# ALWAYS register cleanup immediately after creating temp files
tmp_file=$(mktemp)
trap 'rm -f "$tmp_file"' EXIT
```

---

## 6.8 Tools for Verification

### 6.8.1 ShellCheck

Static analysis for shell scripts:

```bash
# Install
brew install shellcheck  # macOS
sudo apt install shellcheck  # Linux

# Run
shellcheck scripts/sftp-push.sh

# Sample output:
# In scripts/sftp-push.sh line 42:
#     if [ $count -gt 0 ]; then
#            ^----^ SC2086: Double quote to prevent globbing
#
# Did you mean:
#     if [ "$count" -gt 0 ]; then
```

### 6.8.2 shfmt

Code formatter for shell scripts:

```bash
# Install
brew install shfmt

# Format file
shfmt -w scripts/sftp-push.sh

# Check formatting (CI/CD)
shfmt -d scripts/
```

### 6.8.3 bashdb

Bash debugger (step-through debugging):

```bash
# Install
sudo apt install bashdb  # Linux

# Run with debugger
bashdb scripts/sftp-push.sh

# Commands:
# n     - Next line
# s     - Step into function
# c     - Continue
# p VAR - Print variable
# q     - Quit
```

### 6.8.4 strace / dtruss

Trace system calls:

```bash
# Linux - strace
strace -f ./sftp-push.sh 2>&1 | head -100

# macOS - dtruss
sudo dtruss ./sftp-push.sh 2>&1 | head -100

# Useful for debugging:
# - File access failures
# - Permission issues
# - Network connection problems
```

---

## Chapter Summary

### Key Concepts

| Concept | Description | Example |
|---------|-------------|---------|
| `set -euo pipefail` | Strict error handling | Production scripts |
| `set -x` | Debug trace mode | Troubleshooting |
| Log levels | info/warn/error/debug | User communication |
| Verbose mode | `-v` / `--verbose` flag | Debug output on demand |
| `mktemp` | Safe temp file creation | `/tmp/tmp.XXXXXXXXXX` |
| `trap` | Cleanup on exit | `trap cleanup EXIT` |
| Dry-run | Preview without executing | `-n` / `--dry-run` |
| ShellCheck | Static analysis | Catch bugs before runtime |

### Best Practices Checklist

- [ ] Always use `set -euo pipefail` in production scripts
- [ ] Implement log functions (info/warn/error/debug)
- [ ] Add verbose mode (`-v` flag) for debugging
- [ ] Use `mktemp` for temp files, never hardcoded paths
- [ ] Register `trap cleanup EXIT` immediately after creating temp files
- [ ] Validate all required parameters before proceeding
- [ ] Check for required commands with `command -v`
- [ ] Provide dry-run mode (`-n` flag) for preview
- [ ] Run ShellCheck before committing scripts
- [ ] Use consistent exit codes

---

## Exercises

### Exercise 6-1: Add Debug Mode to Your Script

Add verbose mode to an existing script:

1. Add `-v` / `--verbose` argument parsing
2. Implement `debug()` function that only outputs in verbose mode
3. Add debug statements showing:
   - Configuration values being used
   - Files being processed
   - Commands being executed

Example output:
```
[sftp-push.sh] Starting upload...
[DEBUG] Config: host=example.com, user=deploy
[DEBUG] Processing file: src/index.php
[sftp-push.sh] Upload complete!
```

### Exercise 6-2: Write Unit Tests

Create a test file for JSON parsing functions:

1. Create `tests/test-json-parser.sh`
2. Write test cases for:
   - `json_get` with existing key
   - `json_get` with missing key (default value)
   - `json_get` with nested values
3. Run tests and verify all pass

Example structure:
```bash
#!/bin/bash
source scripts/json-parser.sh

test_json_get_existing() {
    # Create test file, call function, assert result
}

test_json_get_missing() {
    # Test default value behavior
}

# Run all tests
test_json_get_existing
test_json_get_missing
echo "All tests passed!"
```

### Exercise 6-3: Implement Error Recovery

Add retry logic to your upload function:

1. Define `MAX_RETRIES=3`
2. Wrap upload in retry loop
3. Add exponential backoff (1s, 2s, 4s delays)
4. Log retry attempts

Example:
```bash
upload_with_retry() {
    local file="$1"
    local retry=0

    while [ $retry -lt $MAX_RETRIES ]; do
        if sftp_put "$file"; then
            return 0
        fi
        retry=$((retry + 1))
        warn "Retry $retry/$MAX_RETRIES..."
        sleep $((2 ** retry))
    done

    return 1
}
```

---

## Extended Resources

### Shell Debugging Guides
- [Bash Manual: The Set Builtin](https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html)
- [ShellCheck User Guide](https://github.com/koalaman/shellcheck#user-content-gallery-of-bad-code)
- [Advanced Bash-Scripting Guide: Debugging](https://tldp.org/LDP/abs/html/debugging.html)

### Tools
- [ShellCheck](https://www.shellcheck.net/) - Online shell script analyzer
- [shfmt](https://github.com/mvdan/sh) - Shell code formatter
- [bashdb](http://bashdb.sourceforge.net/) - Bash debugger

### Further Reading
- "Writing Secure Shell Scripts" - OWASP guidelines
- "Advanced Bash Error Handling" - trap, ERR signals
- "Unit Testing in Shell" - Testing frameworks like bats

---

## Next Chapter Preview

**Chapter 7: Publishing and Distribution**

In Chapter 7, we'll cover publishing your Skill to the Plugin Marketplace:
- Plugin Marketplace architecture and requirements
- `marketplace.json` configuration (all fields explained)
- Semantic Versioning (SemVer) specification
- Creating GitHub Releases via API
- Automated release workflow (git → tag → release)
- Multi-language README structure
- Plugin validation and testing before publishing
- Submitting to the marketplace

By the end of Chapter 7, you'll be ready to share your Skill with the world!

---

## About this Book

**First Edition (Digital), March 2026**

**Author**: [toohamster](https://github.com/toohamster)
**License**: Electronic version: MIT License | Print/Commercial: All Rights Reserved
**Source**: [github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

See [LICENSE](../../LICENSE) and [About Author](../authors.md) for details.

---
