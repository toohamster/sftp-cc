# 第 8 章：トピックとベストプラクティス

> 「完璧とは、もう加えるものがなくなったときではなく、もう取るものがなくなったときに達せられる」 — サン＝テグジュペリ

この章では、次のことを学びます：
- Shell スクリプトのパフォーマンス最適化
- セキュリティベストプラクティス（コマンドインジェクションを回避）
- コード組織と命名規則
- `trap` を使用した高度なエラーハンドリング
- よくある問題のトラブルシューティング
- sftp-cc 開発からの実世界ケーススタディ
- パフォーマンスプロファイリングとベンチマーク
- Skill の維持と反復

---

## 8.1 パフォーマンス最適化

### 8.1.1 サブプロセス呼び出しを削減

すべてのサブプロセス呼び出しにはオーバーヘッドがあります。最小限に抑えましょう：

**非効率的（ループ内でサブプロセス）：**
```bash
#!/bin/bash
# 悪い：すべてのファイルで grep サブプロセスを作成
for file in "${files[@]}"; do
    if grep -q "パターン" "$file"; then
        echo "$file"
    fi
done
```

**効率的（バッチ処理）：**
```bash
#!/bin/bash
# 良い：単一の grep 呼び出しですべてのファイルを処理
grep -l "パターン" "${files[@]}" 2>/dev/null
```

**パフォーマンス比較**：

| アプローチ | サブプロセス | 時間（1000 ファイル） |
|----------|--------------|-------------------|
| ループで grep | 1000 | 約 5 秒 |
| バッチ grep | 1 | 約 0.1 秒 |

### 8.1.2 文字列連結ではなく配列を使用

**危険な文字列連結：**
```bash
#!/bin/bash
# 悪い：文字列操作は遅く、エラーが発生しやすい
args=""
for f in "${files[@]}"; do
    args="$args \"$f\""  # 文字列操作
done
eval "command $args"  # 危険：eval
```

**安全な配列アプローチ：**
```bash
#!/bin/bash
# 良い：配列はスペースと特殊文字を処理
args=()
for f in "${files[@]}"; do
    args+=("$f")  # 配列追加
done
command "${args[@]}"  # 安全：適切な引用
```

### 8.1.3 不要なコマンド置換を回避

**遅い（コマンド置換）：**
```bash
#!/bin/bash
# 各 $() がサブプロセスを作成
current_dir=$(pwd)
file_count=$(ls | wc -l)
git_branch=$(git branch --show-current)

echo "$current_dir にある、ブランチ $git_branch、$file_count ファイル"
```

**速い（組み込み変数）：**
```bash
#!/bin/bash
# 利用可能な場合は組み込み変数を使用
current_dir="$PWD"  # 組み込み、サブプロセスなし
# file_count - ls が必要、代替なし
git_branch="${GIT_BRANCH:-$(git branch --show-current)}"  # 複数回使用される場合はキャッシュ

echo "$current_dir にある、ブランチ $git_branch、$file_count ファイル"
```

### 8.1.4 効率的なファイル読み取り

**非効率的（行ごとに読み取り）：**
```bash
#!/bin/bash
# 遅い：ループ内で行ごとにファイルを読み取り
while IFS= read -r line; do
    process "$line"
done < "$input_file"
```

**効率的（バッチで処理）：**
```bash
#!/bin/bash
# 速い：ファイル全体を一度に処理
if command -v xargs &>/dev/null; then
    cat "$input_file" | xargs -I{} process "{}"
else
    # フォールバックして while ループ
    while IFS= read -r line; do
        process "$line"
    done < "$input_file"
fi
```

### 8.1.5 高価な操作のキャッシング

**キャッシングなし：**
```bash
#!/bin/bash
# git を複数回呼び出し
get_author() {
    git log -1 --format='%an'
}

get_commit_count() {
    git rev-list --count HEAD
}

get_current_branch() {
    git branch --show-current
}

# 各呼び出しが git サブプロセスを生成
author=$(get_author)
commits=$(get_commit_count)
branch=$(get_current_branch)
```

