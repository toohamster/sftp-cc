# 第 7 章：公開と配布

> 「共有された知識は増殖する」 — 匿名

この章では、次のことを学びます：
- Plugin Marketplace アーキテクチャと要件
- `marketplace.json` 設定（すべてのフィールドを説明）
- Semantic Versioning（SemVer）仕様
- GitHub API を介したリリース作成
- 自動化リリースワークフロー（git → tag → release）
- 多言語 README 構造
- 公開前の Plugin 検証
- 配布戦略

---

## 7.1 Plugin Marketplace アーキテクチャ

### 7.1.1 Marketplace の仕組み

Claude Code Plugin Marketplace は、ユーザーが閲覧してインストールできる Skill のキュレーションコレクションです。仕組みは次のとおりです：

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   開発者        │  →  │  GitHub リポジトリ│  →  │   Marketplace   │
│   （あなた）    │     │  （あなたのコード）│     │   （インデックス）│
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                                        ↓
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   ユーザー      │  ←  │  Plugin キャッシュ│  ←  │   インストール  │
│   （インストール）│     │  （~/.claude/）  │     │   コマンド      │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

### 7.1.2 インストールフロー

ユーザーがプラグインをインストールするとき：

1. **ユーザーがインストールコマンドを実行**：
   ```bash
   /plugin marketplace add https://github.com/toohamster/sftp-cc
   ```

2. **Claude Code がリポジトリを取得**：
   - `~/.claude/plugins/marketplaces/sftp-cc/` にクローン
   - `.claude-plugin/marketplace.json` を読み取り
   - 構造を検証

3. **プラグインが登録**：
   - `skills/` ディレクトリの Skill がロード
   - 自然言語トリガーで利用可能

4. **ユーザーが Skill を使用可能**：
   ```
   ユーザー：「コードをサーバーに同期」
   Claude: [sftp-push.sh を実行]
   ```

### 7.1.3 必須ディレクトリ構造

```
sftp-cc/
├── .claude-plugin/
│   └── marketplace.json    # マーケットプレイスに必須
├── skills/
│   └── sftp-cc/
│       └── SKILL.md        # 必須 Skill 定義
├── scripts/
│   ├── sftp-push.sh        # 実行スクリプト
│   ├── sftp-init.sh
│   └── sftp-keybind.sh
├── templates/
│   └── sftp-config.example.json
├── README.md               # ドキュメント（強く推奨）
└── LICENSE                 # ライセンスファイル（推奨）
```

**必須 vs オプション**：

| ファイル/ディレクトリ | 必須 | 目的 |
|---------------------|----------|---------|
| `.claude-plugin/marketplace.json` | **必須** | マーケットプレイスメタデータ |
| `skills/<name>/SKILL.md` | **必須** | Skill 定義 |
| `scripts/` | オプション | 外部スクリプト（インライン使用可能） |
| `README.md` | オプション（推奨） | ユーザードキュメント |
| `LICENSE` | オプション（推奨） | ライセンス情報 |
| `templates/` | オプション | 設定テンプレート |

---

## 7.2 marketplace.json 設定

### 7.2.1 完全な例

```json
{
  "name": "sftp-cc",
  "description": "Claude Code 用の汎用 SFTP アップロードツール。自然言語コマンドでコードをリモートサーバーに同期。",
  "author": "toohamster",
  "version": "1.2.0",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/toohamster/sftp-cc.git"
  },
  "homepage": "https://github.com/toohamster/sftp-cc",
  "keywords": [
    "sftp",
    "upload",
    "sync",
    "deployment",
    "ssh",
    "file-transfer"
  ],
  "engines": {
    "claude-code": ">=1.0.0"
  },
  "categories": [
    "productivity",
    "deployment",
    "file-operations"
  ]
}
```

### 7.2.2 フィールド別説明

#### `name`（必須）
- **型**：文字列
- **形式**：小文字、ハイフン許可
- **目的**：プラグインの一意な識別子

```json
{
  "name": "sftp-cc"  // ✓ 良い
}

{
  "name": "SFTP CC"  // ✗ 悪い：大文字、スペース
}
```

