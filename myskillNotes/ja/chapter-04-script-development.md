# 第 4 章：スクリプト開発

> 「どんな複雑な問題も、理解できるほど単純なステップに分解できる」 — 任意のプログラマー

この章では、次のことを学びます：
- 標準スクリプト構造テンプレート
- ピュア Shell JSON パース（jq なし）
- エラーハンドリングパターン
- Git 統合（プロジェクトルート特定）
- 一時ファイル管理（mktemp + trap）
- SFTP バッチモードアップロード
- ロギングとデバッグ

---

## 4.1 スクリプト構造テンプレート

### 4.1.1 標準構造

すべての sftp-cc スクリプトは共通の構造に従います：

```bash
#!/bin/bash
# スクリプト名：sftp-push.sh
# 説明：ファイル SFTP アップロード
# 使用方法：./sftp-push.sh [オプション] [ファイル...]

set -euo pipefail

#######################################
# 定数
#######################################
readonly VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

#######################################
# グローバル変数
#######################################
VERBOSE=false
DRY_RUN=false
CONFIG_FILE=""

#######################################
# 色の定義
#######################################
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'  # 色なし

#######################################
# ロギング関数
#######################################
info()  { echo -e "${GREEN}[$SCRIPT_NAME]${NC} $*" >&2; }
warn()  { echo -e "${YELLOW}[$SCRIPT_NAME] 警告:${NC} $*" >&2; }
error() { echo -e "${RED}[$SCRIPT_NAME] エラー:${NC} $*" >&2; }
debug() {
    if $VERBOSE; then
        echo -e "${BLUE}[$SCRIPT_NAME] デバッグ:${NC} $*" >&2
    fi
}

#######################################
# 使用法情報
#######################################
usage() {
    cat <<EOF
使用方法：$SCRIPT_NAME [オプション] [ファイル...]

オプション：
  -v, --verbose      詳細出力を有効化
  -n, --dry-run      プレビューモード（実行しない）
  -h, --help         このヘルプを表示
  --version          バージョンを表示
  --full             全量アップロード
  -d, --directory    ディレクトリをアップロード

例：
  $SCRIPT_NAME                      # 変更ファイルをアップロード
  $SCRIPT_NAME --dry-run            # プレビュー
  $SCRIPT_NAME file1.php file2.php  # 指定ファイル
  $SCRIPT_NAME -d src/              # ディレクトリ
EOF
}

#######################################
# 引数解析
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
            --full)
                FULL_UPLOAD=true
                shift
                ;;
            -d|--directory)
                UPLOAD_DIR="$2"
                shift 2
                ;;
            -*)
                error "不明なオプション：$1"
                usage
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done
}

#######################################
# 設定初期化
#######################################
init_config() {
    local config_dir="$PROJECT_ROOT/.claude/sftp-cc"
    CONFIG_FILE="$config_dir/sftp-config.json"

    if [ ! -f "$CONFIG_FILE" ]; then
        error "設定ファイルが見つかりません：$CONFIG_FILE"
        error "最初に初期化を実行："
        error "  bash scripts/sftp-init.sh"
        exit 1
    fi
}

#######################################
# メインエントリーポイント
#######################################
main() {
    parse_args "$@"
    info "開始..."
    init_config

    # あなたのメインロジックをここに

    info "完了！"
}

# すべての引数と共に main を実行
main "$@"
```

### 4.1.2 各セクションの説明

| セクション | 目的 | 必須か |
|-----------|------|--------|
| シェバング (`#!/bin/bash`) | スクリプトインタプリタ | **必須** |
| `set -euo pipefail` | 厳格なエラーハンドリング | 推奨 |
| 定数 | 変更しない値 | 推奨 |
| グローバル変数 | スクリプト全体で使用 | オプション |
| 色の定義 | カラー出力 | 推奨 |
| ロギング関数 | 一貫した出力 | 推奨 |
| 使用法情報 | ヘルプ表示 | 推奨 |
| 引数解析 | コマンドライン処理 | オプション |
| 設定初期化 | 設定読み込み | 状況による |
| メイン関数 | エントリーポイント | **必須** |

### 4.1.3 なぜこの構造か

**利点**：
1. **一貫性**: すべてのスクリプトが同じパターンに従う
2. **保守性**: 他の開発者が理解しやすい
3. **デバッグ容易**: 標準的なエラーハンドリング
4. **再利用性**: 関数を他のスクリプトで共有可能

