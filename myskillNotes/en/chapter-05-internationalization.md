# Chapter 5: Internationalization (i18n)

> "Good localization is not translation, it's adaptation." — i18n Best Practices

In this chapter, you will learn:
- Why multi-language support matters (user experience, market reach)
- Variable-based i18n solution design
- Complete i18n.sh implementation
- How to use multi-language messages in scripts
- Message naming conventions
- Extending to new languages
- Testing and verification methods

---

## 5.1 Why Multi-Language Support

### 5.1.1 User Experience First

Imagine these scenarios:

```
Scenario 1: English user
$ bash sftp-push.sh
[push] Upload complete! 15 files synced to server.
→ ✅ Understands perfectly

Scenario 2: Chinese user (doesn't know English)
$ bash sftp-push.sh
[push] Upload complete! 15 files synced to server.
→ ❌ Doesn't understand, confused about success

Scenario 3: Chinese user (configured Chinese)
$ bash sftp-push.sh
[push] 上传完成！已同步 15 个文件到服务器。
→ ✅ Crystal clear
```

**Value of Multi-Language**:
- Lowers usage barrier
- Reduces user confusion
- Improves professional image
- Expands user base

### 5.1.2 Target User Analysis

Based on sftp-cc project GitHub access data (assumed):

| Region | Language | Percentage |
|--------|----------|------------|
| North America/Europe | English | 45% |
| China/Greater China | Chinese | 35% |
| Japan | Japanese | 15% |
| Other regions | Other | 5% |

**Decision**: Prioritize support for English, Chinese, and Japanese.

### 5.1.3 Internationalization Principles

```
Principle 1: User Language First
  → Whatever language user configures, output uses that language

Principle 2: Zero External Dependencies
  → No gettext, no Python
  → Pure Shell, works out of the box

Principle 3: Simple and Maintainable
  → Adding new language only modifies one place
  → Messages centrally managed, easy to translate
```

---

## 5.2 Solution Design: Variable-Based i18n

### 5.2.1 Solution Comparison

#### Option 1: gettext (Traditional)

```bash
# Requires .po files
msgid "Upload complete"
msgstr "上传完成"

# Requires compiling .mo files
msgfmt -o messages.mo messages.po

# Use in script
eval_gettext "Upload complete"
```

**Problems**:
- ❌ Requires gettext installation
- ❌ Requires understanding .po/.mo format
- ❌ Compilation step adds complexity
- ❌ Not available on all systems

#### Option 2: Variable-Based (Our Choice)

```bash
# Direct variable definition
MSG_UPLOAD_COMPLETE="上传完成"

# Direct use
echo "$MSG_UPLOAD_COMPLETE"
```

**Advantages**:
- ✅ Zero external dependencies
- ✅ No new tools to learn
- ✅ Pure Shell native support
- ✅ Change and use immediately

### 5.2.2 Variable Solution Core Design

```
┌─────────────────────────────────────────────────────────┐
│              Variable-Based Multi-Language Architecture │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. Language Initialization                             │
│     init_lang "$CONFIG_FILE"                           │
│     ↓                                                   │
│  2. Read language field from config                     │
│     lang=$(grep '"language"' "$CONFIG_FILE" ...)       │
│     ↓                                                   │
│  3. Load messages by language                           │
│     load_messages "$lang"                              │
│     ↓                                                   │
│  4. Set MSG_XXX variables                               │
│     MSG_UPLOAD_COMPLETE="上传完成"                      │
│     ↓                                                   │
│  5. Use variables in scripts                            │
│     info "$MSG_UPLOAD_COMPLETE"                        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 5.2.3 Message Category Design

Organize messages by function for easy management:

```bash
# Initialization related (CONFIG_*)
MSG_CONFIG_DIR_CREATED
MSG_CONFIG_FILE_EXISTS
MSG_CONFIG_FILE_CREATED
MSG_INIT_COMPLETE

# Private key binding related (KEY_*)
MSG_KEYBIND_COMPLETE
MSG_KEY_PERMISSIONS_FIXED
MSG_NO_KEY_FOUND

# Upload related (UPLOAD_*)
MSG_CHECKING_CHANGES
MSG_FOUND_FILES_INCREMENTAL
MSG_UPLOADING_FILES
MSG_UPLOAD_COMPLETE

