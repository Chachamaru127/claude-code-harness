# コマンドリファレンス

2エージェントワークフローで使用するコマンドの詳細。

---

## Claude Code 側コマンド

### /harness-init

プロジェクトの初期セットアップ。

```
/harness-init
```

**生成されるファイル**:
- Plans.md - タスク管理
- AGENTS.md - 役割分担定義
- CLAUDE.md - Claude Code 設定
- .claude/commands/ - Cursor 連携コマンド

---

### /plan-with-agent

タスクの計画・分解。

```
/plan-with-agent [タスク説明]
```

**例**:
```
/plan-with-agent ユーザー認証機能を実装したい
```

**出力**: Plans.md にタスクが追加される

---

### /work

Plans.md のタスクを実行。

```
/work
```

**機能**:
- `cc:TODO` または `pm:依頼中` のタスクを自動検出
- 複数タスクの並列実行に対応
- 完了時に `cc:完了` に自動更新

---

### /sync-status

現在の状態サマリーを出力。

```
/sync-status
```

**出力例**:
```
📊 現在の状態
- 進行中: 2件
- 未着手: 5件
- 完了（確認待ち）: 1件
```

---

### /handoff-to-cursor

Cursor PM への完了報告。

```
/handoff-to-cursor
```

**含まれる情報**:
- 完了したタスク一覧
- 変更されたファイル
- テスト結果
- 次のアクション提案

---

## Cursor 側コマンド（参考）

### /handoff-to-claude

Claude Code へのタスク依頼。

### /review-cc-work

Claude Code の完了報告をレビュー。

---

## スキル（会話で自動起動）

### handoff-to-pm

**トリガー**: 「PMに完了報告」「作業完了を報告」

Worker → PM への完了報告を生成。

### handoff-to-impl

**トリガー**: 「実装役に渡して」「Claude Code に依頼」

PM → Worker へのタスク依頼を整形。

---

## コマンド使用フロー

```
[セッション開始]
    │
    ▼
/sync-status  ←── 現状確認
    │
    ▼
/work  ←── タスク実行
    │
    ▼
/handoff-to-cursor  ←── 完了報告
    │
    ▼
[セッション終了]
```
