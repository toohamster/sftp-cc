# 第 6 章：调试与测试

> "调试是编程的必备技能，好的调试能力可以节省 10 倍的开发时间。" — 编程格言

本章你将学到：
- Shell 脚本调试基础（set 命令选项）
- 日志级别设计和实现
- verbose 模式的完整实现
- 临时文件管理和清理
- 错误处理的多种模式
- 测试方法（单元测试、集成测试、dry-run）
- 调试实战案例（真实问题排查）
- 验证工具和自动化测试
- 性能分析和优化

---

## 6.1 Shell 脚本调试基础

### 6.1.1 set 命令选项详解

Shell 的 `set` 命令提供了多种调试和错误处理选项：

```bash
#!/bin/bash
# ============================================================================
# 生产环境推荐设置
# ============================================================================
set -euo pipefail

# ============================================================================
# 调试环境设置
# ============================================================================
set -xv    # 详细调试输出

# ============================================================================
# 各选项详解
# ============================================================================
```

#### 选项对比表

| 选项 | 全称 | 作用 | 使用场景 |
|------|------|------|----------|
| `-e` | errexit | 命令失败时立即退出 | 生产脚本 |
| `-u` | nounset | 使用未定义变量时报错 | 防止拼写错误 |
| `-o pipefail` | - | 管道中任一命令失败则整体失败 | 管道操作 |
| `-x` | xtrace | 打印每条执行命令 | 调试 |
| `-v` | verbose | 打印每行输入 | 调试 |
| `-C` | noclobber | 防止重定向覆盖 | 数据安全 |

#### 各选项详细示例

##### -e（errexit）

```bash
# 不使用 -e
#!/bin/bash
false
echo "这行会执行，即使上面的命令失败了"

# 输出：
# 这行会执行，即使上面的命令失败了

# 使用 -e
#!/bin/bash
set -e
false
echo "这行不会执行"

# 输出：
# （无输出，脚本在 false 处退出）
```

##### -u（nounset）

```bash
# 不使用 -u
#!/bin/bash
echo "$MISSPELLED_VAR"  # 输出空字符串，难以发现拼写错误

# 使用 -u
#!/bin/bash
set -u
echo "$MISSPELLED_VAR"

# 输出：
# bash: line 3: MISSPELLED_VAR: unbound variable
# 脚本退出，错误立即暴露
```

##### -o pipefail

```bash
# 不使用 pipefail
#!/bin/bash
echo "test" | false | cat
echo "退出码：$?"  # 输出 0（cat 的退出码）

# 使用 pipefail
#!/bin/bash
set -o pipefail
echo "test" | false | cat
echo "退出码：$?"  # 输出 1（false 的退出码）
```

##### -x（调试模式）

```bash
#!/bin/bash
set -x

name="World"
echo "Hello, $name"

# 输出：
# + name=World
# + echo 'Hello, World'
# Hello, World
```

### 6.1.2 条件调试模式

在生产脚本中，如何既保持严格错误处理，又能在需要时调试？

```bash
#!/bin/bash
# 生产环境设置
set -euo pipefail

# 调试模式开关（通过环境变量控制）
if [[ "${DEBUG:-}" == "1" ]]; then
    set -x
    echo "[DEBUG] 调试模式已启用" >&2
fi

# 或者通过参数
if [[ "${1:-}" == "--debug" ]]; then
    set -x
    shift
fi

# 主逻辑
main() {
    # ...
}

main "$@"
```

### 6.1.3 局部调试

不需要全局启用调试时，可以局部使用：

```bash
#!/bin/bash
set -euo pipefail

# 正常执行
info "开始处理..."

# 临时启用调试
(
    set -x
    # 需要调试的代码段
    process_complex_data
    calculate_result
)

# 调试自动关闭，继续正常执行
info "处理完成"
```

---

## 6.2 日志级别设计

### 6.2.1 为什么需要日志级别？

```
场景：脚本执行出现问题

没有日志级别：
  $ bash script.sh
  配置文件已创建
  开始上传
  上传完成

  → 无法知道哪一步出问题，无法追踪问题

有日志级别：
  $ bash script.sh -v
  [INFO]  配置文件已创建
  [DEBUG] 配置路径：/path/to/config
  [INFO]  开始上传
  [DEBUG] 正在连接 server:22
  [DEBUG] 连接成功
  [INFO]  上传完成

  → 清晰的执行轨迹，便于定位问题
```