---

## 4.2 ピュア Shell JSON パース

### 4.2.1 jq を使わない理由

sftp-cc は外部依存を避けるため、jq を使用しません：

| 項目 | jq 使用 | ピュア Shell |
|------|---------|-------------|
| 外部依存 | 必要（インストール） | なし（システム標準） |
| 互換性 | jq が無い場合あり | 全システムで動作 |
| 学習曲線 | jq 構文を学習 | 基本的な Shell のみ |
| パフォーマンス | 速い | 十分速い（シンプル JSON） |

### 4.2.2 JSON パース関数

#### 文字列値の取得

```bash
#######################################
# JSON ファイルから文字列値を取得
# 引数：
#   $1 - JSON ファイルパス
#   $2 - キー名
#   $3 - デフォルト値（オプション）
# 出力：
#   値またはデフォルト
#######################################
json_get() {
    local file="$1"
    local key="$2"
    local default="${3:-}"
    local val

    # キーを検索して値を抽出
    val=$(grep "\"$key\"" "$file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

    # 空ならデフォルトを返す
    echo "${val:-$default}"
}
```

**使用例**：
```bash
CONFIG_FILE="sftp-config.json"

HOST=$(json_get "$CONFIG_FILE" "host")
USERNAME=$(json_get "$CONFIG_FILE" "username")
REMOTE_PATH=$(json_get "$CONFIG_FILE" "remote_path" "/var/www")

echo "Host: $HOST"
echo "User: $USERNAME"
echo "Path: $REMOTE_PATH"
```

#### 数値の取得

```bash
#######################################
# JSON ファイルから数値を取得
# 引数：
#   $1 - JSON ファイルパス
#   $2 - キー名
#   $3 - デフォルト値（オプション）
#######################################
json_get_num() {
    local file="$1"
    local key="$2"
    local default="${3:-0}"
    local val

    val=$(grep "\"$key\"" "$file" 2>/dev/null | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
    echo "${val:-$default}"
}
```

**使用例**：
```bash
PORT=$(json_get_num "$CONFIG_FILE" "port" "22")
echo "Port: $PORT"  # Port: 22
```

### 4.2.3 配列の取得

```bash
#######################################
# JSON 配列を取得（シンプル実装）
# 引数：
#   $1 - JSON ファイルパス
#   $2 - キー名
# 出力：
#   配列要素（1 行ずつ）
#######################################
json_get_array() {
    local file="$1"
    local key="$2"

    # 配列セクションを抽出
    sed -n "/\"$key\"/,/\]/p" "$file" | \
        grep -o '"[^"]*"' | \
        sed 's/"//g' | \
        grep -v "$key"
}
```

**使用例**：
```bash
# 除外リストを取得
excludes=()
while IFS= read -r item; do
    excludes+=("$item")
done < <(json_get_array "$CONFIG_FILE" "excludes")

echo "除外アイテム："
for item in "${excludes[@]}"; do
    echo "  - $item"
done
```

### 4.2.4 実装：設定ロード関数

```bash
#######################################
# SFTP 設定をロード
#######################################
load_sftp_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        error "設定ファイルが見つかりません：$CONFIG_FILE"
        exit 1
    fi

    # 必須フィールド
    HOST=$(json_get "$CONFIG_FILE" "host")
    USERNAME=$(json_get "$CONFIG_FILE" "username")
    REMOTE_PATH=$(json_get "$CONFIG_FILE" "remote_path")

    # 必須フィールドの検証
    local missing=()
    [ -z "$HOST" ] && missing+=("host")
    [ -z "$USERNAME" ] && missing+=("username")
    [ -z "$REMOTE_PATH" ] && missing+=("remote_path")

    if [ ${#missing[@]} -gt 0 ]; then
        error "設定が不完全です：${missing[*]}"
        error "実行して初期化：bash scripts/sftp-init.sh"
        exit 1
    fi

    # オプションフィールド
    PORT=$(json_get_num "$CONFIG_FILE" "port" "22")
    LANGUAGE=$(json_get "$CONFIG_FILE" "language" "en")
    PRIVATE_KEY=$(json_get "$CONFIG_FILE" "private_key")

    info "設定をロード：$HOST:$PORT"
}
```

---

## 4.3 エラーハンドリング

### 4.3.1 パラメータ検証

必須設定を検証：

