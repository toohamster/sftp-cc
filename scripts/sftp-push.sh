#!/bin/bash
# sftp-push.sh — SFTP 上传核心脚本
# 将本地文件通过 SFTP 推送到远程服务器
# 默认增量上传（仅变更文件），--full 全量上传
# 零外部依赖，纯 shell 实现

set -euo pipefail

# 定位项目根目录
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SFTP_CC_DIR="$PROJECT_ROOT/.claude/sftp-cc"
CONFIG_FILE="$SFTP_CC_DIR/sftp-config.json"
LAST_PUSH_FILE="$SFTP_CC_DIR/.last-push"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[push]${NC} $*"; }
warn()  { echo -e "${YELLOW}[push]${NC} $*"; }
error() { echo -e "${RED}[push]${NC} $*" >&2; }
step()  { echo -e "${CYAN}[push]${NC} $*"; }

# ====== 纯 shell JSON 工具函数 ======
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

# 读取 JSON 数组值（每行一个元素）
json_get_array() {
    local file="$1" key="$2"
    sed -n '/"'"$key"'"/,/\]/p' "$file" | grep '"' | grep -v "\"$key\"" | sed 's/.*"\([^"]*\)".*/\1/'
}

# 显示帮助
show_help() {
    echo "Usage: sftp-push.sh [OPTIONS] [FILES...]"
    echo ""
    echo "模式:"
    echo "  sftp-push.sh                   增量上传（仅变更文件）"
    echo "  sftp-push.sh --full            全量上传整个项目"
    echo "  sftp-push.sh file1 file2       上传指定文件"
    echo "  sftp-push.sh -d dirname/       上传指定目录"
    echo ""
    echo "Options:"
    echo "  -f, --full            全量上传（忽略增量，上传所有文件）"
    echo "      --delete          同步删除远程已在本地删除的文件（默认不删）"
    echo "  -d, --dir DIR         上传指定目录"
    echo "  -n, --dry-run         仅显示将要执行的操作，不实际上传"
    echo "  -v, --verbose         显示详细输出"
    echo "  -h, --help            显示帮助"
    exit 0
}

# 检查 sftp 命令
if ! command -v sftp &>/dev/null; then
    error "需要 sftp 命令（系统应自带）"
    exit 1
fi

# 解析参数
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
        -*)          error "未知选项: $1"; exit 1 ;;
        *)           FILES+=("$1"); shift ;;
    esac
done

# 检查配置文件
if [ ! -f "$CONFIG_FILE" ]; then
    error "配置文件不存在: $CONFIG_FILE"
    error "请先运行 sftp-init.sh 初始化"
    exit 1
fi

# 推送前自动绑定私钥
KEYBIND_SCRIPT="$SCRIPT_DIR/sftp-keybind.sh"
if [ -f "$KEYBIND_SCRIPT" ]; then
    step "检查私钥绑定..."
    bash "$KEYBIND_SCRIPT"
fi

# 读取配置
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

# 验证必要配置
MISSING=()
[ -z "$HOST" ]        && MISSING+=("host")
[ -z "$USERNAME" ]    && MISSING+=("username")
[ -z "$REMOTE_PATH" ] && MISSING+=("remote_path")