### 6.2.2 五级日志系统

```bash
# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# 日志级别（数字越小越严重）
readonly LOG_LEVEL_ERROR=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_INFO=3
readonly LOG_LEVEL_DEBUG=4

# 当前日志级别（可通过环境变量调整）
CURRENT_LOG_LEVEL="${LOG_LEVEL:-$LOG_LEVEL_INFO}"

# 日志函数
log_error() {
    [[ $CURRENT_LOG_LEVEL -ge $LOG_LEVEL_ERROR ]] || return 0
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_warn() {
    [[ $CURRENT_LOG_LEVEL -ge $LOG_LEVEL_WARN ]] || return 0
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_info() {
    [[ $CURRENT_LOG_LEVEL -ge $LOG_LEVEL_INFO ]] || return 0
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_debug() {
    [[ $CURRENT_LOG_LEVEL -ge $LOG_LEVEL_DEBUG ]] || return 0
    echo -e "${CYAN}[DEBUG]${NC} $*" >&2
}

log_step() {
    [[ $CURRENT_LOG_LEVEL -ge $LOG_LEVEL_INFO ]] || return 0
    echo -e "${BLUE}[STEP]${NC} $*"
}
```

### 6.2.3 使用示例

```bash
#!/bin/bash
# sftp-push.sh

# 解析日志级别
case "${LOG_LEVEL:-}" in
    debug|4) LOG_LEVEL=4 ;;
    info|3)  LOG_LEVEL=3 ;;
    warn|2)  LOG_LEVEL=2 ;;
    error|1) LOG_LEVEL=1 ;;
    *)       LOG_LEVEL=3 ;;  # 默认 info
esac

main() {
    log_step "开始 SFTP 上传"
    log_debug "配置路径：$CONFIG_FILE"

    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "配置文件不存在：$CONFIG_FILE"
        exit 1
    fi

    log_info "配置文件已加载"
    log_debug "主机：$HOST, 端口：$PORT"

    # ...
}
```

### 6.2.4 结构化日志

为了便于日志分析，可以使用结构化格式：

```bash
# JSON 格式日志
log_json() {
    local level="$1"
    local message="$2"
    shift 2

    # 时间戳
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # 输出 JSON
    cat << EOF
{"timestamp":"$timestamp","level":"$level","message":"$message",$@}
EOF
}

# 使用
log_json "INFO" "Upload started" "\"files\":$count"
# 输出：{"timestamp":"2024-01-01T12:00:00Z","level":"INFO","message":"Upload started","files":15}
```

---

## 6.3 verbose 模式实现

### 6.3.1 参数解析

```bash
# 全局变量
VERBOSE=false
DEBUG=false

# 解析函数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--debug)
                DEBUG=true
                set -x  # 启用详细调试
                shift
                ;;
            -q|--quiet)
                VERBOSE=false
                LOG_LEVEL=1  # 只输出错误
                shift
                ;;
            *)
                # 其他参数处理
                shift
                ;;
        esac
    done
}
```

### 6.3.2 debug 函数实现

```bash
# debug 输出函数
debug() {
    if $DEBUG || [[ "${DEBUG_MODE:-}" == "1" ]]; then
        local caller
        caller=$(basename "${BASH_SOURCE[1]}")
        local line_no
        line_no="${BASH_LINENO[0]}"
        echo -e "\033[0;36m[DEBUG]\033[0m [$caller:$line_no] $*" >&2
    fi
}

# 使用示例
debug "配置文件路径：$CONFIG_FILE"
# 输出：[DEBUG] [sftp-push.sh:42] 配置文件路径：/path/to/config

debug "排除列表：${EXCLUDES[*]}"
# 输出：[DEBUG] [sftp-push.sh:43] 排除列表：.git .claude node_modules
```

### 6.3.3 条件详细输出