#### `description`（必須）
- **型**：文字列
- **最大長**：200 文字
- **目的**：マーケットプレイスリストに表示

```json
{
  "description": "Claude Code 用の汎用 SFTP アップロードツール。自然言語コマンドでコードをリモートサーバーに同期。"
}
```

**ヒント**：
- 何をするかで始める
- 主な利点を含める
- 簡潔に保つ

#### `author`（推奨）
- **型**：文字列
- **形式**：あなた名前または GitHub ユーザー名

```json
{
  "author": "toohamster"
}
```

#### `version`（必須）
- **型**：文字列
- **形式**：Semantic Version（SemVer）- セクション 7.3 を参照

```json
{
  "version": "1.2.0"  // MAJOR.MINOR.PATCH
}
```

#### `license`（推奨）
- **型**：文字列
- **形式**：SPDX ライセンス識別子

```json
{
  "license": "MIT"     // ✓ 一般的
}

{
  "license": "Apache-2.0"  // ✓ 一般的
}

{
  "license": "ISC"     // ✓ 有効
}
```

**一般的なライセンス**：

| ライセンス | 識別子 | 使用ケース |
|---------|------------|----------|
| MIT | `MIT` | 寛容、単純 |
| Apache 2.0 | `Apache-2.0` | 寛容、特許保護 |
| ISC | `ISC` | 寛容、MIT に類似 |
| GPL 3.0 | `GPL-3.0` | コピーレフト（ウイルス性） |

#### `repository`（推奨）
- **型**：オブジェクト
- **目的**：ソースコードへのリンク

```json
{
  "repository": {
    "type": "git",
    "url": "https://github.com/toohamster/sftp-cc.git"
  }
}
```

#### `homepage`（推奨）
- **型**：文字列
- **目的**：プロジェクトホームページ/ドキュメント

```json
{
  "homepage": "https://github.com/toohamster/sftp-cc"
}
```

#### `keywords`（オプション）
- **型**：文字列の配列
- **目的**：ユーザーがプラグインを見つけるのを支援

```json
{
  "keywords": [
    "sftp",
    "upload",
    "sync",
    "deployment",
    "ssh",
    "file-transfer"
  ]
}
```

#### `engines`（オプション）
- **型**：オブジェクト
- **目的**：Claude Code バージョン要件を指定

```json
{
  "engines": {
    "claude-code": ">=1.0.0"
  }
}
```

**バージョン指定子**：

| 指定子 | 意味 |
|-----------|---------|
| `>=1.0.0` | バージョン 1.0.0 以上 |
| `^1.0.0` | 1.x.x と互換（>=1.0.0, <2.0.0） |
| `~1.0.0` | 約 1.0.x（>=1.0.0, <1.1.0） |
| `1.0.0` | ちょうどバージョン 1.0.0 |

#### `categories`（オプション）
- **型**：文字列の配列
- **目的**：関連プラグインをグループ化

```json
{
  "categories": [
    "productivity",
    "deployment",
    "file-operations"
  ]
}
```

**一般的なカテゴリ**：
- `productivity` - ワークフローの改善
- `file-operations` - ファイル操作
- `deployment` - デプロイメントツール
- `code-generation` - コード作成
- `testing` - テストユーティリティ
- `documentation` - ドキュメント生成
- `integration` - 外部サービス

### 7.2.3 検証

公開前に `marketplace.json` を検証：

```bash
# JSON 構文をチェック
jq . .claude-plugin/marketplace.json

# または Python を使用
python3 -m json.tool .claude-plugin/marketplace.json

# 必須フィールドが存在することを確認
jq 'has("name") and has("description") and has("version")' .claude-plugin/marketplace.json
# true を返す必要がある
```

---

## 7.3 Semantic Versioning（SemVer）

### 7.3.1 SemVer 仕様

Semantic Versioning 2.0.0（SemVer）は、リリースの変更について意味を伝えるバージョニングスキームです。

**形式**：`MAJOR.MINOR.PATCH`

