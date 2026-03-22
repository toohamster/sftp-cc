# 第 5 章：国際化 (i18n)

> 「言語は文化への窓である。複数の言語を知ることは、複数の窓を持つようなものだ」 — フランク・スミス

この章では、次のことを学びます：
- 多言語サポートの重要性
- 変数式多言語ソリューション
- gettext を使わない理由
- i18n.sh の実装
- 言語検出と切り替え
- スクリプトでの使用方法
- ベストプラクティス

---

## 5.1 多言語の理由

### 5.1.1 ユーザーエクスペリエンス優先

ユーザーが Skill を使用する際、出力は彼らの馴染みのある言語であるべきです：

**シナリオ**：
- 英語ユーザー：`"Upload complete!"` → 自然に理解
- 中国語ユーザー：`"上传完成！"` → 母国語で安心
- 日本語ユーザー：`"アップロード完了！"` → 親切な表示

**なぜ重要か**：
1. **アクセシビリティ**: 英語が得意でないユーザーにも親切
2. **エラー理解**: 問題発生時に母国語だと理解しやすい
3. **プロフェッショナル**: 国際的な製品としての品質
4. **ユーザーベース拡大**: より広い層に受け入れられる

### 5.1.2 i18n 原則

sftp-cc の国際化は次の原則に従います：

| 原則 | 説明 | 実装 |
|------|------|------|
| **ユーザー言語優先** | 設定に基づいて自動切り替え | `config.json` の `language` フィールド |
| **外部依存ゼロ** | gettext なし、Python なし | 純粋な Shell 実装 |
| **シンプルで保守可能** | 複雑な枠組み不使用 | 変数式ソリューション |
| **フォールバック** | 未サポート言語は英語 | デフォルト言語 |

**i18n とは**：
- 「internationalization」の略（18 文字を省略）
- ソフトウェアを複数の言語・文化に適応
- 単なる翻訳ではなく、文化・形式も含む

---

## 5.2 変数式多言語ソリューション

### 5.2.1 gettext を選ばない理由

一般的な i18n フレームワーク gettext と比較：

| 項目 | gettext | 変数式ソリューション |
|------|---------|-------------------|
| 外部依存 | 必要（システムインストール） | なし |
| ファイル形式 | .po/.mo バイナリ | 通常のスクリプト |
| 学習曲線 | 複雑（msgstr など） | 通常の変数 |
| Shell 互換性 | 追加ツール必要 | ネイティブサポート |
| デバッグ | 難しい（バイナリ） | 簡単（テキスト） |

**結論**：
- Shell スクリプトにはオーバーキル
- 依存関係を増やすだけ
- 単純な変数で十分

### 5.2.2 コアコンセプト

変数式ソリューションの基本：

```bash
# 定義ステージ（言語別にロード）
MSG_UPLOAD_COMPLETE="上传完成！"

# 使用ステージ（直接参照）
info "$MSG_UPLOAD_COMPLETE"

# パラメータ付き（printf を使用）
printf "$MSG_UPLOADING_FILES" "10" "server:/var/www"
```

**メリット**：
1. **シンプル**: 通常の変数代入
2. **直接**: フレームワーク不要
3. **軽量**: 追加ファイル不要
4. **デバッグ容易**: 値が見える

### 5.2.3 変数名付け規則

一貫した命名規則：

```bash
# 接頭辞：MSG_（メッセージ）
MSG_UPLOAD_COMPLETE      # アップロード完了
MSG_UPLOADING_FILES      # ファイルをアップロード中
MSG_CONNECTION_FAILED    # 接続失敗
MSG_CONFIG_NOT_FOUND     # 設定が見つからない

# 構造：MSG_ + 機能 + 状態
MSG_ + UPLOAD + COMPLETE
MSG_ + CONNECTION + FAILED
```

**規則**：
- 大文字を使用（定数）
- 単語をアンダースコアで区切る
- 機能を先に、状態を後に

---

## 5.3 i18n.sh 実装

### 5.3.1 全体構造