# Error related (ERROR_*)
MSG_CONFIG_MISSING
MSG_CONFIG_INCOMPLETE
MSG_UPLOAD_FAILED
```

---

## 5.3 i18n.sh Complete Implementation

### 5.3.1 File Structure

```
scripts/
└── i18n.sh
    ├── init_lang()       # Language initialization
    ├── load_messages()   # Load messages
    ├── printf_msg()      # Formatted output
    └── MSG_XXX variables # All language messages
```

### 5.3.2 Complete Code Breakdown

```bash
#!/bin/bash
# i18n.sh — Internationalization support for sftp-cc
# Multi-language support: English (en), Chinese (zh), and Japanese (ja)
# Default language: English
#
# Usage:
#   source "$SCRIPT_DIR/i18n.sh"
#   init_lang "$CONFIG_FILE"
#   echo "$MSG_UPLOAD_COMPLETE"
```

#### init_lang() Function

```bash
init_lang() {
    local config_file="$1"
    local lang=""

    # Read language field from config
    if [ -f "$config_file" ]; then
        lang=$(grep '"language"' "$config_file" 2>/dev/null | head -1 | \
               sed 's/.*: *"\([^"]*\)".*/\1/')
    fi

    # Default to English if not set or invalid
    if [ -z "$lang" ] || [ "$lang" = "null" ]; then
        lang="en"
    fi

    # Load messages for the language
    load_messages "$lang"
}
```

**Workflow**:

```
Input: config_file = "sftp-config.json"
       File content: {"language": "zh", ...}

Step 1: grep '"language"' sftp-config.json
       Result: "language": "zh",

Step 2: sed 's/.*: *"\([^"]*\)".*/\1/'
       Result: zh

Step 3: lang="zh"

Step 4: load_messages "zh"
       → Load Chinese messages
```

#### load_messages() Function

```bash
load_messages() {
    local lang="$1"

    case "$lang" in
        zh|zh_CN|zh_TW)
            # Chinese messages
            MSG_CONFIG_DIR_CREATED="已创建配置目录：%s"
            MSG_CONFIG_FILE_EXISTS="配置文件已存在：%s"
            MSG_CONFIG_FILE_CREATED="已创建配置文件：%s"
            MSG_INIT_COMPLETE="初始化完成！"
            # ... more messages
            ;;

        ja|ja_JP)
            # Japanese messages
            MSG_CONFIG_DIR_CREATED="設定ディレクトリを作成しました：%s"
            MSG_CONFIG_FILE_EXISTS="設定ファイルは既に存在します：%s"
            MSG_CONFIG_FILE_CREATED="設定ファイルを作成しました：%s"
            MSG_INIT_COMPLETE="初期化が完了しました！"
            # ... more messages
            ;;

        *)
            # English messages (default)
            MSG_CONFIG_DIR_CREATED="Configuration directory created: %s"
            MSG_CONFIG_FILE_EXISTS="Config file already exists: %s"
            MSG_CONFIG_FILE_CREATED="Configuration file created: %s"
            MSG_INIT_COMPLETE="Initialization complete!"
            ;;
    esac
}
```

**Design Points**:

| Design Point | Description |
|--------------|-------------|
| `case` statement | Clear language branches |
| Language aliases | `zh|zh_CN|zh_TW` unified as Chinese |
| Default branch | `*` fallback for unknown languages |
| Variable naming | `MSG_` prefix to avoid conflicts |

#### printf_msg() Helper Function

```bash
printf_msg() {
    local format="$1"
    shift
    printf "%s\n" "$(printf "$format" "$@")"
}
```

**Usage Example**:

```bash
# Define formatted message
MSG_UPLOADING_FILES="Uploading %s files to %s ..."

# Use printf_msg
printf_msg "$MSG_UPLOADING_FILES" "15" "server:/var/www"

