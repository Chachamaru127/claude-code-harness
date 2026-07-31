# Monitor Tool Guide & Session Learning Propagation

## Monitor ツール活用ガイド (CC 2.1.98+)

長時間実行コマンドを監視する時は、ポーリング (Read で定期的にファイル末尾を読む) ではなく **Monitor ツール** を使用する。Monitor はバックグラウンドプロセスの stdout 各行を逐次通知として Lead に届けるため、polling より低レイテンシかつ低トークン消費で状況を把握できる。

**適用例**:
- `go test ./... -v` の実行中進捗監視
- `gh run watch` による GitHub Actions 進捗追跡
- `npm run build --watch` / `vite build --watch` のビルドエラー即時検知
- `codex-companion.sh status <job-id>` での Codex job 完了検知
- `docker-compose logs -f` / `kubectl logs -f` のデプロイログ追跡

**使い分けの判断基準**:

| 対象 | Monitor 使う? | 理由 |
|---|---|---|
| Agent (Worker / Reviewer) の完了監視 | 不要 | Agent 層が自前で完了通知する |
| `run_in_background: true` で投げた shell process | 推奨 | stdout 各行を逐次通知で拾える |
| 短時間の一発コマンド (`go test` 1 回実行) | 不要 | 通常の Bash tool 実行で十分 |
| 長時間 tail / watch / stream 系コマンド | 推奨 | polling より効率的 |

**Breezing Lead での典型パターン**:

```
Lead:
  Task(Worker1, ...)           ← Agent 完了待ち (Monitor 不要)
  Task(Worker2, ...)           ← 同上
  Bash(run_in_background, "gh run watch --exit-status")
  Monitor(tailCommand="...")   ← CI 失敗を即時検知 → Worker に修正指示
```

これにより Lead が「Worker 完了 → CI 失敗検知 → 修正指示」の反応速度を上げられる。

## Universal Violations Injection（セッション内 Worker 間の学習伝播）

同一 `/breezing` 起動内で蓄積された Reviewer の universal gotchas を次 Worker の briefing 冒頭に自動注入する。**同一セッション内のみ有効**（セッション終了で破棄、`session-memory` には書かない）。

```python
# Phase A 開始時に Lead プロセスの in-memory 配列を初期化
universal_violations = []  # List[str] — このセッション内で蓄積

# Phase B で Worker を spawn する直前、briefing 冒頭に注入:
def build_worker_briefing(task, contract_path):
    header = ""
    if universal_violations:
        header = (
            "🚨 同一セッションで既に検出された universal 違反（再発禁止）:\n"
            + "\n".join(f"- {v}" for v in universal_violations)
            + "\n\n"
        )
    return header + f"タスク: {task.内容}\nDoD: {task.DoD}\ncontract_path: {contract_path}\nmode: breezing"

# Reviewer が review-result.v1 を返した後、Lead が scope="universal" のみ抽出して累積:
for update in reviewer_result.memory_updates:
    # 後方互換: 文字列は task-specific 扱い → 無視
    if isinstance(update, str):
        continue
    if update.get("scope") == "universal":
        universal_violations.append(update["text"])
```

**方針**: 過剰設計回避のため、`session-memory` や `decisions.md` への永続化は行わない。Lead プロセスの in-memory 配列に保持するだけで、`/breezing` セッション終了時に破棄する（issue #87 本文の方針）。
