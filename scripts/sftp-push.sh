#!/bin/bash
# sftp-push.sh — SFTP upload script
# Upload files to remote server via SFTP
# Default: incremental upload (only changed files), --full for full upload
# Zero external dependencies, pure shell

set -euo pipefail

# Locate project root directory
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SFTP_CC_DIR="$PROJECT_ROOT/.claude/sftp-cc"
CONFIG_FILE="$SFTP_CC_DIR/sftp-config.json"
LAST_PUSH_FILE="$SFTP_CC_DIR/.last-push"
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

info()  { echo -e "${GREEN}[push]${NC} $*"; }
warn()  { echo -e "${YELLOW}[push]${NC} $*"; }
error() { echo -e "${RED}[push]${NC} $*" >&2; }
step()  { echo -e "${CYAN}[push]${NC} $*"; }

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

json_get_num() {
    local file="$1" key="$2" default="${3:-}"
    local val
    val=$(grep "\"$key\"" "$file" 2>/dev/null | head -1 | sed 's/.*: *\([0-9][0-9]*\).*/\1/')
    if [ -z "$val" ] || [ "$val" = "null" ]; then
        echo "$default"
    else
        echo "$val"
    fi
}

json_get_array() {
    local file="$1" key="$2"
    sed -n '/"'"$key"'"/,/\]/p' "$file" | grep '"' | grep -v "\"$key\"" | sed 's/.*"\([^"]*\)".*/\1/'
}

show_help() {
    echo "Usage: sftp-push.sh [OPTIONS] [FILES...]"
    echo ""
    echo "Modes:"
    echo "  sftp-push.sh                   Incremental upload (only changed files)"
    echo "  sftp-push.sh --full            Full upload (all project files)"
    echo "  sftp-push.sh file1 file2       Upload specified files"
    echo "  sftp-push.sh -d dirname/       Upload specified directory"
    echo ""
    echo "Options:"
    echo "  -f, --full            Full upload (ignore incremental, upload all files)"
    echo "      --delete          Sync delete remote files deleted locally (off by default)"
    echo "  -d, --dir DIR         Upload specified directory"
    echo "  -n, --dry-run         Preview mode (show operations without uploading)"
    echo "  -v, --verbose         Verbose output"
    echo "  -h, --help            Show this help"
    exit 0
}

if ! command -v sftp &>/dev/null; then
    error "$MSG_REQUIRES_SFTP"
    exit 1
fi

PUSH_DIR=""
FULL_MODE=false
DELETE_MODE=false
DRY_RUN=false
VERBOSE=false
FILES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--full)   FULL_MODE=true; shift ;;
        --delete)    DELETE_MODE=true; shift ;;
        -d|--dir)    PUSH_DIR="$2"; shift 2 ;;
        -n|--dry-run) DRY_RUN=true; shift ;;
        -v|--verbose) VERBOSE=true; shift ;;
        -h|--help)   show_help ;;
        -*)          error "$(printf "$MSG_UNKNOWN_OPTION" "$1")"; exit 1 ;;
        *)           FILES+=("$1"); shift ;;
    esac
done

if [ ! -f "$CONFIG_FILE" ]; then
    error "$(printf "$MSG_CONFIG_MISSING" "$CONFIG_FILE")"
    error "$MSG_RUN_INIT_FIRST"
    exit 1
fi

KEYBIND_SCRIPT="$SCRIPT_DIR/sftp-keybind.sh"
if [ -f "$KEYBIND_SCRIPT" ]; then
    step "$MSG_CHECKING_KEYBIND"
    bash "$KEYBIND_SCRIPT"
fi

HOST=$(json_get "$CONFIG_FILE" "host")
PORT=$(json_get_num "$CONFIG_FILE" "port" "22")
USERNAME=$(json_get "$CONFIG_FILE" "username")
REMOTE_PATH=$(json_get "$CONFIG_FILE" "remote_path")
LOCAL_PATH=$(json_get "$CONFIG_FILE" "local_path" ".")
PRIVATE_KEY=$(json_get "$CONFIG_FILE" "private_key")
EXCLUDES=()
while IFS= read -r line; do
    [ -n "$line" ] && EXCLUDES+=("$line")
