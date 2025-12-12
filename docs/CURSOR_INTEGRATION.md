# Cursor連携ガイド

`claude-code-harness`は、デフォルトでClaude Code単独モードですが、オプションでCursorとの連携機能を有効化できます。

## 連携モードの概要

Cursor連携を有効化すると、以下の役割分担で開発を進められます。

| 役割 | Cursor | Claude Code |
| :--- | :---: | :---: |
| **計画立案** | ✅ | ✅ |
| **レビュー** | ✅ | ✅ |
| **タスク管理** | ✅ | ✅ |
| **実装** | ❌ | ✅ |
| **テスト作成** | ❌ | ✅ |
| **デバッグ** | ❌ | ✅ |

**実装系の作業はClaude Code専用**とすることで、各AIの強みを活かした効率的な開発が可能になります。

## セットアップ

### Step 1: Cursor連携の有効化

Claude Codeで以下のコマンドを実行します。

```bash
/setup-cursor
```

これにより、`.cursor/commands/`ディレクトリに以下のコマンドファイルが生成されます。

- `plan-with-cc.md` - 計画立案
- `review-cc-work.md` - レビュー
- `project-overview.md` - プロジェクト概要
- `handoff-to-claude.md` - Claude Codeへのタスク引き渡し
- `start-session.md` - セッション開始

### Step 2: 共有ファイルの確認

以下のファイルがCursorとClaude Codeで共有されます。

- **Plans.md**: タスク管理（両方で読み書き可能）
- **AGENTS.md**: 開発フロー概要（参照用）

## ワークフロー

### パターン1: Cursorで計画 → Claude Codeで実装

```mermaid
graph LR
    A[Cursor: /plan-with-cc] --> B[Plans.md更新];
    B --> C[Claude Code: /work];
    C --> D[実装完了];
    D --> E[Cursor: /review-cc-work];
```

1. **Cursorで計画**: `/plan-with-cc`を実行してタスクを計画
2. **Plans.md確認**: 計画がPlans.mdに記録される
3. **Claude Codeで実装**: `/work`を実行して実装
4. **Cursorでレビュー**: `/review-cc-work`を実行してレビュー

### パターン2: Claude Codeで完結

```mermaid
graph LR
    A[Claude Code: /plan] --> B[Plans.md更新];
    B --> C[Claude Code: /work];
    C --> D[実装完了];
    D --> E[Claude Code: /review];
```

Cursor連携を有効化していても、Claude Code単独での開発も可能です。

## コマンド一覧

### Cursor側のコマンド

| コマンド | 説明 |
| :--- | :--- |
| `/plan-with-cc` | Claude Codeと協調して計画を立てる |
| `/review-cc-work` | Claude Codeの実装をレビューする |
| `/handoff-to-claude` | Claude Codeへのタスク引き渡しプロンプトを生成 |
| `/project-overview` | プロジェクト全体の概要を確認 |
| `/start-session` | セッション開始→計画→依頼まで自動化 |

### Claude Code側のコマンド

すべてのコマンドが引き続き使用可能です。特に以下が重要です。

| コマンド | 説明 |
| :--- | :--- |
| `/work` | Plans.mdに基づいて実装（Cursor連携時も変わらず） |
| `/review` | コードレビュー（Cursorでもレビュー可能） |
| `/plan` | 計画立案（Cursorでも計画可能） |

## ベストプラクティス

### 役割分担を明確にする

- **計画・レビュー**: CursorまたはClaude Codeのどちらか一方で統一
- **実装**: 必ずClaude Codeで実行

### Plans.mdの競合を避ける

- 同時編集を避け、タスクの状態更新は実装者（Claude Code）が行う
- Cursorは計画の追加・修正のみを行う

### コピー&ペーストで連携

- Cursor → Claude Code: `/handoff-to-claude`で生成されたプロンプトをコピー
- Claude Code → Cursor: 実装完了後の報告をコピー

## 無効化

Cursor連携が不要になった場合、以下のコマンドで無効化できます。

```bash
rm -rf .cursor/commands
```

## トラブルシューティング

### Q: Cursorで`/work`を実行したい

**A**: `/work`はClaude Code専用です。Cursorでは実行できません。小規模な実装はCursorで直接行い、大規模な実装はClaude Codeに依頼してください。

### Q: Plans.mdが競合した

**A**: 競合を手動で解決し、役割分担を再確認してください。計画はCursor、実装とステータス更新はClaude Codeという役割分担を推奨します。

### Q: セットアップ後もCursorコマンドが表示されない

**A**: Cursorを再起動してください。それでも表示されない場合は、`.cursor/commands/`ディレクトリが正しく作成されているか確認してください。