**キャッシングあり：**
```bash
#!/bin/bash
# git 情報を一度にキャッシュ
declare -A GIT_CACHE

cache_git_info() {
    GIT_CACHE[author]=$(git log -1 --format='%an')
    GIT_CACHE[commits]=$(git rev-list --count HEAD)
    GIT_CACHE[branch]=$(git branch --show-current)
}

# スクリプトの開始時に一度呼び出し
cache_git_info

# キャッシュからアクセス（サブプロセスなし）
echo "著者：${GIT_CACHE[author]}"
echo "コミット：${GIT_CACHE[commits]}"
echo "ブランチ：${GIT_CACHE[branch]}"
```

---

## 8.2 セキュリティベストプラクティス

### 8.2.1 コマンドインジェクションを回避

**危険 - 決してこれを行わない：**
```bash
#!/bin/bash
# 重要な脆弱性：コマンドインジェクション
user_input="$1"
eval "echo $user_input"  # ユーザーは任意のコマンドを実行可能！

# 攻撃者入力："$(rm -rf /)"
# 結果：rm -rf / が実行される！
```

**安全 - 常に引用して検証：**
```bash
#!/bin/bash
# 安全：eval なし、適切な引用
user_input="$1"

# 入力を検証（英数字と安全な文字のみ許可）
if [[ ! "$user_input" =~ ^[a-zA-Z0-9_./-]+$ ]]; then
    error "無効な入力形式"
    exit 1
fi

echo "$user_input"  # 安全：引用、eval なし
```

### 8.2.2 安全なファイルパス処理

**ユーザー提供パスを検証：**
```bash
#!/bin/bash
validate_path() {
    local path="$1"
    local allowed_base="$2"

    # パストラバーサルをチェック
    if [[ "$path" == *".."* ]]; then
        error "パストラバーサルは許可されていません"
        return 1
    fi

    # 絶対パスに解決
    local resolved_path
    resolved_path=$(cd "$path" 2>/dev/null && pwd) || resolved_path="$path"

    # パスが許可されたディレクトリ内にあることを確認
    if [[ "$resolved_path" != "$allowed_base"/* ]]; then
        error "許可されたディレクトリ外のパス"
        return 1
    fi

    return 0
}

# 使用
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
if ! validate_path "$user_path" "$PROJECT_ROOT"; then
    exit 1
fi
```

### 8.2.3 安全な一時ファイル

**安全でない - 予測可能な名前：**
```bash
#!/bin/bash
# 脆弱：レースコンディション、予測可能な名前
tmp_file="/tmp/my-script-$$.tmp"
echo "データ" > "$tmp_file"  # 攻撃者は事前にシンボリックリンクを作成可能！
```

**安全 - mktemp を使用：**
```bash
#!/bin/bash
# 安全：予測不可能な名前、アトミック作成
tmp_file=$(mktemp) || exit 1
echo "データ" > "$tmp_file"

# 追加セキュリティ：制限付き権限
chmod 600 "$tmp_file"
```

### 8.2.4 権限管理

**適切な権限を設定：**
```bash
#!/bin/bash
secure_permissions() {
    # 秘密鍵は所有者のみが読み取り可能である必要
    if [ -f "$PRIVATE_KEY" ]; then
        local perms
        perms=$(stat -c %a "$PRIVATE_KEY" 2>/dev/null || stat -f %Lp "$PRIVATE_KEY")
        if [ "$perms" != "600" ]; then
            warn "秘密鍵の権限を修正"
            chmod 600 "$PRIVATE_KEY"
        fi
    fi

    # 設定ファイルは読み取り可能である必要
    if [ -f "$CONFIG_FILE" ]; then
        chmod 644 "$CONFIG_FILE"
    fi

    # スクリプトは実行可能である必要
    if [ -f "$SCRIPT_FILE" ]; then
        chmod 755 "$SCRIPT_FILE"
    fi
}
```

### 8.2.5 資格情報処理

**決して資格情報をハードコードしない：**
```bash
#!/bin/bash
# 重要：決して資格情報をハードコードしない！
PASSWORD="supersecret123"  # git、ps などで表示！
API_KEY="sk-xxxxxxxxx"    # 漏洩！
```

