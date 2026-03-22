# 第 6 章：デバッグとテスト

> 「デバッグは、コードを書くことの 2 倍の難しさがある。したがって、可能な限り賢くコードを書いた場合、それは自分をデバッグするのに十分賢くない」 — ブライアン・カーニハン

この章では、次のことを学びます：
- Shell スクリプトデバッグ基礎（`set` コマンドオプション）
- ログレベル設計と実装
- Verbose モードの詳細出力
- 一時ファイル管理（`mktemp` + `trap`）
- エラーハンドリングパターンと検証
- テスト方法（ドライラン、ユニット、統合）
- 実世界デバッグケーススタディ
- 検証ツールの使用

---

## 6.1 Shell スクリプトデバッグ基礎

### 6.1.1 `set` コマンド

`set` コマンドはシェルの動作を制御し、早期にエラーを検出するのに役立ちます：

```bash
#!/bin/bash
set -euo pipefail  # 本番環境に推奨

# デバッグ用
set -x  # 実行されたすべてのコマンドを表示
set -v  # 読み取られたすべての行を表示
```

**各オプションの説明**：

| オプション | 正式名称 | 説明 |
|--------|-----------|-------------|
| `-e` | `errexit` | コマンドが 0 以外のステータスで終了したら即座に終了 |
| `-u` | `nounset` | 未定義変数を使用するとエラー |
| `-o pipefail` | `pipefail` | パイプ内のいずれかのコマンドが失敗すると失敗 |
| `-x` | `xtrace` | 実行前に各コマンドを表示（デバッグモード） |
| `-v` | `verbose` | 入力時に行を表示 |

### 6.1.2 `-e` (errexit) の理解

`-e` なしでは、スクリプトはコマンドが失敗しても続行します：

```bash
#!/bin/bash
# -e なし
rm /nonexistent_file  # 失敗するが継続
echo "続行中..."      # まだ実行される！

# -e あり
set -e
rm /nonexistent_file  # スクリプトが即座に終了
echo "これは実行されない"  # 決して到達しない
```

### 6.1.3 `-u` (nounset) の理解

未定義変数は微妙なバグを引き起こします：

```bash
#!/bin/bash
# -u なし
echo "$UNDEFINED_VAR"  # 空文字列を出力、継続

# -u あり
set -u
echo "$UNDEFINED_VAR"  # エラー：未束縛変数
```

**修正**：デフォルト値を提供：
```bash
echo "${UNDEFINED_VAR:-デフォルト値}"
```

### 6.1.4 `-o pipefail` の理解

`pipefail` なしでは、パイプは失敗を隠します：

```bash
#!/bin/bash
# pipefail なし
cat nonexistent.txt | grep "パターン"  # cat は失敗、grep は成功
echo $?  # 0（成功）を返す - 間違い！

# pipefail あり
set -o pipefail
cat nonexistent.txt | grep "パターン"
echo $?  # 1（失敗）を返す - 正解！
```

### 6.1.5 デバッグモード：`-x` (xtrace)

展開された変数で各コマンドを表示：

```bash
#!/bin/bash
set -x

name="World"
echo "Hello, $name"

# 出力：
# + name=World
# + echo 'Hello, World'
# Hello, World
```

**一時的にデバッグ用有効**：
```bash
bash -x script.sh  # デバッグトレースで実行
```

### 6.1.6 オプションの組み合わせ

**開発モード**（最大デバッグ）：
```bash
set -euxo pipefail
```

**本番モード**（厳格だが静か）：
```bash
set -euo pipefail
```

**特定のセクションをデバッグ**：
```bash
#!/bin/bash
set -euo pipefail

# 通常のコード
echo "開始..."

# 複雑なセクションのデバッグ
set -x
complex_operation
set +x  # デバッグ無効

# 継続
echo "完了"
```

---

## 6.2 ログレベル設計

### 6.2.1 なぜロギングが重要か

良いログは次のことに答えます：
- 何が発生したか？
- いつ発生したか？
- コンテキストは何か？
- 何が悪くなったか（何か問題があれば）？

### 6.2.2 4 レベルログシステム