```
1.2.3
│ │ │
│ │ └─ PATCH: バグ修正（後方互換）
│ └─── MINOR: 新機能（後方互換）
└───── MAJOR: 破壊的変更
```

### 7.3.2 各バージョンのインクリメント時期

#### PATCH バージョン（`1.0.0` → `1.0.1`）

後方互換のバグ修正のためにインクリメント：

- 既存機能のバグを修正
- セキュリティパッチ
- パフォーマンスの改善（API 変更なし）
- ドキュメントの更新

**例**：
```
1.0.0 → 1.0.1  # JSON パーサーのヌルポインタを修正
1.0.0 → 1.0.1  # 資格情報ハンドリングのセキュリティパッチ
1.0.0 → 1.0.1  # エラーメッセージのタイプミスを修正
```

#### MINOR バージョン（`1.0.0` → `1.1.0`）

後方互換の新機能のためにインクリメント：

- 新しい Skill またはスクリプト
- 新しい設定オプション（デフォルト付き）
- 拡張機能（既存を壊さない）

**例**：
```
1.0.0 → 1.1.0  # ドライランモード（-n フラグ）を追加
1.0.0 → 1.1.0  # 日本語 i18n を追加
1.0.0 → 1.1.0  # 新しいスクリプト：sftp-copy-id.sh
```

#### MAJOR バージョン（`1.0.0` → `2.0.0`）

破壊的変更のためにインクリメント：

- Skill の削除または改名
- 設定ファイル形式の変更（既存の設定を壊す）
- 非互換な方法でのスクリプト動作の変更
- 非推奨機能の削除

**例**：
```
1.0.0 → 2.0.0  # 設定ファイル形式を変更
1.0.0 → 2.0.0  # 非推奨の "push" トリガーワードを削除
1.0.0 → 2.0.0  # デフォルトの remote_path 動作を変更
```

### 7.3.3 バージョン番号の例

| 從 | へ | 変更タイプ | 理由 |
|------|-----|-------------|------|
| 1.0.0 | 1.0.1 | PATCH | アップロジックのバグ修正 |
| 1.0.1 | 1.1.0 | MINOR | verbose モードを追加 |
| 1.1.0 | 1.1.1 | PATCH | verbose モード出力を修正 |
| 1.1.1 | 1.2.0 | MINOR | 日本語 i18n を追加 |
| 1.2.0 | 2.0.0 | MAJOR | 設定スキーマを変更 |
| 2.0.0 | 2.0.1 | PATCH | 移行スクリプトの修正 |

### 7.3.4 プリリースとビルドメタデータ

**プレリリースバージョン**（alpha、beta、RC）：

```
1.0.0-alpha.1    # 最初のアルファ
1.0.0-alpha.2    # 2 番目のアルファ
1.0.0-beta.1     # 最初のベータ
1.0.0-rc.1       # 最初のリリース候補
1.0.0-rc.2       # 2 番目のリリース候補
1.0.0            # 最終リリース
```

**ビルドメタデータ**：

```
1.0.0+20240101   # ビルド日
1.0.0+abc1234    # コミットハッシュ
1.0.0-beta.1+abc1234  # ビルド付きプレリリース
```

**注**：ビルドメタデータはバージョンの優先順位で無視される。

---

## 7.4 GitHub Release 自動化

### 7.4.1 リリースを自動化する理由

手動リリースはエラーが発生しやすい：
- ❌ タグの作成を忘れる
- ❌ タグのコミットが間違っている
- ❌ リリースノートが一貫していない
- ❌ リリースにファイルが missing

自動化リリースは：
- ✅ 一貫している
- ✅ 再現可能
- ✅ 追跡可能
- ✅ 高速

### 7.4.2 GitHub API 概要

GitHub はリリース作成のための REST API を提供：

**使用するエンドポイント**：

| エンドポイント | メソッド | 目的 |
|----------|--------|---------|
| `/git/refs` | POST | タグリファレンスを作成 |
| `/releases` | POST | リリースを作成 |
| `/repos/{owner}/{repo}` | GET | リポジトリ情報を取得 |

