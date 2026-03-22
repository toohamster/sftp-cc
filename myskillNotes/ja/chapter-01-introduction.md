# 第 1 章：Claude Code Skill とは

> 「最も良いツールは、存在していることを忘れてしまうものだ」 — アラン・ケイ

この章では、次のことを学びます：
- Claude Code Skill の定義と、それが解決する問題
- Plugin アーキテクチャのコアコンポーネントと動作原理
- 完全な開発環境のセットアップ方法
- 初めての Hello World Skill を実際に作成

---

## 1.1 Claude Code Skill とは何か

### 1.1.1 背景：Skill の誕生

ソフトウェア開発の歴史において、開発体験のすべての革新は生産性の飛躍をもたらしました：

```
コマンドライン IDE (Vi/Emacs) → GUI IDE (VS Code) → AI 支援コーディング (Claude Code)
         ↓                          ↓                        ↓
    プレーンテキスト編集      可視化 + プラグイン    自然言語インタラクション
```

Claude Code は Anthropic がリリースした CLI プログラミングアシスタントで、**Skill** はそのプラグインシステムです。従来の IDE プラグインとは異なり、Skill は**自然言語でトリガー**され、話すだけで自動化機能を呼び出せます。

### 1.1.2 Skill の正式な定義

**Claude Code Skill** は Markdown ベースのプラグイン定義形式で、Claude に次のことを伝えます：
1. **いつトリガーするか** — ユーザーが何を言えばこの Skill を呼び出すか
2. **どのように実行するか** — トリガー後にどのスクリプトやコマンドを実行するか
3. **何の機能を提供するか** — Skill が完了できる特定の機能

コードで表現すると、Skill には最低限以下内容が必要です：
````markdown
---
name: my-skill
description: 私の最初の Skill
---

# 私の Skill

## トリガー

ユーザーが「こんにちは」と言ったとき、次を実行：
```bash
echo "こんにちは、ワールド！"
```
````

### 1.1.3 Skill でできること

Skill の機能の限界は、ほぼ Shell でできることと同等です。いくつかの実践的なアプリケーションシナリオを紹介しましょう：

#### ファイル操作
| Skill | トリガー例 | 目的 |
|-------|-----------|------|
| SFTP アップロード | 「コードをサーバーに同期」 | ローカルコードをリモートサーバーにデプロイ |
| ファイル同期 | 「設定をテスト環境に同期」 | 複数環境の設定を同期 |
| バックアップツール | 「現在のデータベースをバックアップ」 | 重要なデータの定期バックアップ |

#### コード処理
| Skill | トリガー例 | 目的 |
|-------|-----------|------|
| コードフォーマット | 「このファイルをフォーマット」 | コードスタイルを統一 |
| バッチリネーム | 「.jsx をすべて.tsx に変更」 | 大規模なファイル名変更 |
| API ジェネレーター | 「ユーザーの CRUD API を生成」 | テンプレートからコードを生成 |

#### 外部統合
| Skill | トリガー例 | 目的 |
|-------|-----------|------|
| GitHub 操作 | 「新しいリリースを作成」 | GitHub API を呼び出し |
| デプロイ通知 | 「チームにデプロイ完了を通知」 | Slack/钉钉 メッセージを送信 |
| ドキュメント生成 | 「API ドキュメントを生成」 | ドキュメント生成ツールを呼び出し |

### 1.1.4 他のプラグインシステムとの比較

Skill のポジショニングを理解するには、他のシステムと比較するのが最善です：

#### VS Code Extensions との比較

| 次元 | Claude Code Skill | VS Code 拡張 |
|-----------|-------------------|-------------------|
| **トリガー方法** | 自然言語会話 | ボタンクリック / キーボードショートカット / コマンドパレット |
| **開発言語** | Markdown + Shell/Python | TypeScript/JavaScript |
| **学習曲線** | 低い（ドキュメント作成 = 開発） | 高い（VS Code API の理解が必要） |
| **配布** | Git リポジトリ URL | VS Code Marketplace |
| **実行環境** | Claude Code CLI | VS Code レンダラープロセス |
| **デバッグ方法** | スクリプト出力を表示 | DevTools + デバッグブレークポイント |
| **典型的な開発時間** | 30 分 | 数日〜数週間 |

