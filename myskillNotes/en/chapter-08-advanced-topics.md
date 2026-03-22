# Chapter 8: Advanced Topics and Best Practices

> "The only way to learn a new programming language is by writing programs in it." — Dennis Ritchie

In this chapter, you will learn:
- Performance optimization techniques for shell scripts
- Security best practices (avoid command injection)
- Code organization and naming conventions
- Advanced error handling with `trap`
- Troubleshooting common issues
- Real-world case studies from sftp-cc development
- Performance profiling and benchmarking
- Maintaining and iterating on your Skill

---

## 8.1 Performance Optimization

### 8.1.1 Reduce Subprocess Calls

Every subprocess call has overhead. Minimize them:

**Inefficient (subprocess in loop):**
```bash
#!/bin/bash
# BAD: Creates grep subprocess for every file
for file in "${files[@]}"; do
    if grep -q "pattern" "$file"; then
        echo "$file"
    fi
done
```

**Efficient (batch processing):**
```bash
#!/bin/bash
# GOOD: Single grep call processes all files
grep -l "pattern" "${files[@]}" 2>/dev/null
```

**Performance comparison:**

| Approach | Subprocesses | Time (1000 files) |
|----------|--------------|-------------------|
| Loop with grep | 1000 | ~5 seconds |
| Batch grep | 1 | ~0.1 seconds |

### 8.1.2 Use Arrays Instead of String Concatenation

**Dangerous string concatenation:**
```bash
#!/bin/bash
# BAD: String concatenation is slow and error-prone
args=""
for f in "${files[@]}"; do
    args="$args \"$f\""  # String manipulation
done
eval "command $args"  # DANGEROUS: eval
```

**Safe array approach:**
```bash
#!/bin/bash
# GOOD: Arrays handle spaces and special chars
args=()
for f in "${files[@]}"; do
    args+=("$f")  # Array append
done
command "${args[@]}"  # SAFE: proper quoting
```

### 8.1.3 Avoid Unnecessary Command Substitution

**Slow (command substitution):**
```bash
#!/bin/bash
# Each $() creates a subprocess
current_dir=$(pwd)
file_count=$(ls | wc -l)
git_branch=$(git branch --show-current)

echo "In $current_dir, branch $git_branch, $file_count files"
```

**Fast (built-in variables):**
```bash
#!/bin/bash
# Use built-in variables when available
current_dir="$PWD"  # Built-in, no subprocess
# file_count - need ls, no alternative
git_branch="${GIT_BRANCH:-$(git branch --show-current)}"  # Cache if used multiple times

echo "In $current_dir, branch $git_branch, $file_count files"
```

### 8.1.4 Efficient File Reading

**Inefficient (read line by line):**
```bash
#!/bin/bash
# Slow: reads file line by line in loop
while IFS= read -r line; do
    process "$line"
done < "$input_file"
```

**Efficient (process in batch):**
```bash
#!/bin/bash
# Fast: process entire file at once
if command -v xargs &>/dev/null; then
    cat "$input_file" | xargs -I{} process "{}"
else
    # Fallback to while loop
    while IFS= read -r line; do
        process "$line"
    done < "$input_file"
fi
```

### 8.1.5 Caching Expensive Operations

**Without caching:**
```bash
#!/bin/bash
# Calls git multiple times
get_author() {
    git log -1 --format='%an'
}

get_commit_count() {
    git rev-list --count HEAD
}

get_current_branch() {
    git branch --show-current
}

# Each call spawns git subprocess
author=$(get_author)
commits=$(get_commit_count)
branch=$(get_current_branch)
```

**With caching:**
```bash
#!/bin/bash
# Cache git info once
declare -A GIT_CACHE

cache_git_info() {
    GIT_CACHE[author]=$(git log -1 --format='%an')
    GIT_CACHE[commits]=$(git rev-list --count HEAD)
    GIT_CACHE[branch]=$(git branch --show-current)
}

# Call once at script start
cache_git_info

# Access from cache (no subprocess)
echo "Author: ${GIT_CACHE[author]}"
echo "Commits: ${GIT_CACHE[commits]}"
echo "Branch: ${GIT_CACHE[branch]}"
```

---

## 8.2 Security Best Practices

### 8.2.1 Avoid Command Injection

**DANGEROUS - Never do this:**
```bash
#!/bin/bash
# CRITICAL VULNERABILITY: Command injection
user_input="$1"
eval "echo $user_input"  # User can execute arbitrary commands!

# Attacker input: "$(rm -rf /)"
# Result: rm -rf / gets executed!
```