**認証**：
- パーソナルアクセストークン（PAT）または OAuth トークンを使用
- 必要なスコープ：`repo`（プライベートリポジトリの完全制御）

### 7.4.3 GitHub トークンの取得

#### 方法 1: Git 認証情報から

Git を認証している場合：

```bash
GITHUB_TOKEN=$(echo "url=https://github.com" | git credential fill | grep password | cut -d= -f2)
```

#### 方法 2: 環境変数から

```bash
# ~/.zshrc または ~/.bashrc に追加
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"

# スクリプトで使用
echo $GITHUB_TOKEN
```

#### 方法 3: パーソナルアクセストークンを作成

1. GitHub → 設定 → 開発者設定 → パーソナルアクセストークンに移動
2. 「新しいトークンを生成（クラシック）」をクリック
3. スコープを選択：`repo`（完全制御）
4. トークンを生成してコピー
5. 安全に保管（パスワードマネージャー、`~/.netrc` など）

### 7.4.4 API を介したタグの作成

**ステップ 1: 最新コミットハッシュを取得**

```bash
COMMIT_HASH=$(git rev-parse HEAD)
echo "最新コミット：$COMMIT_HASH"
```

**ステップ 2: 新しいバージョンを計算**

```bash
# 最後のタグを取得
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v1.0.0")

# バージョン番号を抽出
LAST_MAJOR=$(echo "$LAST_TAG" | sed 's/v\([0-9]*\)\.[0-9]*\.[0-9]*/\1/')
LAST_MINOR=$(echo "$LAST_TAG" | sed 's/v[0-9]*\.\([0-9]*\)\.[0-9]*/\1/')
LAST_PATCH=$(echo "$LAST_TAG" | sed 's/v[0-9]*\.[0-9]*\.\([0-9]*\)/\1/')

# PATCH バージョンをインクリメント
NEW_PATCH=$((LAST_PATCH + 1))
NEW_TAG="v${LAST_MAJOR}.${LAST_MINOR}.${NEW_PATCH}"

echo "新しいバージョン：$NEW_TAG"
```

**ステップ 3: タグリファレンスを作成**

```bash
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/toohamster/sftp-cc/git/refs \
  -d "{\"ref\":\"refs/tags/$NEW_TAG\",\"sha\":\"$COMMIT_HASH\"}"
```

**レスポンス（成功）**：
```json
{
  "ref": "refs/tags/v1.2.1",
  "object": {
    "sha": "abc123...",
    "type": "commit"
  }
}
```

### 7.4.5 API を介したリリースの作成

```bash
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/toohamster/sftp-cc/releases \
  -d "{
    \"tag_name\": \"$NEW_TAG\",
    \"target_commitish\": \"$COMMIT_HASH\",
    \"name\": \"$NEW_TAG - リリース\",
    \"body\": \"## 変更\\n\\n- 機能 1\\n- 機能 2\\n- バグ修正\\n\\n**完全な変更ログ**: https://github.com/toohamster/sftp-cc/compare/$LAST_TAG...$NEW_TAG\",
    \"draft\": false,
    \"prerelease\": false
  }"
```

**レスポンス（成功）**：
```json
{
  "id": 123456789,
  "tag_name": "v1.2.1",
  "name": "v1.2.1 - リリース",
  "html_url": "https://github.com/toohamster/sftp-cc/releases/tag/v1.2.1",
  "created_at": "2024-01-01T00:00:00Z"
}
```

### 7.4.6 完全なリリーススクリプト