**Skill を選ぶべき場合**：
- ✅ 迅速に自動化スクリプトを実装する必要がある
- ✅ コマンドラインで機能を完了できる
- ✅ 自然言語でトリガーしたい

**VS Code 拡張を選ぶべき場合**：
- ✅ UI インターフェースが必要
- ✅ 深い VS Code 機能統合（デバッガー、ターミナル）が必要
- ✅ 複雑なユーザー設定インターフェースが必要

#### JetBrains プラグインとの比較

| 次元 | Claude Code Skill | JetBrains プラグイン |
|-----------|-------------------|------------------|
| 開発言語 | Markdown + Shell | Java/Kotlin |
| IDE 互換性 | クロス IDE（Claude Code 経由） | 特定の IDE（IntelliJ、PyCharm など） |
| 配布の複雑さ | 単純（Git URL） | 複雑（JetBrains Marketplace） |

---

## 1.2 Claude Code Plugin アーキテクチャ

### 1.2.1 ディレクトリ構造

完全な Claude Code Plugin には次のような基本構造があります：

```
my-plugin/
├── .claude-plugin/
│   └── marketplace.json    # Marketplace 設定（配布用）
├── skills/
│   └── my-skill/
│       └── SKILL.md        # Skill 定義（コア）
├── scripts/
│   └── my-script.sh        # 実行スクリプト
└── README.md               # ドキュメント
```

**ディレクトリの目的**：

| ディレクトリ/ファイル | 目的 | 必須か |
|----------------|---------|----------|
| `.claude-plugin/marketplace.json` | Plugin marketplace 設定 | 配布時に必要 |
| `skills/<skill-name>/SKILL.md` | Skill 定義ファイル | **必須** |
| `scripts/` | 実行可能スクリプト | オプション（インライン使用可能） |
| `README.md` | ドキュメント | 推奨 |

### 1.2.2 コアコンポーネント

#### 1. SKILL.md — Skill の心臓部

SKILL.md は Skill のコア定義ファイルで、以下内容を含みます：

````markdown
---
name: skill-name
description: Skill の簡単な説明
---

# Skill 名

## トリガー時期

トリガーワードとフレーズのリスト...

## 何をするか

機能の説明...

## 実行方法

スクリプトの実行指示...
````

**重要な要素**：
- **YAML Frontmatter**: 上部のメタデータ（`---` の間）
- **トリガーワード**: Skill をアクティブにするフレーズ
- **実行ロジック**: トリガー後に発生すること

#### 2. ${CLAUDE_PLUGIN_ROOT} 変数

```markdown
**重要**: ${CLAUDE_PLUGIN_ROOT} は Claude Code によって注入される Skill 内部変数

- Skill コンテキストでのみ有効
- 実行時にプラグインルートディレクトリパスに自動解決
- 例：`~/.claude/plugins/marketplaces/my-plugin/`
```

**変数注入の仕組み**：

```
ユーザーが Skill をトリガー
       ↓
Claude Code が SKILL.md をロード
       ↓
Claude Code が ${CLAUDE_PLUGIN_ROOT} を実際のパスで置換
       ↓
スクリプトが解決されたパスで実行
```

#### 3. scripts/ ディレクトリ

scripts/ ディレクトリは実行可能スクリプトを格納します：

- **サポート言語**: Shell、Python、Ruby、Node.js など
- **アクセス方法**: `${CLAUDE_PLUGIN_ROOT}/scripts/` 経由
- **ベストプラクティス**: スクリプトはモジュール式でよくドキュメント化

**スクリプト構造の例**：

```bash
#!/bin/bash
# my-script.sh — 簡単な説明

set -euo pipefail

# あなたのロジックをここに
echo "Skill からこんにちは！"
```