**環境または設定ファイルを使用：**
```bash
#!/bin/bash
# 安全：環境または設定から読み取り
API_KEY="${API_KEY:-}"
if [ -z "$API_KEY" ]; then
    # 設定ファイルにフォールバック
    API_KEY=$(json_get "$CONFIG_FILE" "api_key")
fi

if [ -z "$API_KEY" ]; then
    error "API キーが設定されていません"
    error "API_KEY 環境変数を設定するか、sftp-config.json で設定"
    exit 1
fi
```

### 8.2.6 入力のサニタイズ

**すべての外部入力をサニタイズ：**
```bash
#!/bin/bash
sanitize_filename() {
    local filename="$1"

    # 危険な文字を削除
    filename="${filename//\//_}"      # パスセパレーターなし
    filename="${filename//../_}"      # 親ディレクトリなし
    filename="${filename//:/_}"       # コロンなし（Windows）
    filename="${filename//\\/_}"      # バックスラッシュなし

    # 制御文字を削除
    filename=$(echo "$filename" | tr -d '[:cntrl:]')

    # 長さを制限
    filename="${filename:0:255}"

    echo "$filename"
}

# 使用
safe_name=$(sanitize_filename "$user_input")
```

---

## 8.3 コード組織

### 8.3.1 関数の命名規則

**説明的な動詞 + 名前の名前を使用：**
```bash
# アクション関数：動詞 + 名詞
init_config() { }
load_messages() { }
upload_files() { }
check_dependencies() { }

# ブール関数：is/has/check/validate プレフィックス
is_excluded() { }
has_permission() { }
check_config() { }
validate_path() { }

# ゲッター関数：get_ プレフィックス
get_config_value() { }
get_git_root() { }
get_temp_dir() { }
```

**曖昧な名前を回避：**
```bash
# 悪い：これは何をするか？
do_stuff() { }
handle() { }
process() { }

# 良い：明確な目的
upload_changed_files() { }
handle_connection_error() { }
process_git_changes() { }
```

### 8.3.2 変数スコープ

**ローカル変数（関数内）：**
```bash
#!/bin/bash
process_file() {
    local file="$1"           # ローカル変数
    local content
    local line_count

    content=$(cat "$file")
    line_count=$(wc -l < "$file")

    # これらの変数は関数の終了時に消滅
}
```

**グローバル変数（スクリプト全体）：**
```bash
#!/bin/bash
# グローバル定数（readonly）
readonly VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly CONFIG_DIR=".claude/sftp-cc"

# グローバル変数（変更可能、控えめに使用）
VERBOSE=false
DRY_RUN=false
CONFIG_FILE=""
```

**命名規則：**
```bash
# 定数：大文字
readonly MAX_RETRIES=3
readonly DEFAULT_PORT=22

# 変数：小文字
config_file=""
retry_count=0

# 配列：複数形小文字
files_to_upload=()
excluded_patterns=()
```

### 8.3.3 スクリプト構造テンプレート

**標準スクリプトレイアウト：**
```bash
#!/bin/bash
# script-name.sh - 簡単な説明
# このスクリプトが何をするかの完全な説明
#
# 使用方法：./script-name.sh [オプション] [引数]
# オプション：
#   -v, --verbose    詳細出力を有効
#   -n, --dry-run    プレビューモード
#   -h, --help       ヘルプを表示

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
readonly NC='\033[0m'

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
使用方法：$SCRIPT_NAME [オプション] [引数]

オプション：
  -v, --verbose      詳細出力を有効
  -n, --dry-run      プレビューモード（実行しない）
  -h, --help         このヘルプを表示
  --version          バージョンを表示

例：
  $SCRIPT_NAME                    # 通常の実行
  $SCRIPT_NAME --verbose          # デバッグ出力あり
  $SCRIPT_NAME --dry-run          # プレビューのみ
EOF
}

#######################################
# コマンドライン引数の解析
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
                error "不明なオプション：$1"
                usage
                exit 1
                ;;
        esac
    done
}

#######################################
# 設定の初期化
#######################################
init_config() {
    local config_dir="$PROJECT_ROOT/.claude/sftp-cc"
    CONFIG_FILE="$config_dir/sftp-config.json"

    if [ ! -f "$CONFIG_FILE" ]; then
        error "設定が見つかりません：$CONFIG_FILE"
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
    info "$SCRIPT_NAME を開始..."
    init_config

    # ここにメインロジック

    info "正常に完了！"
}

# すべての引数と共に main 関数を実行
main "$@"
```