done < <(json_get_array "$CONFIG_FILE" "excludes")

MISSING=()
[ -z "$HOST" ]        && MISSING+=("host")
[ -z "$USERNAME" ]    && MISSING+=("username")
[ -z "$REMOTE_PATH" ] && MISSING+=("remote_path")

if [ ${#MISSING[@]} -gt 0 ]; then
    error "$(printf "$MSG_CONFIG_INCOMPLETE" "${MISSING[*]}")"
    error "$(printf "$MSG_EDIT_CONFIG" "$CONFIG_FILE")"
    exit 1
fi

SFTP_OPTS="-P $PORT"

if [ -n "$PRIVATE_KEY" ] && [ -f "$PRIVATE_KEY" ]; then
    SFTP_OPTS="$SFTP_OPTS -i $PRIVATE_KEY"
fi

SFTP_OPTS="$SFTP_OPTS -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
SFTP_TARGET="$USERNAME@$HOST"

if [[ "$LOCAL_PATH" == "." ]] || [[ "$LOCAL_PATH" == "./" ]]; then
    LOCAL_PATH="$PROJECT_ROOT"
elif [[ "$LOCAL_PATH" != /* ]]; then
    LOCAL_PATH="$PROJECT_ROOT/$LOCAL_PATH"
fi

is_excluded() {
    local filepath="$1"
    for ex in "${EXCLUDES[@]}"; do
        case "$filepath" in
            "$ex"/*|*/"$ex"/*|"$ex"|*/"$ex") return 0 ;;
        esac
        if [ "$(basename "$filepath")" = "$ex" ]; then
            return 0
        fi
    done
    return 1
}

save_push_marker() {
    local commit_hash
    commit_hash=$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null || echo "")
    if [ -n "$commit_hash" ]; then
        echo "$commit_hash" > "$LAST_PUSH_FILE"
        date +%s >> "$LAST_PUSH_FILE"
        $VERBOSE && info "$(printf "$MSG_UPLOAD_SUCCESS" "$commit_hash")"
    fi
}

collect_changed_files() {
    local changed_list
    changed_list=$(mktemp)
    local deleted_list
    deleted_list=$(mktemp)

    if [ ! -f "$LAST_PUSH_FILE" ]; then
        echo ""
        rm -f "$changed_list" "$deleted_list"
        return
    fi

    local last_hash
    last_hash=$(head -1 "$LAST_PUSH_FILE")

    if ! git -C "$PROJECT_ROOT" cat-file -t "$last_hash" &>/dev/null; then
        warn "$MSG_COMMIT_INVALID"
        echo ""
        rm -f "$changed_list" "$deleted_list"
        return
    fi

    local current_hash
    current_hash=$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null || echo "")

    if [ "$last_hash" != "$current_hash" ] && [ -n "$current_hash" ]; then
        git -C "$PROJECT_ROOT" diff --name-only --diff-filter=ACMR "$last_hash" HEAD 2>/dev/null >> "$changed_list" || true
        git -C "$PROJECT_ROOT" diff --name-only --diff-filter=D "$last_hash" HEAD 2>/dev/null >> "$deleted_list" || true
    fi

    git -C "$PROJECT_ROOT" diff --cached --name-only --diff-filter=ACMR 2>/dev/null >> "$changed_list" || true
    git -C "$PROJECT_ROOT" diff --cached --name-only --diff-filter=D 2>/dev/null >> "$deleted_list" || true

    git -C "$PROJECT_ROOT" diff --name-only --diff-filter=ACMR 2>/dev/null >> "$changed_list" || true
    git -C "$PROJECT_ROOT" diff --name-only --diff-filter=D 2>/dev/null >> "$deleted_list" || true

    git -C "$PROJECT_ROOT" ls-files --others --exclude-standard 2>/dev/null >> "$changed_list" || true

    local unique_changed unique_deleted
    unique_changed=$(mktemp)
    unique_deleted=$(mktemp)
    sort -u "$changed_list" > "$unique_changed"
    sort -u "$deleted_list" > "$unique_deleted"
    rm -f "$changed_list" "$deleted_list"

    local filtered_changed filtered_deleted
    filtered_changed=$(mktemp)
    filtered_deleted=$(mktemp)

    while IFS= read -r filepath; do
        [ -z "$filepath" ] && continue
        is_excluded "$filepath" && continue
        [ ! -e "$PROJECT_ROOT/$filepath" ] && continue
        echo "$filepath" >> "$filtered_changed"
    done < "$unique_changed"

    while IFS= read -r filepath; do
        [ -z "$filepath" ] && continue
        is_excluded "$filepath" && continue
        [ -e "$PROJECT_ROOT/$filepath" ] && continue
        echo "$filepath" >> "$filtered_deleted"
    done < "$unique_deleted"

    rm -f "$unique_changed" "$unique_deleted"

    echo "$filtered_changed $filtered_deleted"
}