```bash
#!/bin/bash
# scripts/release.sh
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m'

info() { echo -e "${GREEN}[$SCRIPT_NAME]${NC} $*"; }
error() { echo -e "${RED}[$SCRIPT_NAME] エラー:${NC} $*" >&2; }

# GitHub トークンを取得
GITHUB_TOKEN=$(echo "url=https://github.com" | git credential fill | grep password | cut -d= -f2)
if [ -z "$GITHUB_TOKEN" ]; then
    error "GitHub トークンの取得に失敗"
    exit 1
fi

# リポジトリ情報
REPO_OWNER="toohamster"
REPO_NAME="sftp-cc"

# 最新コミットを取得
COMMIT_HASH=$(git rev-parse HEAD)
info "最新コミット：$COMMIT_HASH"

# 最後のタグを取得
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v1.0.0")
info "最後のタグ：$LAST_TAG"

# 新しいバージョンを計算（PATCH をインクリメント）
LAST_MAJOR=$(echo "$LAST_TAG" | sed 's/v\([0-9]*\)\.[0-9]*\.[0-9]*/\1/')
LAST_MINOR=$(echo "$LAST_TAG" | sed 's/v[0-9]*\.\([0-9]*\)\.[0-9]*/\1/')
LAST_PATCH=$(echo "$LAST_TAG" | sed 's/v[0-9]*\.[0-9]*\.\([0-9]*\)/\1/')
NEW_PATCH=$((LAST_PATCH + 1))
NEW_TAG="v${LAST_MAJOR}.${LAST_MINOR}.${NEW_PATCH}"

info "新しいタグを作成：$NEW_TAG"

# タグを作成
TAG_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/git/refs \
  -d "{\"ref\":\"refs/tags/$NEW_TAG\",\"sha\":\"$COMMIT_HASH\"}")

if echo "$TAG_RESPONSE" | grep -q '"ref"'; then
    info "タグを作成：$NEW_TAG"
else
    error "タグの作成に失敗：$TAG_RESPONSE"
    exit 1
fi

# 変更ログを生成（最後のタグ以降のコミット）
CHANGELOG=$(git log "$LAST_TAG"..HEAD --pretty=format:"- %s" | head -20)
if [ -z "$CHANGELOG" ]; then
    CHANGELOG="- 最初のリリース"
fi

# リリースを作成
RELEASE_DATA=$(cat <<EOF
{
  "tag_name": "$NEW_TAG",
  "target_commitish": "$COMMIT_HASH",
  "name": "$NEW_TAG - リリース",
  "body": "## 変更点\n\n$CHANGELOG\n\n**完全な変更ログ**: https://github.com/$REPO_OWNER/$REPO_NAME/compare/$LAST_TAG...$NEW_TAG",
  "draft": false,
  "prerelease": false
}
EOF
)

RELEASE_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases \
  -d "$RELEASE_DATA")

if echo "$RELEASE_RESPONSE" | grep -q '"tag_name"'; then
    RELEASE_URL=$(echo "$RELEASE_RESPONSE" | grep -o '"html_url":"[^"]*"' | cut -d'"' -f4)
    info "リリースを作成：$RELEASE_URL"
else
    error "リリースの作成に失敗：$RELEASE_RESPONSE"
    exit 1
fi

info "リリース $NEW_TAG を公開しました！"
```

### 7.4.7 ワンコマンドリリース

コミット、プッシュ、リリースを結合：

```bash
#!/bin/bash
# scripts/commit-and-release.sh
set -euo pipefail

# 使用法：./commit-and-release.sh "feat: 新機能を追加"

if [ -z "${1:-}" ]; then
    echo "使用法：$0 \"コミットメッセージ\""
    exit 1
fi

COMMIT_MSG="$1"

# コミット
git add -A
git commit -m "$COMMIT_MSG

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"

# プッシュ
git push origin main

# リリース
bash scripts/release.sh
```

**使用法**：
```bash
./commit-and-release.sh "feat: ドライランモードを追加"
```

---

## 7.5 多言語 README

### 7.5.1 ディレクトリ構造

```
sftp-cc/
├── README.md           # 英語（デフォルト）
├── README_CN.md        # 簡体字中国語
├── README_JP.md        # 日本語
├── README_ES.md        # スペイン語（オプション）
└── README_DE.md        # ドイツ語（オプション）
```

### 7.5.2 英語 README.md 構造

````markdown
# sftp-cc

Universal SFTP upload tool for Claude Code.

## 機能

- 🚀 ワンコマンドでリモートサーバーにアップロード
- 🔄 増分同期（変更ファイルのみ）
- 🔐 自動 SSH 秘密鍵バインド
- 🌍 多言語サポート（EN/ZH/JA）