# Output
Uploading 15 files to server:/var/www ...
```

### 5.3.3 Complete Message List

Here's the complete message list used in sftp-cc (partial):

```bash
# ============================================================================
# Initialization (sftp-init.sh)
# ============================================================================
MSG_CONFIG_DIR_CREATED="Configuration directory created: %s"
MSG_CONFIG_FILE_EXISTS="Config file already exists: %s"
MSG_CONFIG_FILE_CREATED="Configuration file created: %s"
MSG_CONFIG_FIELDS_UPDATED="Configuration fields updated"
MSG_MISSING_FIELDS="Missing fields: %s"
MSG_EDIT_CONFIG="Please edit %s to complete configuration"
MSG_INIT_COMPLETE="Initialization complete!"
MSG_NEXT_STEPS="Next steps:"
MSG_STEP_EDIT_CONFIG="  1. Edit %s to fill in server information"
MSG_STEP_PLACE_KEY="  2. Place private key in %s"
MSG_STEP_TELL_CLAUDE="  3. Tell Claude: 'Sync code to server'"

# ============================================================================
# Private Key Binding (sftp-keybind.sh)
# ============================================================================
MSG_KEYBIND_COMPLETE="Private key bound with correct permissions: %s"
MSG_KEY_PERMISSIONS_FIXED="Fixed private key permissions: %s -> 600"
MSG_NO_KEY_FOUND="No private key found in %s"
MSG_SUPPORTED_KEYS="Supported files: %s"
MSG_PLACE_KEY_IN_DIR="Please place private key in %s"
MSG_KEY_BOUND="Private key bound: %s"
MSG_CONFIG_UPDATED="Configuration updated: %s"

# ============================================================================
# Public Key Deployment (sftp-copy-id.sh)
# ============================================================================
MSG_USING_PROJECT_PUBKEY="Using project private key's public key: %s"
MSG_USING_SYSTEM_PUBKEY="Using system default public key: %s"
MSG_NO_PUBKEY_FOUND="Public key file not found"
MSG_GENERATE_KEYPAIR="Please generate key pair: ssh-keygen -t ed25519"
MSG_NEED_SSH_COPY_ID="Requires ssh-copy-id command (comes with OpenSSH)"
MSG_DEPLOYING_TO="Deploying public key to %s"
MSG_PUBKEY_FILE="Public key file: %s"
MSG_ENTER_PASSWORD="Enter server password when prompted (password won't show)"
MSG_PUBKEY_DEPLOYED="Done! Public key deployed to server"

# ============================================================================
# File Upload (sftp-push.sh)
# ============================================================================
MSG_CHECKING_KEYBIND="Checking private key binding..."
MSG_TARGET_SERVER="Target server: %s"
MSG_CHECKING_CHANGES="Checking for file changes..."
MSG_FIRST_UPLOAD_FULL="First upload, no history, performing full upload"
MSG_SCANNING_FILES="Scanning project files..."
MSG_FOUND_FILES_FULL="Found %s files (full)"
MSG_FOUND_FILES_INCREMENTAL="Detected %s changed files (incremental)"
MSG_FOUND_FILES_DELETED="Detected %s deleted files"
MSG_DELETE_NOT_ENABLED="--delete not enabled, skipping remote deletion"
MSG_NO_CHANGES="No file changes detected, nothing to upload"
MSG_UPLOADING_FILES="Uploading %s files to %s ..."
MSG_UPLOADING_DIR="Uploading directory %s ..."
MSG_SYNCING_INCREMENTAL="Incrementally syncing to %s (upload %s, delete %s) ..."
MSG_ENSURE_REMOTE_DIR="Ensuring remote directory exists..."
MSG_UPLOAD_COMPLETE="Upload complete!"
MSG_DRY_RUN_MODE="[Preview Mode]"
MSG_DRY_RUN_WILL_UPLOAD="[Preview] Will upload %s files to %s"
MSG_FILE_NOT_FOUND="File not found, skipping: %s"
MSG_UPLOAD_SUCCESS="Recorded push point: %s"
MSG_PUSHING_DIR="Pushing directory: %s -> %s"

# ============================================================================
# Error Messages
# ============================================================================
MSG_CONFIG_MISSING="Configuration file not found: %s"
MSG_RUN_INIT_FIRST="Please run sftp-init.sh to initialize configuration"
MSG_CONFIG_INCOMPLETE="Configuration incomplete, missing: %s"
MSG_UNKNOWN_OPTION="Unknown option: %s"
MSG_UNKNOWN_PARAMETER="Unknown parameter: %s"
MSG_REQUIRES_SFTP="Requires sftp command"
MSG_UPLOAD_FAILED="Upload failed (exit code: %s)"
MSG_NO_FILES_TO_UPLOAD="No files to upload"
MSG_DIR_NOT_EXISTS="Directory does not exist: %s"
```

---

## 5.4 Using i18n in Scripts

### 5.4.1 Importing i18n Library

```bash
#!/bin/bash
# sftp-push.sh