```bash
#!/bin/bash

# 色の定義
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'  # 色なし

# スクリプト名（ログプレフィックス用）
readonly SCRIPT_NAME="$(basename "$0")"

# ログ関数
info()  { echo -e "${GREEN}[$SCRIPT_NAME]${NC} $*" >&2; }
warn()  { echo -e "${YELLOW}[$SCRIPT_NAME] 警告:${NC} $*" >&2; }
error() { echo -e "${RED}[$SCRIPT_NAME] エラー:${NC} $*" >&2; }
debug() { echo -e "${BLUE}[$SCRIPT_NAME] デバッグ:${NC} $*" >&2; }
```

### 6.2.3 ログレベルの使用

| レベル | 使用時期 | 例 |
|-------|-------------|---------|
| `info` | 通常の操作メッセージ | "アップロード完了：5 ファイル" |
| `warn` | 致命的でない問題 | "設定ファイルが見つからない、デフォルトを使用" |
| `error` | 致命的なエラー（stderr へ） | "SFTP 接続に失敗" |
| `debug` | 詳細な内部状態 | "ファイル処理中：/path/to/file.php" |

### 6.2.4 実践での使用

```bash
#!/bin/bash
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

info()  { echo -e "${GREEN}[$SCRIPT_NAME]${NC} $*" >&2; }
warn()  { echo -e "${YELLOW}[$SCRIPT_NAME] 警告:${NC} $*" >&2; }
error() { echo -e "${RED}[$SCRIPT_NAME] エラー:${NC} $*" >&2; }

# メインロジック
main() {
    info "アップロードプロセスを開始..."

    if [ ! -f "config.json" ]; then
        warn "設定ファイルが見つからない、デフォルトを使用"
    fi

    if ! upload_files; then
        error "アップロードに失敗！"
        exit 1
    fi

    info "アップロード完了！"
}

main
```

**サンプル出力**：
```
[sftp-push.sh] アップロードプロセスを開始...
[sftp-push.sh] 警告：設定ファイルが見つからない、デフォルトを使用
[sftp-push.sh] アップロード完了！
```

---

## 6.3 Verbose モード

### 6.3.1 デバッグスイッチの追加

ユーザーに詳細出力を有効にする機能を許可：

```bash
#!/bin/bash
set -euo pipefail

# デフォルト：クワイエットモード
VERBOSE=false

# コマンドライン引数を解析
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

# デバッグ関数（VERBOSE=true の場合のみ出力）
debug() {
    if $VERBOSE; then
        echo -e "\033[0;34m[デバッグ]\033[0m $*" >&2
    fi
}

# 使用
debug "設定ファイル：$CONFIG_FILE"
debug "ターゲットホスト：$HOST"
```

### 6.3.2 条件付きデバッグ実行

verbose モードでのみ追加チェックを実行：

```bash
if $VERBOSE; then
    debug "環境をチェック..."
    debug "  PATH: $PATH"
    debug "  PWD: $(pwd)"
    debug "  ユーザー：$(whoami)"
fi
```

### 6.3.3 環境変数オーバーライド

環境変数で verbose モードを有効にすることを許可：

```bash
# 最初に環境変数を確認
VERBOSE="${VERBOSE:-false}"

# コマンドライン引数がオーバーライド
if [[ "${1:-}" == "-v" ]] || [[ "${1:-}" == "--verbose" ]]; then
    VERBOSE=true
fi
```

**使用法**：
```bash
# 環境変数で有効
VERBOSE=true ./sftp-push.sh

# 引数で有効
./sftp-push.sh --verbose
```

---

## 6.4 一時ファイル管理

### 6.4.1 安全な一時ファイルの作成

`/tmp/myscript.tmp` のような予測可能な名前を使用しない：

```bash
# 危険 - 予測可能な名前
tmp_file="/tmp/my-script-$$.tmp"  # レースコンディションのリスク！

# 安全 - mktemp を使用
tmp_file=$(mktemp)              # /tmp/tmp.XXXXXXXXXX
tmp_dir=$(mktemp -d)            # /tmp/tmp.XXXXXXXXXX/
```

### 6.4.2 mktemp オプション

| オプション | 説明 | 例の出力 |
|--------|-------------|----------------|
| (なし) | 一時ファイルを作成 | `/tmp/tmp.Xk9jL2mN3p` |
| `-d` | 一時ディレクトリを作成 | `/tmp/tmp.Xk9jL2mN3p/` |
| `-t prefix` | 名前付き一時ファイル | `/tmp/myapp.Xk9jL2mN3p` |
| `--suffix .ext` | 接尾辞を追加 | `/tmp/tmp.Xk9jL2mN3p.log` |