---

## 8.4 trap を使用した高度なエラーハンドリング

### 8.4.1 基本的な trap の使用

**エラーをキャッチしてクリーンアップ：**
```bash
#!/bin/bash
set -euo pipefail

# 一時ファイル
tmp_file=""
batch_file=""

cleanup() {
    info "クリーンアップ中..."
    [ -n "$tmp_file" ] && [ -f "$tmp_file" ] && rm -f "$tmp_file"
    [ -n "$batch_file" ] && [ -f "$batch_file" ] && rm -f "$batch_file"
}

# EXIT でクリーンアップを登録（常に実行）
trap cleanup EXIT

# あなたのコード
tmp_file=$(mktemp)
batch_file=$(mktemp)

# スクリプトが終了した場合（成功またはエラー）、cleanup が実行
```

### 8.4.2 行番号付きエラーハンドラ

**詳細なエラー情報を取得：**
```bash
#!/bin/bash
set -euo pipefail

error_handler() {
    local line_no=$1
    local func=$2
    local cmd=$3

    error "スクリプトに失敗！"
    error "  行：$line_no"
    error "  関数：${func:-main}"
    error "  コマンド：$cmd"
    error ""
    error "デバッグ：bash -x $SCRIPT_NAME"
}

# エラーハンドラを登録
trap 'error_handler ${LINENO} "${FUNCNAME[0]:-main}" "$BASH_COMMAND"' ERR

# あなたのコード
risky_operation  # これが失敗した場合、error_handler が呼び出
```

### 8.4.3 シグナルハンドリング

**割り込みシグナルを処理：**
```bash
#!/bin/bash

interrupt_handler() {
    warn "ユーザーによって割り込まれた（Ctrl+C）"
    cleanup
    exit 130  # Ctrl+C の標準終了コード
}

terminate_handler() {
    warn "終了シグナルを受信"
    cleanup
    exit 143  # SIGTERM の標準終了コード
}

# シグナルハンドラを登録
trap interrupt_handler INT  # Ctrl+C
trap terminate_handler TERM  # kill コマンド
trap cleanup EXIT  # 常にクリーンアップ
```

### 8.4.4 完全なエラーハンドリング例

```bash
#!/bin/bash
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"

# グローバル
tmp_files=()
cleanup_done=false

#######################################
# クリーンアップ関数
#######################################
cleanup() {
    if $cleanup_done; then
        return
    fi
    cleanup_done=true

    info "${#tmp_files[@]} 一時ファイルをクリーンアップ..."
    for f in "${tmp_files[@]:-}"; do
        [ -n "$f" ] && [ -f "$f" ] && rm -f "$f"
    done
}

#######################################
# エラーハンドラ
#######################################
error_handler() {
    local line_no=$1
    error "行 $line_no で予期しないエラー"
    error "終了コード：$?"
}

#######################################
# 割り込みハンドラ
#######################################
interrupt_handler() {
    warn "ユーザーによってキャンセル"
    cleanup
    exit 130
}

#######################################
# ハンドラを登録
#######################################
trap cleanup EXIT
trap 'error_handler ${LINENO}' ERR
trap interrupt_handler INT TERM

#######################################
# 一時ファイルを作成（追跡付き）
#######################################
create_temp() {
    local tmp
    tmp=$(mktemp)
    tmp_files+=("$tmp")
    echo "$tmp"
}

#######################################
# メインロジック
#######################################
main() {
    info "操作を開始..."

    local data_file
    data_file=$(create_temp)

    # 処理をシミュレート
    echo "データ" > "$data_file"

    # ここで割り込まれても、cleanup は依然として実行

    info "操作が完了！"
}

main "$@"
```

---

## 8.5 よくある問題のトラブルシューティング

### 8.5.1 Skill がトリガーされない

**問題**：Claude がトリガーワードに反応しない。

**チェックリスト**：

