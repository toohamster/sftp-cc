# 第 3 章：初めての Skill を書く

> 「完璧になるまでには、まず存在しなければならない」 — ウォルト・ディズニー

この章では、次のことを学びます：
- SKILL.md の完全な構造
- YAML frontmatter の書き方
- トリガーワードの設計
- スクリプトパスの説明
- 実行指示の記述
- ユーザーガイドの作成
- デバッグのヒント

---

## 3.1 SKILL.md 構造

### 3.1.1 完全な例

sftp-cc の実際の SKILL.md を見てみましょう：

````markdown
---
name: sftp-cc
description: 汎用 SFTP アップロードツール、自然言語でトリガー、ローカルプロジェクトファイルをリモートサーバーにアップロード。増分アップロード、自動秘密鍵バインド、権限修正をサポート。
---

# SFTP Push Skill — sftp-cc

> 自動秘密鍵バインドと権限修正付きの汎用 SFTP アップロードツール。

## トリガー

**SFTP アップロード/デプロイ**:
- "sync code to server"
- "upload to server"
- "deploy code"
- "同步代码到服务器"
- "上传到服务器"
- "サーバーに同期する"
- "デプロイする"

**秘密鍵バインド**:
- "bind sftp private key"
- "bind ssh key"
- "绑定 SFTP 私钥"
- "绑定私钥"
- "秘密鍵をバインドする"
- "SSH 鍵をバインドする"

**注**: "push"、"推送"、"プッシュ" はトリガーとして扱いません — git push と競合します。

## 概要

この Skill はローカルプロジェクトファイルを SFTP でリモートサーバーにアップロードします。
Git の変更検出機能により、変更されたファイルのみを効率的にデプロイできます。

## 実行

SFTP アップロードがトリガーされると、次を実行：

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh
```

秘密鍵バインドがトリガーされると、次を実行：

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-keybind.sh
```

## 設定

設定ファイル：`.claude/sftp-cc/sftp-config.json`

```json
{
  "host": "example.com",
  "port": 22,
  "username": "deploy",
  "remote_path": "/var/www/html",
  "language": "ja"
}
```

## はじめに