```bash
#!/bin/bash
# i18n.sh - 多言語サポート
# 使用方法：source i18n.sh; init_lang "$CONFIG_FILE"

#######################################
# グローバルメッセージ変数
#######################################
MSG_UPLOAD_COMPLETE=""
MSG_UPLOADING_FILES=""
MSG_CONNECTION_FAILED=""
MSG_CONFIG_NOT_FOUND=""
# ... 他のメッセージ

#######################################
# 設定から言語を初期化
#######################################
init_lang() {
    local config_file="$1"
    local lang=""

    # 設定から言語を読み取り
    if [ -f "$config_file" ]; then
        lang=$(grep '"language"' "$config_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    fi

    # デフォルトは英語
    if [ -z "$lang" ] || [ "$lang" = "null" ]; then
        lang="en"
    fi

    # メッセージをロード
    load_messages "$lang"
}

#######################################
# 言語別メッセージをロード
#######################################
load_messages() {
    local lang="$1"

    case "$lang" in
        zh|zh_CN|zh_TW)
            # 中国語
            MSG_UPLOAD_COMPLETE="上传完成！"
            MSG_UPLOADING_FILES="正在上传 %d 个文件到 %s..."
            MSG_CONNECTION_FAILED="SFTP 连接失败"
            MSG_CONFIG_NOT_FOUND="配置文件未找到"
            ;;
        ja|ja_JP)
            # 日本語
            MSG_UPLOAD_COMPLETE="アップロード完了！"
            MSG_UPLOADING_FILES="%d 個のファイルを %s にアップロード中..."
            MSG_CONNECTION_FAILED="SFTP 接続に失敗しました"
            MSG_CONFIG_NOT_FOUND="設定ファイルが見つかりません"
            ;;
        *)
            # デフォルト（英語）
            MSG_UPLOAD_COMPLETE="Upload complete!"
            MSG_UPLOADING_FILES="Uploading %d files to %s..."
            MSG_CONNECTION_FAILED="SFTP connection failed"
            MSG_CONFIG_NOT_FOUND="Configuration file not found"
            ;;
    esac
}
```

### 5.3.2 言語検出

```bash
#######################################
# 設定から言語を検出
# 引数：
#   $1 - 設定ファイルパス
# 出力：
#   言語コード
#######################################
detect_language() {
    local config_file="$1"
    local lang=""

    # ファイルが存在すれば読み取り
    if [ -f "$config_file" ]; then
        lang=$(grep '"language"' "$config_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    fi

    # 空または null の場合はデフォルト
    if [ -z "$lang" ] || [ "$lang" = "null" ]; then
        echo "en"
    else
        echo "$lang"
    fi
}
```

### 5.3.3 言語コードの正規化

ユーザー入力を正規化：

```bash
#######################################
# 言語コードを正規化
# 引数：
#   $1 - 言語コード
# 出力：
#   正規化されたコード
#######################################
normalize_lang() {
    local lang="$1"

    # 大文字を小文字に変換
    lang=$(echo "$lang" | tr '[:upper:]' '[:lower:]')

    # エイリアスを処理
    case "$lang" in
        chinese|chinese_cn|zh-cn|zh_cn)
            echo "zh"
            ;;
        japanese|ja-jp|ja_jp)
            echo "ja"
            ;;
        english|en-us|en_gb|en-uk)
            echo "en"
            ;;
        *)
            # 不明なコードはそのまま
            echo "$lang"
            ;;
    esac
}
```

### 5.3.4 完全な i18n.sh

