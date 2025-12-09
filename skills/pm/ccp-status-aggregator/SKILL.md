---
name: ccp-status-aggregator
description: "タスク状態を集計し進捗サマリーを生成するスキル"
metadata:
  skillport:
    category: pm
    tags: [status, aggregate, progress, summary]
    alwaysApply: false
---

# Status Aggregator

Plans.md からタスク状態を集計し、進捗サマリーを生成するスキル。

---

## 目的

Plans.md の情報を解析して：
- タスクのステータス別カウント
- 進捗率の算出
- 現在の作業内容の特定
- 次に着手すべきタスクの特定

---

## 入力

| 項目 | 説明 |
|------|------|
| `tasks_todo` | 未着手タスク (cc:TODO) |
| `tasks_wip` | 作業中タスク (cc:WIP) |
| `tasks_done` | 完了タスク (cc:完了 / cc:done) |
| `tasks_blocked` | ブロック中タスク |

---

## 出力

| 項目 | 説明 |
|------|------|
| `total_tasks` | 総タスク数 |
| `progress_percent` | 進捗率 (%) |
| `current_work` | 現在作業中のタスク |
| `next_task` | 次に着手すべきタスク |

---

## 集計ロジック

### 進捗率の計算

```
進捗率 = (完了タスク数 / 総タスク数) × 100
```

### 現在の作業

`cc:WIP` マーカーが付いたタスクを抽出：
- 複数ある場合は最初のものを表示
- ない場合は「作業中タスクなし」

### 次のタスク

優先度判定：
1. `cursor:依頼中` マーカーがあるもの（PM から依頼済み）
2. `cc:TODO` の先頭タスク
3. なければ「次のタスクなし」

---

## マーカー対応表

| 日本語マーカー | 英語マーカー | ステータス |
|--------------|-------------|-----------|
| `cursor:依頼中` | `cursor:requested` | PM依頼済み |
| `cc:TODO` | `cc:TODO` | 未着手 |
| `cc:WIP` | `cc:WIP` | 作業中 |
| `cc:完了` | `cc:done` | 完了 |
| `cursor:確認済` | `cursor:verified` | PM確認済み |

---

## 出力例

```yaml
total_tasks: 12
progress_percent: 58
current_work:
  title: "ユーザー認証機能の実装"
  started_at: "2024-01-15 10:30"
  estimated_completion: "今日中"
next_task:
  title: "検索機能の追加"
  priority: "高"
  reason: "cursor:依頼中 マーカーあり"
```

---

## フェーズ別集計

Plans.md にフェーズ構造がある場合：

```markdown
### 📊 フェーズ別進捗

| フェーズ | 完了 | 残り | 進捗 |
|---------|------|------|------|
| Phase 1: 基盤 | 5/5 | 0 | 100% |
| Phase 2: 機能 | 3/6 | 3 | 50% |
| Phase 3: UI | 0/4 | 4 | 0% |

**現在のフェーズ**: Phase 2: 機能
```

---

## 注意事項

- 日本語・英語両方のマーカーを認識する
- マーカーがないタスクはカウントしない
- ブロック中タスクは進捗から除外しない