```bash
#######################################
# 必須パラメータを検証
#######################################
validate_params() {
    local missing=()

    [ -z "${HOST:-}" ] && missing+=("host")
    [ -z "${PORT:-}" ] && missing+=("port")
    [ -z "${USERNAME:-}" ] && missing+=("username")
    [ -z "${REMOTE_PATH:-}" ] && missing+=("remote_path")

    if [ ${#missing[@]} -gt 0 ]; then
        error "必須パラメータが不足：${missing[*]}"
        error "設定を確認：$CONFIG_FILE"
        exit 1
    fi

    debug "パラメータ検証：OK"
}
```

### 4.3.2 コマンド存在チェック

必要なコマンドが利用可能か確認：

```bash
#######################################
# 必要なコマンドをチェック
#######################################
check_dependencies() {
    local deps=("sftp" "git" "grep" "sed" "mktemp")
    local missing=()

    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        error "必要なコマンドが見つかりません：${missing[*]}"
        exit 1
    fi

    debug "依存関係チェック：OK"
}
```

### 4.3.3 ファイル存在チェック

重要なファイルの存在を検証：

```bash
#######################################
# 重要なファイルをチェック
#######################################
check_files() {
    # 設定ファイル
    if [ ! -f "$CONFIG_FILE" ]; then
        error "設定ファイルが見つかりません：$CONFIG_FILE"
        error "実行：bash scripts/sftp-init.sh"
        exit 1
    fi

    # 秘密鍵
    if [ -n "$PRIVATE_KEY" ] && [ ! -f "$PRIVATE_KEY" ]; then
        error "秘密鍵が見つかりません：$PRIVATE_KEY"
        error ".claude/sftp-cc/ ディレクトリに鍵を配置"
        exit 1
    fi

    # 秘密鍵の読み取り権限
    if [ -n "$PRIVATE_KEY" ] && [ ! -r "$PRIVATE_KEY" ]; then
        error "秘密鍵を読み取れません：$PRIVATE_KEY"
        error "権限を確認：chmod 600 $PRIVATE_KEY"
        exit 1
    fi

    debug "ファイルチェック：OK"
}
```

### 4.3.4 包括的エラーハンドリング

```bash
#######################################
# 包括的エラーハンドリング
#######################################
error_handler() {
    local line_no=$1
    local func=$2
    local cmd=$3

    error "スクリプトエラー！"
    error "  行：$line_no"
    error "  関数：${func:-main}"
    error "  コマンド：$cmd"
    error ""
    error "デバッグ：bash -x $SCRIPT_NAME"
}

# エラーハンドラを登録
trap 'error_handler ${LINENO} "${FUNCNAME[0]:-main}" "$BASH_COMMAND"' ERR
```

---

## 4.4 プロジェクトルートの特定

### 4.4.1 git を使用

```bash
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
```

**なぜこれを使用するか**：
1. **サブディレクトリからの実行**: `src/` ディレクトリからでも正しいルートを特定
2. **Git プロジェクト**: 正確なルートディレクトリを取得
3. **非 Git プロジェクト**: 現在ディレクトリにフォールバック

### 4.4.2 使用例

```bash
# スクリプトがどこから実行されても正しいパスを取得
cd project/src/subdir
bash scripts/sftp-push.sh

# 内部：
PROJECT_ROOT="/path/to/project"  # 正しいルート
CONFIG_FILE="$PROJECT_ROOT/.claude/sftp-cc/sftp-config.json"
```

### 4.4.3 代替：非 Git 環境

```bash
# git が利用できない場合
if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null; then
    PROJECT_ROOT="$(git rev-parse --show-toplevel)"
else
    PROJECT_ROOT="$(pwd)"
fi
```

---

## 4.5 一時ファイル管理

### 4.5.1 mktemp の使用

安全な一時ファイルを作成：

```bash
# 一時ファイルを作成
tmp_file=$(mktemp)              # /tmp/tmp.XXXXXXXXXX
batch_file=$(mktemp)            # /tmp/tmp.YYYYYYYYYY

# 一時ディレクトリを作成
tmp_dir=$(mktemp -d)            # /tmp/tmp.ZZZZZZZZZZ/
```

**なぜ安全か**：
- 予測不可能な名前（ランダム）
- 競合状態条件を回避
- 適切な権限（600）

### 4.5.2 trap によるクリーンアップ