## インストール

```bash
/plugin marketplace add https://github.com/toohamster/sftp-cc
```

## クイックスタート

1. 秘密鍵を `.claude/sftp-cc/` に配置
2. 初期化を実行：
   ```bash
   bash scripts/sftp-init.sh --host example.com --username deploy --remote-path /var/www
   ```
3. コードをアップロード：
   ```
   ユーザー：「コードをサーバーに同期」
   ```

## 設定

`.claude/sftp-cc/sftp-config.json` を編集：

```json
{
  "host": "example.com",
  "port": 22,
  "username": "deploy",
  "remote_path": "/var/www"
}
```

## 使用法

| コマンド | 説明 |
|---------|-------------|
| `bash scripts/sftp-push.sh` | 変更ファイルをアップロード |
| `bash scripts/sftp-push.sh -n` | プレビューモード |
| `bash scripts/sftp-push.sh --full` | 完全アップロード |
| `bash scripts/sftp-init.sh` | 設定を初期化 |

## 他の言語

- [中文](README_CN.md)
- [日本語](README_JP.md)

## ライセンス

MIT License
````

### 7.5.3 中国語 README_CN.md 構造

````markdown
# sftp-cc

通用的 Claude Code SFTP 上传工具。

## 功能特性

- 🚀 一键上传到远程服务器
- 🔄 增量同步（仅上传变更文件）
- 🔐 自动绑定 SSH 私钥
- 🌍 多语言支持（中/英/日）

## 安装

```bash
/plugin marketplace add https://github.com/toohamster/sftp-cc
```

## 快速开始

1. 将私钥放入 `.claude/sftp-cc/` 目录
2. 初始化配置：
   ```bash
   bash scripts/sftp-init.sh --host example.com --username deploy --remote-path /var/www
   ```
3. 上传代码：
   ```
   User: "同步代码到服务器"
   ```

## 配置说明

编辑 `.claude/sftp-cc/sftp-config.json`：

```json
{
  "host": "example.com",
  "port": 22,
  "username": "deploy",
  "remote_path": "/var/www"
}
```

## 使用命令

| 命令 | 说明 |
|------|------|
| `bash scripts/sftp-push.sh` | 上传变更文件 |
| `bash scripts/sftp-push.sh -n` | 预览模式 |
| `bash scripts/sftp-push.sh --full` | 全量上传 |
| `bash scripts/sftp-init.sh` | 初始化配置 |

## 其他语言

- [English](README.md)
- [日本語](README_JP.md)

## 授权

MIT License
````

### 7.5.4 日本語 README_JP.md 構造

````markdown
# sftp-cc

Claude Code 用の汎用 SFTP アップロードツール

## 機能

- 🚀 ワンコマンドでリモートサーバーにアップロード
- 🔄 増分同期（変更ファイルのみ）
- 🔐 SSH 秘密鍵の自動バインド
- 🌍 多言語サポート（英語/中国語/日本語）

## インストール

```bash
/plugin marketplace add https://github.com/toohamster/sftp-cc
```

## クイックスタート

1. 秘密鍵を `.claude/sftp-cc/` に配置
2. 初期化：
   ```bash
   bash scripts/sftp-init.sh --host example.com --username deploy --remote-path /var/www
   ```
3. アップロード：
   ```
   ユーザー：「サーバーに同期する」
   ```

## 設定

`.claude/sftp-cc/sftp-config.json` を編集：

```json
{
  "host": "example.com",
  "port": 22,
  "username": "deploy",
  "remote_path": "/var/www"
}
```

## 使い方

| コマンド | 説明 |
|----------|------|
| `bash scripts/sftp-push.sh` | 変更ファイルをアップロード |
| `bash scripts/sftp-push.sh -n` | プレビューモード |
| `bash scripts/sftp-push.sh --full` | フルアップロード |
| `bash scripts/sftp-init.sh` | 設定を初期化 |

## 他の言語

- [English](README.md)
- [中文](README_CN.md)

