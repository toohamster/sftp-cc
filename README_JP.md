# sftp-cc

[English Documentation](README.md) | [中文文档](README_CN.md)

Claude Code 用の汎用 SFTP アップロードツール。増分アップロード、秘密鍵の自動バインド、権限修正をサポートします。

**外部依存関係ゼロ** — ピュアシェル実装。システム標準の `sftp`、`git`、`grep`、`sed` のみで動作します。

## 多言語サポート

このツールは **英語（English）**、**中国語（中文）**、**日本語** をサポートしています。

言語はインタラクティブ初期化時に設定するか、設定ファイルを編集して変更します。

## なぜこのツールを作ったか

PhpStorm を使っていた頃、内置の SFTP 拡張機能がファイルの変更を自動的に開発サーバーに同期してくれていました。作成、変更、削除、すべてシームレスに動作します。しかし Claude Code に乗り換えて後、その機能を失いました。Claude がコードを変更するたびに、テストサーバーで手動でプルする必要があり、その摩擦が開発スピードを大きく低下させました。このツールはその自動同期体験を Claude Code に持ち込むために作りました。ただ「sync code to server」と言うだけで完了します。

## インストール

### 方法 1: Plugin Marketplace（推奨）

```bash
# マーケットプレイスを追加
/plugin marketplace add https://github.com/toohamster/sftp-cc

# プラグインをインストール
/plugin install sftp-cc@sftp-cc
```

### 方法 2: 手動インストール

```bash
# リポジトリをクローン
git clone https://github.com/toohamster/sftp-cc.git

# プロジェクトにインストール
bash sftp-cc/install.sh /path/to/your-project
```

手動インストール後のディレクトリ構造：
```
your-project/
├── .claude/
│   ├── skills/
│   │   └── sftp-cc/
│   │       ├── skill.md
│   │       └── scripts/
│   └── sftp-cc/
│       ├── sftp-config.json    ← サーバー設定
│       └── id_rsa              ← あなたの秘密鍵
```

## 設定

### ステップ 1: サーバー設定の初期化

**方法 A: インタラクティブモード（推奨）**

引数なしで実行すると、インタラクティブモードになります：

```bash
# Plugin インストール後
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-init.sh

# 手動インストール後
bash .claude/skills/sftp-cc/scripts/sftp-init.sh
```

スクリプトが以下の情報を尋ねます：
- SFTP サーバーアドレス
- SFTP ポート（デフォルト：22）
- ログインユーザー名
- リモートターゲットパス
- 言語選択（English / 中文 / 日本語）
- SSH 秘密鍵パス（オプション、例：`~/.ssh/id_rsa`）

秘密鍵ファイルが存在する場合、自動的に `.claude/sftp-cc/` にコピーされます。

**方法 B: コマンドライン引数**

```bash
# Plugin インストール後
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-init.sh \
  --host your-server.com \
  --username deploy \
  --remote-path /var/www/html \
  --language ja \
  --private-key ~/.ssh/id_rsa

# 手動インストール後
bash .claude/skills/sftp-cc/scripts/sftp-init.sh \
  --host your-server.com \
  --username deploy \
  --remote-path /var/www/html \
  --language ja \
  --private-key ~/.ssh/id_rsa
```

### ステップ 2: SSH 公開鍵をサーバーにデプロイ

**方法 A: ネイティブターミナルで実行（推奨）**

ターミナルを開いて実行：
```bash
# Plugin インストール後
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-copy-id.sh

# 手動インストール後
bash .claude/skills/sftp-cc/scripts/sftp-copy-id.sh
```

**方法 B: ssh-copy-id を直接使用**
```bash
# 公開鍵を見つける（通常 ~/.ssh/id_ed25519.pub または ~/.ssh/id_rsa.pub）
ssh-copy-id -i ~/.ssh/id_ed25519.pub username@your-server.com
```

**方法 C: 手動デプロイ**
```bash
# 公開鍵の内容をコピー
cat ~/.ssh/id_ed25519.pub | pbcopy  # macOS
# または
cat ~/.ssh/id_ed25519.pub | xclip -selection clipboard  # Linux

# SSH でサーバーにログインし、authorized_keys に貼り付け
ssh username@your-server.com
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys  # 公開鍵の内容を貼り付け
chmod 600 ~/.ssh/authorized_keys
```

このワンタイム設定で、SFTP アップロード用のパスワードレス SSH 認証が有効になります。

### ステップ 3: 秘密鍵を配置

```bash
cp ~/.ssh/id_rsa .claude/sftp-cc/
```

**秘密鍵の自動バインド：**