1. **設定を作成**：
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-init.sh
   ```

2. **秘密鍵を配置**：
   秘密鍵ファイルを `.claude/sftp-cc/` ディレクトリに置きます。
   サポート形式：`id_rsa`, `id_ed25519`, `*.pem`, `*.key`

3. **秘密鍵をバインド**：
   「秘密鍵をバインドして」と言ってください。

4. **アップロード**：
   「コードをサーバーに同期」と言ってください。

## スクリプト

| スクリプト | 説明 |
|-----------|------|
| `sftp-push.sh` | ファイルをアップロード |
| `sftp-init.sh` | 設定を初期化 |
| `sftp-keybind.sh` | 秘密鍵をバインド |
| `sftp-copy-id.sh` | 公開鍵をデプロイ |

## オプション

**sftp-push.sh**：
- `-n`, `--dry-run` — プレビューモード（実行せずに表示）
- `--full` — 全量アップロード
- `file1 file2` — 指定ファイルのみをアップロード
- `-d dirname/` — 指定ディレクトリをアップロード

## トラブルシューティング

**問題**: 接続に失敗
- ネットワーク接続を確認
- サーバーアドレスとポートを検証
- 秘密鍵の権限を確認（600）

**問題**: 設定ファイルが見つからない
- `sftp-init.sh` を実行して初期化

**問題**: 秘密鍵の権限エラー
- `chmod 600 ~/.ssh/id_rsa` で権限を修正
````

### 3.1.2 必須セクション

SKILL.md には最低限以下のセクションが必要です：

| セクション | 必須 | 目的 |
|-----------|------|------|
| YAML frontmatter | **必須** | Skill メタデータ |
| トリガー | **必須** | 発動条件の定義 |
| 実行 | **必須** | 実行スクリプトの指定 |
| 概要 | 推奨 | Skill の説明 |
| 設定 | 推奨 | 設定ファイルの説明 |
| はじめに | 推奨 | 初回セットアップガイド |
| トラブルシューティング | 推奨 | よくある問題と解決策 |

---

## 3.2 YAML Frontmatter

### 3.2.1 基本構造

YAML frontmatter は Markdown ファイルの先頭に配置します：

```yaml
---
name: skill-name
description: Skill の簡単な説明
---
```

**重要なルール**：
1. `---` で開始し、`---` で終了
2. 左揃え（インデントなし）
3. `name` と `description` は必須
4. UTF-8 エンコーディング

### 3.2.2 name フィールド

Skill の一意な識別子：

```yaml
---
name: sftp-cc
---
```

**命名規則**：
- ✅ 小文字のみ使用
- ✅ 区切りにはハイフン（`-`）を使用
- ✅ 簡潔で説明적인名前
- ❌ 大文字は使用しない
- ❌ スペースは使用しない
- ❌ 特殊文字は使用しない

**良い例**：
```yaml
name: sftp-cc
name: hello-world
name: api-generator
name: code-formatter
```

**悪い例**：
```yaml
name: SFTP-CC          # 大文字
name: sftp_cc          # アンダースコア
name: sftp cc          # スペース
name: sftp@cc          # 特殊文字
```

### 3.2.3 description フィールド

Skill の機能を簡潔に説明：

```yaml
---
name: sftp-cc
description: 汎用 SFTP アップロードツール、自然言語でトリガー、ローカルプロジェクトファイルをリモートサーバーにアップロード
---
```

**ベストプラクティス**：
- 1 文で簡潔に（200 文字以内）
- 主な機能を説明
- キーワードを含める
- 価値提案を明確化

**良い例**：
```yaml
description: 汎用 SFTP アップロードツール、自然言語でトリガー、ローカルプロジェクトファイルをリモートサーバーにアップロード
description: Hello World Skill、挨拶するとこんにちはと返す
description: API ドキュメント自動生成、OpenAPI 仕様から Markdown を作成
```

**悪い例**：
```yaml
description: これは私の最初の Skill で、多くの機能があります...  # 長すぎる、曖昧
description: SFTP ツール  # 短すぎる、不十分
```

---

## 3.3 トリガーワード設計

### 3.3.1 良いトリガーワードの特徴

効果的なトリガーワードには 4 つの特徴があります：

#### 1. 自然言語

ユーザーが実際に言うフレーズを使用：

```markdown
## トリガー

✅ 良い：
- "コードをサーバーに同期"
- "変更をデプロイ"
- "サーバーにアップロード"

❌ 悪い：
- "sftp_push_execute"      # 機械的
- "run_deployment_script"  # 不自然
- "trigger_upload"         # 命令形
```

#### 2. 多言語カバレッジ

主要言語をカバー：

```markdown
## トリガー

**英語**：
- "sync code to server"
- "upload to server"

**中国語**：
- "同步代码到サーバー"
- "上传到服务器"

**日本語**：
- "コードをサーバーに同期"
- "サーバーにデプロイ"
```

#### 3. 具体的な文脈

曖昧さを回避：

```markdown
✅ 良い：
- "sync **code** to **server**"  # 何処に何を同期
- "upload **changed files**"     # 何を変更

❌ 悪い：
- "sync"        # 何を？どこに？
- "upload"      # 何を？
- "push"        # git push と競合
```

#### 4. 競合回避

他の機能との競合を避ける：

```markdown
✅ 使用する：
- "sync code to server"
- "deploy to production"

❌ 避ける：
- "push"              # git push
- "commit"            # git commit
- "merge"             # git merge
- "checkout"          # git checkout
```

### 3.3.2 トリガーグループ

関連するトリガーをグループ化：

```markdown
## トリガー

**アップロード**：
- "sync code to server"
- "upload changes"
- "deploy code"

**設定**：
- "setup sftp"
- "configure deployment"
- "initialize sftp"

**認証**：
- "bind ssh key"
- "setup private key"
```

**なぜグループ化するか**：
1. Claude の意図認識を支援
2. 類似トリガーを整理
3. ドキュメントの可読性向上

---

## 3.4 スクリプトパス説明

### 3.4.1 ${CLAUDE_PLUGIN_ROOT} 変数

**重要**: `${CLAUDE_PLUGIN_ROOT}` は Claude Code によって注入される特別な変数：

```markdown
**スクリプト場所**: `${CLAUDE_PLUGIN_ROOT}/scripts/`