**SAFE - Always quote and validate:**
```bash
#!/bin/bash
# SAFE: No eval, proper quoting
user_input="$1"

# Validate input (allow only alphanumeric and safe chars)
if [[ ! "$user_input" =~ ^[a-zA-Z0-9_./-]+$ ]]; then
    error "Invalid input format"
    exit 1
fi

echo "$user_input"  # Safe: quoted, no eval
```

### 8.2.2 Safe File Path Handling

**Validate user-provided paths:**
```bash
#!/bin/bash
validate_path() {
    local path="$1"
    local allowed_base="$2"

    # Check for path traversal
    if [[ "$path" == *".."* ]]; then
        error "Path traversal not allowed"
        return 1
    fi

    # Resolve to absolute path
    local resolved_path
    resolved_path=$(cd "$path" 2>/dev/null && pwd) || resolved_path="$path"

    # Ensure path is within allowed directory
    if [[ "$resolved_path" != "$allowed_base"/* ]]; then
        error "Path outside allowed directory"
        return 1
    fi

    return 0
}

# Usage
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
if ! validate_path "$user_path" "$PROJECT_ROOT"; then
    exit 1
fi
```

### 8.2.3 Secure Temporary Files

**INSECURE - Predictable names:**
```bash
#!/bin/bash
# VULNERABLE: Race condition, predictable name
tmp_file="/tmp/my-script-$$.tmp"
echo "data" > "$tmp_file"  # Attacker could pre-create symlink!
```

**SECURE - Use mktemp:**
```bash
#!/bin/bash
# SECURE: Unpredictable name, atomic creation
tmp_file=$(mktemp) || exit 1
echo "data" > "$tmp_file"

# Additional security: restrictive permissions
chmod 600 "$tmp_file"
```

### 8.2.4 Permission Management

**Set appropriate permissions:**

```bash
#!/bin/bash
secure_permissions() {
    # Private keys must be readable only by owner
    if [ -f "$PRIVATE_KEY" ]; then
        local perms
        perms=$(stat -c %a "$PRIVATE_KEY" 2>/dev/null || stat -f %Lp "$PRIVATE_KEY")
        if [ "$perms" != "600" ]; then
            warn "Fixing private key permissions"
            chmod 600 "$PRIVATE_KEY"
        fi
    fi

    # Config files should be readable
    if [ -f "$CONFIG_FILE" ]; then
        chmod 644 "$CONFIG_FILE"
    fi

    # Scripts should be executable
    if [ -f "$SCRIPT_FILE" ]; then
        chmod 755 "$SCRIPT_FILE"
    fi
}
```

### 8.2.5 Credential Handling

**NEVER hardcode credentials:**
```bash
#!/bin/bash
# CRITICAL: Never hardcode credentials!
PASSWORD="supersecret123"  # Visible in git, ps, etc.
API_KEY="sk-xxxxxxxxx"    # Leaked!
```

**Use environment or config files:**
```bash
#!/bin/bash
# SECURE: Read from environment or config
API_KEY="${API_KEY:-}"
if [ -z "$API_KEY" ]; then
    # Fall back to config file
    API_KEY=$(json_get "$CONFIG_FILE" "api_key")
fi

if [ -z "$API_KEY" ]; then
    error "API key not configured"
    error "Set API_KEY environment variable or configure in sftp-config.json"
    exit 1
fi
```

### 8.2.6 Input Sanitization

**Sanitize all external input:**
```bash
#!/bin/bash
sanitize_filename() {
    local filename="$1"

    # Remove dangerous characters
    filename="${filename//\//_}"      # No path separators
    filename="${filename//../_}"      # No parent directory
    filename="${filename//:/_}"       # No colons (Windows)
    filename="${filename//\\/_}"      # No backslashes

    # Remove control characters
    filename=$(echo "$filename" | tr -d '[:cntrl:]')

    # Limit length
    filename="${filename:0:255}"

    echo "$filename"
}

# Usage
safe_name=$(sanitize_filename "$user_input")
```

---

## 8.3 Code Organization

### 8.3.1 Function Naming Conventions