```bash
# 文件列表详细输出
list_files() {
    local files=("$@")

    log_info "找到 ${#files[@]} 个文件"

    if $VERBOSE; then
        log_info "文件列表:"
        for f in "${files[@]}"; do
            echo "  - $f"
        done
    fi
}

# 上传进度详细输出
upload_files() {
    local files=("$@")
    local count=0
    local total=${#files[@]}

    for f in "${files[@]}"; do
        ((count++))

        if $VERBOSE; then
            log_info "[$count/$total] 上传：$f"
        else
            # 简洁模式：只显示进度
            echo -ne "\r上传进度：$count/$total"
        fi

        # 实际上传逻辑
        upload_single_file "$f"
    done

    if ! $VERBOSE; then
        echo  # 换行
    fi
}
```

---

## 6.4 临时文件管理

### 6.4.1 mktemp 详解

```bash
# 创建临时文件
tmp_file=$(mktemp)
# 示例输出：/tmp/tmp.XXXXXXXXXX

# 创建临时目录
tmp_dir=$(mktemp -d)
# 示例输出：/tmp/tmp.XXXXXXXXXX

# 指定前缀
tmp_file=$(mktemp -t myscript.XXXXXXXXXX)
# 示例输出：/tmp/myscript.XXXXXXXXXX

# 指定后缀
tmp_file=$(mktemp --suffix=.log)
# 示例输出：/tmp/tmp.XXXXXXXXXX.log
```

### 6.4.2 trap 清理机制

```bash
#!/bin/bash
set -euo pipefail

# 临时文件数组
declare -a TEMP_FILES=()

# 清理函数
cleanup() {
    local exit_code=$?

    log_debug "正在清理临时文件..."

    for f in "${TEMP_FILES[@]}"; do
        if [ -f "$f" ]; then
            rm -f "$f"
            log_debug "已删除：$f"
        fi
        if [ -d "$f" ]; then
            rm -rf "$f"
            log_debug "已删除目录：$f"
        fi
    done

    # 保留原始退出码
    exit $exit_code
}

# 注册清理函数
trap cleanup EXIT

# 注册错误处理
trap 'log_error "脚本在第 ${BASH_LINENO[0]} 行失败"; exit 1' ERR

# 创建临时文件的辅助函数
make_temp() {
    local tmp
    tmp=$(mktemp)
    TEMP_FILES+=("$tmp")
    echo "$tmp"
}

make_temp_dir() {
    local tmp
    tmp=$(mktemp -d)
    TEMP_FILES+=("$tmp")
    echo "$tmp"
}

# 使用示例
main() {
    local changed_list
    changed_list=$(make_temp)

    local batch_file
    batch_file=$(make_temp)

    local temp_dir
    temp_dir=$(make_temp_dir)

    # ... 使用临时文件 ...

    # 不需要手动删除，退出时自动清理
}

main "$@"
```

### 6.4.3 临时文件最佳实践

```bash
# ✅ 好的做法
# 1. 使用 mktemp 而非固定路径
tmp_file=$(mktemp)  # 安全

# 2. 使用 trap 确保清理
trap 'rm -f "$tmp_file"' EXIT

# 3. 及时删除不需要的临时文件
process_file "$tmp_file"
rm -f "$tmp_file"  # 尽早释放资源

# ❌ 差的做法
# 1. 使用固定路径（可能被占用）
tmp_file="/tmp/my_script.tmp"  # 不安全

# 2. 忘记清理
tmp_file=$(mktemp)
# ... 使用但不清理 ...  # 泄漏

# 3. 在清理前退出
tmp_file=$(mktemp)
rm -f "$tmp_file"
exit 1  # trap 未执行，临时文件残留
```

---

## 6.5 错误处理模式

### 6.5.1 参数验证

#### 多字段批量验证

```bash
validate_required() {
    local missing=()

    while [[ $# -gt 0 ]]; do
        local var_name="$1"
        local var_value="${!1}"

        if [ -z "$var_value" ]; then
            missing+=("$var_name")
        fi
        shift
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "缺少必需的参数：${missing[*]}"
        return 1
    fi

    return 0
}

# 使用
if ! validate_required HOST USERNAME REMOTE_PATH; then
    exit 1
fi
```

#### 类型验证

```bash
validate_number() {
    local var_name="$1"
    local var_value="$2"

    if ! [[ "$var_value" =~ ^[0-9]+$ ]]; then
        log_error "$var_name 必须是数字：$var_value"
        return 1
    fi

    return 0
}

validate_port() {
    local port="$1"

    if ! validate_number "端口" "$port"; then
        return 1
    fi

    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_error "端口必须在 1-65535 之间：$port"
        return 1
    fi

    return 0
}
```

