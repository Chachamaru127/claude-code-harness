---
description: 全セッションにメッセージを送信（セッション間通信）
description-en: Broadcast message to all sessions (inter-session communication)
---

# /session-broadcast - セッション間ブロードキャスト

他のセッションで作業中の自分（または他のユーザー）にメッセージを送信します。
**API変更や重要な決定を即座に共有**できます。

## VibeCoder Quick Reference

- "**他のセッションに伝えて**" → このコマンド
- "**API変わったよ**" → 自動的に全セッションに通知
- "**変更を共有**" → ブロードキャスト送信

## Deliverables

- `.claude/sessions/broadcast.md` にメッセージを追記
- 他セッションが次のアクション前に通知を受け取る

---

## Usage

### 基本的な使い方

```bash
/session-broadcast "UserAPI: userId → user に引数名を変更しました"
```

### 自然言語での使い方

```
「他のセッションに、API変更したことを伝えて」
→ ブロードキャストメッセージを送信
```

---

## Execution Flow

### Step 1: メッセージ確認

ユーザーからメッセージを受け取ったら、内容を確認：

> 📤 **以下のメッセージを全セッションに送信しますか？**
>
> ```
> {ユーザーのメッセージ}
> ```
>
> 送信する場合は「はい」または Enter

### Step 2: ブロードキャスト実行

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/session-broadcast.sh" "メッセージ内容"
```

### Step 3: 完了報告

> ✅ **ブロードキャスト送信完了**
>
> | 項目 | 内容 |
> |------|------|
> | 送信時刻 | {timestamp} |
> | セッションID | {session_id} |
> | メッセージ | {message} |
>
> 💡 他のセッションは次のアクション前に通知を受け取ります

---

## Message Format

送信されるメッセージは以下の形式で保存されます：

```markdown
## 2024-01-23T10:30:00Z [session-abc1]
UserAPI: userId → user に引数名を変更しました

## 2024-01-23T10:45:00Z [session-abc1]
テストを追加しました
```

---

## Use Cases

### 1. API/型定義の変更通知

```bash
/session-broadcast "UserService.getUser() の戻り値に email フィールドを追加"
```

### 2. 重要な決定の共有

```bash
/session-broadcast "認証方式を JWT から Session に変更することに決定"
```

### 3. 作業状況の共有

```bash
/session-broadcast "決済機能の実装完了、レビューお願いします"
```

### 4. 注意喚起

```bash
/session-broadcast "⚠️ main ブランチにマージしないでください、CI修正中"
```

---

## Auto-broadcast (hooks連携)

特定のファイルを変更した際に自動でブロードキャストすることも可能です：

```yaml
# hooks で設定（将来実装）
trigger:
  file_changed:
    - "src/api/**"
    - "src/types/**"
action:
  broadcast: "{{file}} が変更されました"
```

---

## Related Commands

- `/session-inbox` - 受信メッセージを確認
- `/session-list` - アクティブセッション一覧

---

## Notes

- メッセージは最大100件まで保持されます（古いものから削除）
- 自分が送信したメッセージは自分の inbox には表示されません
- メッセージはローカルの `.claude/sessions/` に保存されます（リモート同期なし）