**Use descriptive verb + noun names:**
```bash
# Action functions: verb + noun
init_config() { }
load_messages() { }
upload_files() { }
check_dependencies() { }

# Boolean functions: is/has/check/validate prefix
is_excluded() { }
has_permission() { }
check_config() { }
validate_path() { }

# Getter functions: get_ prefix
get_config_value() { }
get_git_root() { }
get_temp_dir() { }
```

**Avoid ambiguous names:**
```bash
# BAD: What does this do?
do_stuff() { }
handle() { }
process() { }

# GOOD: Clear purpose
upload_changed_files() { }
handle_connection_error() { }
process_git_changes() { }
```

### 8.3.2 Variable Scope

**Local variables (inside functions):**
```bash
#!/bin/bash
process_file() {
    local file="$1"           # Local variable
    local content
    local line_count

    content=$(cat "$file")
    line_count=$(wc -l < "$file")

    # These variables disappear when function returns
}
```

**Global variables (script-wide):**
```bash
#!/bin/bash
# Global constants (readonly)
readonly VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly CONFIG_DIR=".claude/sftp-cc"

# Global variables (mutable, use sparingly)
VERBOSE=false
DRY_RUN=false
CONFIG_FILE=""
```

**Naming conventions:**
```bash
# Constants: UPPERCASE
readonly MAX_RETRIES=3
readonly DEFAULT_PORT=22

# Variables: lowercase
config_file=""
retry_count=0

# Arrays: plural lowercase
files_to_upload=()
excluded_patterns=()
```

### 8.3.3 Script Structure Template

**Standard script layout:**
```bash
#!/bin/bash
# script-name.sh - Brief description
# Full description of what this script does
#
# Usage: ./script-name.sh [options] [arguments]
# Options:
#   -v, --verbose    Enable verbose output
#   -n, --dry-run    Preview mode
#   -h, --help       Show this help

set -euo pipefail

#######################################
# Constants
#######################################
readonly VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

#######################################
# Global Variables
#######################################
VERBOSE=false
DRY_RUN=false
CONFIG_FILE=""

#######################################
# Color Definitions
#######################################
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

#######################################
# Logging Functions
#######################################
info()  { echo -e "${GREEN}[$SCRIPT_NAME]${NC} $*" >&2; }
warn()  { echo -e "${YELLOW}[$SCRIPT_NAME] WARNING:${NC} $*" >&2; }
error() { echo -e "${RED}[$SCRIPT_NAME] ERROR:${NC} $*" >&2; }
debug() {
    if $VERBOSE; then
        echo -e "${BLUE}[$SCRIPT_NAME] DEBUG:${NC} $*" >&2
    fi
}

#######################################
# Usage Information
#######################################
usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [options] [arguments]

Options:
  -v, --verbose      Enable verbose output
  -n, --dry-run      Preview mode (don't execute)
  -h, --help         Show this help message
  --version          Show version information

Examples:
  $SCRIPT_NAME                    # Normal execution
  $SCRIPT_NAME --verbose          # With debug output
  $SCRIPT_NAME --dry-run          # Preview only
EOF
}

#######################################
# Parse Command-line Arguments
#######################################
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --version)
                echo "$SCRIPT_NAME $VERSION"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

#######################################
# Initialize Configuration
#######################################
init_config() {
    local config_dir="$PROJECT_ROOT/.claude/sftp-cc"
    CONFIG_FILE="$config_dir/sftp-config.json"

    if [ ! -f "$CONFIG_FILE" ]; then
        error "Configuration not found: $CONFIG_FILE"
        error "Run initialization first:"
        error "  bash scripts/sftp-init.sh"
        exit 1
    fi
}

#######################################
# Main Entry Point
#######################################
main() {
    parse_args "$@"
    info "Starting $SCRIPT_NAME..."
    init_config

    # Your main logic here

    info "Completed successfully!"
}

# Run main function with all arguments
main "$@"
```

---

## 8.4 Advanced Error Handling with trap

### 8.4.1 Basic trap Usage

**Catch errors and clean up:**
```bash
#!/bin/bash
set -euo pipefail

# Temporary files
tmp_file=""
batch_file=""

cleanup() {
    info "Cleaning up..."
    [ -n "$tmp_file" ] && [ -f "$tmp_file" ] && rm -f "$tmp_file"
    [ -n "$batch_file" ] && [ -f "$batch_file" ] && rm -f "$batch_file"
}

# Register cleanup on EXIT (always runs)
trap cleanup EXIT

# Your code
tmp_file=$(mktemp)
batch_file=$(mktemp)

# If script exits (success or error), cleanup runs
```