```bash
# 1. SKILL.md が存在することを確認
ls -la skills/sftp-cc/SKILL.md

# 2. トリガーワード定義を確認
grep -A 10 "トリガー" skills/sftp-cc/SKILL.md

# 3. marketplace.json を検証
jq . .claude-plugin/marketplace.json

# 4. プラグインをリロード
claude plugin reload sftp-cc
```

**一般的な原因**：
- ❌ SKILL.md が正しいディレクトリにない
- ❌ トリガーワードが一般的すぎる
- ❌ プラグインがロードされていない

**修正**：
````markdown
# SKILL.md で、トリガーを具体的に：

## トリガー

ユーザーが次に言ったとき：
- "コードをサーバーに同期"     ✓ 具体的
- "サーバーにアップロード"       ✓ 具体的
- "コードをデプロイ"            ✓ 具体的

次ではなく：
- "アップロード"               ✗ 一般的すぎる
- "同期"                      ✗ 一般的すぎる
- "プッシュ"                  ✗ git と競合
````

### 8.5.2 変数が解決されない

**問題**：`${CLAUDE_PLUGIN_ROOT}` が空。

**原因**：変数は Skill コンテキストでのみ存在。

**解決策**：
```bash
# SKILL.md 内（Skill コンテキスト）- ✓ 動作
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh

# shell で直接 - ✗ 失敗
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh
# エラー：bash: /scripts/sftp-push.sh: そのようなファイルまたはディレクトリはありません

# 代わりに絶対パスを使用
bash ~/.claude/plugins/marketplaces/sftp-cc/scripts/sftp-push.sh
```

### 8.5.3 SFTP 接続に失敗

**問題**：接続タイムアウトまたは認証失敗。

**デバッグステップ**：

```bash
# 1. 手動で接続をテスト
sftp -v -i ~/.ssh/id_rsa user@host

# 2. 秘密鍵の権限を確認
ls -la ~/.ssh/id_rsa
# 次である必要：-rw-------（600）

# 3. 設定を検証
cat .claude/sftp-cc/sftp-config.json

# 4. 詳細 sftp でテスト
sftp -v -b batch_file user@host
```

**一般的な修正**：
```bash
# 鍵の権限を修正
chmod 600 ~/.ssh/id_rsa

# 鍵形式を検証
ssh-keygen -lf ~/.ssh/id_rsa

# SSH 接続をテスト
ssh -i ~/.ssh/id_rsa user@host
```

### 8.5.4 JSON パースが空を返す

**問題**：`json_get` 関数が空の値を返す。

**デバッグ**：
```bash
# 1. JSON 構文をチェック
jq . .claude/sftp-cc/sftp-config.json

# 2. フィールドが存在することを確認
jq '.host' .claude/sftp-cc/sftp-config.json

# 3. json_get 関数をテスト
source scripts/json-parser.sh
json_get config.json "host"
```

**一般的な問題**：
```json
// キー周りの引用符がない
{
    host: "example.com"  // ✗ 無効な JSON
}

{
    "host": "example.com"  // ✓ 有効な JSON
}

// 末尾のコンマ
{
    "host": "example.com",  // ✗ 無効（末尾のコンマ）
}

{
    "host": "example.com"  // ✓ 有効
}
```

### 8.5.5 スクリプトが無限にハング

**問題**：スクリプトがフリーズしたように見える。

**原因と修正**：

| 原因 | 症状 | 修正 |
|-------|---------|-----|
| 入力を待機 | カーソルが点滅、プロンプトなし | read に `-n` を追加 |
| ネットワークタイムアウト | SFTP コマンドがハング | タイムアウトラッパーを追加 |
| 無限ループ | 高い CPU 使用率 | ループカウンターを追加 |
| デッドロック | 待機中の複数プロセス | パイプ使用をレビュー |

**タイムアウトを追加**：
```bash
# timeout コマンドを使用
timeout 30 sftp -b batch_file user@host || error "アップロードタイムアウト"

# またはスクリプトで実装
start_time=$(date +%s)
sftp_command &
pid=$!

while kill -0 $pid 2>/dev/null; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))

    if [ $elapsed -gt 30 ]; then
        kill $pid
        error "30 秒後に操作がタイムアウト"
        exit 1
    fi

    sleep 1
done

wait $pid
```

