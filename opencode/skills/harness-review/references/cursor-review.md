# Cursor Review (--cursor) — second-opinion only

cursor (composer-2.5-fast) を harness-review の **second-opinion** として並走させる lean モード。`HARNESS_IMPL_BACKEND=cursor` の時も同等 trigger。

## 不変ルール

- **cursor は primary reviewer に昇格しない**。Opus reviewer が必ず並走し、primary verdict は Opus から取る。cursor 出力は `dual_review.cursor_verdict` に advisory として格納する。
- 根拠: `harness-work` の「実装したバックエンドが自分の出力をレビューしてはならない」不変ルール (cursor backend で書いたコードを cursor backend にレビューさせる構成を避ける)。
- cursor は read-only delegate のため、worktree 隔離 / Lead diff review / cherry-pick / `worker-report.v1` は **不要**。

## 委譲前 mandatory banner

cursor delegate を起動する前に、必ず以下の literal 1 行を出力する:

```
⚠️ cursor review (read-only): model=composer-2.5-fast / R01-R13 は cursor-agent 内部に適用されない / 出力は Lead 評定まで untrusted
```

## 委譲コマンド (read-only、workspace 不要)

```bash
bash scripts/cursor-companion.sh task "<review prompt>"
```

- `--write` を **絶対に付けない** (cursor-companion.sh は `--write` 未指定で default `--mode ask` = hard read-only stop)
- `--workspace` も **付けない** (read mode では companion guard が発火せず optional 扱い、不要)
- `--force` / `--yolo` も付けない (Cursor 公式 "Never use")

review prompt の構成例:

```
diff レビュー (base_ref={BASE_REF}, head=HEAD):

<git diff の要点 or branch range>

観点:
- 仕様逸脱 / 範囲外変更
- 既存テスト regression リスク
- secret / 認証情報の混入
- protected path (settings*, .eslintrc*, tsconfig*.json) への変更

verdict は APPROVE / REQUEST_CHANGES / NEEDS_INFO のいずれかで返す。
```

## Trust boundary (read mode でも保持必須)

| 項目 | 内容 | 設定場所 |
|---|---|---|
| Secret 遮断 | `.cursorignore` で `.env` / `*.pem` / `*.key` / `.ssh` / `.aws` / `.git` を除外 | repo root |
| Egress allowlist | `~/.claude/settings.json` の `sandbox.network.allowedDomains` に `*.cursor.sh` | user settings |
| Filesystem allowlist | 同 `sandbox.filesystem.allowWrite` に `~/.cursor` | user settings |
| permissions.json | `~/.cursor/permissions.json` の `terminalAllowlist` / `mcpAllowlist` (best-effort、security boundary ではない) | user config |

cursor 公式は "Allowlists are best-effort convenience. They are not a security guarantee." と明言。これら 4 点は **read mode でも保持必要**だが、依存しすぎないこと。実効的境界は Lead 判定。

## Verdict マッピング

cursor 出力を以下の schema 拡張で `dual_review` に格納する (`references/dual-review.md` 参照):

```json
{
  "claude_verdict": "APPROVE | REQUEST_CHANGES | NEEDS_INFO",
  "codex_verdict": "approve | needs-attention | unavailable | timeout",
  "cursor_verdict": "APPROVE | REQUEST_CHANGES | NEEDS_INFO | unavailable | timeout",
  "cursor_divergence_notes": "string?"
}
```

- `cursor_verdict` は **optional field**。`--dual` / `--cursor` を指定したときだけ追加される
- `cursor_divergence_notes`: Claude/Codex/Cursor の verdict が割れた場合に Lead が記入
- 既存 consumer (HTML render / harness-accept 等) は optional 扱いで parser を壊さない

## Verdict 統合ルール

primary verdict (Opus reviewer) を最優先。cursor / codex は **advisory**:

| Opus | Codex | Cursor | 最終 verdict |
|---|---|---|---|
| APPROVE | approve | APPROVE | APPROVE (3 者一致、最高信頼) |
| APPROVE | approve | REQUEST_CHANGES | APPROVE + cursor_divergence_notes (Opus 優先、cursor の指摘は次回 PR の改善点として記録) |
| REQUEST_CHANGES | * | * | REQUEST_CHANGES (Opus が REQUEST なら即 REQUEST) |
| APPROVE | needs-attention | * | TeamAgent Debate を実行 (`--team-debate`) |

## 不可逆ガード

cursor からの suggested edit は **実コードで確認してから採否を決める** (`codex-closeout.md` の Advisory rule と同じ契約)。cursor が「この行を削除すべき」と言っても、Lead が diff の文脈と影響範囲を確認してから判断する。cursor 単独で commit / push を発火させない。

## Related

- `.claude/rules/cursor-cli-only.md` — Cursor backend governance + Read mode delegation
- `references/dual-review.md` — dual / triple review の合格ライン統合
- `references/governance.md` — review 全体の合格ライン
- `skills/cursor-ask/SKILL.md` — read-only delegate の汎用版 (review 以外の質問・調査)