push_files() {
    local files=("$@")
    local batch_file
    batch_file=$(mktemp)

    echo "cd $REMOTE_PATH" >> "$batch_file"

    for f in "${files[@]}"; do
        local abs_path
        if [[ "$f" == /* ]]; then
            abs_path="$f"
        else
            abs_path="$PROJECT_ROOT/$f"
        fi

        if [ ! -e "$abs_path" ]; then
            warn "$(printf "$MSG_FILE_NOT_FOUND" "$f")"
            continue
        fi

        local rel_path="${abs_path#$PROJECT_ROOT/}"
        local remote_dir
        remote_dir=$(dirname "$rel_path")

        if [ "$remote_dir" != "." ]; then
            IFS='/' read -ra parts <<< "$remote_dir"
            local current=""
            for part in "${parts[@]}"; do
                current="${current:+$current/}$part"
                echo "-mkdir $REMOTE_PATH/$current" >> "$batch_file"
            done
        fi

        if [ -d "$abs_path" ]; then
            echo "put -r $abs_path $REMOTE_PATH/$rel_path" >> "$batch_file"
        else
            echo "put $abs_path $REMOTE_PATH/$rel_path" >> "$batch_file"
        fi
        info "  + $rel_path"
    done

    if $DRY_RUN; then
        info "$MSG_DRY_RUN_BATCH_COMMANDS"
        cat "$batch_file"
        rm -f "$batch_file"
        return 0
    fi

    step "$(printf "$MSG_UPLOADING_FILES" "${#files[@]}" "$SFTP_TARGET:$REMOTE_PATH")"
    sftp $SFTP_OPTS -b "$batch_file" "$SFTP_TARGET"
    local rc=$?
    rm -f "$batch_file"
    return $rc
}

push_directory() {
    local dir="$1"
    local abs_dir

    if [[ "$dir" == /* ]]; then
        abs_dir="$dir"
    else
        abs_dir="$PROJECT_ROOT/$dir"
    fi

    if [ ! -d "$abs_dir" ]; then
        error "$(printf "$MSG_DIR_NOT_EXISTS" "$dir")"
        exit 1
    fi

    local rel_dir="${abs_dir#$PROJECT_ROOT/}"

    local batch_file
    batch_file=$(mktemp)

    echo "-mkdir $REMOTE_PATH/$rel_dir" >> "$batch_file"
    echo "put -r $abs_dir $REMOTE_PATH/$rel_dir" >> "$batch_file"

    info "$(printf "$MSG_PUSHING_DIR" "$rel_dir" "$REMOTE_PATH/$rel_dir")"

    if $DRY_RUN; then
        info "$MSG_DRY_RUN_BATCH_COMMANDS"
        cat "$batch_file"
        rm -f "$batch_file"
        return 0
    fi

    step "$(printf "$MSG_UPLOADING_DIR" "$rel_dir")"
    sftp $SFTP_OPTS -b "$batch_file" "$SFTP_TARGET"
    local rc=$?
    rm -f "$batch_file"
    return $rc
}

ensure_remote_dir() {
    step "$MSG_ENSURE_REMOTE_DIR"
    ssh -i "$PRIVATE_KEY" -o StrictHostKeyChecking=no -o BatchMode=yes \
        "$SFTP_TARGET" "mkdir -p '$REMOTE_PATH'" 2>/dev/null || \
    ssh -i "$PRIVATE_KEY" -o StrictHostKeyChecking=no \
        "$SFTP_TARGET" "mkdir -p '$REMOTE_PATH'" 2>/dev/null || true
}

push_project_full() {
    step "$MSG_SCANNING_FILES"

    local find_excludes=()
    for ex in "${EXCLUDES[@]}"; do
        find_excludes+=(-not -path "*/$ex" -not -path "*/$ex/*" -not -name "$ex")
    done

    local file_list
    file_list=$(mktemp)
    find "$LOCAL_PATH" -maxdepth 10 "${find_excludes[@]}" -type f -print > "$file_list" 2>/dev/null || true

    local file_count
    file_count=$(wc -l < "$file_list" | tr -d ' ')

    if [ "$file_count" -eq 0 ]; then
        warn "$MSG_NO_FILES_TO_UPLOAD"
        rm -f "$file_list"
        return 0
    fi

    info "$(printf "$MSG_FOUND_FILES_FULL" "$file_count")"

    local batch_file
    batch_file=$(mktemp)

    local dirs_file
    dirs_file=$(mktemp)
    while IFS= read -r filepath; do
        local rel_path
        rel_path="${filepath#$LOCAL_PATH/}"
        local remote_dir
        remote_dir=$(dirname "$rel_path")
        if [ "$remote_dir" != "." ]; then
            echo "$remote_dir"
        fi
    done < "$file_list" | sort -u > "$dirs_file"

    while IFS= read -r dir; do
        IFS='/' read -ra parts <<< "$dir"
        local current=""
        for part in "${parts[@]}"; do
            current="${current:+$current/}$part"
            echo "-mkdir $REMOTE_PATH/$current" >> "$batch_file"
        done
    done < "$dirs_file"

    while IFS= read -r filepath; do
        local rel_path
        rel_path="${filepath#$LOCAL_PATH/}"
        echo "put $filepath $REMOTE_PATH/$rel_path" >> "$batch_file"
        $VERBOSE && info "  + $rel_path"
    done < "$file_list"

    rm -f "$file_list" "$dirs_file"

    if $DRY_RUN; then
        info "$(printf "$MSG_DRY_RUN_WILL_UPLOAD" "$file_count" "$SFTP_TARGET:$REMOTE_PATH")"
        info "$MSG_DRY_RUN_BATCH_PREVIEW"
        head -20 "$batch_file"
        [ "$file_count" -gt 20 ] && info "$(printf "$MSG_TOTAL_COMMANDS" "$(wc -l < "$batch_file" | tr -d ' ')")"
        rm -f "$batch_file"
        return 0
    fi

    step "$(printf "$MSG_UPLOADING_FILES" "$file_count" "$SFTP_TARGET:$REMOTE_PATH")"
    ensure_remote_dir
    sftp $SFTP_OPTS -b "$batch_file" "$SFTP_TARGET"
    local rc=$?
    rm -f "$batch_file"
    return $rc
}

push_incremental() {
    step "$MSG_CHECKING_CHANGES"

    local result
    result=$(collect_changed_files)

    if [ -z "$result" ]; then
        warn "$MSG_FIRST_UPLOAD_FULL"
        push_project_full
        return $?
    fi

    local changed_file deleted_file
    changed_file=$(echo "$result" | cut -d' ' -f1)
    deleted_file=$(echo "$result" | cut -d' ' -f2)

    local change_count=0 delete_count=0
    [ -f "$changed_file" ] && change_count=$(wc -l < "$changed_file" | tr -d ' ')
    [ -f "$deleted_file" ] && delete_count=$(wc -l < "$deleted_file" | tr -d ' ')

    if [ "$change_count" -eq 0 ] && { ! $DELETE_MODE || [ "$delete_count" -eq 0 ]; }; then
        info "$MSG_NO_CHANGES"
        rm -f "$changed_file" "$deleted_file"
        return 0
    fi

    [ "$change_count" -gt 0 ] && info "$(printf "$MSG_FOUND_FILES_INCREMENTAL" "$change_count")"
    if [ "$delete_count" -gt 0 ]; then
        if $DELETE_MODE; then
            warn "$(printf "$MSG_FOUND_FILES_DELETED" "$delete_count")"
        else
            info "$MSG_DELETE_NOT_ENABLED"
        fi
    fi

    local upload_files=()
    if [ "$change_count" -gt 0 ]; then
        while IFS= read -r rel_path; do
            [ -z "$rel_path" ] && continue
            upload_files+=("$rel_path")
            $VERBOSE && info "  ~ $rel_path"
        done < "$changed_file"
    fi
    rm -f "$changed_file"

    local delete_files=()
    if $DELETE_MODE && [ "$delete_count" -gt 0 ]; then
        while IFS= read -r rel_path; do
            [ -z "$rel_path" ] && continue
            delete_files+=("$rel_path")
            $VERBOSE && warn "  - $rel_path"
        done < "$deleted_file"
    fi
    rm -f "$deleted_file"

    if [ ${#upload_files[@]} -eq 0 ] && [ ${#delete_files[@]} -eq 0 ]; then
        info "$MSG_SYNC_NO_CHANGES"
        return 0
    fi

    local batch_file
    batch_file=$(mktemp)

    if [ ${#upload_files[@]} -gt 0 ]; then
        local dirs_file
        dirs_file=$(mktemp)
        for rel_path in "${upload_files[@]}"; do
            local remote_dir
            remote_dir=$(dirname "$rel_path")
            if [ "$remote_dir" != "." ]; then
                echo "$remote_dir"
            fi
        done | sort -u > "$dirs_file"

        while IFS= read -r dir; do
            IFS='/' read -ra parts <<< "$dir"
            local current=""
            for part in "${parts[@]}"; do
                current="${current:+$current/}$part"
                echo "-mkdir $REMOTE_PATH/$current" >> "$batch_file"
            done
        done < "$dirs_file"
        rm -f "$dirs_file"

        for rel_path in "${upload_files[@]}"; do
            echo "put $PROJECT_ROOT/$rel_path $REMOTE_PATH/$rel_path" >> "$batch_file"
            info "  + $rel_path"
        done
    fi

    if [ ${#delete_files[@]} -gt 0 ]; then
        for rel_path in "${delete_files[@]}"; do
            echo "-rm $REMOTE_PATH/$rel_path" >> "$batch_file"
            warn "$(printf "$MSG_DELETING_REMOTE" "$rel_path")"
        done
    fi

    local total_ops=$(( ${#upload_files[@]} + ${#delete_files[@]} ))

    if $DRY_RUN; then
        info "$(printf "$MSG_SYNCING_INCREMENTAL" "$SFTP_TARGET:$REMOTE_PATH" "${#upload_files[@]}" "${#delete_files[@]}")"
        info "$MSG_DRY_RUN_BATCH_COMMANDS"
        cat "$batch_file"
        rm -f "$batch_file"
        return 0
    fi

    step "$(printf "$MSG_SYNCING_INCREMENTAL" "$SFTP_TARGET:$REMOTE_PATH" "${#upload_files[@]}" "${#delete_files[@]}")"
    ensure_remote_dir
    sftp $SFTP_OPTS -b "$batch_file" "$SFTP_TARGET"
    local rc=$?
    rm -f "$batch_file"
    return $rc
}

info "$(printf "$MSG_TARGET_SERVER" "$SFTP_TARGET:$REMOTE_PATH")"

if [ -n "$PUSH_DIR" ]; then
    push_directory "$PUSH_DIR"
elif [ ${#FILES[@]} -gt 0 ]; then
    push_files "${FILES[@]}"
elif $FULL_MODE; then
    push_project_full
else
    push_incremental
fi

rc=$?
if [ $rc -eq 0 ]; then
    if ! $DRY_RUN; then
        save_push_marker
    fi
    info "$MSG_UPLOAD_COMPLETE"
else
    error "$(printf "$MSG_UPLOAD_FAILED" "$rc")"
    exit $rc
fi