if [ ${#MISSING[@]} -gt 0 ]; then
    error "配置不完整，缺少: ${MISSING[*]}"
    error "请编辑 $CONFIG_FILE 补充配置"
    exit 1
fi

# 构建 sftp 选项
SFTP_OPTS="-P $PORT"

if [ -n "$PRIVATE_KEY" ] && [ -f "$PRIVATE_KEY" ]; then
    SFTP_OPTS="$SFTP_OPTS -i $PRIVATE_KEY"
fi

SFTP_OPTS="$SFTP_OPTS -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
SFTP_TARGET="$USERNAME@$HOST"

# 解析 LOCAL_PATH（相对于项目根目录）
if [[ "$LOCAL_PATH" == "." ]] || [[ "$LOCAL_PATH" == "./" ]]; then
    LOCAL_PATH="$PROJECT_ROOT"
elif [[ "$LOCAL_PATH" != /* ]]; then
    LOCAL_PATH="$PROJECT_ROOT/$LOCAL_PATH"
fi

# ====== 检查文件是否在 excludes 中 ======
is_excluded() {
    local filepath="$1"
    for ex in "${EXCLUDES[@]}"; do
        case "$filepath" in
            "$ex"/*|*/"$ex"/*|"$ex"|*/"$ex") return 0 ;;
        esac
        # 文件名匹配
        if [ "$(basename "$filepath")" = "$ex" ]; then
            return 0
        fi
    done
    return 1
}

# ====== 记录推送点 ======
save_push_marker() {
    local commit_hash
    commit_hash=$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null || echo "")
    if [ -n "$commit_hash" ]; then
        echo "$commit_hash" > "$LAST_PUSH_FILE"
        # 同时记录时间戳，用于检测未提交的改动
        date +%s >> "$LAST_PUSH_FILE"
        $VERBOSE && info "已记录推送点: $commit_hash"
    fi
}

# ====== 收集增量变更文件列表 ======
# 输出两个临时文件路径，用空格分隔：changed_file deleted_file
# 如果无历史记录返回空字符串
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
        warn "上次推送记录的 commit 已失效，将执行全量上传"
        echo ""
        rm -f "$changed_list" "$deleted_list"
        return
    fi

    local current_hash
    current_hash=$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null || echo "")

    # 1) 已提交的变更（上次推送 → 当前 HEAD）
    if [ "$last_hash" != "$current_hash" ] && [ -n "$current_hash" ]; then
        git -C "$PROJECT_ROOT" diff --name-only --diff-filter=ACMR "$last_hash" HEAD 2>/dev/null >> "$changed_list" || true
        git -C "$PROJECT_ROOT" diff --name-only --diff-filter=D "$last_hash" HEAD 2>/dev/null >> "$deleted_list" || true
    fi

    # 2) 暂存区的变更
    git -C "$PROJECT_ROOT" diff --cached --name-only --diff-filter=ACMR 2>/dev/null >> "$changed_list" || true
    git -C "$PROJECT_ROOT" diff --cached --name-only --diff-filter=D 2>/dev/null >> "$deleted_list" || true

    # 3) 工作区未暂存的变更
    git -C "$PROJECT_ROOT" diff --name-only --diff-filter=ACMR 2>/dev/null >> "$changed_list" || true
    git -C "$PROJECT_ROOT" diff --name-only --diff-filter=D 2>/dev/null >> "$deleted_list" || true

    # 4) 未跟踪的新文件
    git -C "$PROJECT_ROOT" ls-files --others --exclude-standard 2>/dev/null >> "$changed_list" || true

    # 去重
    local unique_changed unique_deleted
    unique_changed=$(mktemp)
    unique_deleted=$(mktemp)
    sort -u "$changed_list" > "$unique_changed"
    sort -u "$deleted_list" > "$unique_deleted"
    rm -f "$changed_list" "$deleted_list"

    # 过滤 excludes
    local filtered_changed filtered_deleted
    filtered_changed=$(mktemp)
    filtered_deleted=$(mktemp)

    while IFS= read -r filepath; do
        [ -z "$filepath" ] && continue
        is_excluded "$filepath" && continue
        # 变更文件必须本地存在
        [ ! -e "$PROJECT_ROOT/$filepath" ] && continue
        echo "$filepath" >> "$filtered_changed"
    done < "$unique_changed"

    while IFS= read -r filepath; do
        [ -z "$filepath" ] && continue
        is_excluded "$filepath" && continue
        # 删除文件必须本地不存在（确认已删除）
        [ -e "$PROJECT_ROOT/$filepath" ] && continue
        echo "$filepath" >> "$filtered_deleted"
    done < "$unique_deleted"

    rm -f "$unique_changed" "$unique_deleted"

    echo "$filtered_changed $filtered_deleted"
}