#### 路径验证

```bash
validate_path() {
    local path="$1"
    local name="${2:-路径}"
    local must_exist="${3:-false}"

    # 空路径检查
    if [ -z "$path" ]; then
        log_error "$name 不能为空"
        return 1
    fi

    # 存在性检查
    if [ "$must_exist" = "true" ]; then
        if [ ! -e "$path" ]; then
            log_error "$name 不存在：$path"
            return 1
        fi
    fi

    # 安全路径检查（防止路径遍历攻击）
    if [[ "$path" == *".."* ]]; then
        log_warn "$name 包含 .. 路径：$path"
    fi

    return 0
}
```

### 6.5.2 命令依赖检查

```bash
# 检查单个命令
check_command() {
    local cmd="$1"

    if ! command -v "$cmd" &>/dev/null; then
        log_error "未找到命令：$cmd"
        return 1
    fi

    return 0
}

# 检查多个命令
check_dependencies() {
    local deps=("$@")
    local missing=()

    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "缺少必需的命令：${missing[*]}"
        log_error "请安装缺失的命令后重试"
        return 1
    fi

    return 0
}

# 在脚本开头使用
REQUIRED_COMMANDS=("sftp" "git" "grep" "sed" "find")
if ! check_dependencies "${REQUIRED_COMMANDS[@]}"; then
    exit 1
fi
```

### 6.5.3 错误恢复模式

#### 重试机制

```bash
# 带重试的命令执行
retry_command() {
    local max_attempts="${1:-3}"
    local delay="${2:-5}"
    shift 2

    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        log_debug "尝试 $attempt/$max_attempts: $*"

        if "$@"; then
            return 0
        fi

        local exit_code=$?
        log_warn "命令失败（尝试 $attempt），$delay 秒后重试..."
        sleep "$delay"
        ((attempt++))
    done

    log_error "命令在 $max_attempts 次尝试后仍失败"
    return $exit_code
}

# 使用
if ! retry_command 3 5 sftp "$SFTP_OPTS" "$SFTP_TARGET" < "$batch_file"; then
    exit 1
fi
```

#### 回退机制

```bash
# 多方法回退
safe_copy() {
    local src="$1"
    local dst="$2"

    # 方法 1: cp
    if cp "$src" "$dst" 2>/dev/null; then
        log_debug "使用 cp 复制成功"
        return 0
    fi

    # 方法 2: cat
    if cat "$src" > "$dst" 2>/dev/null; then
        log_debug "使用 cat 复制成功"
        return 0
    fi

    # 方法 3: rsync（如果有）
    if command -v rsync &>/dev/null; then
        if rsync "$src" "$dst" 2>/dev/null; then
            log_debug "使用 rsync 复制成功"
            return 0
        fi
    fi

    log_error "所有复制方法都失败了：$src -> $dst"
    return 1
}
```

---

## 6.6 测试方法

### 6.6.1 单元测试

#### 测试框架

```bash
#!/bin/bash
# test-runner.sh

# 测试计数器
TESTS_PASSED=0
TESTS_FAILED=0

# 断言函数
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    if [ "$expected" = "$actual" ]; then
        log_info "✓ PASS: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "✗ FAIL: $test_name"
        log_error "  期望：$expected"
        log_error "  实际：$actual"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local test_name="$2"

    if [ -f "$file" ]; then
        log_info "✓ PASS: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "✗ FAIL: $test_name"
        log_error "  文件不存在：$file"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    if [ "$expected" -eq "$actual" ]; then
        log_info "✓ PASS: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "✗ FAIL: $test_name"
        log_error "  期望退出码：$expected"
        log_error "  实际退出码：$actual"
        ((TESTS_FAILED++))
        return 1
    fi
}

# 测试报告
print_report() {
    echo ""
    echo "================================"
    echo "测试报告"
    echo "================================"
    echo "通过：$TESTS_PASSED"
    echo "失败：$TESTS_FAILED"
    echo "总计：$((TESTS_PASSED + TESTS_FAILED))"
    echo "================================"

    if [ $TESTS_FAILED -gt 0 ]; then
        return 1
    fi
    return 0
}

# 运行测试
run_tests() {
    log_info "运行测试..."
    echo ""

    # 调用各个测试函数
    test_json_get
    test_json_get_num
    test_validate_config
    # ...

    print_report
}
```

