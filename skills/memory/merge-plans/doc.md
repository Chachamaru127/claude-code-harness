---
name: merge-plans
description: "Plans.md のマージ更新を行うスキル（ユーザータスクを保持）。複数のPlans.mdを統合する必要がある場合に使用します。"
allowed-tools: ["Read", "Write", "Edit"]
metadata:
  skillport:
    category: core
    tags: [merge, plans, tasks, preserve]
    alwaysApply: false
---

# Merge Plans Skill

既存の Plans.md を更新する際に、ユーザーのタスクデータを保持しながら
テンプレートの構造を適用するスキル。

---

## 目的

- ユーザーのタスク（🔴🟡🟢📦セクション）を保持
- テンプレートの構造・マーカー定義を更新
- 最終更新情報を更新

---

## Plans.md の構造

```markdown
# Plans.md - タスク管理

> **プロジェクト**: {{PROJECT_NAME}}
> **最終更新**: {{DATE}}
> **更新者**: Claude Code

---

## 🔴 進行中のタスク        ← ユーザーデータ（保持）

## 🟡 未着手のタスク        ← ユーザーデータ（保持）

## 🟢 完了タスク            ← ユーザーデータ（保持）

## 📦 アーカイブ            ← ユーザーデータ（保持）

## マーカー凡例             ← テンプレートから更新

## 最終更新情報             ← 日付を更新
```

---

## マージアルゴリズム

### Step 1: セクション分割

```
既存の Plans.md を以下のセクションに分割:

1. ヘッダー部分（# Plans.md ... ---）
2. 🔴 進行中のタスク（次のセクションまで）
3. 🟡 未着手のタスク（次のセクションまで）
4. 🟢 完了タスク（次のセクションまで）
5. 📦 アーカイブ（次のセクションまで）
6. マーカー凡例（次のセクションまで）
7. 最終更新情報（ファイル末尾まで）
```

### Step 2: タスクセクションの抽出

```bash
extract_section() {
  local file="$1"
  local start_marker="$2"
  local end_markers="$3"  # パイプ区切りの終了マーカー

  awk -v start="$start_marker" -v ends="$end_markers" '
    BEGIN { in_section = 0; split(ends, end_arr, "|") }
    $0 ~ start { in_section = 1; next }
    in_section {
      for (i in end_arr) {
        if ($0 ~ end_arr[i]) { in_section = 0; exit }
      }
      if (in_section) print
    }
  ' "$file"
}

# 各セクションを抽出
TASKS_WIP=$(extract_section "$PLANS_FILE" "## 🔴" "## 🟡|## 🟢|## 📦|## マーカー|---")
TASKS_TODO=$(extract_section "$PLANS_FILE" "## 🟡" "## 🔴|## 🟢|## 📦|## マーカー|---")
TASKS_DONE=$(extract_section "$PLANS_FILE" "## 🟢" "## 🔴|## 🟡|## 📦|## マーカー|---")
TASKS_ARCHIVE=$(extract_section "$PLANS_FILE" "## 📦" "## 🔴|## 🟡|## 🟢|## マーカー|---")
```

### Step 3: タスクの検証

```bash
# 空でないことを確認
count_tasks() {
  echo "$1" | grep -c "^\s*- \[" || echo "0"
}

WIP_COUNT=$(count_tasks "$TASKS_WIP")
TODO_COUNT=$(count_tasks "$TASKS_TODO")
DONE_COUNT=$(count_tasks "$TASKS_DONE")
ARCHIVE_COUNT=$(count_tasks "$TASKS_ARCHIVE")

echo "保持されるタスク:"
echo "  進行中: $WIP_COUNT"
echo "  未着手: $TODO_COUNT"
echo "  完了: $DONE_COUNT"
echo "  アーカイブ: $ARCHIVE_COUNT"
```

### Step 4: 新しい Plans.md の生成

```markdown
# Plans.md - タスク管理

> **プロジェクト**: {{PROJECT_NAME}}
> **最終更新**: {{DATE}}
> **更新者**: Claude Code

---

## 🔴 進行中のタスク

<!-- cc:WIP のタスクをここに記載 -->

{{TASKS_WIP}}

---

## 🟡 未着手のタスク

<!-- cc:TODO, pm:依頼中（互換: cursor:依頼中） のタスクをここに記載 -->

{{TASKS_TODO}}

---

## 🟢 完了タスク

<!-- cc:完了, pm:確認済（互換: cursor:確認済） のタスクをここに記載 -->

{{TASKS_DONE}}

---

## 📦 アーカイブ

<!-- 古い完了タスクはここに移動 -->

{{TASKS_ARCHIVE}}

---

## マーカー凡例

| マーカー | 意味 |
|---------|------|
| `pm:依頼中` | PM から依頼されたタスク（互換: cursor:依頼中） |
| `cc:TODO` | Claude Code 未着手 |
| `cc:WIP` | Claude Code 作業中 |
| `cc:完了` | Claude Code 完了（確認待ち） |
| `pm:確認済` | PM 確認完了（互換: cursor:確認済） |
| `cursor:依頼中` | （互換）pm:依頼中 と同義 |
| `cursor:確認済` | （互換）pm:確認済 と同義 |
| `blocked` | ブロック中（理由を併記） |

---

## 最終更新情報

- **更新日時**: {{DATE}}
- **最終セッション担当**: Claude Code
- **ブランチ**: main
- **更新種別**: プラグインアップデート
```

---

## 空セクションの処理

タスクが空の場合は、デフォルトテキストを挿入:

```markdown
## 🔴 進行中のタスク

<!-- cc:WIP のタスクをここに記載 -->

（現在なし）
```

---

## エラー処理

### Plans.md が解析できない場合

```bash
if ! validate_plans_structure "$PLANS_FILE"; then
  echo "⚠️ Plans.md の構造を解析できませんでした"
  echo "バックアップを保持し、新規テンプレートを使用します"

  # バックアップ
  cp "$PLANS_FILE" "${PLANS_FILE}.bak.$(date +%Y%m%d%H%M%S)"

  # テンプレートを使用
  use_template_instead=true
fi
```

### 必須セクションがない場合

不足しているセクションはテンプレートのデフォルトで補完。

---

## 出力

| 項目 | 説明 |
|------|------|
| `merge_successful` | マージ成功フラグ |
| `tasks_wip_count` | 進行中タスク数 |
| `tasks_todo_count` | 未着手タスク数 |
| `tasks_done_count` | 完了タスク数 |
| `tasks_archive_count` | アーカイブタスク数 |
| `backup_created` | バックアップ作成有無 |

---

## 使用例

```bash
# スキルの呼び出し
merge_plans \
  --existing "./Plans.md" \
  --template "$PLUGIN_PATH/templates/Plans.md.template" \
  --output "./Plans.md" \
  --project-name "my-project" \
  --date "$(date +%Y-%m-%d)"
```

---

## 関連スキル

- `update-2agent-files` - 更新フロー全体
- `generate-workflow-files` - 新規生成