- `sftp-init.sh` 実行**前**に鍵を配置した場合 → 自動でバインドされます
- `sftp-init.sh` 実行**後**に鍵を配置した場合 → 手動でバインド：

  **方法 A: Claude に実行させる（推奨）**

  プロジェクト内で Claude に伝える：
  > "bind SFTP private key"

  **方法 B: スクリプトを直接実行**

  ```bash
  # Plugin インストール後
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-keybind.sh

  # 手動インストール後
  bash .claude/skills/sftp-cc/scripts/sftp-keybind.sh
  ```

鍵は自動検出され、設定に自動バインドされ、権限が自動的に `600` に修正されます。

サポートされている鍵フォーマット：`id_rsa`、`id_ed25519`、`id_ecdsa`、`*.pem`、`*.key`

## 使い方

Claude Code で自然言語でトリガー：

- "sync code to server"
- "upload files to server"
- "deploy code to server"
- "sftp upload"
- "sftp sync"

**注意**: "push" は `git push` との競合を避けるため、このスキルをトリガーしません。

スクリプトを直接呼び出すこともできます：

```bash
# 増分アップロード（デフォルト、変更されたファイルのみ）
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh

# 増分アップロード + ローカルで削除されたファイルをリモートでも削除
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh --delete

# 完全アップロード（すべてのファイル）
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh --full

# 特定のファイルをアップロード
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh src/index.php

# 特定のディレクトリをアップロード
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh -d src/

# ドライラン（プレビューのみ）
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh -n
```

## 増分アップロード

- 各アップロード成功後、現在の git コミットハッシュが `.claude/sftp-cc/.last-push` に保存されます
- 次回アップロード時、`git diff` で前回のアップロードからの変更を検出 — 変更/新規ファイルのみアップロード
- 一時停止された変更、未停止の変更、未トラックの新規ファイルを検出
- 初回実行時またはマーカーがない場合、完全アップロードにフォールバック
- `--full` で強制完全アップロード
- `--delete` でローカルで削除されたファイルをリモートでも同期削除（デフォルトではオフ、誤操作防止）

## 依存関係

- `sftp` — SSH ファイル転送（システム標準）
- `git` — プロジェクトルート検出と増分変更検出
- **jq は不要** — ピュアシェル JSON パース

## セキュリティ

- `.claude/sftp-cc/` ディレクトリには秘密鍵とサーバー情報が含まれ、自動的に `.gitignore` に追加されます
- 秘密鍵の権限は自動的に `600` に修正されます

## トラブルシューティングと注意事項

### よくある問題

**1. Plugin インストール後「秘密鍵をバインドする」が機能しない**

Plugin Marketplace からインストールした後、Claude に「绑定 SFTP 私钥（秘密鍵をバインドする）」と言っても反応がない場合：

```
# Plugin を再インストールして最新の SKILL.md を読み込む
/plugin marketplace remove sftp-cc
/plugin marketplace add https://github.com/toohamster/sftp-cc
```

これで Claude Code が秘密鍵バインドのトリガーキーワードを正しく認識します。

**2. 秘密鍵の権限が拒否される**

スクリプトは自動的に `chmod 600` を実行して権限を修正します。それでもエラーが出る場合：
```bash
chmod 600 .claude/sftp-cc/id_ed25519
```

**3. 公開鍵をデプロイしても SFTP 認証が失敗する**

`sftp-copy-id.sh` は **Claude Code 内部ではなく、ローカルターミナルで** 実行してください。このスクリプトは対話的なパスワード入力が必要です。

**4. 初回アップロードですべてのファイルがアップロードされる**

これは正常な動作です。増分アップロードは、初回の成功したアップロード後に `.last-push` マーカーファイルが作成されてから有効になります。

**5. 「push」と言ってもアップロードがトリガーされない**

これは `git push` との競合を避けるための設計です。「sync code to server」や「sftp upload」などの明確な表現を使用してください。

### インストールの注意事項

- **Plugin インストール（推奨）**：スクリプトの場所 `${CLAUDE_PLUGIN_ROOT}/scripts/`
- **手動インストール**：スクリプトは `.claude/skills/sftp-cc/scripts/` にコピーされます
- 両方のインストール方式で共通の設定ディレクトリ：`.claude/sftp-cc/`

### 設定の注意事項

- `.claude/sftp-cc/` ディレクトリは常に `.gitignore` に含めてください（機密情報が含まれます）
- 言語設定（`en`/`zh`/`ja`）は `sftp-config.json` に保存されます
- `private_key` フィールドは `sftp-keybind.sh` によって自動的に設定されます — 手動編集不要