#### 测试示例

```bash
# 测试 json_get
test_json_get() {
    log_info "测试 json_get..."

    local test_file
    test_file=$(mktemp)

    # 测试用例 1：基本字符串
    echo '{"host": "example.com"}' > "$test_file"
    local result
    result=$(json_get "$test_file" "host")
    assert_equals "example.com" "$result" "json_get 基本字符串"

    # 测试用例 2：带默认值
    result=$(json_get "$test_file" "missing" "default_value")
    assert_equals "default_value" "$result" "json_get 默认值"

    # 测试用例 3：空值
    echo '{"key": ""}' > "$test_file"
    result=$(json_get "$test_file" "key" "fallback")
    assert_equals "fallback" "$result" "json_get 空值使用默认"

    rm -f "$test_file"
}

# 测试 json_get_num
test_json_get_num() {
    log_info "测试 json_get_num..."

    local test_file
    test_file=$(mktemp)

    echo '{"port": 22, "timeout": 30}' > "$test_file"

    local result
    result=$(json_get_num "$test_file" "port")
    assert_equals "22" "$result" "json_get_num 基本数字"

    result=$(json_get_num "$test_file" "missing" "80")
    assert_equals "80" "$result" "json_get_num 默认值"

    rm -f "$test_file"
}

# 运行所有测试
run_tests
```

### 6.6.2 集成测试

#### 完整工作流测试

```bash
#!/bin/bash
# test-integration.sh

set -euo pipefail

# 测试目录
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

cd "$TEST_DIR"

log_info "测试目录：$TEST_DIR"

# 初始化测试
test_init() {
    log_step "测试配置初始化..."

    # 运行初始化脚本
    bash "$PROJECT_ROOT/scripts/sftp-init.sh" \
        --host "test.example.com" \
        --port 2222 \
        --username "testuser" \
        --remote-path "/tmp/test"

    # 验证配置文件
    assert_file_exists ".claude/sftp-cc/sftp-config.json" "配置文件创建"

    # 验证配置内容
    local host
    host=$(grep '"host"' .claude/sftp-cc/sftp-config.json | sed 's/.*: *"\([^"]*\)".*/\1/')
    assert_equals "test.example.com" "$host" "配置 host 正确"
}

# 私钥绑定测试
test_keybind() {
    log_step "测试私钥绑定..."

    # 创建测试私钥
    mkdir -p .claude/sftp-cc
    ssh-keygen -t ed25519 -f .claude/sftp-cc/test_key -N "" -q

    # 运行绑定脚本
    bash "$PROJECT_ROOT/scripts/sftp-keybind.sh"

    # 验证权限
    local perms
    perms=$(stat -c "%a" .claude/sftp-cc/test_key)
    assert_equals "600" "$perms" "私钥权限正确"

    # 验证配置
    local key_path
    key_path=$(grep '"private_key"' .claude/sftp-cc/sftp-config.json | sed 's/.*: *"\([^"]*\)".*/\1/')
    assert_equals "$PWD/.claude/sftp-cc/test_key" "$key_path" "私钥路径已配置"
}

# 运行集成测试
log_info "开始集成测试..."
test_init
test_keybind
log_info "集成测试完成"
```

### 6.6.3 Dry-run 模式

#### 预览模式实现

```bash
# 预览模式参数
DRY_RUN=false

# 参数解析
case $1 in
    -n|--dry-run)
        DRY_RUN=true
        shift
        ;;
esac

# 执行函数（支持预览）
execute_upload() {
    local files=("$@")

    if $DRY_RUN; then
        log_info "[预览模式] 将执行以下操作:"
        echo ""

        for f in "${files[@]}"; do
            echo "  PUT $f -> $REMOTE_PATH/$f"
        done

        echo ""
        log_info "[预览模式] 共 ${#files[@]} 个文件"
        return 0
    fi

    # 实际执行上传
    # ...
}

# 使用示例
# $ bash sftp-push.sh -n
# [INFO] [预览模式] 将执行以下操作:
#
#   PUT src/main.php -> /var/www/src/main.php
#   PUT config/app.json -> /var/www/config/app.json
#
# [INFO] [预览模式] 共 2 个文件
```

