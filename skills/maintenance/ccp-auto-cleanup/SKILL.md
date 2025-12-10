---
name: ccp-auto-cleanup
description: "ファイルの自動整理・アーカイブを行うスキル"
metadata:
  skillport:
    category: maintenance
    tags: [cleanup, archive, rotate, maintenance]
    alwaysApply: false
---

# Auto Cleanup Skill

Plans.md、session-log.md 等のファイル肥大化を防ぐ自動整理スキル。

---

## トリガーフレーズ

このスキルは以下のフレーズで起動します：

- 「ファイルを整理して」
- 「アーカイブして」
- 「古いタスクを移動して」
- `/cleanup`
- "clean up files"
- "archive old tasks"

---

## 概要

このスキルは以下のファイルを自動整理します：

| ファイル | 閾値 | アクション |
|---------|------|-----------|
| Plans.md | 完了から7日 or 200行超 | 📦 アーカイブへ移動 |
| session-log.md | 30日経過 or 500行超 | 月別ファイルに分割 |
| CLAUDE.md | 100行超 | 警告 + 分割提案 |

---

## 設定ファイル

`.cursor-cc-config.yaml` で閾値をカスタマイズ可能：

```yaml
cleanup:
  plans:
    archive_after_days: 7        # 完了からN日でアーカイブ
    max_lines: 200               # 最大行数
    archive_max_items: 50        # アーカイブ最大件数

  session_log:
    archive_after_days: 30       # N日で月別に分割
    max_lines: 500               # 最大行数
    archive_path: ".claude/memory/archive/sessions/"

  claude_md:
    max_lines: 100               # 警告閾値
    warn_only: true              # 警告のみ（自動編集しない）

  auto_run: session_start        # 実行タイミング
```

---

## 実行手順

### Step 1: 設定の読み込み

```bash
# 設定ファイルがあれば読み込み、なければデフォルト値
CONFIG_FILE=".cursor-cc-config.yaml"
if [ -f "$CONFIG_FILE" ]; then
  # YAML パース
  PLANS_MAX_LINES=$(grep "max_lines:" "$CONFIG_FILE" | head -1 | awk '{print $2}')
else
  # デフォルト値
  PLANS_MAX_LINES=200
  ARCHIVE_AFTER_DAYS=7
fi
```

### Step 2: Plans.md の整理

```bash
check_plans_cleanup() {
  local file="Plans.md"
  [ ! -f "$file" ] && return 0

  local lines=$(wc -l < "$file")
  local completed_count=$(grep -c "\[x\].*cursor:確認済" "$file" || echo 0)

  echo "📊 Plans.md: ${lines}行, 完了タスク: ${completed_count}件"

  # 閾値チェック
  if [ "$lines" -gt "$PLANS_MAX_LINES" ]; then
    echo "⚠️ Plans.md が ${PLANS_MAX_LINES} 行を超えています"
    return 1
  fi

  # 7日以上前の完了タスクをカウント
  local old_tasks=$(grep -E "\[x\].*\([0-9]{4}-[0-9]{2}-[0-9]{2}\)" "$file" | while read line; do
    date_str=$(echo "$line" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}" | tail -1)
    if [ -n "$date_str" ]; then
      task_date=$(date -j -f "%Y-%m-%d" "$date_str" "+%s" 2>/dev/null || date -d "$date_str" "+%s" 2>/dev/null)
      now=$(date "+%s")
      diff=$(( (now - task_date) / 86400 ))
      [ "$diff" -gt 7 ] && echo "$line"
    fi
  done | wc -l)

  if [ "$old_tasks" -gt 0 ]; then
    echo "📦 ${old_tasks} 件の古いタスクをアーカイブ可能"
    return 1
  fi

  return 0
}
```

### Step 3: アーカイブ実行

```bash
archive_old_tasks() {
  local file="Plans.md"
  local archive_section="## 📦 アーカイブ"
  local today=$(date +%Y-%m-%d)

  # 🟢 完了タスクセクションから7日以上前のタスクを抽出
  # 📦 アーカイブセクションに移動
  # 移動後、元のセクションから削除

  echo "✅ 古いタスクをアーカイブに移動しました"
}
```

### Step 4: session-log.md の整理

```bash
check_session_log_cleanup() {
  local file=".claude/memory/session-log.md"
  [ ! -f "$file" ] && return 0

  local lines=$(wc -l < "$file")

  if [ "$lines" -gt 500 ]; then
    echo "⚠️ session-log.md が 500 行を超えています"

    # 月別に分割
    mkdir -p .claude/memory/archive/sessions
    # 古いエントリを archive/sessions/YYYY-MM.md に移動

    return 1
  fi

  return 0
}
```

### Step 5: CLAUDE.md のチェック

```bash
check_claude_md() {
  local file="CLAUDE.md"
  [ ! -f "$file" ] && return 0

  local lines=$(wc -l < "$file")

  if [ "$lines" -gt 100 ]; then
    echo "💡 CLAUDE.md が ${lines} 行あります"
    echo "   常に必要な情報以外は docs/ に分割することを検討してください"
    echo "   参考: @docs/filename.md で必要な時だけ読み込めます"
  fi

  return 0
}
```

---

## 出力フォーマット

### 整理が不要な場合

```
✅ **ファイル状態: 正常**

- Plans.md: 85行 (上限: 200行)
- session-log.md: 120行 (上限: 500行)
- 完了タスク: 5件 (7日以内)

整理の必要はありません。
```

### 整理が必要な場合

```
⚠️ **整理が推奨されます**

📋 **Plans.md**
- 現在: 250行 (上限: 200行)
- 完了タスク: 15件 (うち7日以上前: 8件)

**推奨アクション:**
1. 8件の古いタスクをアーカイブへ移動

実行しますか？ (y/n)
```

### 整理完了後

```
✅ **整理完了**

- Plans.md: 250行 → 180行 (-70行)
- アーカイブに移動: 8タスク
- バックアップ: .claude/memory/archive/Plans-2025-01-15.md

次回の自動チェック: セッション開始時
```

---

## Hook との連携

PostToolUse Hook から呼び出される場合：

1. Plans.md への書き込み検知
2. 行数チェック
3. 閾値超過時は警告メッセージを返す
4. Claude へのフィードバックとして整理を提案

```json
{
  "decision": "allow",
  "feedback": "⚠️ Plans.md が 200行を超えました。`/cleanup` で整理することを推奨します。"
}
```

---

## 関連コマンド

- `/cleanup` - 手動で整理を実行
- `/cleanup --dry-run` - 実行せずプレビュー
- `/cleanup plans` - Plans.md のみ整理
- `/cleanup sessions` - session-log のみ整理

---

## 注意事項

- **進行中タスクは移動しない**: `cc:WIP` や `cursor:依頼中` は対象外
- **バックアップを作成**: 整理前に自動バックアップ
- **設定でカスタマイズ可能**: 閾値はプロジェクトごとに調整可能