```bash
#######################################
# グローバル変数
#######################################
TMP_FILES=()

#######################################
# クリーンアップ関数
#######################################
cleanup() {
    info "一時ファイルをクリーンアップ..."
    for f in "${TMP_FILES[@]:-}"; do
        [ -n "$f" ] && [ -f "$f" ] && rm -f "$f"
    done
}

# 終了時にクリーンアップを登録
trap cleanup EXIT

# 使用
tmp_file=$(mktemp)
TMP_FILES+=("$tmp_file")

batch_file=$(mktemp)
TMP_FILES+=("$batch_file")

# スクリプト終了時、自動的にクリーンアップ
```

### 4.5.3 実例：SFTP バッチファイル

```bash
#######################################
# SFTP バッチファイルを構築
# 引数：
#   $1 - アップロードファイルリスト
#   $2 - リモートパス
# 戻り値：
#   バッチファイルパス
#######################################
build_batch_file() {
    local files_list="$1"
    local remote_path="$2"

    local batch_file
    batch_file=$(mktemp)
    TMP_FILES+=("$batch_file")

    # バッチコマンドを書き込み
    cat > "$batch_file" <<EOF
lcd $PROJECT_ROOT
cd $remote_path
EOF

    # put コマンドを追加
    while IFS= read -r file; do
        echo "put -r $file" >> "$batch_file"
    done < "$files_list"

    echo "$batch_file"
}
```

---

## 4.6 SFTP アップロード実装

### 4.6.1 変更ファイルの検出

```bash
#######################################
# 変更ファイルを検出
# 出力：
#   ファイルパス（1 行ずつ）
#######################################
detect_changes() {
    # 完全アップロード
    if $FULL_UPLOAD; then
        find . -type f \
            ! -path './.git/*' \
            ! -path './.claude/*' \
            ! -path './node_modules/*' \
            -print
        return
    fi

    # 増分アップロード：コミット済み変更
    git diff --name-only --diff-filter=ACMR HEAD 2>/dev/null

    # ステージング済み変更
    git diff --cached --name-only --diff-filter=ACMR 2>/dev/null

    # ワークキング変更
    git diff --name-only --diff-filter=ACMR 2>/dev/null

    # 未トラックファイル
    git ls-files --others --exclude-standard 2>/dev/null
}
```

### 4.6.2 SFTP 接続文字列

```bash
build_sftp_target() {
    local target=""

    # オプション：バッチモード
    target="-b"

    # オプション：詳細出力
    if $VERBOSE; then
        target="$target -v"
    fi

    # オプション：秘密鍵
    if [ -n "$PRIVATE_KEY" ]; then
        target="$target -i $PRIVATE_KEY"
    fi

    # ユーザー@ホスト
    target="$target $USERNAME@$HOST"

    echo "$target"
}
```

### 4.6.3 アップロード実行

```bash
#######################################
# ファイルをアップロード
# 引数：
#   $1 - バッチファイル
#######################################
upload_files() {
    local batch_file="$1"
    local sftp_target
    sftp_target=$(build_sftp_target)

    info "SFTP 接続：$USERNAME@$HOST"
    debug "バッチファイル：$batch_file"

    if $DRY_RUN; then
        info "[プレビュー] SFTP コマンド："
        cat "$batch_file"
        return 0
    fi

    # SFTP 実行
    if sftp $sftp_target < "$batch_file"; then
        info "アップロード成功！"
    else
        error "SFTP 失敗"
        exit 1
    fi
}
```

---

## 4.7 完全なスクリプト例

### 4.7.1 sftp-push.sh 完全版