---

## 6.7 调试实战案例

### 6.7.1 案例 1：JSON 解析失败

#### 问题现象

```bash
$ bash sftp-push.sh
[push] 目标服务器：@:
[push] 检查私钥绑定...
[push] 配置不完整，缺少：host username remote_path
```

#### 排查步骤

```bash
# 步骤 1：检查配置文件内容
$ cat .claude/sftp-cc/sftp-config.json
{
  "host": "example.com",
  "port": 22,
  "username": "deploy"
}
# 内容看起来正常

# 步骤 2：手动测试 grep
$ grep '"host"' .claude/sftp-cc/sftp-config.json
  "host": "example.com",
# grep 正常

# 步骤 3：测试 sed
$ grep '"host"' .claude/sftp-cc/sftp-config.json | sed 's/.*: *"\([^"]*\)".*/\1/'
example.com
# sed 也正常

# 步骤 4：在函数中添加调试输出
json_get() {
    local file="$1" key="$2" default="${3:-}"
    echo "[DEBUG] file=$file key=$key" >&2
    local val
    val=$(grep "\"$key\"" "$file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    echo "[DEBUG] result=$val" >&2
    # ...
}

# 再次运行
$ bash sftp-push.sh
[DEBUG] file=.claude/sftp-cc/sftp-config.json key=host
[DEBUG] result=
```

#### 问题原因

配置文件有 BOM 头（Byte Order Mark）：

```bash
# 检查文件编码
$ file .claude/sftp-cc/sftp-config.json
.sftp-config.json: UTF-8 Unicode (with BOM) text

# 查看文件开头
$ head -c 10 .claude/sftp-cc/sftp-config.json | xxd
00000000: efbb bf7b 0a20 2022 686f                 ...{.  "ho
# efbb bf 是 UTF-8 BOM
```

#### 解决方案

```bash
# 方法 1：修复 json_get，处理 BOM
json_get() {
    local file="$1" key="$2" default="${3:-}"
    # 使用 sed 去除 BOM
    local content
    content=$(sed '1s/^\xef\xbb\xbf//' "$file")
    local val
    val=$(echo "$content" | grep "\"$key\"" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    # ...
}

# 方法 2：修复配置文件
$ sed -i '1s/^\xef\xbb\xbf//' .claude/sftp-cc/sftp-config.json
```

### 6.7.2 案例 2：SFTP 连接失败

#### 问题现象

```bash
$ bash sftp-push.sh
[push] 目标服务器：deploy@example.com:/var/www
[push] 检查私钥绑定...
[push] 私钥已绑定：/path/to/key
[push] 确保远程目录存在...
[ERROR] 上传失败 (exit code: 1)
```

#### 排查步骤

```bash
# 步骤 1：手动测试 SFTP 连接
$ sftp -v -P 22 -i /path/to/key deploy@example.com
OpenSSH_8.9p1, OpenSSL 1.1.1n
debug1: Connecting to example.com port 22.
debug1: Connection established.
debug1: Authenticating as deploy...
debug1: Will attempt key: /path/to/key
debug1: Offering public key: /path/to/key
debug1: Server accepted key
debug1: Authentication succeeded.

# 手动连接成功，问题可能在脚本参数

# 步骤 2：检查脚本中的 SFTP 选项
$ bash -x sftp-push.sh 2>&1 | grep sftp
+ sftp -P 22 -i /path/to/key -o StrictHostKeyChecking=no deploy@example.com

# 步骤 3：测试完整命令
$ sftp -P 22 -i /path/to/key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null deploy@example.com <<EOF
cd /var/www
put test.txt
EOF

# 发现问题：UserKnownHostsFile 导致 known_hosts 检查问题

# 步骤 4：修正 SFTP 选项
SFTP_OPTS="-P $PORT -i $PRIVATE_KEY"
SFTP_OPTS="$SFTP_OPTS -o StrictHostKeyChecking=no"
# 移除 UserKnownHostsFile=/dev/null
```

### 6.7.3 案例 3：增量检测异常

#### 问题现象

```bash
$ bash sftp-push.sh
[push] 检测文件变更...
[push] 没有检测到文件变更，无需上传

# 但明明修改了文件，为什么没检测到？
```

#### 排查步骤