---

## 8.6 実世界ケーススタディ

### 8.6.1 ケーススタディ：増分アップロードバグ

**背景**：sftp-cc 増分アップロードが一部のファイルを見逃した。

**症状**：
```
ユーザー：「コードをサーバーに同期」
Claude: アップロード完了！5 ファイルをアップロード。

しかし、ユーザーには 8 の変更ファイルがあった...
```

**調査**：
```bash
# デバッグを有効
set -x

# git 検出をチェック
git diff --name-only --diff-filter=ACMR HEAD
# 返す：5 ファイル

git ls-files --others --exclude-standard
# 返す：3 ファイル（未トラック）

# バグ発見：未トラックファイルが含まれていない！
```

**根本原因**：スクリプトがコミット済み変更のみをチェックし、未トラックファイルをチェックしなかった。

**修正**：
```bash
# 前（バグ）
changed_files=$(git diff --name-only --diff-filter=ACMR HEAD)

# 後（修正）
changed_files=$(
    git diff --name-only --diff-filter=ACMR HEAD
    git diff --cached --name-only --diff-filter=ACMR
    git ls-files --others --exclude-standard
)
```

**教訓**：すべての変更シナリオ（コミット済み、ステージング済み、変更済み、未トラック）をテスト。

### 8.6.2 ケーススタディ：秘密鍵権限修正

**背景**：自動鍵バインドが時々静かに失敗。

**症状**：
```
ユーザー：「SSH 鍵をバインド」
Claude: 鍵が正常にバインドされました！

しかし sftp-config.json にはまだ空の private_key がある...
```

**調査**：
```bash
# 鍵検出をチェック
ls -la .claude/sftp-cc/
# 発見：id_rsa（644 権限）

# スクリプトをチェック
bash -x scripts/sftp-keybind.sh

# 発見：chmod 600 が静かに失敗
chmod 600 id_rsa
# エラー出力なし、ただし権限は変更されない（一部のファイルシステムで）
```

**根本原因**：スクリプトが chmod の成功を検証しなかった。

**修正**：
```bash
# 前（静かな失敗）
chmod 600 "$key_file"

# 後（検証してエラー）
if ! chmod 600 "$key_file"; then
    error "鍵の権限設定に失敗"
    exit 1
fi

# 検証
perms=$(stat -c %a "$key_file")
if [ "$perms" != "600" ]; then
    error "権限修正に失敗：$perms"
    exit 1
fi
```

**教訓**：システムコマンドが成功することを決して仮定しない。重要な操作を検証。

### 8.6.3 ケーススタディ：i18n 変数が設定されない

**背景**：多言語メッセージが時々空で表示。

**症状**：
```
アップロード完了：  # メッセージが欠落！
```

**調査**：
```bash
# i18n.sh ローディングをチェック
source scripts/i18n.sh
init_lang "$CONFIG_FILE"

echo "MSG_UPLOAD_COMPLETE=$MSG_UPLOAD_COMPLETE"
# 出力：MSG_UPLOAD_COMPLETE=

# 設定をチェック
cat .claude/sftp-cc/sftp-config.json
# 発見："language": "zh-cn"  // 認識されない！
```

**根本原因**：言語コード "zh-cn" が case 文と一致しなかった。

**修正**：
```bash
# 前（厳密な一致）
case "$lang" in
    zh) load_chinese ;;
    ja) load_japanese ;;
    *) load_english ;;
esac

# 後（柔軟な一致）
case "${lang:0:2}" in  # 最初の 2 文字を使用
    zh) load_chinese ;;
    ja) load_japanese ;;
    *) load_english ;;
esac
```

**教訓**：比較前に入力値を正規化。

---

## 8.7 パフォーマンスプロファイリング

### 8.7.1 スクリプト実行のタイミング

**シンプルなタイミング**：
```bash
# スクリプト全体をタイミング
time ./sftp-push.sh

# 出力：
# real    0m2.341s
# user    0m0.523s
# sys     0m0.412s
```

**特定のセクションをタイミング**：
```bash
#!/bin/bash

start_time=$(date +%s.%N)

# タイミングするセクション
upload_files

end_time=$(date +%s.%N)
elapsed=$(echo "$end_time - $start_time" | bc)

info "アップロードに${elapsed}秒かかった"
```