### 8.4.2 Error Handler with Line Number

**Get detailed error information:**
```bash
#!/bin/bash
set -euo pipefail

error_handler() {
    local line_no=$1
    local func=$2
    local cmd=$3

    error "Script failed!"
    error "  Line: $line_no"
    error "  Function: ${func:-main}"
    error "  Command: $cmd"
    error ""
    error "Debug with: bash -x $SCRIPT_NAME"
}

# Register error handler
trap 'error_handler ${LINENO} "${FUNCNAME[0]:-main}" "$BASH_COMMAND"' ERR

# Your code
risky_operation  # If this fails, error_handler is called
```

### 8.4.3 Signal Handling

**Handle interrupt signals:**
```bash
#!/bin/bash

interrupt_handler() {
    warn "Interrupted by user (Ctrl+C)"
    cleanup
    exit 130  # Standard exit code for Ctrl+C
}

terminate_handler() {
    warn "Received termination signal"
    cleanup
    exit 143  # Standard exit code for SIGTERM
}

# Register signal handlers
trap interrupt_handler INT  # Ctrl+C
trap terminate_handler TERM  # kill command
trap cleanup EXIT  # Always cleanup
```

### 8.4.4 Complete Error Handling Example

```bash
#!/bin/bash
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"

# Globals
tmp_files=()
cleanup_done=false

#######################################
# Cleanup Function
#######################################
cleanup() {
    if $cleanup_done; then
        return
    fi
    cleanup_done=true

    info "Cleaning up ${#tmp_files[@]} temporary file(s)..."
    for f in "${tmp_files[@]:-}"; do
        [ -n "$f" ] && [ -f "$f" ] && rm -f "$f"
    done
}

#######################################
# Error Handler
#######################################
error_handler() {
    local line_no=$1
    error "Unexpected error at line $line_no"
    error "Exit code: $?"
}

#######################################
# Interrupt Handler
#######################################
interrupt_handler() {
    warn "Operation cancelled by user"
    cleanup
    exit 130
}

#######################################
# Register Handlers
#######################################
trap cleanup EXIT
trap 'error_handler ${LINENO}' ERR
trap interrupt_handler INT TERM

#######################################
# Create Temp File (with tracking)
#######################################
create_temp() {
    local tmp
    tmp=$(mktemp)
    tmp_files+=("$tmp")
    echo "$tmp"
}

#######################################
# Main Logic
#######################################
main() {
    info "Starting operation..."

    local data_file
    data_file=$(create_temp)

    # Simulate work
    echo "data" > "$data_file"

    # If interrupted here, cleanup still runs

    info "Operation complete!"
}

main "$@"
```

---

## 8.5 Troubleshooting Common Issues

### 8.5.1 Skill Not Triggering

**Problem:** Claude doesn't respond to trigger words.

**Checklist:**

```bash
# 1. Verify SKILL.md exists
ls -la skills/sftp-cc/SKILL.md

# 2. Check trigger word definition
grep -A 10 "When to trigger" skills/sftp-cc/SKILL.md

# 3. Validate marketplace.json
jq . .claude-plugin/marketplace.json

# 4. Reload plugin
claude plugin reload sftp-cc
```

**Common causes:**
- ❌ SKILL.md not in correct directory
- ❌ Trigger words too generic
- ❌ Plugin not loaded

**Fix:**
````markdown
# In SKILL.md, be specific with triggers:

## When to trigger

When user says:
- "sync code to server"     ✓ Specific
- "upload to server"        ✓ Specific
- "deploy code"             ✓ Specific

NOT just:
- "upload"                  ✗ Too generic
- "sync"                    ✗ Too generic
- "push"                    ✗ Conflicts with git
````

### 8.5.2 Variable Not Resolved

**Problem:** `${CLAUDE_PLUGIN_ROOT}` is empty.

**Cause:** Variable only exists in Skill context.

**Solution:**
```bash
# In SKILL.md (Skill context) - ✓ WORKS
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh

# In shell directly - ✗ FAILS
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh
# Error: bash: /scripts/sftp-push.sh: No such file or directory

# Use absolute path instead
bash ~/.claude/plugins/marketplaces/sftp-cc/scripts/sftp-push.sh
```

### 8.5.3 SFTP Connection Failed

**Problem:** Connection timeout or authentication failure.