### 6.4.3 trap によるクリーンアップ

エラー時でも一時ファイルを常にクリーンアップ：

```bash
#!/bin/bash
set -euo pipefail

# 一時ファイルを作成
tmp_file=$(mktemp)
batch_file=$(mktemp)

# クリーンアップ関数
cleanup() {
    rm -f "$tmp_file" "$batch_file"
}

# クリーンアップを登録（EXIT で実行）
trap cleanup EXIT

# あなたのコード
echo "処理中..." > "$tmp_file"
# スクリプトが終了（正常またはエラー）
# → cleanup() が自動的に実行
```

### 6.4.4 trap シグナルハンドリング

さまざまな終了シナリオを処理：

```bash
#!/bin/bash

cleanup() {
    info "一時ファイルをクリーンアップ..."
    rm -f "$tmp_file"
}

error_handler() {
    local line_no=$1
    error "スクリプトエラー 行 $line_no"
}

# 正常終了時にクリーンアップ
trap cleanup EXIT

# Ctrl+C（INT）または kill（TERM）時にクリーンアップ
trap cleanup INT TERM

# エラーハンドラ（set -e のみ）
trap 'error_handler ${LINENO}' ERR
```

### 6.4.5 完全な例

```bash
#!/bin/bash
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"

# 一時ファイル
changed_files=""
batch_file=""

cleanup() {
    [ -n "$changed_files" ] && rm -f "$changed_files"
    [ -n "$batch_file" ] && rm -f "$batch_file"
}
trap cleanup EXIT

# 一時ファイルを作成
changed_files=$(mktemp)
batch_file=$(mktemp)

# 使用
git diff --name-only > "$changed_files"
build_sftp_batch "$changed_files" > "$batch_file"

# クリーンアップは自動的に実行
```

---

## 6.5 エラーハンドリングパターン

### 6.5.1 パラメータ検証

必須パラメータを早期にチェック：

```bash
validate_params() {
    local missing=()

    [ -z "${HOST:-}" ] && missing+=("host")
    [ -z "${PORT:-}" ] && missing+=("port")
    [ -z "${USERNAME:-}" ] && missing+=("username")
    [ -z "${REMOTE_PATH:-}" ] && missing+=("remote_path")

    if [ ${#missing[@]} -gt 0 ]; then
        error "必須設定が不足：${missing[*]}"
        error "最初に初期化を実行："
        error "  bash scripts/sftp-init.sh"
        exit 1
    fi
}
```

### 6.5.2 コマンド存在チェック

必要なコマンドが利用可能か確認：

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
        error "必要なコマンドが見つかりません：${missing[*]}"
        exit 1
    fi
}
```

### 6.5.3 ファイル存在チェック

重要なファイルが存在するか確認：

```bash
check_files() {
    if [ ! -f "$CONFIG_FILE" ]; then
        error "設定ファイルが見つかりません：$CONFIG_FILE"
        error "最初に初期化を実行："
        error "  bash scripts/sftp-init.sh"
        exit 1
    fi

    if [ ! -f "$PRIVATE_KEY" ]; then
        error "秘密鍵が見つかりません：$PRIVATE_KEY"
        error "秘密鍵を次に配置："
        error "  .claude/sftp-cc/"
        error "サポート形式：id_rsa, id_ed25519, *.pem, *.key"
        exit 1
    fi

    if [ ! -r "$PRIVATE_KEY" ]; then
        error "秘密鍵を読み取れません：$PRIVATE_KEY"
        error "ファイル権限を確認："
        error "  chmod 600 $PRIVATE_KEY"
        exit 1
    fi
}
```

### 6.5.4 穏やかなエラーリカバリ

一部のエラーはリカバリ可能：

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
        warn "アップロードに失敗、再試行 ($retry/$max_retries)..."
        sleep 1
    done

    error "$file のアップロードに $max_retries 回試行後失敗"
    return 1
}
```

### 6.5.5 終了コードの規約

標準終了コードを使用：

```bash
# 終了コード
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_CONFIG_ERROR=2
readonly EXIT_CONNECTION_ERROR=3
readonly EXIT_PERMISSION_ERROR=4

# 使用
if [ ! -f "$CONFIG_FILE" ]; then
    error "設定が見つからない"
    exit $EXIT_CONFIG_ERROR
fi

if ! sftp_connect; then
    error "接続に失敗"
    exit $EXIT_CONNECTION_ERROR
fi

exit $EXIT_SUCCESS
```