```bash
#!/bin/bash
# i18n.sh - 多言語サポート（完全版）

#######################################
# グローバルメッセージ変数
#######################################
MSG_UPLOAD_COMPLETE=""
MSG_UPLOADING_FILES=""
MSG_CONNECTION_FAILED=""
MSG_CONFIG_NOT_FOUND=""
MSG_INITIALIZING_CONFIG=""
MSG_SECRET_KEY_BOUND=""
MSG_PERMISSION_FIXED=""
MSG_NO_FILES_TO_UPLOAD=""
MSG_PREVIEW_MODE=""
MSG_TOTAL_FILES=""
MSG_SFTP_TARGET=""

#######################################
# 設定から言語を初期化
#######################################
init_lang() {
    local config_file="${1:-}"

    # 設定ファイルが指定されていない場合はデフォルト
    if [ -z "$config_file" ] || [ ! -f "$config_file" ]; then
        load_messages "en"
        return
    fi

    # 設定から言語を読み取り
    local lang
    lang=$(grep '"language"' "$config_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

    # デフォルトは英語
    if [ -z "$lang" ] || [ "$lang" = "null" ]; then
        lang="en"
    fi

    # メッセージをロード
    load_messages "$lang"
}

#######################################
# 言語別メッセージをロード
#######################################
load_messages() {
    local lang="$1"

    # 言語コードを正規化（最初の 2 文字）
    lang="${lang:0:2}"

    case "$lang" in
        zh)
            # 中国語（簡体字）
            MSG_UPLOAD_COMPLETE="上传完成！"
            MSG_UPLOADING_FILES="正在上传 %d 个文件到 %s..."
            MSG_CONNECTION_FAILED="SFTP 连接失败"
            MSG_CONFIG_NOT_FOUND="配置文件未找到，请先运行初始化"
            MSG_INITIALIZING_CONFIG="正在初始化配置..."
            MSG_SECRET_KEY_BOUND="秘密键已绑定"
            MSG_PERMISSION_FIXED="权限已修正为 600"
            MSG_NO_FILES_TO_UPLOAD="没有要上传的文件"
            MSG_PREVIEW_MODE="[预览模式] 将上传 %d 个文件"
            MSG_TOTAL_FILES="共 %d 个文件"
            MSG_SFTP_TARGET="SFTP 目标：%s@%s:%s"
            ;;
        ja)
            # 日本語
            MSG_UPLOAD_COMPLETE="アップロード完了！"
            MSG_UPLOADING_FILES="%d 個のファイルを %s にアップロード中..."
            MSG_CONNECTION_FAILED="SFTP 接続に失敗しました"
            MSG_CONFIG_NOT_FOUND="設定ファイルが見つかりません。最初に初期化を実行してください。"
            MSG_INITIALIZING_CONFIG="設定を初期化中..."
            MSG_SECRET_KEY_BOUND="秘密鍵がバインドされました"
            MSG_PERMISSION_FIXED="権限を 600 に修正しました"
            MSG_NO_FILES_TO_UPLOAD="アップロード対象ファイルはありません"
            MSG_PREVIEW_MODE="[プレビューモード] %d 個のファイルをアップロード予定"
            MSG_TOTAL_FILES="合計 %d 個のファイル"
            MSG_SFTP_TARGET="SFTP ターゲット：%s@%s:%s"
            ;;
        *)
            # デフォルト（英語）
            MSG_UPLOAD_COMPLETE="Upload complete!"
            MSG_UPLOADING_FILES="Uploading %d files to %s..."
            MSG_CONNECTION_FAILED="SFTP connection failed"
            MSG_CONFIG_NOT_FOUND="Configuration file not found. Please run initialization first."
            MSG_INITIALIZING_CONFIG="Initializing configuration..."
            MSG_SECRET_KEY_BOUND="Secret key bound successfully"
            MSG_PERMISSION_FIXED="Permission fixed to 600"
            MSG_NO_FILES_TO_UPLOAD="No files to upload"
            MSG_PREVIEW_MODE="[Preview Mode] Would upload %d files"
            MSG_TOTAL_FILES="Total %d files"
            MSG_SFTP_TARGET="SFTP target: %s@%s:%s"
            ;;
    esac
}

#######################################
# メッセージを取得（直接呼び出し用）
# 引数：
#   $1 - メッセージ変数名（接頭辞なし）
# 出力：
#   メッセージ値
#######################################
msg() {
    local key="$1"
    local var_name="MSG_$key"
    echo "${!var_name}"
}
```

---

## 5.4 スクリプトで i18n を使用

### 5.4.1 基本的な使用方法