**Debug steps:**
```bash
# 1. Test connection manually
sftp -v -i ~/.ssh/id_rsa user@host

# 2. Check private key permissions
ls -la ~/.ssh/id_rsa
# Should be: -rw------- (600)

# 3. Verify config
cat .claude/sftp-cc/sftp-config.json

# 4. Test with verbose sftp
sftp -v -b batch_file user@host
```

**Common fixes:**
```bash
# Fix key permissions
chmod 600 ~/.ssh/id_rsa

# Verify key format
ssh-keygen -lf ~/.ssh/id_rsa

# Test SSH connection
ssh -i ~/.ssh/id_rsa user@host
```

### 8.5.4 JSON Parsing Returns Empty

**Problem:** `json_get` function returns empty values.

**Debug:**
```bash
# 1. Check JSON syntax
jq . .claude/sftp-cc/sftp-config.json

# 2. Verify field exists
jq '.host' .claude/sftp-cc/sftp-config.json

# 3. Test json_get function
source scripts/json-parser.sh
json_get config.json "host"
```

**Common issues:**
```json
// Missing quotes around keys
{
    host: "example.com"  // ✗ Invalid JSON
}

{
    "host": "example.com"  // ✓ Valid JSON
}

// Trailing comma
{
    "host": "example.com",  // ✗ Invalid (trailing comma)
}

{
    "host": "example.com"  // ✓ Valid
}
```

### 8.5.5 Script Hangs Indefinitely

**Problem:** Script appears frozen.

**Causes and fixes:**

| Cause | Symptom | Fix |
|-------|---------|-----|
| Waiting for input | Cursor blinks, no prompt | Add `-n` to reads |
| Network timeout | SFTP command hangs | Add timeout wrapper |
| Infinite loop | High CPU usage | Add loop counter |
| Deadlock | Multiple processes waiting | Review pipe usage |

**Add timeout:**
```bash
# With timeout command
timeout 30 sftp -b batch_file user@host || error "Upload timeout"

# Or implement in script
start_time=$(date +%s)
sftp_command &
pid=$!

while kill -0 $pid 2>/dev/null; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))

    if [ $elapsed -gt 30 ]; then
        kill $pid
        error "Operation timed out after 30 seconds"
        exit 1
    fi

    sleep 1
done

wait $pid
```

---

## 8.6 Real-World Case Studies

### 8.6.1 Case Study: Incremental Upload Bug

**Background:** sftp-cc incremental upload missed some files.

**Symptom:**
```
User: "Sync code to server"
Claude: Upload complete! 5 files uploaded.

But user had 8 changed files...
```

**Investigation:**
```bash
# Enable debug
set -x

# Check git detection
git diff --name-only --diff-filter=ACMR HEAD
# Returns: 5 files

git ls-files --others --exclude-standard
# Returns: 3 files (untracked)

# Bug found: untracked files not included!
```

**Root cause:** Script only checked committed changes, not untracked files.

**Fix:**
```bash
# Before (bug)
changed_files=$(git diff --name-only --diff-filter=ACMR HEAD)

# After (fixed)
changed_files=$(
    git diff --name-only --diff-filter=ACMR HEAD
    git diff --cached --name-only --diff-filter=ACMR
    git ls-files --others --exclude-standard
)
```

**Lesson:** Test all change scenarios (committed, staged, modified, untracked).

### 8.6.2 Case Study: Private Key Permission Fix

**Background:** Auto keybind sometimes failed silently.

**Symptom:**
```
User: "Bind my SSH key"
Claude: Key bound successfully!

But sftp-config.json still has empty private_key...
```

**Investigation:**
```bash
# Check key detection
ls -la .claude/sftp-cc/
# Found: id_rsa (644 permissions)

# Check script
bash -x scripts/sftp-keybind.sh

# Found: chmod 600 failed silently
chmod 600 id_rsa
# No error output, but permissions unchanged (on some filesystems)
```

**Root cause:** Script didn't verify chmod succeeded.

**Fix:**
```bash
# Before (silent failure)
chmod 600 "$key_file"

# After (verify and error)
if ! chmod 600 "$key_file"; then
    error "Failed to set key permissions"
    exit 1
fi

# Verify
perms=$(stat -c %a "$key_file")
if [ "$perms" != "600" ]; then
    error "Permission fix failed: $perms"
    exit 1
fi
```

**Lesson:** Never assume system commands succeed; verify critical operations.

### 8.6.3 Case Study: i18n Variable Not Set