---

## 6.6 テスト方法

### 6.6.1 ドライランモード（プレビューモード）

実際に実行せずに何が起こるかを予測：

```bash
#!/bin/bash
set -euo pipefail

DRY_RUN=false

# 引数を解析
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

# メインロジック
files_to_upload=($(find . -name "*.php" -type f))
count=${#files_to_upload[@]}

if $DRY_RUN; then
    info "[ドライラン] $count ファイルをアップロード予定："
    for file in "${files_to_upload[@]}"; do
        echo "  - $file"
    done
    exit 0
fi

# 実際に実行
for file in "${files_to_upload[@]}"; do
    sftp_put "$file"
done
```

**使用法**：
```bash
# まずプレビュー
./sftp-push.sh --dry-run

# 次に実行
./sftp-push.sh
```

### 6.6.2 スクリプトのユニットテスト

個々の関数を個別にテスト：

```bash
#!/bin/bash
# test-json-parser.sh

source scripts/json-parser.sh  # テストする関数をソース

# テストヘルパー
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    if [ "$expected" = "$actual" ]; then
        echo "✓ 合格：$test_name"
    else
        echo "✗ 失敗：$test_name"
        echo "  予期：$expected"
        echo "  実際：$actual"
        exit 1
    fi
}

# テストファイルを作成
cat > /tmp/test-config.json <<EOF
{
    "host": "example.com",
    "port": 22,
    "username": "testuser"
}
EOF

# json_get 関数をテスト
result=$(json_get /tmp/test-config.json "host")
assert_equals "example.com" "$result" "json_get はホストを返す"

result=$(json_get /tmp/test-config.json "port")
assert_equals "22" "$result" "json_get はポートを返す"

result=$(json_get /tmp/test-config.json "missing" "default")
assert_equals "default" "$result" "json_get はデフォルトを返す"

# クリーンアップ
rm -f /tmp/test-config.json

echo "すべてのテストに合格！"
```

### 6.6.3 統合テスト

完全なワークフローをテスト：

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

echo "=== 統合テスト ==="
echo "テストディレクトリ：$TEST_DIR"

# テストプロジェクトをセットアップ
cd "$TEST_DIR"
git init
echo "test" > test.txt
git add .
git commit -m "初期コミット"

# 初期化を実行
info "初期化をテスト..."
bash "$SCRIPT_DIR/scripts/sftp-init.sh" \
    --host "test.example.com" \
    --username "testuser" \
    --remote-path "/var/www"

# 設定が作成されたか確認
if [ -f ".claude/sftp-cc/sftp-config.json" ]; then
    echo "✓ 設定ファイルが作成された"
else
    echo "✗ 設定ファイルが作成されていない"
    exit 1
fi

# 鍵バインドスクリプトをテスト
info "鍵バインドをテスト..."
touch .claude/sftp-cc/id_rsa
chmod 600 .claude/sftp-cc/id_rsa
bash "$SCRIPT_DIR/scripts/sftp-keybind.sh"

# 設定で private_key が設定されたか確認
if grep -q '"private_key":' .claude/sftp-cc/sftp-config.json; then
    echo "✓ 秘密鍵がバインドされた"
else
    echo "✗ 秘密鍵がバインドされていない"
    exit 1
fi

echo "=== すべての統合テストに合格 ==="
```

### 6.6.4 外部サービスのモック

実際の SFTP サーバーなしでテスト：

```bash
#!/bin/bash
# モック sftp コマンドを作成

mkdir -p /tmp/mock-bin

cat > /tmp/mock-bin/sftp <<'EOF'
#!/bin/bash
echo "[モック SFTP] 接続先：$*"
echo "[モック SFTP] アップロード成功"
exit 0
EOF

chmod +x /tmp/mock-bin/sftp

# PATH に追加（実際の sftp より優先）
export PATH="/tmp/mock-bin:$PATH"

# テストを実行
./sftp-push.sh
```

---

## 6.7 実世界デバッグケース

### 6.7.1 ケーススタディ：変数が展開しない

**問題**：スクリプトがファイルアップロード時に静かに失敗。

**調査**：
```bash
# デバッグモードを有効
set -x

# スクリプトを実行
./sftp-push.sh