```bash
#!/bin/bash
# sftp-push.sh - SFTP ファイルアップロード
# 使用方法：./sftp-push.sh [オプション] [ファイル...]

set -euo pipefail

readonly VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

VERBOSE=false
DRY_RUN=false
FULL_UPLOAD=false
UPLOAD_DIR=""
CONFIG_FILE=""
TMP_FILES=()

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

info()  { echo -e "${GREEN}[$SCRIPT_NAME]${NC} $*" >&2; }
warn()  { echo -e "${YELLOW}[$SCRIPT_NAME] 警告:${NC} $*" >&2; }
error() { echo -e "${RED}[$SCRIPT_NAME] エラー:${NC} $*" >&2; }
debug() { $VERBOSE && echo -e "${YELLOW}[$SCRIPT_NAME] デバッグ:${NC} $*" >&2; }

cleanup() {
    for f in "${TMP_FILES[@]:-}"; do
        [ -n "$f" ] && [ -f "$f" ] && rm -f "$f"
    done
}
trap cleanup EXIT

json_get() {
    local file="$1" key="$2" default="${3:-}"
    local val
    val=$(grep "\"$key\"" "$file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    echo "${val:-$default}"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose) VERBOSE=true; shift ;;
            -n|--dry-run) DRY_RUN=true; shift ;;
            --full) FULL_UPLOAD=true; shift ;;
            -d|--directory) UPLOAD_DIR="$2"; shift 2 ;;
            -h|--help) echo "使用方法：$SCRIPT_NAME [オプション] [ファイル...]"; exit 0 ;;
            *) break ;;
        esac
    done
}

load_config() {
    CONFIG_FILE="$PROJECT_ROOT/.claude/sftp-cc/sftp-config.json"
    [ ! -f "$CONFIG_FILE" ] && { error "設定が見つかりません"; exit 1; }

    HOST=$(json_get "$CONFIG_FILE" "host")
    PORT=$(json_get_num "$CONFIG_FILE" "port" "22")
    USERNAME=$(json_get "$CONFIG_FILE" "username")
    REMOTE_PATH=$(json_get "$CONFIG_FILE" "remote_path")
    PRIVATE_KEY=$(json_get "$CONFIG_FILE" "private_key")
}

main() {
    parse_args "$@"
    load_config

    local files_list
    files_list=$(mktemp)
    TMP_FILES+=("$files_list")

    if [ -n "$UPLOAD_DIR" ]; then
        find "$UPLOAD_DIR" -type f > "$files_list"
    elif [[ $# -gt 0 ]]; then
        printf '%s\n' "$@" > "$files_list"
    else
        detect_changes > "$files_list"
    fi

    local count
    count=$(wc -l < "$files_list")

    if [ "$count" -eq 0 ]; then
        info "アップロード対象ファイルなし"
        exit 0
    fi

    info "$count ファイルをアップロード"

    local batch_file
    batch_file=$(mktemp)
    TMP_FILES+=("$batch_file")

    cat > "$batch_file" <<EOF
lcd $PROJECT_ROOT
cd $REMOTE_PATH
EOF

    while IFS= read -r file; do
        echo "put -r $file" >> "$batch_file"
    done < "$files_list"

    sftp -b "$batch_file" -P "$PORT" -i "$PRIVATE_KEY" "$USERNAME@$HOST"

    info "完了！"
}

main "$@"
```

---

## 本章のまとめ

### 重要な概念

| 概念 | 説明 |
|---------|-------------|
| **標準構造** | 一貫したスクリプト構造、保守容易 |
| **ピュア Shell JSON** | jq なし、grep/sed でパース |
| **エラーハンドリング** | 検証、チェック、trap |
| **プロジェクトルート** | `git rev-parse` で正確なパス |
| **一時ファイル** | `mktemp` + `trap` で安全に管理 |
| **SFTP バッチ** | バッチファイルで効率的アップロード |

---

## 練習問題

### 練習問題 4-1: スクリプト構造

標準構造に従ってスクリプトを作成：
1. シェバングと `set -euo pipefail`
2. 定数とグローバル変数
3. 色の定義
4. ロギング関数
5. メイン関数

### 練習問題 4-2: JSON パース

設定ファイルから値を読み取る：
1. `json_get` 関数を実装
2. `json_get_num` 関数を実装
3. 設定値を検証

### 練習問題 4-3: エラーハンドリング

包括的エラーハンドリングを追加：
1. パラメータ検証
2. コマンドチェック
3. ファイルチェック
4. `trap` エラーハンドラ

---

## 拡張リソース

### Shell スクリプティング
- [Advanced Bash-Scripting Guide](https://tldp.org/LDP/abs/html/)
- [ShellCheck](https://www.shellcheck.net/) - 静的解析

### 副読本
- 「Classic Shell Scripting」- O'Reilly
- 「Bash Cookbook」- O'Reilly

---

## 次章のプレビュー

**第 5 章：国際化 (i18n)**

第 5 章では多言語サポートを実装：
- 変数式多言語ソリューション
- i18n.sh 実装
- 言語検出と切り替え
- メッセージ定義

---

## 本書について

**初版（デジタル版）, 2026 年 3 月**

**著者**: [toohamster](https://github.com/toohamster)
**ライセンス**: 電子版：MIT License | 印刷版/商業版：All Rights Reserved
**ソース**: [github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

詳細は [LICENSE](../../LICENSE) と [著者について](../authors.md) をご覧ください。

---