**Background:** Multi-language messages sometimes showed empty.

**Symptom:**
```
Upload complete:  # Missing message!
```

**Investigation:**
```bash
# Check i18n.sh loading
source scripts/i18n.sh
init_lang "$CONFIG_FILE"

echo "MSG_UPLOAD_COMPLETE=$MSG_UPLOAD_COMPLETE"
# Output: MSG_UPLOAD_COMPLETE=

# Check config
cat .claude/sftp-cc/sftp-config.json
# Found: "language": "zh-cn"  // Not recognized!
```

**Root cause:** Language code "zh-cn" didn't match case statement.

**Fix:**
```bash
# Before (strict matching)
case "$lang" in
    zh) load_chinese ;;
    ja) load_japanese ;;
    *) load_english ;;
esac

# After (flexible matching)
case "${lang:0:2}" in  # Use first 2 chars
    zh) load_chinese ;;
    ja) load_japanese ;;
    *) load_english ;;
esac
```

**Lesson:** Normalize input values before comparison.

---

## 8.7 Performance Profiling

### 8.7.1 Timing Script Execution

**Simple timing:**
```bash
# Time entire script
time ./sftp-push.sh

# Output:
# real    0m2.341s
# user    0m0.523s
# sys     0m0.412s
```

**Time specific sections:**
```bash
#!/bin/bash

start_time=$(date +%s.%N)

# Section to measure
upload_files

end_time=$(date +%s.%N)
elapsed=$(echo "$end_time - $start_time" | bc)

info "Upload took ${elapsed}s"
```

### 8.7.2 Identify Slow Operations

**Profile each function:**
```bash
#!/bin/bash

profile_function() {
    local func_name="$1"
    shift

    local start_time
    start_time=$(date +%s.%N)

    "$func_name" "$@"

    local end_time
    end_time=$(date +%s.%N)
    local elapsed
    elapsed=$(echo "$end_time - $start_time" | bc)

    debug "$func_name took ${elapsed}s"
}

# Usage
profile_function detect_changes
profile_function build_batch_file
profile_function upload_files
```

### 8.7.3 Count Subprocess Calls

**Track subprocess usage:**
```bash
#!/bin/bash

# Wrap common commands to count
subprocess_count=0

original_sftp=$(which sftp)
sftp() {
    subprocess_count=$((subprocess_count + 1))
    debug "Subprocess #$subprocess_count: sftp $*"
    "$original_sftp" "$@"
}

original_grep=$(which grep)
grep() {
    subprocess_count=$((subprocess_count + 1))
    debug "Subprocess #$subprocess_count: grep $*"
    "$original_grep" "$@"
}

# At end
info "Total subprocess calls: $subprocess_count"
```

---

## Chapter Summary

### Key Concepts

| Concept | Description | Best Practice |
|---------|-------------|---------------|
| Subprocess reduction | Minimize external calls | Batch operations |
| Array usage | Safe argument handling | Use arrays, not strings |
| Command injection | Security vulnerability | Never use `eval` |
| Path validation | Prevent traversal attacks | Validate and sanitize |
| Function naming | Code readability | Verb + noun pattern |
| Variable scope | Prevent conflicts | `local` in functions |
| `trap` usage | Error handling | Always cleanup |
| Performance profiling | Identify bottlenecks | Time critical sections |

### Best Practices Summary

**Code Quality:**
- [ ] Use `set -euo pipefail` for strict mode
- [ ] Implement logging functions (info/warn/error/debug)
- [ ] Follow naming conventions
- [ ] Keep functions small and focused
- [ ] Comment complex logic

**Security:**
- [ ] Never use `eval` with user input
- [ ] Validate all file paths
- [ ] Use `mktemp` for temp files
- [ ] Set proper permissions (600 for keys)
- [ ] Don't hardcode credentials

**Performance:**
- [ ] Batch operations (avoid loops with subprocesses)
- [ ] Use arrays instead of string concatenation
- [ ] Cache expensive operations
- [ ] Profile to identify bottlenecks

**Error Handling:**
- [ ] Use `trap` for cleanup
- [ ] Validate parameters early
- [ ] Provide clear error messages
- [ ] Handle interrupt signals

---

## Exercises

### Exercise 8-1: Security Audit Your Script

Review an existing script for security issues:

1. Search for `eval` usage - remove or replace
2. Check all user input is validated
3. Verify temp files use `mktemp`
4. Confirm file permissions are set correctly
5. Ensure no hardcoded credentials