```bash
#!/bin/bash
# sftp-push.sh

set -euo pipefail

# スクリプトディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# i18n をソース
source "$SCRIPT_DIR/i18n.sh"

# 設定ファイルパス
CONFIG_FILE="$PROJECT_ROOT/.claude/sftp-cc/sftp-config.json"

# 言語を初期化
init_lang "$CONFIG_FILE"

# メッセージを使用
info "$MSG_UPLOAD_COMPLETE"
```

### 5.4.2 パラメータ付きメッセージ

```bash
# 変数定義
count=5
target="deploy@example.com:/var/www"

# printf でフォーマット
info "$(printf "$MSG_UPLOADING_FILES" "$count" "$target")"

# 出力例（日本語）：
# [sftp-push.sh] 5 個のファイルを deploy@example.com:/var/www にアップロード中...
```

### 5.4.3 実装例：完全な統合

```bash
#!/bin/bash
# sftp-push.sh - 多言語サポート付き

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# 色
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

info() { echo -e "${GREEN}[$SCRIPT_NAME]${NC} $*" >&2; }
error() { echo -e "${RED}[$SCRIPT_NAME] エラー:${NC} $*" >&2; }

# i18n をロード
source "$SCRIPT_DIR/i18n.sh"

# 設定
CONFIG_FILE="$PROJECT_ROOT/.claude/sftp-cc/sftp-config.json"
init_lang "$CONFIG_FILE"

# メインロジック
main() {
    info "$MSG_INITIALIZING_CONFIG"

    # 設定チェック
    if [ ! -f "$CONFIG_FILE" ]; then
        error "$MSG_CONFIG_NOT_FOUND"
        exit 1
    fi

    # アップロード処理
    local count=5
    local target="server:/var/www"

    if [ "$count" -eq 0 ]; then
        info "$MSG_NO_FILES_TO_UPLOAD"
        return 0
    fi

    info "$(printf "$MSG_UPLOADING_FILES" "$count" "$target")"

    # ... アップロードロジック ...

    info "$MSG_UPLOAD_COMPLETE"
}

main "$@"
```

---

## 5.5 言語設定

### 5.5.1 sftp-config.json

```json
{
  "host": "example.com",
  "port": 22,
  "username": "deploy",
  "remote_path": "/var/www/html",
  "language": "ja",
  "excludes": [".git", ".claude", "node_modules"]
}
```

### 5.5.2 サポート言語

| コード | 言語 | 別名 |
|------|----------|------|
| `en` | 英語（デフォルト） | `en_US`, `en_GB`, `english` |
| `zh` | 中国語（簡体字） | `zh_CN`, `zh_TW`, `chinese` |
| `ja` | 日本語 | `ja_JP`, `japanese` |

### 5.5.3 言語の追加

新しい言語を追加する方法：

```bash
load_messages() {
    local lang="$1"
    lang="${lang:0:2}"

    case "$lang" in
        zh)
            # 中国語
            MSG_UPLOAD_COMPLETE="上传完成！"
            ;;
        ja)
            # 日本語
            MSG_UPLOAD_COMPLETE="アップロード完了！"
            ;;
        ko)
            # 韓国語（新規追加）
            MSG_UPLOAD_COMPLETE="업로드 완료!"
            MSG_UPLOADING_FILES="%d 개의 파일을 %s 에 업로드 중..."
            MSG_CONNECTION_FAILED="SFTP 연결 실패"
            ;;
        es)
            # スペイン語（新規追加）
            MSG_UPLOAD_COMPLETE="¡Carga completa!"
            MSG_UPLOADING_FILES="Subiendo %d archivos a %s..."
            MSG_CONNECTION_FAILED="Conexión SFTP fallida"
            ;;
        *)
            # デフォルト（英語）
            MSG_UPLOAD_COMPLETE="Upload complete!"
            ;;
    esac
}
```

---

## 5.6 ベストプラクティス

### 5.6.1 メッセージ設計

**良いメッセージ**：
```bash
✅ 具体的：
MSG_CONFIG_NOT_FOUND="設定ファイルが見つかりません。最初に初期化を実行してください。"

✅ 親切：
MSG_SECRET_KEY_BOUND="秘密鍵がバインドされました。アップロード準備完了！"

✅ 一貫：
すべてのメッセージが同じトーン（丁寧）
```

