---
description: アクティブセッション一覧を表示（セッション間通信）
description-en: Show active sessions list (inter-session communication)
---

# /session-list - アクティブセッション一覧

現在アクティブなセッションの一覧を表示します。
**誰が作業中かを把握**するために使用します。

## VibeCoder Quick Reference

- "**他に誰か作業してる？**" → このコマンド
- "**セッション一覧**" → アクティブセッションを表示

## Deliverables

- アクティブセッションの一覧
- 各セッションの最終アクティブ時刻
- 現在のセッションの識別

---

## Usage

```bash
/session-list
```

---

## Execution Flow

### Step 1: セッション一覧取得

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/session-list.sh"
```

### Step 2: 結果表示

> 📋 **アクティブセッション一覧**
>
> | セッションID | 最終アクティブ | 状態 |
> |-------------|---------------|------|
> | session-abc1 | 2分前 | 🟢 現在のセッション |
> | session-def4 | 15分前 | 🟡 アクティブ |
> | session-ghi7 | 2時間前 | ⚪ 非アクティブ |
>
> 💡 ヒント:
> - `/session-broadcast "メッセージ"` で全セッションに通知
> - `/session-inbox` で受信メッセージを確認

---

## Session Status

| 状態 | アイコン | 説明 |
|------|----------|------|
| 現在のセッション | 🟢 | 今操作しているセッション |
| アクティブ | 🟡 | 1時間以内にアクティビティあり |
| 非アクティブ | ⚪ | 1時間以上アクティビティなし |

---

## How It Works

### セッション登録

- 各セッションは起動時に `.claude/sessions/active.json` に登録
- 定期的に最終アクティブ時刻を更新
- セッションIDは Harness が自動生成

### クリーンアップ

- 24時間以上非アクティブなセッションは自動削除
- 手動でのクリーンアップは不要

---

## Data Format

`.claude/sessions/active.json`:

```json
{
  "session-1234567890": {
    "short_id": "session-1234",
    "last_seen": 1706000000,
    "pid": "12345",
    "status": "active"
  }
}
```

---

## Related Commands

- `/session-broadcast` - メッセージを送信
- `/session-inbox` - 受信メッセージを確認

---

## Notes

- セッション情報はローカルに保存されます
- 同一マシン上の複数セッションのみ追跡可能
- ネットワーク越しのセッション共有は対象外（将来のMCP化で対応予定）