# 1. Determine script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 2. Source i18n library
source "$SCRIPT_DIR/i18n.sh"

# 3. Initialize language (from config)
CONFIG_FILE="$PROJECT_ROOT/.claude/sftp-cc/sftp-config.json"
init_lang "$CONFIG_FILE"

# 4. Now can use MSG_XXX variables
info "$MSG_UPLOAD_COMPLETE"
```

### 5.4.2 Replacing Hard-Coded Messages

#### Before (Hard-Coded English)

```bash
#!/bin/bash
# Old code

info "Upload complete!"
error "Configuration file not found: $CONFIG_FILE"
warn "No changes detected, nothing to upload"
```

#### After (Multi-Language)

```bash
#!/bin/bash
# New code

info "$MSG_UPLOAD_COMPLETE"
error "$(printf "$MSG_CONFIG_MISSING" "$CONFIG_FILE")"
warn "$MSG_NO_CHANGES"
```

### 5.4.3 Handling Parameterized Messages

#### Simple Parameters

```bash
# Define
MSG_UPLOADING_FILES="Uploading %s files to %s ..."

# Use (multiple parameters)
info "$(printf "$MSG_UPLOADING_FILES" "$count" "$target")"

# Output
Uploading 15 files to user@server:/var/www ...
```

#### Multiple Parameters

```bash
# Define
MSG_SYNCING_INCREMENTAL="Incrementally syncing to %s (upload %s, delete %s) ..."

# Use
info "$(printf "$MSG_SYNCING_INCREMENTAL" "$SFTP_TARGET" "$upload_count" "$delete_count")"

# Output
Incrementally syncing to user@server:/var/www (upload 5, delete 2) ...
```

### 5.4.4 Using in Logging Functions

```bash
# Define log functions
info()  { echo -e "${GREEN}[push]${NC} $*"; }
error() { echo -e "${RED}[push]${NC} $*" >&2; }

# Use i18n messages
info "$MSG_CHECKING_KEYBIND"
info "$(printf "$MSG_TARGET_SERVER" "$SFTP_TARGET:$REMOTE_PATH")"

# Error messages
if [ ! -f "$CONFIG_FILE" ]; then
    error "$(printf "$MSG_CONFIG_MISSING" "$CONFIG_FILE")"
    error "$MSG_RUN_INIT_FIRST"
    exit 1
fi
```

### 5.4.5 Conditional Messages

```bash
# Choose message based on condition
if [ "$change_count" -eq 0 ]; then
    info "$MSG_NO_CHANGES"
else
    info "$(printf "$MSG_FOUND_FILES_INCREMENTAL" "$change_count")"
fi

# Choose based on mode
if $DRY_RUN; then
    info "$MSG_DRY_RUN_MODE"
else
    info "$MSG_UPLOAD_COMPLETE"
fi
```

---

## 5.5 Language Configuration

### 5.5.1 language Field in sftp-config.json

```json
{
  "host": "example.com",
  "port": 22,
  "username": "deploy",
  "remote_path": "/var/www/html",
  "local_path": ".",
  "private_key": "",
  "language": "zh",
  "excludes": [".git", ".claude", "node_modules"]
}
```

### 5.5.2 Supported Language Codes

| Code | Language | Notes |
|------|----------|-------|
| `en` | English | Default language |
| `zh` | Chinese | Simplified Chinese |
| `zh_CN` | Chinese (China) | Same as `zh` |
| `zh_TW` | Chinese (Taiwan) | Same as `zh` (current) |
| `ja` | Japanese | Japanese |
| `ja_JP` | Japanese (Japan) | Same as `ja` |

### 5.5.3 Extending to New Language: Korean Example

#### Step 1: Add case Branch

```bash
load_messages() {
    local lang="$1"

    case "$lang" in
        # ... existing languages ...

        ko|ko_KR)
            # Korean messages
            MSG_CONFIG_DIR_CREATED="설정 디렉토리를 생성했습니다：%s"
            MSG_CONFIG_FILE_EXISTS="설정 파일이 이미 존재합니다：%s"
            MSG_CONFIG_FILE_CREATED="설정 파일을 생성했습니다：%s"
            MSG_INIT_COMPLETE="초기화가 완료되었습니다!"

            MSG_KEYBIND_COMPLETE="개인 키가 바인딩되었습니다：%s"
            MSG_KEY_PERMISSIONS_FIXED="개인 키 권한 수정：%s -> 600"
            MSG_NO_KEY_FOUND="%s 에서 개인 키를 찾을 수 없습니다"

            MSG_UPLOAD_COMPLETE="업로드 완료!"
            MSG_CHECKING_KEYBIND="개인 키 바인드 확인 중..."
            MSG_TARGET_SERVER="대상 서버：%s"
            MSG_CHECKING_CHANGES="파일 변경 확인 중..."
            MSG_FOUND_FILES_INCREMENTAL="%s 개의 변경 파일 감지 (증분)"
            MSG_UPLOADING_FILES="%s 개의 파일을 %s 에 업로드 중 ..."
            # ... continue adding all messages ...
            ;;
    esac
}
```

#### Step 2: Update Documentation

````markdown
Supported Languages:
- English (en)
- Chinese (zh, zh_CN, zh_TW)
- Japanese (ja, ja_JP)
- Korean (ko, ko_KR)  ← New
````

#### Step 3: Test

```bash
# Modify config
echo '{"language": "ko"}' > test-config.json

