---
name: plans-management
description: "Manages Plans.md tasks and marker operations. Use when user mentions adding tasks, updating Plans.md, marking complete, or changing task status. Do NOT load for: implementation work, reviews, or non-Plans file operations."
allowed-tools: ["Read", "Write", "Edit"]
---

# Plans Management Skill

Plans.md のタスク管理とマーカー運用を行うスキル。

---

## トリガーフレーズ

このスキルは以下のフレーズで起動します：

- 「タスクを追加して」
- 「Plans.md を更新して」
- 「完了マークをつけて」
- 「タスクの状態を変更して」
- "add a task"
- "update plans"
- "mark as complete"

---

## 概要

このスキルは Plans.md の編集・更新を支援します。
タスクの追加、状態変更、アーカイブを一貫したフォーマットで行います。

---

## Plans.md の構造

```markdown
# Plans.md - タスク管理

> **最終更新**: YYYY-MM-DD HH:MM
> **更新者**: Claude Code / PM（Cursor/PM Claude）

---

## 🔴 進行中のタスク

- [ ] タスク名 `cc:WIP`
  - 詳細説明
  - 関連ファイル: `path/to/file.ts`

---

## 🟡 未着手のタスク

- [ ] タスク名 `cc:TODO`
- [ ] タスク名 `pm:依頼中`（互換: cursor:依頼中）

---

## 🟢 完了タスク

- [x] タスク名 `pm:確認済` (YYYY-MM-DD)

---

## 📦 アーカイブ

<!-- 古い完了タスクはここに移動 -->
```

---

## マーカー運用ルール

### 状態変更のルール

| 変更 | 実行者 | 条件 |
|------|--------|------|
| `pm:依頼中`（互換: cursor:依頼中） → `cc:WIP` | Claude Code | タスク着手時 |
| `cc:TODO` → `cc:WIP` | Claude Code | タスク着手時 |
| `cc:WIP` → `cc:完了` | Claude Code | 作業完了時 |
| `cc:完了` → `pm:確認済`（互換: cursor:確認済） | PM | レビュー完了時 |
| `*` → `blocked` | どちらでも | ブロック発生時 |

### マーカーのフォーマット

```markdown
# 正しい例
- [ ] タスク名 `cc:WIP`
- [x] タスク名 `cc:完了` (2024-01-15)

# 間違った例
- [ ] タスク名 cc:WIP      # バッククォートなし
- [ ] タスク名 `cc: WIP`   # スペースあり
```

---

## タスク操作

### タスクの追加

```markdown
## 追加前
## 🟡 未着手のタスク

- [ ] 既存タスク `cc:TODO`

## 追加後
## 🟡 未着手のタスク

- [ ] 既存タスク `cc:TODO`
- [ ] 新規タスク `cc:TODO`
  - 詳細説明（あれば）
```

### タスクの状態変更

```markdown
## 変更前
- [ ] タスク名 `cc:TODO`

## 変更後
- [ ] タスク名 `cc:WIP`
```

### タスクの完了

```markdown
## 変更前
- [ ] タスク名 `cc:WIP`

## 変更後
- [x] タスク名 `cc:完了` (2024-01-15)
```

### タスクのアーカイブ

完了から 7日以上経過したタスクはアーカイブセクションに移動：

```markdown
## 📦 アーカイブ

### 2024年1月
- [x] タスク1 `pm:確認済` (2024-01-10)
- [x] タスク2 `pm:確認済` (2024-01-08)
```

---

## 自動整形ルール

Plans.md を更新する際は以下を遵守：

1. **最終更新を必ず記載**: ヘッダーの日時を更新
2. **セクション順序を維持**: 進行中 → 未着手 → 完了 → アーカイブ
3. **空セクションは残す**: タスクがなくてもセクションヘッダーは削除しない
4. **インデントを統一**: 2スペースまたは4スペース

---

## 便利なパターン

### サブタスク

```markdown
- [ ] 親タスク `cc:WIP`
  - [x] サブタスク1
  - [ ] サブタスク2
  - [ ] サブタスク3
```

### ブロック理由の記載

```markdown
- [ ] タスク名 `blocked`
  - ブロック理由: API キーの発行待ち
  - 担当: @username
  - 期限: 2024-01-20
```

### 優先度の表現

```markdown
- [ ] 🔥 緊急タスク `pm:依頼中`（互換: cursor:依頼中）
- [ ] ⭐ 重要タスク `cc:TODO`
- [ ] タスク `cc:TODO`
```

---

## 関連コマンド

- `/sync-status` - 現在の状態サマリーを出力
- `/handoff-to-cursor` - 完了報告時に Plans.md を自動更新

---

## 注意事項

- **Plans.md は単一ソース**: タスク情報を他のファイルに分散させない
- **こまめに更新**: 作業開始時・終了時に必ず更新
- **Cursor との同期**: 長時間経過したら `/sync-status` で確認

---

## 拡張記法（オプション）

大規模プロジェクトでは以下の記法を**オプション**で使用可能：

### タスク ID / 依存関係 / 並列可

```markdown
- [ ] T001: 認証機能 `cc:TODO`
- [ ] T002: ユーザーAPI `cc:TODO` depends:T001
- [ ] T003: 商品API `cc:TODO` [P]
- [ ] T004: 注文API `cc:TODO` depends:T001,T003
```

| 記法 | 意味 | 用途 |
|------|------|------|
| `T001:` | タスクID | 参照・依存指定に利用 |
| `depends:ID` | 依存タスク | `depends:T001,T002`（カンマ区切り） |
| `[P]` | 並列可（Parallelizable） | `/work` 実行時に他タスクと同時実行 |

### 依存解析の例

```
T001 (認証) ─────────────┐
                         ↓
T003 (商品API) [P] ─────> T004 (注文API)
                         ↑
T002 (ユーザーAPI) ─────┘
```

**後方互換**: ID/depends/[P] がなくても従来形式で問題なく動作する。