```bash
# 步骤 1：检查 .last-push 文件
$ cat .claude/sftp-cc/.last-push
abc123def456
1704067200

# 步骤 2：检查 git 状态
$ git status
On branch main
Your branch is up to date with 'origin/main'.

Changes not staged for commit:
  modified:   src/main.php

# 步骤 3：手动测试 git diff
$ git diff --name-only HEAD
src/main.php

# 步骤 4：检查脚本中的 git 命令
$ bash -x sftp-push.sh 2>&1 | grep "git diff"
+ git -C /path/to/project diff --name-only --diff-filter=ACMR abc123def456 HEAD

# 步骤 5：检查 last_hash 是否有效
$ git cat-file -t abc123def456
commit

# 步骤 6：在 collect_changed_files 中添加详细调试
collect_changed_files() {
    debug "=== 开始收集变更文件 ==="
    debug "LAST_PUSH_FILE: $LAST_PUSH_FILE"

    if [ ! -f "$LAST_PUSH_FILE" ]; then
        debug "文件不存在，返回空"
        echo ""
        return
    fi

    local last_hash
    last_hash=$(head -1 "$LAST_PUSH_FILE")
    debug "last_hash: $last_hash"

    # 检查 commit 是否有效
    if ! git cat-file -t "$last_hash" &>/dev/null; then
        debug "commit 无效，触发全量"
        echo ""
        return
    fi

    # 收集各类变更
    debug "--- 已提交变更 ---"
    git diff --name-only "$last_hash" HEAD

    debug "--- 暂存区变更 ---"
    git diff --cached --name-only

    debug "--- 工作区修改 ---"
    git diff --name-only
}
```

#### 问题原因和解决

```bash
# 原因：只检查了已提交的变更，没有检查工作区修改

# 修复：确保所有变更来源都被检查
collect_changed_files() {
    local changed_list
    changed_list=$(mktemp)

    # 1. 已提交的变更
    git diff --name-only --diff-filter=ACMR "$last_hash" HEAD >> "$changed_list"

    # 2. 暂存区变更
    git diff --cached --name-only --diff-filter=ACMR >> "$changed_list"

    # 3. 工作区修改（未暂存）
    git diff --name-only --diff-filter=ACMR >> "$changed_list"

    # 4. 未跟踪文件
    git ls-files --others --exclude-standard >> "$changed_list"

    # 去重
    sort -u "$changed_list" -o "$changed_list"

    cat "$changed_list"
}
```

---

## 6.8 验证工具

### 6.8.1 Plugin 验证

```bash
# 验证 Plugin 结构
$ claude plugin validate .

Validating plugin at /path/to/sftp-cc...
✓ marketplace.json is valid
✓ skills/sftp-cc/SKILL.md is valid
✓ All scripts are executable

Plugin validation passed!
```

### 6.8.2 Shellcheck 静态分析

```bash
# 安装 shellcheck
# macOS
brew install shellcheck

# Ubuntu/Debian
apt-get install shellcheck

# 运行检查
$ shellcheck scripts/*.sh

In scripts/sftp-push.sh line 42:
    HOST=$(grep '"host"' "$CONFIG" | sed 's/.*: *"\([^"]*\)".*/\1/')
          ^-- SC2002 (style): Useless cat. Consider 'cmd < file | ..' or '.. < file | cmd' instead.

In scripts/sftp-keybind.sh line 67:
    PERMS=$(stat -f "%Lp" "$CURRENT_KEY" 2>/dev/null || stat -c "%a" "$CURRENT_KEY" 2>/dev/null)
                                                                                ^-- SC2086 (info): Double quote to prevent globbing.

# 修复建议：
# SC2002: 避免不必要的 cat
# SC2086: 使用双引号包裹变量
```

### 6.8.3 自动化测试脚本