# Run script
source i18n.sh
init_lang "test-config.json"

# Verify
echo "$MSG_UPLOAD_COMPLETE"
# Should output: 업로드 완료!
```

---

## 5.6 Message Naming Conventions

### 5.6.1 Naming Format

```
MSG_<MODULE>_<ACTION>_<OBJECT>_<STATE>
```

**Example Breakdown**:

| Message | Naming Breakdown |
|---------|------------------|
| `MSG_CONFIG_DIR_CREATED` | CONFIG + DIR + CREATED |
| `MSG_UPLOAD_COMPLETE` | UPLOAD + COMPLETE |
| `MSG_KEY_PERMISSIONS_FIXED` | KEY + PERMISSIONS + FIXED |

### 5.6.2 Naming Best Practices

```bash
# ✅ Good naming
MSG_CONFIG_FILE_EXISTS      # Clear, specific
MSG_UPLOAD_FAILED           # Action + State
MSG_UNKNOWN_OPTION          # Problem type

# ❌ Bad naming
MSG_1                     # Meaningless
MSG_ERROR                 # Too generic
MSG_UPLOAD_ERR            # Abbreviation unclear
```

### 5.6.3 Message List Management

Recommended to maintain a message list file:

```bash
# docs/i18n-messages.md

# i18n Message List

## Initialization
| Key | English | Chinese | Japanese |
|-----|---------|---------|----------|
| MSG_CONFIG_DIR_CREATED | Configuration directory created: %s | 已创建配置目录：%s | 設定ディレクトリを作成しました：%s |
| MSG_INIT_COMPLETE | Initialization complete! | 初始化完成！ | 初期化が完了しました！ |

## Upload
| Key | English | Chinese | Japanese |
|-----|---------|---------|----------|
| MSG_UPLOAD_COMPLETE | Upload complete! | 上传完成！ | アップロード完了！ |
| MSG_NO_CHANGES | No changes detected | 没有检测到变更 | 変更が検出されませんでした |
```

---

## 5.7 Testing and Verification

### 5.7.1 Verify Language Loading

```bash
# Add debug output in script
VERBOSE=true
if $VERBOSE; then
    echo "[DEBUG] Language: $lang" >&2
    echo "[DEBUG] MSG_UPLOAD_COMPLETE: $MSG_UPLOAD_COMPLETE" >&2
    echo "[DEBUG] MSG_CONFIG_MISSING: $MSG_CONFIG_MISSING" >&2
fi
```

### 5.7.2 Test Different Languages

#### Method 1: Temporarily Modify Config

```bash
# Backup original config
cp sftp-config.json sftp-config.json.bak

# Test Chinese
echo '{"language": "zh"}' > sftp-config.json
bash scripts/sftp-push.sh -n

# Test Japanese
echo '{"language": "ja"}' > sftp-config.json
bash scripts/sftp-push.sh -n

