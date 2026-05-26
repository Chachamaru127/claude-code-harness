# Cleanup Reference

`/maintenance` 各サブコマンドの実行手順・閾値・アーカイブ先の詳細。

## 共通: 環境変数（auto-cleanup-hook と同一 SSOT）

| 変数 | デフォルト | 参照元 |
|------|---------|-------|
| `PLANS_MAX_LINES` | 200 | `scripts/auto-cleanup-hook.sh` |
| `SESSION_LOG_MAX_LINES` | 500 | 同上 |
| `CLAUDE_MD_MAX_LINES` | 100 | 同上 |
| `ARCHIVE_AFTER_DAYS` | 7 | Plans.md 完了タスクの年齢閾値 |
| `LOGS_RETAIN_DAYS` | 30 | `.claude/logs/` の保持日数 |

ユーザーが自由記述で別の閾値を指定したらそちらを優先。

---

## plans — Plans.md アーカイブ

### 前提

1. `.claude/state/.ssot-synced-this-session` フラグ未存在 → `/memory sync` を促す
2. `cc:WIP`, `pm:依頼中`, `cursor:依頼中` タグの行は**絶対に動かさない**

### 手順

```bash
PLANS="Plans.md"
cp "$PLANS" "$PLANS.bak.$(date +%s)"

# 1. 現状を計測
wc -l "$PLANS"
grep -c '\[x\].*pm:確認済\|cursor:確認済' "$PLANS" || true

# 2. 7日以上前に完了した行を抽出（Edit ツールで個別に）
#    対象: `- [x] ... (YYYY-MM-DD) ... pm:確認済|cursor:確認済`
#    例外: cc:WIP / pm:依頼中 / cursor:依頼中 を含む行は除外

# 3. 抽出した行を「## 📦 アーカイブ」セクションへ append
#    アーカイブセクションが無ければ末尾に新設
```

### アーカイブセクションの書式

```markdown
## 📦 アーカイブ

### YYYY-MM (月ごとにグルーピング)

- [x] 旧タスク A (2026-04-05) pm:確認済
- [x] 旧タスク B (2026-04-07) cursor:確認済
```

### 検知しない場合の出力

```
✅ Plans.md: 180行（上限 200）。完了タスク 6件、うち7日以上前 0件。整理不要。
```

### 実行後の報告例

```
✅ Plans.md 整理完了
- 行数: 250 → 178 (-72)
- アーカイブ移動: 9件 (2026-03 グループ)
- バックアップ: Plans.md.bak.1712900000
```

---

## session-log — session-log.md 月別分割

対象は `.claude/memory/session-log.md`。500行超で分割推奨。

### 手順

```bash
LOG=".claude/memory/session-log.md"
ARCHIVE_DIR=".claude/memory/archive/sessions"
mkdir -p "$ARCHIVE_DIR"

# 1. エントリは `## YYYY-MM-DD` ヘッダーで区切られている前提
# 2. 直近30日分を残し、それより古いものを月別に分割
#    出力: .claude/memory/archive/sessions/YYYY-MM.md (append)
# 3. 元ファイルからは移動分を削除
```

### 分割ファイルの書式

各 `archive/sessions/YYYY-MM.md` の先頭に以下を記載:

```markdown
# Session Log — YYYY-MM

元ファイル: `.claude/memory/session-log.md` から N 日以降に移動。
移動日: YYYY-MM-DD
```

### 実行後の報告例

```
✅ session-log.md 分割完了
- 行数: 620 → 180
- 分割先: archive/sessions/2026-03.md (+230行), 2026-02.md (+210行)
```

---

## logs — `.claude/logs/` の古いファイル削除

### 手順

```bash
LOGS_DIR=".claude/logs"
[ -d "$LOGS_DIR" ] || exit 0

# dry-run で対象を列挙
find "$LOGS_DIR" -type f -mtime +${LOGS_RETAIN_DAYS:-30} -print

# 実行
find "$LOGS_DIR" -type f -mtime +${LOGS_RETAIN_DAYS:-30} -delete
```

### 報告例

```
✅ logs/ クリーンアップ完了
- 削除: 12 ファイル (30日以上前)
- 残存: 34 ファイル
```

---

## state — agent-trace / harness-usage のトリム

`.claude/state/agent-trace.jsonl` と `.claude/state/harness-usage.json` は
append-only / growing JSON で放置すると数十MBになりうる。

### agent-trace.jsonl のトリム

```bash
TRACE=".claude/state/agent-trace.jsonl"
[ -f "$TRACE" ] || exit 0

# 末尾1000行だけ残す
tail -1000 "$TRACE" > "$TRACE.tmp" && mv "$TRACE.tmp" "$TRACE"
```

### harness-usage.json の圧縮

```bash
USAGE=".claude/state/harness-usage.json"
[ -f "$USAGE" ] || exit 0

# 60日以上前のエントリを削除（構造依存なので jq で条件を適切に書く）
# 実装前に現物構造を Read で確認してから処理する
```

### 報告例

```
✅ state トリム完了
- agent-trace.jsonl: 8421行 → 1000行
- harness-usage.json: 2026-02 以前のエントリを削除
```

---

## all — 全部実行

plans → session-log → logs → state の順で実行。途中でエラーが出たら停止してユーザーに報告。

### 実行フロー

1. SSOT 同期チェック（plans が対象に含まれる時のみ）
2. 各サブコマンドを順次実行
3. 最後に Before/After を一覧表示

### 報告例

```
✅ 総メンテナンス完了

| 対象 | Before | After | 変化 |
|------|--------|-------|------|
| Plans.md | 250行 | 178行 | -72 (アーカイブ 9件) |
| session-log.md | 620行 | 180行 | -440 (2ファイル分割) |
| logs/ | 46 files | 34 files | -12 (30日超) |
| agent-trace.jsonl | 8421行 | 1000行 | -7421 |

バックアップ: Plans.md.bak.1712900000
```

---

## よくある追加指示の処理例

| 指示 | 処理 |
|------|------|
| 「古いアーカイブも消して」 | `.claude/memory/archive/` 内の N 日超過を追加削除 |
| 「dry-run で」 | すべての削除・移動を `echo` に差し替え、何を消すかだけ列挙 |
| 「このファイルは残して」 | 対象リストから該当ファイルを除外して実行 |
| 「閾値を 300 行に上げて」 | `PLANS_MAX_LINES=300 ` 等の環境変数を一時的に上書き |

---

## 禁止事項

- ❌ `.claude/memory/decisions.md` / `patterns.md` の自動編集（SSOT 直接改変は禁止）
- ❌ `CHANGELOG.md` の圧縮・アーカイブ（歴史は削除しない）
- ❌ `.git/` 配下の操作
- ❌ バックアップ無しでの行削除（200行超ファイルは必ずバックアップを取る）