## ライセンス

MIT License
````

### 7.5.5 言語リンク

各 README は他へのリンクを含める必要があります：

````markdown
## 他の言語

| 言語 | リンク |
|------|--------|
| 英語 | [README.md](README.md) |
| 中国語 | [README_CN.md](README_CN.md) |
| 日本語 | [README_JP.md](README_JP.md) |
````

---

## 7.6 Plugin 検証

### 7.6.1 公開前チェックリスト

公開前に検証：

```bash
# 1. marketplace.json を検証
jq . .claude-plugin/marketplace.json > /dev/null && echo "✓ JSON 有効"

# 2. 必須フィールドを確認
jq -e '.name and .description and .version' .claude-plugin/marketplace.json > /dev/null && echo "✓ 必須フィールドあり"

# 3. SKILL.md が存在することを確認
[ -f "skills/sftp-cc/SKILL.md" ] && echo "✓ SKILL.md が存在"

# 4. スクリプトが実行可能か確認
[ -x "scripts/sftp-push.sh" ] && echo "✓ スクリプト実行可能"

# 5. テンプレートの JSON を検証
jq . templates/sftp-config.example.json > /dev/null && echo "✓ テンプレート有効"

# 6. スクリプトで ShellCheck を実行
shellcheck scripts/*.sh && echo "✓ ShellCheck に合格"

# 7. ローカルでインストールをテスト
bash install.sh /tmp/test-project && echo "✓ インストール動作"
```

### 7.6.2 Claude Plugin Validator

Claude の組み込みバリデーターを使用：

```bash
claude plugin validate .
```

**予期される出力**：
```
✓ marketplace.json は有効
✓ SKILL.md が見つかり、適切にフォーマット
✓ すべてのスクリプトが実行可能
✓ プラグイン構造が正しい
```

### 7.6.3 テストインストールフロー

```bash
# テストプロジェクトを作成
mkdir -p /tmp/test-sftp-cc
cd /tmp/test-sftp-cc
git init

# プラグインをインストール（手動方法）
bash /path/to/sftp-cc/install.sh .

# 構造を確認
tree -a .claude/

# Skill をテスト
claude
# 発言：「こんにちは」または「コードを同期」
```

---

## 7.7 配布戦略

### 7.7.1 GitHub のみの配布

最も単純なアプローチ - GitHub でホスト：

```bash
# ユーザーがインストール：
/plugin marketplace add https://github.com/toohamster/sftp-cc
```

**利点**：
- ✅ 無料ホスティング
- ✅ 組み込みバージョン管理
- ✅ フィードバック用の Issue と PR
- ✅ リリース管理

**欠点**：
- ❌ GitHub アカウントが必要
- ❌ ユーザーは GitHub アクセスが必要

### 7.7.2 セルフホスト配布

独自のサーバーでプラグインファイルをホスト：

```
your-domain.com/
└── sftp-cc/
    ├── .claude-plugin/
    │   └── marketplace.json
    └── skills/
        └── sftp-cc/
            └── SKILL.md
```

**ユーザーがインストール**：
```bash
/plugin marketplace add https://your-domain.com/sftp-cc
```

**要件**：
- HTTPS 対応サーバー
- 静的ファイルホスティング
- CORS ヘッダー（必要な場合）

### 7.7.3 プライベート/内部配布

内部チーム使用：

```bash
# 内部サーバーにクローン
git clone git@github.com:your-org/sftp-cc-internal.git

# チームメンバーがインストール：
/plugin marketplace add /path/to/internal/sftp-cc
```

または内部 git サーバーを使用：
```bash
/plugin marketplace add git@internal-server:tools/sftp-cc.git
```

### 7.7.4 バージョンピン

安定したデプロイメントのために特定のバージョンにピン：

```bash
# 特定のタグをインストール
/plugin marketplace add https://github.com/toohamster/sftp-cc@v1.2.0

# または特定のブランチ
/plugin marketplace add https://github.com/toohamster/sftp-cc@stable
```

---

## 本章のまとめ

### 重要な概念

