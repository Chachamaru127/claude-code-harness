---
description: Plans.md タスク管理ルール（Plans.md 編集時のみ適用）
paths: "**/Plans.md"
_harness_template: "rules/plans-management.md.template"
_harness_version: "2.5.27"
---

# Plans.md Management Rules

## タスク記述フォーマット

```markdown
- [ ] タスク説明 `マーカー`
  - サブタスク1
  - サブタスク2
```

## マーカー運用

| マーカー | 付与者 | 意味 |
|---------|--------|------|
| `pm:依頼中` | PM（Cursor/PM Claude） | タスクを依頼 |
| `cc:TODO` | Claude Code | 未着手 |
| `cc:WIP` | Claude Code | 作業中 |
| `cc:完了` | Claude Code | 完了 |
| `pm:確認済` | PM（Cursor/PM Claude） | レビュー完了 |
| `cursor:依頼中` | Cursor | （互換）`pm:依頼中` と同義 |
| `cursor:確認済` | Cursor | （互換）`pm:確認済` と同義 |

## セクション構成

```markdown
## 🔴 進行中のタスク
（cc:WIP のタスク）

## 🟡 未着手のタスク
（cc:TODO, pm:依頼中（互換: cursor:依頼中） のタスク）

## 🟢 完了タスク
（cc:完了, pm:確認済（互換: cursor:確認済） のタスク）

## 📦 アーカイブ
（古い完了タスク）
```

## 更新ルール

1. **即時更新**: タスク開始時に `cc:WIP`、完了時に `cc:完了` を即座に付与
2. **サマリー記載**: 完了時は作業内容のサマリーを追記
3. **日付記録**: 完了セクションには日付を記載 `(YYYY-MM-DD)`
4. **アーカイブ**: 7日以上前の完了タスクは📦アーカイブへ移動

## 禁止事項

- ❌ 他者のマーカーを勝手に変更
- ❌ 進行中タスクの削除
- ❌ サマリーなしでの完了マーク

---

## 拡張記法（オプション）

大規模プロジェクトでは以下の記法を**オプション**で使用可能：

```markdown
- [ ] T001: 認証機能 `cc:TODO`
- [ ] T002: ユーザーAPI `cc:TODO` depends:T001
- [ ] T003: 商品API `cc:TODO` [P]
```

| 記法 | 意味 |
|------|------|
| `T001:` | タスクID（依存指定用） |
| `depends:ID` | 依存タスク（カンマ区切り可） |
| `[P]` | 並列実行可（Parallelizable） |

**後方互換**: これらがなくても従来通り動作する。