# 出力表示：
# + sftp_batch_file=
# + sftp -b '' user@host
```

**根本原因**：タイプミスで変数が空。

**修正**：
```bash
# 間違った
sftp_batch_file=$(mktemp)
# ... 後で ...
sftp -b "$sftp_batchfie" "$SFTP_TARGET"  # タイプミス！

# 正しい
sftp -b "$sftp_batch_file" "$SFTP_TARGET"
```

### 6.7.2 ケーススタディ：パイプ失敗が隠蔽

**問題**：スクリプトがファイルがアップロードされていない場合でも成功を報告。

**調査**：
```bash
# pipefail なし
cat files.txt | grep "\.php$" | xargs -I{} sftp_put "{}"
echo "終了コード：$?"  # sftp_put が失敗しても 0 を返す！
```

**修正**：
```bash
set -o pipefail

# パイプ内のいずれかのコマンドが失敗すると現在失敗
cat files.txt | grep "\.php$" | xargs -I{} sftp_put "{}"
echo "終了コード：$?"  # 正しいエラーコードを返す
```

### 6.7.3 ケーススタディ：未定義変数

**問題**：スクリプトが時々動作し、時々失敗。

**調査**：
```bash
set -u  # 厳格な変数チェックを有効

# エラー表示：
# ./script.sh: 42 行目：HOST: 束縛されていない変数
```

**根本原因**：設定ファイルに時々 `host` フィールドがない。

**修正**：
```bash
HOST=$(json_get "$CONFIG_FILE" "host")
if [ -z "$HOST" ]; then
    error "ホストが設定されていません"
    exit 1
fi
```

### 6.7.4 ケーススタディ：一時ファイルが残る

**問題**：繰り返し実行後、`/tmp` が一時ファイルでいっぱいになる。

**調査**：
```bash
ls -la /tmp/tmp.*
# スクリプトからの数十のファイルが表示
```

**根本原因**：`trap cleanup EXIT` が登録されていない。

**修正**：
```bash
# 一時ファイル作成後に常にクリーンアップを登録
tmp_file=$(mktemp)
trap 'rm -f "$tmp_file"' EXIT
```

---

## 6.8 検証ツール

### 6.8.1 ShellCheck

Shell スクリプトの静的解析：

```bash
# インストール
brew install shellcheck  # macOS
sudo apt install shellcheck  # Linux

# 実行
shellcheck scripts/sftp-push.sh

# サンプル出力：
# scripts/sftp-push.sh 42 行目：
#     if [ $count -gt 0 ]; then
#            ^----^ SC2086: グロビングを防止するために二重引用符で囲む
#
# 推奨：
#     if [ "$count" -gt 0 ]; then
```

### 6.8.2 shfmt

Shell スクリプトのコードフォーマッター：

```bash
# インストール
brew install shfmt

# ファイルをフォーマット
shfmt -w scripts/sftp-push.sh

# フォーマットをチェック（CI/CD）
shfmt -d scripts/
```

### 6.8.3 bashdb

Bash デバッガー（ステップスルーデバッグ）：

```bash
# インストール
sudo apt install bashdb  # Linux

# デバッガーで実行
bashdb scripts/sftp-push.sh

# コマンド：
# n     - 次の行
# s     - 関数に入る
# c     - 続行
# p VAR - 変数を表示
# q     - 終了
```

### 6.8.4 strace / dtruss

システムコールをトレース：

```bash
# Linux - strace
strace -f ./sftp-push.sh 2>&1 | head -100

# macOS - dtruss
sudo dtruss ./sftp-push.sh 2>&1 | head -100