**悪いメッセージ**：
```bash
❌ 曖昧：
MSG_ERROR="エラーが発生しました"

❌ 失礼：
MSG_WRONG_INPUT="間違っている"

❌ 技術的すぎる：
MSG_ERRNO_13="Permission denied (13)"
```

### 5.6.2 プレースホルダー

```bash
# 数値：'%d'
MSG_FILE_COUNT="%d 個のファイル"
printf "$MSG_FILE_COUNT" "10"  # 10 個のファイル

# 文字列：'%s'
MSG_TARGET="ターゲット：%s"
printf "$MSG_TARGET" "server:/path"  # ターゲット：server:/path

# 複数：
MSG_FULL="%d 個のファイルを %s にアップロード"
printf "$MSG_FULL" "5" "server:/www"  # 5 個のファイルを server:/www にアップロード
```

### 5.6.3 翻訳の品質

**チェックリスト**：
- [ ] 文法が正しい
- [ ] 専門用語が一貫
- [ ] トーンが統一
- [ ] 長さが適切（短すぎず、長すぎず）
- [ ] 文化的に適切

**翻訳サービス**：
- 自作（バイリンガル）
- DeepL / Google Translate（下訳）
- ネイティブチェック（推奨）

---

## 本章のまとめ

### 重要な概念

| 概念 | 説明 |
|---------|-------------|
| **変数式ソリューション** | gettext なし、純粋な Shell |
| **MSG_変数** | 言語別メッセージを格納 |
| **init_lang()** | 設定から言語を検出 |
| **load_messages()** | 言語別メッセージをロード |
| **printf フォーマット** | パラメータ付きメッセージ |

### 実装チェックリスト

- [ ] i18n.sh を作成
- [ ] メッセージ変数を定義
- [ ] `load_messages()` で言語別メッセージ
- [ ] `init_lang()` で自動検出
- [ ] スクリプトで `source` して使用
- [ ] デフォルト言語（英語）を設定

---

## 練習問題

### 練習問題 5-1: i18n.sh を作成

多言語サポートを実装：
1. `i18n.sh` ファイルを作成
2. 10 個以上のメッセージ変数を定義
3. 英語、中国語、日本語をサポート
4. `init_lang()` 関数を実装

### 練習問題 5-2: スクリプトに統合

既存スクリプトに i18n を追加：
1. `source i18n.sh` を追加
2. ハードコードメッセージを置き換え
3. `printf` でパラメータ処理

### 練習問題 5-3: 新しい言語を追加

4 つ目の言語を追加：
1. 言語を選択（韓国語、スペイン語など）
2. 全メッセージを翻訳
3. `load_messages()` にケースを追加
4. テスト

---

## 拡張リソース

### i18n リソース
- [Unicode CLDR](https://cldr.unicode.org/) - 言語データ
- [ISO 639-1 Codes](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes) - 言語コード

### 翻訳ツール
- [DeepL](https://www.deepl.com/) - 高精度翻訳
- [Google Translate](https://translate.google.com/) - 多言語対応

### 副読本
- 「Internationalization Best Practices」- W3C
- 「Software Localization」-  localization ガイド

---

## 次章のプレビュー

**第 6 章：デバッグとテスト**

第 6 章ではデバッグとテスト技術を学びます：
- Shell スクリプトデバッグ基礎（`set` オプション）
- ログレベル設計
- Verbose モード実装
- 一時ファイル管理
- エラーハンドリングパターン
- テスト方法（ユニット、統合、dry-run）
- 実世界デバッグケース

---

## 本書について

**初版（デジタル版）, 2026 年 3 月**

**著者**: [toohamster](https://github.com/toohamster)
**ライセンス**: 電子版：MIT License | 印刷版/商業版：All Rights Reserved
**ソース**: [github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

詳細は [LICENSE](../../LICENSE) と [著者について](../authors.md) をご覧ください。

---