| 概念 | 説明 | 例 |
|---------|-------------|---------|
| `marketplace.json` | プラグインメタデータ | 名前、バージョン、ライセンス |
| SemVer | バージョン番号 | `1.2.3` = MAJOR.MINOR.PATCH |
| GitHub API | プログラムによるリリース作成 | `POST /releases` |
| リリース自動化 | コミット → タグ → リリース | ワンコマンドワークフロー |
| 多言語 README | 複数言語のドキュメント | README.md、README_CN.md |
| プラグイン検証 | 公開前チェックリスト | JSON、構造、スクリプト |
| 配布チャネル | ユーザーがプラグインを取得する方法 | GitHub、セルフホスト、内部 |

### 公開チェックリスト

- [ ] `marketplace.json` にすべての必須フィールドがある
- [ ] `SKILL.md` が存在し、適切にフォーマット
- [ ] すべてのスクリプトが ShellCheck に合格
- [ ] README.md が完成
- [ ] LICENSE ファイルが含まれている
- [ ] テストがローカルで合格
- [ ] バージョン番号がインクリメント
- [ ] GitHub Release が作成
- [ ] プラグインが正常に検証

---

## 練習問題

### 練習問題 7-1: marketplace.json を作成

Skill の完全な `marketplace.json` を作成：
1. `.claude-plugin/` ディレクトリを作成
2. すべてのフィールドを含む `marketplace.json` を作成：
   - name、description、version
   - author、license
   - repository、homepage
   - keywords、categories
3. `jq` で検証：
   ```bash
   jq . .claude-plugin/marketplace.json
   ```

### 練習問題 7-2: リリーススクリプトを作成

`scripts/release.sh` を作成：
1. 認証情報から GitHub トークンを取得
2. 新しいバージョン番号を計算
3. GitHub API を介してタグを作成
4. git log から変更ログを生成
5. GitHub API を介してリリースを作成
6. 成功時にリリース URL を表示

ドライランでテスト（`--dry-run` フラグを追加）。

### 練習問題 7-3: 多言語 README を作成

国際ドキュメントを追加：
1. 英語の `README.md` を作成
2. `README_CN.md`（中国語）を作成
3. `README_JP.md`（日本語）を作成
4. 各ファイルに言語リンクを追加
5. ブラウザで表示してテスト

---

## 拡張リソース

### GitHub API ドキュメント
- [GitHub REST API](https://docs.github.com/ja/rest)
- [リリースの作成](https://docs.github.com/ja/rest/releases/releases)
- [Git リファレンス API](https://docs.github.com/ja/rest/git/refs)

### Semantic Versioning
- [SemVer 2.0.0 仕様](https://semver.org/lang/ja/)
- [Semantic Versioning の説明](https://blog.npmjs.org/post/617484925549558784/semantic-versioning)

### プラグイン例
- [sftp-cc リポジトリ](https://github.com/toohamster/sftp-cc)
- [Claude Code Plugin Marketplace](https://claude.ai/marketplace)

### 副読本
- 「Writing Great Release Notes」- Keep a Changelog
- 「GitHub Actions for CI/CD」- ワークフローの自動化
- 「Open Source Licensing」- ライセンスの選択

---

## 次章のプレビュー

**第 8 章：トピックとベストプラクティス**

第 8 章では、高度なトピックをカバーします：
- パフォーマンス最適化テクニック
- セキュリティベストプラクティス（コマンドインジェクションを回避）
- コード組織と命名規則
- `trap` を使用した高度なエラーハンドリング
- よくある問題のトラブルシューティング
- 実世界のケーススタディ
- パフォーマンスプロファイリング

第 8 章の終わりまでに、本番対応の Skill を書けるようになります！

---

## 本書について

**初版（デジタル版）, 2026 年 3 月**

**著者**: [toohamster](https://github.com/toohamster)
**ライセンス**: 電子版：MIT License | 印刷版/商業版：All Rights Reserved
**ソース**: [github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

詳細は [LICENSE](../../LICENSE) と [著者について](../authors.md) をご覧ください。

---