# Restore
mv sftp-config.json.bak sftp-config.json
```

#### Method 2: Environment Variable Override

```bash
# Add environment variable support in i18n.sh
init_lang() {
    local config_file="$1"
    local lang=""

    # Environment variable takes priority
    if [ -n "$SFTP_CC_LANGUAGE" ]; then
        lang="$SFTP_CC_LANGUAGE"
    elif [ -f "$config_file" ]; then
        lang=$(grep '"language"' "$config_file" ...)
    fi

    # ...
}

# Use
SFTP_CC_LANGUAGE=zh bash scripts/sftp-push.sh
```

### 5.7.3 Check Message Completeness

```bash
# Script 1: Extract all used MSG_XXX variables
grep -oh 'MSG_[A-Z_]*' scripts/*.sh | sort -u > used_messages.txt

# Script 2: Extract messages defined in i18n.sh
grep -o 'MSG_[A-Z_]*=' scripts/i18n.sh | sed 's/=//' | sort -u > defined_messages.txt

# Script 3: Compare differences
comm -23 used_messages.txt defined_messages.txt
# Output: Used but undefined messages (need to add)
```

### 5.7.4 Automated Testing

```bash
#!/bin/bash
# test-i18n.sh

source scripts/i18n.sh

test_language() {
    local expected_lang="$1"
    local config_content="$2"

    echo "$config_content" > /tmp/test-config.json
    init_lang "/tmp/test-config.json"

    if [ -z "$MSG_UPLOAD_COMPLETE" ]; then
        echo "FAIL: $expected_lang - MSG_UPLOAD_COMPLETE is empty"
        return 1
    fi

    echo "PASS: $expected_lang"
    return 0
}

# Test cases
test_language "en" '{"language": "en"}'
test_language "zh" '{"language": "zh"}'
test_language "ja" '{"language": "ja"}'
test_language "en (default)" '{"language": "invalid"}'
test_language "en (missing)" '{}'

rm -f /tmp/test-config.json
```

---

## Chapter Summary

### Key Concepts

| Concept | Key Points |
|---------|-----------|
| **Variable Solution** | Zero dependencies, pure Shell, maintainable |
| **init_lang()** | Reads language field from config |
| **load_messages()** | case statement loads by language |
| **Message Naming** | MSG_<Module>_<Action>_<Object> |
| **Testing** | Modify config, environment variable override |

### What You've Learned

- ✅ Why multi-language matters for user experience
- ✅ Variable-based i18n solution design
- ✅ Complete i18n.sh implementation
- ✅ How to use MSG_XXX variables in scripts
- ✅ Message naming conventions
- ✅ How to extend to new languages
- ✅ Testing and verification methods

---

## i18n Checklist

Before release, confirm:

- [ ] All user-visible messages are translated
- [ ] Three languages (en/zh/ja) messages complete
- [ ] Message naming follows conventions
- [ ] No hard-coded message strings
- [ ] Tested output in each language
- [ ] Documentation explains how to switch language

---

## Exercises

### Exercise 5-1: Add English Messages

- Check if i18n.sh has English default messages
- Ensure all Chinese messages have English translations

### Exercise 5-2: Test Language Switching

- Create three test configs (en/zh/ja)
- Verify output in each language

### Exercise 5-3: Add Fourth Language

- Choose a language you know
- Add new branch in load_messages()
- Translate all messages

### Exercise 5-4: Create Message List

- Create a table of all MSG_XXX variables
- Include English, Chinese, Japanese columns

---

## Extended Resources

### Internationalization
- "Internationalization Best Practices" — W3C guide
- "Unicode Standard" — Character encoding reference

### Shell Scripting
- "Advanced Bash-Scripting Guide" — String handling

---

## Next Chapter Preview

**Chapter 6: Debugging and Testing**

In Chapter 6, we cover debugging and testing techniques:
- Shell script debugging basics (set command options)
- Log level design
- Verbose mode implementation
- Temporary file management
- Error handling patterns
- Testing methods (unit, integration, dry-run)
- Debugging real-world cases
- Verification tools

By the end of Chapter 6, you'll debug and test your Skills like a pro!

---

## About this Book

**First Edition (Digital), March 2026**

**Author**: [toohamster](https://github.com/toohamster)
**License**: Electronic version: MIT License | Print/Commercial: All Rights Reserved
**Source**: [github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

See [LICENSE](../../LICENSE) and [About Author](../authors.md) for details.

---