```bash
#!/bin/bash
# run-tests.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

log_info "运行 sftp-cc 测试套件..."
echo ""

# 1. 语法检查
log_step "Shell 语法检查..."
for script in "$PROJECT_ROOT"/scripts/*.sh; do
    if ! bash -n "$script" 2>/dev/null; then
        log_error "语法错误：$script"
        exit 1
    fi
done
log_info "✓ 所有脚本语法正确"

# 2. Shellcheck 检查
if command -v shellcheck &>/dev/null; then
    log_step "Shellcheck 静态分析..."
    if ! shellcheck "$PROJECT_ROOT"/scripts/*.sh; then
        log_warn "Shellcheck 发现一些问题（非致命）"
    fi
fi

# 3. 单元测试
log_step "运行单元测试..."
bash "$PROJECT_ROOT/tests/test-unit.sh"

# 4. 集成测试
log_step "运行集成测试..."
bash "$PROJECT_ROOT/tests/test-integration.sh"

# 5. Plugin 验证
if command -v claude &>/dev/null; then
    log_step "验证 Plugin 结构..."
    claude plugin validate "$PROJECT_ROOT"
fi

echo ""
log_info "所有测试完成！"
```

---

## 6.9 性能分析

### 6.9.1 执行时间测量

```bash
# 测量函数执行时间
time_function() {
    local func_name="$1"
    shift

    local start_time
    start_time=$(date +%s.%N)

    "$func_name" "$@"

    local end_time
    end_time=$(date +%s.%N)

    local elapsed
    elapsed=$(echo "$end_time - $start_time" | bc)

    log_debug "$func_name 执行时间：${elapsed}s"
}

# 使用
time_function upload_files "${files[@]}"
```

### 6.9.2 性能瓶颈定位

```bash
# 使用 bash 内置的 -x 选项配合时间戳
export PS4='+ $(date +%s.%N) ${BASH_SOURCE}:${LINENO}: '
bash -x script.sh 2>&1 | sort -t' ' -k2 -n | tail -20

# 输出最慢的 20 个命令
```

---

## 6.10 本章总结

### 核心知识点回顾

| 概念 | 关键点 |
|------|--------|
| set 选项 | -e（错误退出）、-u（未定义变量）、-o pipefail（管道失败）、-x（调试） |
| 日志级别 | ERROR/WARN/INFO/DEBUG 四级，支持动态调整 |
| verbose 模式 | -v/--verbose 参数，控制详细输出 |
| 临时文件 | mktemp 创建，trap 清理 |
| 错误处理 | 参数验证、依赖检查、重试机制、回退机制 |
| 测试方法 | 单元测试、集成测试、dry-run 预览 |
| 调试工具 | shellcheck、bash -x、日志输出 |

### 脚本检查清单

在发布前确认：

- [ ] 使用 set -euo pipefail 严格模式
- [ ] 日志函数完整（info/warn/error/debug）
- [ ] 支持 -v/--verbose 详细输出
- [ ] 临时文件正确清理
- [ ] 参数验证完善
- [ ] 命令依赖检查
- [ ] 错误消息清晰有帮助
- [ ] 通过 shellcheck 检查
- [ ] 单元测试覆盖核心功能

---

## 6.11 练习与实践

### 基础练习

**练习 6-1**：添加调试模式
- 为你的脚本添加 --debug 参数
- 启用 set -x 详细输出

**练习 6-2**：实现日志级别
- 添加 LOG_LEVEL 环境变量支持
- 实现 ERROR/WARN/INFO/DEBUG 四级日志

### 进阶练习

**练习 6-3**：编写单元测试
- 为 json_get 等工具函数编写测试
- 使用 assert_equals 等断言函数

**练习 6-4**：实现重试机制
- 为 SFTP 上传添加重试逻辑
- 支持配置重试次数和间隔

### 实践项目

为你的 Skill 添加完整的测试套件：
1. 创建 tests/ 目录
2. 编写 test-unit.sh（单元测试）
3. 编写 test-integration.sh（集成测试）
4. 添加 run-tests.sh（测试入口）
5. 确保所有测试通过

---

## 下一章预告

第 7 章将介绍**发布与分发流程**：
- Plugin Marketplace 架构
- marketplace.json 详解
- 版本管理（SemVer 语义化版本）
- GitHub HTTP API 发布
- 完整的发布脚本
- 多语言 README 编写
- 持续集成（GitHub Actions）

---

## 关于本书

**第一版（数字版）, 2026 年 3 月**

**作者**：[toohamster](https://github.com/toohamster)
**授权**：电子版 MIT License，纸质版/商业版 © All Rights Reserved
**源码**：[github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

详细说明请参阅 [LICENSE](../../LICENSE) 和 [关于作者](../authors.md)

---