**注**: `${CLAUDE_PLUGIN_ROOT}` は Skill コンテキストでのみ有効で、実行時にプラグインルートディレクトリパスに自動解決されます。
```

### 3.4.2 正しい使い方

```markdown
## 実行

スクリプトを実行：

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh
```

**実行時パス解決**：
```
${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh
↓
~/.claude/plugins/marketplaces/sftp-cc/scripts/sftp-push.sh
```

### 3.4.3 よくある間違い

````markdown
❌ 間違い 1: 相対パス
```bash
bash ./scripts/sftp-push.sh  # 失敗：カレントディレクトリに依存
```

❌ 間違い 2: 絶対パス
```bash
bash ~/.claude/plugins/sftp-cc/scripts/sftp-push.sh  # 失敗：固定パス
```

✅ 正解：変数使用
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh  # 成功：自動解決
```
````

---

## 3.5 実行指示

### 3.5.1 シンプルな実行

単一スクリプトの実行：

````markdown
## 実行

トリガーされると、次を実行：

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/my-script.sh
```
````

### 3.5.2 条件付き実行

複数のシナリオ：

```markdown
## 実行

**ファイルアップロード**：
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh
```

**秘密鍵バインド**：
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-keybind.sh
```

**設定初期化**：
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-init.sh
```
````

### 3.5.3 パラメータ付き実行

スクリプトにパラメータを渡す：

````markdown
## 実行

デフォルト（増分アップロード）：
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh
```

プレビューモード：
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh -n
```

全量アップロード：
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh --full
```
````

---

## 3.6 ユーザーガイド

### 3.6.1 はじめにセクション

新規ユーザーのためのクイックスタート：

````markdown
## はじめに

**ステップ 1: 設定を作成**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-init.sh
```

**ステップ 2: 秘密鍵を配置**

秘密鍵ファイルを `.claude/sftp-cc/` ディレクトリに置きます。

**ステップ 3: 秘密鍵をバインド**

「秘密鍵をバインドして」と言ってください。

**ステップ 4: アップロード**

「コードをサーバーに同期」と言ってください。
````

### 3.6.2 設定セクション

設定ファイルの形式を説明：

```markdown
## 設定

設定ファイル：`.claude/sftp-cc/sftp-config.json`

```json
{
  "host": "example.com",
  "port": 22,
  "username": "deploy",
  "remote_path": "/var/www/html",
  "language": "ja"
}
```

**フィールド説明**：
- `host`: SFTP サーバーアドレス（必須）
- `port`: SFTP ポート、デフォルト 22（オプション）
- `username`: ログインユーザー名（必須）
- `remote_path`: リモートデプロイ先パス（必須）
- `language`: インターフェース言語、デフォルト "en"（オプション）
```

### 3.6.3 オプションセクション

使用可能なオプションをリスト：

```markdown
## オプション

**sftp-push.sh**：

| オプション | 説明 | 例 |
|-----------|------|-----|
| `-n`, `--dry-run` | プレビューモード | 実行前に確認 |
| `--full` | 全量アップロード | 全ファイルをデプロイ |
| `file` | 指定ファイル | `sftp-push.sh index.php` |
| `-d dir` | 指定ディレクトリ | `sftp-push.sh -d src/` |
```

### 3.6.4 トラブルシューティング

よくある問題と解決策：

```markdown
## トラブルシューティング

**問題**: 接続に失敗

**確認事項**：
1. ネットワーク接続を確認
2. サーバーアドレスとポートを検証
3. 秘密鍵の権限を確認（600）

**解決策**：
```bash
# 秘密鍵の権限を修正
chmod 600 ~/.ssh/id_rsa

# 接続をテスト
sftp -i ~/.ssh/id_rsa user@host
```

---

**問題**: 設定ファイルが見つからない

**解決策**：
```bash
# 設定を初期化
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-init.sh
```

---

**問題**: 秘密鍵の権限エラー

**解決策**：
```bash
# 権限を修正
chmod 600 .claude/sftp-cc/id_rsa

# 再度バインド
秘密鍵をバインドして
```
```

---

## 3.7 デバッグのヒント

### 3.7.1 SKILL.md の検証

Skill をテストする前に検証：

```bash
# Plugin 構造を検証
claude plugin validate .

# SKILL.md の構文を確認
head -20 skills/sftp-cc/SKILL.md

# YAML frontmatter を確認
grep -A 5 "^---" skills/sftp-cc/SKILL.md
```

### 3.7.2 よくある問題

#### 問題 1: Skill がトリガーされない

**原因**：
- トリガーワードが曖昧すぎる
- YAML frontmatter の形式が不正
- Plugin がロードされていない

**解決策**：
```bash
# Plugin をリロード
claude plugin reload sftp-cc

# トリガーワードを具体的にする
# 悪い："sync"
# 良い："sync code to server"
```

#### 問題 2: 変数が解決されない

**原因**：
- `${CLAUDE_PLUGIN_ROOT}` が Skill コンテキスト外で使用

**解決策**：
````markdown
✅ 良い：
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/script.sh
```

❌ 悪い（shell で直接実行）：
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/script.sh
# 失敗：変数が空
```
````

#### 問題 3: スクリプトが実行されない

**原因**：
- 実行権限がない
- パスが正しくない
- シェバングが不足

**解決策**：
```bash
# 実行権限を付与
chmod +x scripts/*.sh

# シェバングを確認
head -1 scripts/sftp-push.sh
# #!/bin/bash が必要
```

---

## 本章のまとめ

### 重要な概念

| 概念 | 説明 |
|---------|-------------|
| **YAML frontmatter** | Skill メタデータ、name と description 必須 |
| **トリガーワード** | 自然言語、多言語、具体的、競合回避 |
| **${CLAUDE_PLUGIN_ROOT}** | Skill 内部変数、実行時に自動解決 |
| **実行指示** | bash コマンドでスクリプトを指定 |
| **ユーザーガイド** | はじめに、設定、オプション、トラブルシューティング |

### SKILL.md チェックリスト

- [ ] YAML frontmatter に `name` と `description` がある
- [ ] トリガーワードが具体的で多言語
- [ ] `${CLAUDE_PLUGIN_ROOT}` を使用
- [ ] 実行スクリプトのパスが正しい
- [ ] 設定ファイルの説明がある
- [ ] はじめにセクションがある
- [ ] トラブルシューティングがある

---

## 練習問題

### 練習問題 3-1: SKILL.md を作成

初めての Skill を作成：
1. `skills/hello-world/SKILL.md` を作成
2. YAML frontmatter を設定
3. トリガーワードを定義（3 つ以上）
4. 実行スクリプトを指定
5. 簡単なユーザーガイドを追加

### 練習問題 3-2: トリガーワードを設計

あなたの Skill のトリガーワード：
1. 英語で 3 つのトリガーを設計
2. 中国語で 3 つのトリガーを設計
3. 日本語で 3 つのトリガーを設計
4. 競合するワードをリスト

### 練習問題 3-3: ユーザーガイドを作成

クイックスタートガイド：
1. 必要な前提条件をリスト
2. インストール手順を記述
3. 基本的な使用例を示す
4. よくある問題を記載

---

## 拡張リソース

### 公式ドキュメント
- [Claude Code Skill 仕様](https://docs.anthropic.com/claude-code/)
- [YAML Frontmatter 仕様](https://jekyllrb.com/docs/front-matter/)

### 例プロジェクト
- [sftp-cc SKILL.md](https://github.com/toohamster/sftp-cc/blob/main/skills/sftp-cc/SKILL.md)
- [その他の Skill 例](https://claude.ai/marketplace)

### 副読本
- 「Markdown 完璧ガイド」— 書き方とベストプラクティス
- 「YAML 入門」— 構造と構文

---

## 次章のプレビュー

**第 4 章：スクリプト開発**

第 4 章では、実際のスクリプト開発を学びます：
- 標準スクリプト構造
- ピュア Shell JSON パース
- エラーハンドリングパターン
- Git 統合
- SFTP バッチモード
- 一時ファイル管理

第 4 章の終わりまでに、完全に機能するスクリプトが書けます。

---

## 本書について

**初版（デジタル版）, 2026 年 3 月**

**著者**: [toohamster](https://github.com/toohamster)
**ライセンス**: 電子版：MIT License | 印刷版/商業版：All Rights Reserved
**ソース**: [github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

詳細は [LICENSE](../../LICENSE) と [著者について](../authors.md) をご覧ください。

---