---

## 1.3 Skill の動作原理

### 1.3.1 トリガーフロー

Skill の完全な実行フロー：

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐     ┌──────────┐     ┌────────┐
│ ユーザー入力 │  →  │  Claude が   │  →  │   トリガー  │  →  │  SKILL.md│  →  │スクリプト│
│「コードを同期」│     │  意図認識    │     │   マッチ    │     │  をロード │     │ を実行  │
└─────────────┘     └──────────────┘     └─────────────┘     └──────────┘     └────────┘
```

**ステップバイステップの内訳**：

| ステップ | アクション | 説明 |
|------|--------|-------------|
| 1 | ユーザー入力 | ユーザーがフレーズを入力または発話 |
| 2 | 意図認識 | Claude が意図を分析 |
| 3 | トリガーマッチ | 定義されたトリガーワードと一致 |
| 4 | SKILL.md をロード | Skill 定義ファイルを読み込む |
| 5 | スクリプトを実行 | 指定されたスクリプトやコマンドを実行 |

### 1.3.2 変数注入メカニズム

完全な例を追跡してみましょう：

```
ユーザー：「コードをサーバーに同期」と言う
  ↓
Claude が SFTP アップロード意図を認識
  ↓
一致する Skill を検索（sftp-cc）
  ↓
SKILL.md をロード、${CLAUDE_PLUGIN_ROOT} を注入
  ↓
実行：bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh
  ↓
スクリプトが実際のパスで実行：bash ~/.claude/plugins/marketplaces/sftp-cc/scripts/sftp-push.sh
```

### 1.3.3 よくある質問 (FAQ)

#### Q1: bash で直接実行すると ${CLAUDE_PLUGIN_ROOT} が空になるのはなぜ？

**A**: `${CLAUDE_PLUGIN_ROOT}` は **Skill コンテキストでのみ Claude Code によって注入**されます。shell で直接実行する場合は、絶対パスを使用する必要があります：

```bash
# ❌ 間違い：直接実行、変数が空
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh
# エラー：bash: /scripts/sftp-push.sh: そのようなファイルまたはディレクトリはありません

