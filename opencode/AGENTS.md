<!-- Generated from CLAUDE.md by build-opencode.js -->
<!-- opencode.ai compatible version of Claude Code Harness -->

# AGENTS.md - Claude harness 開発ガイド

このファイルは Claude Code がこのリポジトリで作業する際の指針です。

## プロジェクト概要

**Claude harness** は、Claude Code を「Plan → Work → Review」の型で自律運用するためのプラグインです。

**特殊な点**: このプロジェクトは「ハーネス自身を使ってハーネスを改善する」自己参照的な構成です。

## 開発ルール

### コミットメッセージ

[Conventional Commits](https://www.conventionalcommits.org/) に従う:

- `feat:` - 新機能
- `fix:` - バグ修正
- `docs:` - ドキュメント変更
- `refactor:` - リファクタリング
- `test:` - テスト追加/更新
- `chore:` - メンテナンス

### バージョン管理

バージョンは 2 箇所で定義（同期必須）:
- `VERSION` - ソース・オブ・トゥルース
- `.claude-plugin/plugin.json` - プラグインシステム用

変更時は `./scripts/sync-version.sh bump` を使用。

### CHANGELOG 記載ルール（必須）

**[Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) フォーマットに準拠**

各バージョンエントリには以下のセクションを使用:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- 新機能について

### Changed
- 既存機能の変更について

### Deprecated
- 間もなく削除される機能について

### Removed
- 削除された機能について

### Fixed
- バグ修正について

### Security
- 脆弱性に関する場合

#### Before/After（大きな変更時のみ）

| Before | After |
|--------|-------|
| 変更前の状態 | 変更後の状態 |
```

**セクション使い分け**:

| セクション | 使うとき |
|------------|----------|
| Added | 完全に新しい機能を追加したとき |
| Changed | 既存機能の動作や体験を変更したとき |
| Deprecated | 将来削除予定の機能を告知するとき |
| Removed | 機能やコマンドを削除したとき |
| Fixed | バグや不具合を修正したとき |
| Security | セキュリティ関連の修正をしたとき |

**Before/After テーブル**: 大きな体験変化（コマンド廃止・統合、ワークフロー変更、破壊的変更）があるときのみ追加。軽微な修正では省略可。

**バージョン比較リンク**: CHANGELOG.md 末尾に `[X.Y.Z]: https://github.com/.../compare/vPREV...vX.Y.Z` 形式で追加

### コードスタイル

- 明確で説明的な名前を使う
- 複雑なロジックにはコメントを追加
- コマンド/エージェント/スキルは単一責任に保つ

## リポジトリ構成

```
claude-code-harness/
├── .claude-plugin/     # プラグインマニフェスト
├── commands/           # スラッシュコマンド（ユーザー向け）
├── agents/             # サブエージェント定義（Task tool で並列起動可能）
├── skills/             # エージェントスキル
├── hooks/              # ライフサイクルフック
├── scripts/            # シェルスクリプト（ガード、自動化）
├── templates/          # テンプレートファイル
├── docs/               # ドキュメント
└── tests/              # 検証スクリプト
```

## スキルの活用（重要）

### スキル評価フロー

> 💡 重いタスク（並列レビュー、CI修正ループ）では、スキルが `agents/` のサブエージェントを Task tool で並列起動します。

**作業を開始する前に、必ず以下のフローを実行すること:**

1. **評価**: 利用可能なスキルを確認し、今回の依頼に該当するものがあるか評価
2. **起動**: 該当するスキルがあれば、Skill ツールで起動してから作業開始
3. **実行**: スキルの手順に従って作業を進める

```
ユーザーの依頼
    ↓
スキルを評価（該当するものがあるか？）
    ↓
YES → Skill ツールで起動 → スキルの手順に従う
NO  → 通常の推論で対応
```

### スキルの階層構造

スキルは **親スキル（カテゴリ）** と **子スキル（具体的な機能）** の階層構造になっています。

```
skills/
├── impl/                  # 実装（機能追加、テスト作成）
├── review/                # レビュー（品質、セキュリティ、パフォーマンス）
├── verify/                # 検証（ビルド、エラー復旧、修正適用）
├── setup/                 # セットアップ（CLAUDE.md、Plans.md生成）
├── 2agent/                # 2エージェント設定（PM連携、Cursor設定）
├── memory/                # メモリ管理（SSOT、decisions.md、patterns.md）
├── principles/            # 原則・ガイドライン（VibeCoder、差分編集）
├── auth/                  # 認証・決済（Clerk、Supabase、Stripe）
├── deploy/                # デプロイ（Vercel、Netlify、アナリティクス）
├── ui/                    # UI（コンポーネント、フィードバック）
├── workflow/              # ワークフロー（ハンドオフ、自動修正）
├── docs/                  # ドキュメント（NotebookLM、YAML）
├── ci/                    # CI/CD（失敗分析、テスト修正）
└── maintenance/           # メンテナンス（クリーンアップ）
```

**使い方:**
1. 親スキルを Skill ツールで起動
2. 親スキルがユーザーの意図に応じて適切な子スキル（doc.md）にルーティング
3. 子スキルの手順に従って作業実行

### 開発用スキル（非公開）

以下のスキルは開発・実験用であり、リポジトリには含まれません（.gitignore で除外）：

```
skills/
├── test-*/      # テスト用スキル
└── x-promo/     # X投稿作成スキル（開発用）
```

これらのスキルは個別の開発環境でのみ使用し、プラグイン配布には含めないこと。

### 主要スキルカテゴリ

| カテゴリ | 用途 | トリガー例 |
|---------|------|-----------|
| impl | 実装、機能追加、テスト作成 | 「実装して」「機能追加」「コードを書いて」 |
| review | コードレビュー、品質チェック | 「レビューして」「セキュリティ」「パフォーマンス」 |
| verify | ビルド検証、エラー復旧 | 「ビルド」「エラー復旧」「検証して」 |
| setup | プロジェクト初期化、ファイル生成 | 「セットアップ」「CLAUDE.md」「初期化」 |
| 2agent | 2エージェント運用設定 | 「2-Agent」「Cursor設定」「PM連携」 |
| memory | SSOT管理、メモリ初期化 | 「SSOT」「decisions.md」「マージ」 |
| principles | 開発原則、ガイドライン | 「原則」「VibeCoder」「安全性」 |
| auth | 認証、決済機能 | 「ログイン」「Clerk」「Stripe」「決済」 |
| deploy | デプロイ、アナリティクス | 「デプロイ」「Vercel」「GA」 |
| ui | UIコンポーネント生成 | 「コンポーネント」「ヒーロー」「フォーム」 |
| workflow | ハンドオフ、自動修正 | 「ハンドオフ」「PMに報告」「自動修正」 |
| docs | ドキュメント生成 | 「ドキュメント」「NotebookLM」「スライド」 |
| ci | CI/CD問題解決 | 「CIが落ちた」「テスト失敗」 |
| maintenance | ファイル整理 | 「整理して」「クリーンアップ」 |

## 開発フロー

1. **計画**: `/plan-with-agent` でタスクを Plans.md に落とす
2. **実装**: `/work` で Plans.md のタスクを実行
3. **レビュー**: `/harness-review` で品質チェック
4. **検証**: `./tests/validate-plugin.sh` で構造検証

## テスト方法

```bash
# プラグイン構造の検証
./tests/validate-plugin.sh
./scripts/ci/check-consistency.sh

# 別プロジェクトでローカルテスト
cd /path/to/test-project
claude --plugin-dir /path/to/claude-code-harness
```

## 注意事項

- **自己参照に注意**: このプラグインの `/work` を実行すると、自分自身のコードを編集することになる
- **Hooks は自動実行**: PreToolUse/PostToolUse で自動ガードが働く
- **VERSION 同期**: コード変更時は必ずバージョンを更新

## 主要コマンド（開発時に使用）

| コマンド | 用途 |
|---------|------|
| `/plan-with-agent` | 改善タスクを Plans.md に追加 |
| `/work` | タスクを実装（並列実行対応） |
| `/harness-review` | 変更内容をレビュー |
| `/validate` | プラグイン検証 |
| `/remember` | 学習事項を記録 |

### ハンドオフ

| コマンド | 用途 |
|---------|------|
| `/handoff-to-cursor` | Cursor 運用時の完了報告 |

**スキル（会話で自動起動）**:
- `handoff-to-impl` - 「実装役に渡して」→ PM → Impl への依頼
- `handoff-to-pm` - 「PMに完了報告」→ Impl → PM への完了報告

## SSOT（Single Source of Truth）

- `.claude/memory/decisions.md` - 決定事項（Why）
- `.claude/memory/patterns.md` - 再利用パターン（How）

## テスト改ざん防止（品質保証）

> 詳細: [D9: テスト改ざん防止の3層防御戦略](.claude/memory/decisions.md#d9-テスト改ざん防止の3層防御戦略)

Coding Agent がテスト失敗時に「楽をする」傾向（テスト改ざん、lint 緩和、形骸化実装）を防ぐための仕組みです。

### 3層防御戦略

| 層 | 仕組み | 強制力 |
|----|--------|--------|
| 第1層: Rules | `.claude/rules/test-quality.md`, `implementation-quality.md` | 良心ベース（常時適用） |
| 第2層: Skills | `impl`, `verify` スキルに品質ガードレール内蔵 | 文脈的強制（スキル使用時） |
| 第3層: Hooks | PostToolUse で改ざんパターンを検出・警告 | 非ブロッキング検出（常時適用） |

### 禁止パターン

**テスト改ざん（test-quality.md）**:
- `it.skip()`, `test.skip()` への変更
- アサーションの削除・緩和
- eslint-disable コメントの追加

**形骸化実装（implementation-quality.md）**:
- テスト期待値のハードコード
- スタブ・モック・空実装
- 特定入力のみ動作するコード

### 困難な場合の対応フロー

```
1. 正直に報告（「この方法では実装が困難です」）
2. 理由を説明（技術的制約、前提条件の不備）
3. 選択肢を提示（代替案、段階的実装）
4. ユーザーの判断を仰ぐ
```

> ⚠️ **絶対にしてはいけないこと**: テストを改ざんして「成功」を偽装すること