# デバッグに有用：
# - ファイルアクセスの失敗
# - 権限の問題
# - ネットワーク接続の問題
```

---

## 本章のまとめ

### 重要な概念

| 概念 | 説明 | 例 |
|---------|-------------|---------|
| `set -euo pipefail` | 厳格なエラーハンドリング | 本番スクリプト |
| `set -x` | デバッグトレースモード | トラブルシューティング |
| ログレベル | info/warn/error/debug | ユーザーコミュニケーション |
| Verbose モード | `-v` / `--verbose` フラグ | オンデマンドデバッグ出力 |
| `mktemp` | 安全な一時ファイル作成 | `/tmp/tmp.XXXXXXXXXX` |
| `trap` | 終了時にクリーンアップ | `trap cleanup EXIT` |
| ドライラン | 実行せずにプレビュー | `-n` / `--dry-run` |
| ShellCheck | 静的解析 | 実行前にバグを検出 |

### ベストプラクティスチェックリスト

- [ ] 本番スクリプトで常に `set -euo pipefail` を使用
- [ ] ログ関数を実装（info/warn/error/debug）
- [ ] デバッグ用に verbose モードを追加（`-v` フラグ）
- [ ] 一時ファイルに `mktemp` を使用、ハードコードパスは使用しない
- [ ] 一時ファイル作成後に `trap cleanup EXIT` を登録
- [ ] 続行前にすべての必須パラメータを検証
- [ ] `command -v` で必要なコマンドをチェック
- [ ] プレビュー用にドライランモードを追加（`-n` フラグ）
- [ ] コミット前に ShellCheck を実行
- [ ] 一貫した終了コードを使用

---

## 練習問題

### 練習問題 6-1: デバッグモードを追加

既存のスクリプトに verbose モードを追加：
1. `-v` / `--verbose` 引数解析を追加
2. verbose モードでのみ出力する `debug()` 関数を実装
3. デバッグステートメントを追加：
   - 使用されている設定値
   - 処理中のファイル
   - 実行中のコマンド

サンプル出力：
```
[sftp-push.sh] アップロード開始...
[デバッグ] 設定：host=example.com, user=deploy
[デバッグ] ファイル処理中：src/index.php
[sftp-push.sh] アップロード完了！
```

### 練習問題 6-2: ユニットテストを作成

JSON パース関数のテストファイルを作成：
1. `tests/test-json-parser.sh` を作成
2. テストケースを作成：
   - 既存キーの `json_get`
   - 不足キーの `json_get`（デフォルト値）
   - ネスト値の `json_get`
3. テストを実行し、すべて合格することを確認

### 練習問題 6-3: エラーリカバリを実装

アップロード関数に再試行ロジックを追加：
1. `MAX_RETRIES=3` を定義
2. 再試行ループでアップロードをラップ
3. 指数バックオフを追加（1 秒、2 秒、4 秒の遅延）
4. 再試行をログに記録

例：
```bash
upload_with_retry() {
    local file="$1"
    local retry=0

    while [ $retry -lt $MAX_RETRIES ]; do
        if sftp_put "$file"; then
            return 0
        fi
        retry=$((retry + 1))
        warn "再試行 $retry/$MAX_RETRIES..."
        sleep $((2 ** retry))
    done

    return 1
}
```

---

## 拡張リソース

### Shell デバッグガイド
- [Bash マニュアル：The Set Builtin](https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html)
- [ShellCheck ユーザーガイド](https://github.com/koalaman/shellcheck#user-content-gallery-of-bad-code)
- [Advanced Bash-Scripting Guide: Debugging](https://tldp.org/LDP/abs/html/debugging.html)

### ツール
- [ShellCheck](https://www.shellcheck.net/) - オンライン Shell スクリプトアナライザー
- [shfmt](https://github.com/mvdan/sh) - Shell コードフォーマッター
- [bashdb](http://bashdb.sourceforge.net/) - Bash デバッガー

### 副読本
- 「Writing Secure Shell Scripts」- OWASP ガイドライン
- 「Advanced Bash Error Handling」- trap、ERR シグナル
- 「Unit Testing in Shell」- bats などのテストフレームワーク

---

## 次章のプレビュー

**第 7 章：公開と配布**

第 7 章では、Skill を Plugin Marketplace に公開する方法を学びます：
- Plugin Marketplace アーキテクチャと要件
- `marketplace.json` 設定（すべてのフィールドを説明）
- Semantic Versioning（SemVer）仕様
- GitHub API を介した Release の作成
- 自動化リリースワークフロー（git → tag → release）
- 多言語 README 構造
- 公開前の Plugin 検証とテスト
- マーケットプレイスへの提出

第 7 章の終わりまでに、Skill を世界に公開する準備が整います！

---

## 本書について

**初版（デジタル版）, 2026 年 3 月**

**著者**: [toohamster](https://github.com/toohamster)
**ライセンス**: 電子版：MIT License | 印刷版/商業版：All Rights Reserved
**ソース**: [github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

詳細は [LICENSE](../../LICENSE) と [著者について](../authors.md) をご覧ください。

---