Create a checklist and fix any issues found.

### Exercise 8-2: Add Performance Profiling

Add timing to your script:

1. Create a `profile()` function that times operations
2. Wrap each major function with profiling
3. Output timing summary at end:
   ```
   Performance Summary:
   - detect_changes: 0.12s
   - build_batch: 0.34s
   - upload_files: 1.89s
   Total: 2.35s
   ```
3. Identify and optimize the slowest operation.

### Exercise 8-3: Implement Comprehensive Error Handling

Add robust error handling:

1. Create `cleanup()` function for temp files
2. Register `trap cleanup EXIT`
3. Create `error_handler()` with line numbers
4. Register `trap 'error_handler ${LINENO}' ERR`
5. Add interrupt handlers for INT and TERM
6. Test by interrupting mid-operation (Ctrl+C)

---

## Extended Resources

### Shell Script Security
- [OWASP Shell Injection Prevention](https://owasp.org/www-community/attacks/Command_Injection)
- [ShellCheck Rules](https://github.com/koalaman/shellcheck/wiki/Rules)
- "Secure Shell Scripting" - DEF CON talks

### Performance Optimization
- [Bash Performance Tips](https://mywiki.wooledge.org/BashPerformance)
- "Advanced Bash-Scripting Guide: Optimization"
- [ShellCheck for performance issues](https://www.shellcheck.net/)

### Error Handling
- [Bash trap documentation](https://www.gnu.org/software/bash/manual/html_node/Trap.html)
- "Robust Shell Scripting" - Various blogs
- [Exit codes reference](https://tldp.org/LDP/abs/html/exitcodes.html)

### Further Reading
- "The Art of UNIX Programming" - Eric S. Raymond
- "Classic Shell Scripting" - O'Reilly
- "Linux Command Line and Shell Scripting Bible"

---

## Book Summary

Congratulations! You've completed the entire book. Let's recap what you've learned:

### Chapter 1: Introduction
- What Claude Code Skill is
- Plugin architecture (SKILL.md, marketplace.json)
- `${CLAUDE_PLUGIN_ROOT}` variable
- Development environment setup
- Created your first Hello World Skill

### Chapter 2: Planning and Design
- Requirements analysis from pain points
- User personas and use cases
- Functional boundaries (what to do and not do)
- Directory structure planning
- Configuration file design

### Chapter 3: Writing Your First Skill
- SKILL.md structure and YAML frontmatter
- Trigger word design
- Script path configuration
- Execution instructions
- User guide documentation

### Chapter 4: Script Development
- Shell script structure template
- Global variables and constants
- Color output and logging
- JSON parsing (pure shell)
- Git integration
- SFTP batch mode upload
- Error handling patterns

### Chapter 5: Internationalization
- i18n importance and approaches
- Variable-based multi-language (MSG_XXX)
- i18n.sh implementation
- Language detection and loading
- Best practices for translations

### Chapter 6: Debugging and Testing
- `set -euo pipefail` strict mode
- Log level design
- Verbose mode implementation
- Temporary file management with `trap`
- Error handling patterns
- Dry-run mode
- ShellCheck and other tools

### Chapter 7: Publishing and Distribution
- Plugin Marketplace architecture
- `marketplace.json` configuration
- Semantic Versioning (SemVer)
- GitHub Release automation
- Multi-language README
- Plugin validation
- Distribution strategies

### Chapter 8: Advanced Topics (This Chapter)
- Performance optimization
- Security best practices
- Code organization
- Advanced error handling
- Troubleshooting guide
- Real-world case studies

### Your Journey Ahead

You now have the knowledge to:
1. ✅ Design and plan your own Skills
2. ✅ Write robust shell scripts
3. ✅ Implement multi-language support
4. ✅ Debug and test effectively
5. ✅ Publish to the Plugin Marketplace
6. ✅ Maintain and iterate on your work

**Next Steps:**
1. Build your own unique Skill
2. Share it with the community
3. Learn from user feedback
4. Continue improving your craft

Good luck, and happy coding!

---

## About this Book

**First Edition (Digital), March 2026**

**Author**: [toohamster](https://github.com/toohamster)
**License**: Electronic version: MIT License | Print/Commercial: All Rights Reserved
**Source**: [github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

See [LICENSE](../../LICENSE) and [About Author](../authors.md) for details.

---