# ✅ 正解：絶対パスを使用
bash ~/.claude/plugins/marketplaces/sftp-cc/scripts/sftp-push.sh
```

#### Q2: Skill のデバッグ方法は？

**A**: 次のデバッグアプローチを使用します：

1. **スクリプトに echo 文を追加**：
   ```bash
   echo "[DEBUG] アップロード開始..." >&2
   ```

2. **ターミナルで Claude Code の出力を確認**

3. **Skill と統合する前にスクリプトを個別にテスト**

#### Q3: Shell ではなく Python を使えますか？

**A**: はい！どんなスクリプト言語でも動作します：

````markdown
実行：
```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/my-script.py
```
````

---

## 1.4 開発環境のセットアップ

### 1.4.1 Claude Code のインストール

次のいずれかのインストール方法を選択します：

#### macOS (Homebrew)
```bash
brew install claude-code
```

#### npm（クロスプラットフォーム）
```bash
npm install -g @anthropic-ai/claude-code
```

#### インストールの確認
```bash
claude --version
# 予期される出力：claude-code x.x.x
```

### 1.4.2 ディレクトリの準備

初めての Skill プロジェクトを作成しましょう：

````bash
# プロジェクトディレクトリを作成
mkdir my-first-skill
cd my-first-skill

# 基本構造を作成
mkdir -p .claude-plugin skills/hello-world scripts

# SKILL.md を作成
cat > skills/hello-world/SKILL.md << 'EOF'
---
name: hello-world
description: 私の最初の Skill — 挨拶するとこんにちはと返す
---

# Hello World Skill

## トリガー

ユーザーが次に言ったとき：
- "こんにちは"
- "やあ"
- "やっほー"
- "hello"
- "hi"

## 実行

```bash
echo "こんにちは！Claude Code Skill 開発へようこそ！"
```
EOF

# Skill をテスト
claude
# 次に：「こんにちは」と言う
````

### 1.4.3 Skill を初めて実行

セットアップ後、Skill をテストしましょう：

1. **Claude Code を起動**：
   ```bash
   claude
   ```

2. **トリガーフレーズを発話**：
   ```
   ユーザー：こんにちは

   Claude: こんにちは！Claude Code Skill 開発へようこそ！
   ```

3. **おめでとうございます！** 初めての Skill が完成しました！

---

## 1.5 初心者向けベストプラクティス

### 1.5.1 単純なものから始める

シンプルな「Hello World」Skill から始めましょう：
- 単一のトリガーワード
- 単一の echo コマンド
- 複雑なロジックなし

### 1.5.2 段階的にテスト

ステップバイステップで構築とテスト：
1. まずスクリプトを個別にテスト
2. SKILL.md ラッパーを追加
3. Claude Code でテスト

### 1.5.3 進めながらドキュメント化

良いドキュメントは役立ちます：
- Skill の機能を説明
- すべてのトリガーワードをリスト
- 使用例を提供

---

## 本章のまとめ

### 重要な概念

| 概念 | 説明 |
|---------|-------------|
| **Skill** | Claude Code のプラグインシステム、自然言語でトリガー |
| **SKILL.md** | YAML frontmatter を含むコア定義ファイル |
| **${CLAUDE_PLUGIN_ROOT}** | 内部変数、実行時に自動解決 |
| **トリガーワード** | Skill をアクティブにするフレーズ |

### 学んだこと

- ✅ Claude Code Skill とその目的
- ✅ Plugin アーキテクチャ：SKILL.md、scripts/、marketplace.json
- ✅ 変数注入の仕組み
- ✅ 開発環境のセットアップ方法
- ✅ Hello World Skill を作成

---

## 練習問題

### 練習問題 1-1: Hello World をカスタマイズ

Hello World Skill を修正：
- 母国語でトリガーワードを追加
- パーソナライズされたメッセージを表示
- 現在の日時を含める

### 練習問題 1-2: 天気 Skill を作成

シンプルな天気 Skill を作成：
- 「天気」または「今日の天気」でトリガー
- モックの天気予報を表示
- （オプション）`curl` で実際の天気データを取得

例：
```bash
curl wttr.in?format=3
```

### 練習問題 1-3: 既存の Skill を調査

- [Plugin Marketplace](https://claude.ai/marketplace) を閲覧
- 2〜3 個の既存の Skill を研究
- トリガーワードのパターンを記録

---

## 拡張リソース

### 公式ドキュメント
- [Claude Code ドキュメント](https://docs.anthropic.com/claude-code/)
- [Plugin Marketplace](https://claude.ai/marketplace)

### 例プロジェクト
- [sftp-cc](https://github.com/toohamster/sftp-cc) — SFTP アップロードツール（本書の companion プロジェクト）
- [その他の例](https://github.com/topics/claude-code-skill)

### 副読本
- 「Advanced Bash-Scripting Guide」— Shell スクリプトの深掘り
- 「Writing Secure Code」— セキュリティベストプラクティス

---

## 次章のプレビュー

**第 2 章：プロジェクト計画と設計**

第 2 章では、プロジェクト計画と設計を深く掘り下げます：
- ペインポイントからの要件分析
- 機能バウンダリの定義（何をするか vs 何をしないか）
- ディレクトリ構造のベストプラクティス
- 設定ファイル設計の原則

第 2 章の終わりまでに、sftp-cc プロジェクトの完全な設計ドキュメントを完成させます。

---

## 本書について

**初版（デジタル版）, 2026 年 3 月**

**著者**: [toohamster](https://github.com/toohamster)
**ライセンス**: 電子版：MIT License | 印刷版/商業版：All Rights Reserved
**ソース**: [github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

詳細は [LICENSE](../../LICENSE) と [著者について](../authors.md) をご覧ください。

---