### 8.7.2 遅い操作を特定

**各関数をプロファイル**：
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

    debug "$func_name に${elapsed}秒かかった"
}

# 使用
profile_function detect_changes
profile_function build_batch_file
profile_function upload_files
```

### 8.7.3 サブプロセス呼び出しをカウント

**サブプロセス使用を追跡**：
```bash
#!/bin/bash

# 一般的なコマンドをラップしてカウント
subprocess_count=0

original_sftp=$(which sftp)
sftp() {
    subprocess_count=$((subprocess_count + 1))
    debug "サブプロセス #$subprocess_count: sftp $*"
    "$original_sftp" "$@"
}

original_grep=$(which grep)
grep() {
    subprocess_count=$((subprocess_count + 1))
    debug "サブプロセス #$subprocess_count: grep $*"
    "$original_grep" "$@"
}

# 終了時
info "総サブプロセス呼び出し：$subprocess_count"
```

---

## 本章のまとめ

### 重要な概念

| 概念 | 説明 | ベストプラクティス |
|---------|-------------|---------------|
| サブプロセス削減 | 外部呼び出しを最小限 | バッチ操作 |
| 配列使用 | 安全な引数処理 | 文字列ではなく配列 |
| コマンドインジェクション | セキュリティ脆弱性 | `eval` を決して使用 |
| パス検証 | トラバーサル攻撃を防止 | 検証してサニタイズ |
| 関数命名 | コードの可読性 | 動詞 + 名詞パターン |
| 変数スコープ | 競合を防止 | 関数で `local` |
| `trap` 使用 | エラーハンドリング | 常にクリーンアップ |
| パフォーマンスプロファイリング | ボトルネックを特定 | 重要なセクションをタイミング |

### ベストプラクティス要約

**コード品質**：
- [ ] 厳格モードに `set -euo pipefail` を使用
- [ ] ロギング関数を実装（info/warn/error/debug）
- [ ] 命名規則に従う
- [ ] 関数を小さく焦点を絞る
- [ ] 複雑なロジックにコメント

**セキュリティ**：
- [ ] ユーザー入力で `eval` を決して使用
- [ ] すべてのファイルパスを検証
- [ ] 一時ファイルに `mktemp` を使用
- [ ] 適切な権限を設定（鍵に 600）
- [ ] 資格情報をハードコードしない

**パフォーマンス**：
- [ ] バッチ操作（サブプロセスのループを回避）
- [ ] 文字列連結ではなく配列を使用
- [ ] 高価な操作をキャッシュ
- [ ] ボトルネックを特定するためにプロファイル

**エラーハンドリング**：
- [ ] クリーンアップに `trap` を使用
- [ ] 早期にパラメータを検証
- [ ] 明確なエラーメッセージを提供
- [ ] 割り込みシグナルを処理

---

## 練習問題

### 練習問題 8-1: スクリプトのセキュリティ監査

既存のスクリプトをセキュリティ問題でレビュー：
1. `eval` の使用を検索 - 削除または置換
2. すべてのユーザー入力が検証されているか確認
3. 一時ファイルが `mktemp` を使用しているか確認
4. ファイル権限が正しく設定されているか確認
5. ハードコードされた資格情報がないことを確認

チェックリストを作成し、見つかった問題を修正。

### 練習問題 8-2: パフォーマンスプロファイリングを追加

スクリプトにタイミングを追加：
1. 操作をタイミングする `profile()` 関数を作成
2. 各主要関数をプロファイリングでラップ
3. 終了時にタイミングサマリーを出力：
   ```
   パフォーマンスサマリー：
   - detect_changes: 0.12 秒
   - build_batch: 0.34 秒
   - upload_files: 1.89 秒
   合計：2.35 秒
   ```
3. 最も遅い操作を特定して最適化。

### 練習問題 8-3: 包括的エラーハンドリングを実装

堅牢なエラーハンドリングを追加：
1. 一時ファイルの `cleanup()` 関数を作成
2. `trap cleanup EXIT` を登録
3. 行番号付き `error_handler()` を作成
4. `trap 'error_handler ${LINENO}' ERR` を登録
5. INT と TERM の割り込みハンドラを追加
6. 操作中に中断（Ctrl+C）してテスト

---

## 拡張リソース

### Shell スクリプトセキュリティ
- [OWASP コマンドインジェクション防止](https://owasp.org/www-community/attacks/Command_Injection)
- [ShellCheck ルール](https://github.com/koalaman/shellcheck/wiki/Rules)
- 「Secure Shell Scripting」- DEF CON トーク

### パフォーマンス最適化
- [Bash パフォーマンスヒント](https://mywiki.wooledge.org/BashPerformance)
- 「Advanced Bash-Scripting Guide: Optimization」
- [パフォーマンス問題の ShellCheck](https://www.shellcheck.net/)

### エラーハンドリング
- [Bash trap ドキュメント](https://www.gnu.org/software/bash/manual/html_node/Trap.html)
- 「Robust Shell Scripting」- 各種ブログ
- [終了コードリファレンス](https://tldp.org/LDP/abs/html/exitcodes.html)

### 副読本
- 「The Art of UNIX Programming」- Eric S. Raymond
- 「Classic Shell Scripting」- O'Reilly
- 「Linux Command Line and Shell Scripting Bible」

---

## 本書のまとめ

おめでとうございます！本書を完了しました。学んだことを振り返りましょう：

### 第 1 章：導入
- Claude Code Skill とは何か
- Plugin アーキテクチャ（SKILL.md、marketplace.json）
- `${CLAUDE_PLUGIN_ROOT}` 変数
- 開発環境セットアップ
- 初めての Hello World Skill を作成

### 第 2 章：計画と設計
- ペインポイントからの要件分析
- ユーザーペルソナと使用ケース
- 機能バウンダリ（行うことと行わないこと）
- ディレクトリ構造の計画
- 設定ファイル設計

### 第 3 章：初めての Skill を書く
- SKILL.md 構造と YAML frontmatter
- トリガーワード設計
- スクリプトパス設定
- 実行指示
- ユーザーガイドドキュメント

### 第 4 章：スクリプト開発
- Shell スクリプト構造テンプレート
- グローバル変数と定数
- 色出力とロギング
- JSON パース（純粋な Shell）
- Git 統合
- SFTP バッチモードアップロード
- エラーハンドリングパターン

### 第 5 章：国際化
- i18n の重要性とアプローチ
- 変数ベースの多言語（MSG_XXX）
- i18n.sh 実装
- 言語検出とローディング
- 翻訳のベストプラクティス

### 第 6 章：デバッグとテスト
- `set -euo pipefail` 厳格モード
- ログレベル設計
- Verbose モード実装
- `trap` を使用した一時ファイル管理
- エラーハンドリングパターン
- ドライランモード
- ShellCheck と他のツール

### 第 7 章：公開と配布
- Plugin Marketplace アーキテクチャ
- `marketplace.json` 設定
- Semantic Versioning（SemVer）
- GitHub Release 自動化
- 多言語 README
- Plugin 検証
- 配布戦略

### 第 8 章：トピック（本章）
- パフォーマンス最適化
- セキュリティベストプラクティス
- コード組織
- 高度なエラーハンドリング
- トラブルシューティングガイド
- 実世界ケーススタディ

### あなたの今後の旅

あなたには次の知識があります：
1. ✅ 独自の Skill を設計して計画
2. ✅ 堅牢な Shell スクリプトを作成
3. ✅ 多言語サポートを実装
4. ✅ 効果的にデバッグしてテスト
5. ✅ Plugin Marketplace に公開
6. ✅ 作業を維持して反復

**次のステップ**：
1. 独自のユニークな Skill を構築
2. コミュニティと共有
3. ユーザーフィードバックから学習
4. 技術を継続的に改善

ご健闘と、ハッピーコーディング！

---

## 本書について

**初版（デジタル版）, 2026 年 3 月**

**著者**: [toohamster](https://github.com/toohamster)
**ライセンス**: 電子版：MIT License | 印刷版/商業版：All Rights Reserved
**ソース**: [github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

詳細は [LICENSE](../../LICENSE) と [著者について](../authors.md) をご覧ください。

---