# ====== 推送指定文件 ======
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
            warn "文件不存在，跳过: $f"
            continue
        fi

        # 计算相对路径
        local rel_path="${abs_path#$PROJECT_ROOT/}"
        local remote_dir
        remote_dir=$(dirname "$rel_path")

        if [ "$remote_dir" != "." ]; then
            # 逐层创建远程目录
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
        info "[dry-run] 批处理命令:"
        cat "$batch_file"
        rm -f "$batch_file"
        return 0
    fi

    step "正在上传 ${#files[@]} 个文件..."
    # shellcheck disable=SC2086
    sftp $SFTP_OPTS -b "$batch_file" "$SFTP_TARGET"
    local rc=$?
    rm -f "$batch_file"
    return $rc
}

# ====== 推送目录 ======
push_directory() {
    local dir="$1"
    local abs_dir

    if [[ "$dir" == /* ]]; then
        abs_dir="$dir"
    else
        abs_dir="$PROJECT_ROOT/$dir"
    fi

    if [ ! -d "$abs_dir" ]; then
        error "目录不存在: $dir"
        exit 1
    fi

    local rel_dir="${abs_dir#$PROJECT_ROOT/}"

    local batch_file
    batch_file=$(mktemp)

    echo "-mkdir $REMOTE_PATH/$rel_dir" >> "$batch_file"
    echo "put -r $abs_dir $REMOTE_PATH/$rel_dir" >> "$batch_file"

    info "推送目录: $rel_dir -> $REMOTE_PATH/$rel_dir"

    if $DRY_RUN; then
        info "[dry-run] 批处理命令:"
        cat "$batch_file"
        rm -f "$batch_file"
        return 0
    fi

    step "正在上传目录 $rel_dir..."
    # shellcheck disable=SC2086
    sftp $SFTP_OPTS -b "$batch_file" "$SFTP_TARGET"
    local rc=$?
    rm -f "$batch_file"
    return $rc
}

# ====== 辅助函数：确保远程目录存在 ======
ensure_remote_dir() {
    step "确保远程目录存在..."
    # 使用 SSH 执行 mkdir -p 创建远程目录（忽略已存在的情况）
    ssh -i "$PRIVATE_KEY" -o StrictHostKeyChecking=no -o BatchMode=yes \
        "$SFTP_TARGET" "mkdir -p '$REMOTE_PATH'" 2>/dev/null
    if [ $? -ne 0 ]; then
        # 如果 SSH 命令失败（如 BatchMode 无密码），尝试不带 BatchMode
        ssh -i "$PRIVATE_KEY" -o StrictHostKeyChecking=no \
            "$SFTP_TARGET" "mkdir -p '$REMOTE_PATH'" 2>/dev/null
    fi
}

# ====== 推送整个项目（全量） ======
push_project_full() {
    step "全量扫描项目文件..."

    # 构建 find 排除参数
    local find_excludes=()
    for ex in "${EXCLUDES[@]}"; do
        find_excludes+=(-not -path "*/$ex" -not -path "*/$ex/*" -not -name "$ex")
    done

    # 收集文件列表
    local file_list
    file_list=$(mktemp)
    find "$LOCAL_PATH" -maxdepth 10 "${find_excludes[@]}" -type f -print > "$file_list" 2>/dev/null || true

    local file_count
    file_count=$(wc -l < "$file_list" | tr -d ' ')

    if [ "$file_count" -eq 0 ]; then
        warn "没有找到需要上传的文件"
        rm -f "$file_list"
        return 0
    fi

    info "找到 $file_count 个文件（全量）"

    # 构建 sftp batch 文件
    local batch_file
    batch_file=$(mktemp)

    # 先收集所有需要创建的远程目录
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

    # 创建远程目录（逐层，从浅到深）
    while IFS= read -r dir; do
        IFS='/' read -ra parts <<< "$dir"
        local current=""
        for part in "${parts[@]}"; do
            current="${current:+$current/}$part"
            echo "-mkdir $REMOTE_PATH/$current" >> "$batch_file"
        done
    done < "$dirs_file"

    # 添加文件上传命令
    while IFS= read -r filepath; do
        local rel_path
        rel_path="${filepath#$LOCAL_PATH/}"
        echo "put $filepath $REMOTE_PATH/$rel_path" >> "$batch_file"
        $VERBOSE && info "  + $rel_path"
    done < "$file_list"

    rm -f "$file_list" "$dirs_file"

    if $DRY_RUN; then
        info "[dry-run] 将上传 $file_count 个文件到 $SFTP_TARGET:$REMOTE_PATH"
        info "[dry-run] 批处理命令 (前20行):"
        head -20 "$batch_file"
        [ "$file_count" -gt 20 ] && info "  ... (共 $(wc -l < "$batch_file" | tr -d ' ') 条命令)"
        rm -f "$batch_file"
        return 0
    fi

    step "正在上传 $file_count 个文件到 $SFTP_TARGET:$REMOTE_PATH ..."
    # 确保远程目录存在
    ensure_remote_dir
    # shellcheck disable=SC2086
    sftp $SFTP_OPTS -b "$batch_file" "$SFTP_TARGET"
    local rc=$?
    rm -f "$batch_file"
    return $rc
}

# ====== 增量推送 ======
push_incremental() {
    step "检测文件变更..."

    local result
    result=$(collect_changed_files)

    # 如果返回空字符串，说明没有上次记录，回退全量
    if [ -z "$result" ]; then
        warn "首次上传，无历史推送记录，执行全量上传"
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
        info "没有检测到文件变更，无需上传"
        rm -f "$changed_file" "$deleted_file"
        return 0
    fi

    [ "$change_count" -gt 0 ] && info "检测到 $change_count 个变更文件（增量）"
    if [ "$delete_count" -gt 0 ]; then
        if $DELETE_MODE; then
            warn "检测到 $delete_count 个已删除文件，将同步删除远程文件"
        else
            info "检测到 $delete_count 个已删除文件（未启用 --delete，跳过远程删除）"
        fi
    fi

    # 构建上传文件列表
    local upload_files=()
    if [ "$change_count" -gt 0 ]; then
        while IFS= read -r rel_path; do
            [ -z "$rel_path" ] && continue
            upload_files+=("$rel_path")
            $VERBOSE && info "  ~ $rel_path"
        done < "$changed_file"
    fi
    rm -f "$changed_file"

    # 构建删除文件列表
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
        info "没有需要同步的变更"
        return 0
    fi

    # 构建 batch 文件
    local batch_file
    batch_file=$(mktemp)

    # 收集远程目录并创建
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

        # 添加上传命令
        for rel_path in "${upload_files[@]}"; do
            echo "put $PROJECT_ROOT/$rel_path $REMOTE_PATH/$rel_path" >> "$batch_file"
            info "  + $rel_path"
        done
    fi

    # 添加删除命令
    if [ ${#delete_files[@]} -gt 0 ]; then
        for rel_path in "${delete_files[@]}"; do
            echo "-rm $REMOTE_PATH/$rel_path" >> "$batch_file"
            warn "  x $rel_path (远程删除)"
        done
    fi

    local total_ops=$(( ${#upload_files[@]} + ${#delete_files[@]} ))

    if $DRY_RUN; then
        info "[dry-run] 增量同步 $total_ops 项操作 (上传 ${#upload_files[@]}, 删除 ${#delete_files[@]})"
        info "[dry-run] 批处理命令:"
        cat "$batch_file"
        rm -f "$batch_file"
        return 0
    fi

    step "正在增量同步到 $SFTP_TARGET:$REMOTE_PATH (上传 ${#upload_files[@]}, 删除 ${#delete_files[@]}) ..."
    # 确保远程目录存在
    ensure_remote_dir
    # shellcheck disable=SC2086
    sftp $SFTP_OPTS -b "$batch_file" "$SFTP_TARGET"
    local rc=$?
    rm -f "$batch_file"
    return $rc
}

# ====== 主逻辑 ======
info "目标服务器: $SFTP_TARGET:$REMOTE_PATH"

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
    # 上传成功后记录推送点
    if ! $DRY_RUN; then
        save_push_marker
    fi
    info "上传完成！"
else
    error "上传失败 (exit code: $rc)"
    exit $rc
fi
