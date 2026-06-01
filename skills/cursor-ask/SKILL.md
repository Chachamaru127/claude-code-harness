---
name: cursor-ask
description: "Read-only delegate to cursor-agent (Composer) for questions, investigation, design discussion, and adversarial sanity checks. No worktree, no cherry-pick, no Lead diff review — cursor-agent is locked to ask mode and cannot write. Use when user says: ask cursor, cursor sanity check, get a second opinion, adversarial review, design discussion, investigate with cursor, /cursor:ask, /ask-cursor. Do NOT load for: implementation, refactor, file edits, commit/push work, anything requiring write access (use /cursor:do or /breezing --cursor instead)."
description-en: "Read-only delegate to cursor-agent (Composer) for questions, investigation, design discussion, and adversarial sanity checks. No worktree, no cherry-pick, no Lead diff review — cursor-agent is locked to ask mode and cannot write. Use when user says: ask cursor, cursor sanity check, get a second opinion, adversarial review, design discussion, investigate with cursor, /cursor:ask, /ask-cursor. Do NOT load for: implementation, refactor, file edits, commit/push work, anything requiring write access (use /cursor:do or /breezing --cursor instead)."
description-ja: "cursor-agent (Composer) への読み取り専用デリゲート。質問・調査・設計相談・敵対的視点（sanity check）用。worktree 不要、cherry-pick 不要、Lead diff review 不要。cursor は ask mode 固定で書き込み不可。Use when user says: cursor に聞いて, cursor に相談, セカンドオピニオン, 敵対的レビュー, 設計相談, cursor で調査, /cursor:ask, /ask-cursor. Do NOT load for: 実装、リファクタ、ファイル編集、コミット/プッシュ作業、書き込みが必要な作業 (代わりに /cursor:do / /breezing --cursor を使う)。"
allowed-tools: ["Read", "Bash"]
argument-hint: "[question]"
user-invocable: true
---

# cursor-ask — Read-Only Cursor Delegate

cursor-agent (Composer) に **read-only** で質問・調査・設計相談・敵対的レビューを委譲する軽量スキル。

`cursor-companion.sh task` は引数なしで **`--mode ask` (hard read-only stop)** が自動で付くため、`--write` を渡さない限り cursor 側は **ファイル書き込み・コマンド実行ができない**。これにより worktree 隔離・cherry-pick・Lead diff review がすべて不要になる。

## Quick Reference

```bash
/cursor:ask "この設計判断、Composer 視点でどう思う？"
/cursor:ask "TASK_BASE_REF からの diff を読んで、見落としを 3 つ挙げて"
/cursor:ask "harness-mem の cross-project N-call、楽観的すぎる前提はある？"
```

用途:

| ケース | 例 |
|---|---|
| 質問 | "この型エラーの根本原因は？" |
| 調査 | "scripts/ 配下で curl を使ってる箇所を全部挙げて理由付きで" |
| 設計相談 | "この abstraction、3 年後に保守できる？" |
| 敵対的視点 | "この PR の最大の弱点を 1 つだけ挙げて" |

## Narration Rules (UX Contract)

敵は **冗長さ** であって進捗報告ではない。**起動時に何を聞くか・どう進めるかを簡潔に明示してから実行する**。冗長な繰り返し・中身のない前置きだけを禁ずる。

### 起動時に必ず出すもの (banner + plan、3 行以内)

```
🚀 cursor / composer-2.5-fast / ask
これから: <質問の要点> を composer に投げて、結果を 3-5 行で要約
```

banner 1 行 + 計画 1-2 行。1 秒以内に出し、即 Step 2 へ。

### 進捗報告は出してよい

- 委譲開始の 1 行 (`→ composer に問い合わせ中`)
- 判断に必要な経緯を 1 行で

### 禁止 (= 冗長さ)

- **同じ事実の 2 回言い換え**: cursor-companion の結果を後段で再説明しない
- **中身のない前置き**: 「使い方を確認します」だけの行など tool call で自明な宣言
- **3 行以上の経緯振り返り**: 必要なら 1 行に圧縮
- **起動シーケンス中の ★ Insight ブロック**: Insight は最終要約で 1 回のみ

違反例 (冗長):
```
× 「cursor に質問を投げる準備をします」→ bash → 「投げます」（中身のない前置き + 言い換え）
× 「ask モードは読み取り専用なので安全です」と再説明（既知事実の繰り返し）
× ★ Insight ──── まず cursor の状態を確認します: ...
```

正常例 (簡潔 + 計画明示):
```
🚀 cursor / composer-2.5-fast / ask
これから: 設計の弱点を composer に問い、結果を 3-5 行で要約
```

## Execution Flow

### Step 0: 起動時 banner + plan

上記 Narration Rules に従い、banner + 計画 (3 行以内) を出してから Step 1 へ。

### Step 1: banner 確認

Step 0 で banner + 計画 (3 行以内) は出し切っているので、ここでは banner 行が出ていることを確認する。banner は:

```
🚀 cursor / composer-2.5-fast / ask
```

以降は委譲開始の 1 行ステータス等で進捗を見せてよい。冗長な繰り返しのみ避ける。

`composer-2.5-fast` は `scripts/model-routing.sh --host cursor --role worker --field model` で解決される値の代表表記。実際の resolved model は cursor-companion 側のログに出る。

### Step 2: cursor-companion 直接実行

`$ARGUMENTS` を質問文として渡す。**`--write` は絶対に付けない**。`scripts/cursor-companion.sh` を相対パスで呼ぶと consumer repo の cwd 直下に見えず exit するため、`CLAUDE_PLUGIN_ROOT` / `HARNESS_PLUGIN_ROOT` を hooks.json と同じ `valid_root` パターンで解決する (Issue #193 §2):

```bash
QUESTION="$ARGUMENTS"
if [ -z "$QUESTION" ]; then
  echo "ERROR: question required. Usage: /cursor:ask \"<your question>\"" >&2
  exit 1
fi

bash -c '
  set -euo pipefail
  valid_root() {
    [ -n "${1:-}" ] && [ -f "$1/scripts/cursor-companion.sh" ] && [ -f "$1/.claude-plugin/plugin.json" ]
  }
  ROOT="${CLAUDE_PLUGIN_ROOT:-${HARNESS_PLUGIN_ROOT:-}}"
  if ! valid_root "$ROOT"; then
    ROOT=""
    for c in "${CLAUDE_PROJECT_DIR:-}" "$PWD" \
             "$HOME/.claude/plugins/marketplaces/claude-code-harness-marketplace" \
             "$HOME/.claude/plugins/cache/claude-code-harness-marketplace/claude-code-harness/"*; do
      if valid_root "$c"; then ROOT="$c"; break; fi
    done
  fi
  if ! valid_root "$ROOT"; then
    echo "ERROR: claude-code-harness plugin root not found (no scripts/cursor-companion.sh)" >&2
    exit 2
  fi
  bash "$ROOT/scripts/cursor-companion.sh" task "$1"
' _ "$QUESTION"
```

これだけで cursor-agent 側は `--mode ask` (hard read-only stop) に locked される。`--force` / `--yolo` も付かない。

### Step 3: 結果を host が 3-5 行で要約

cursor の出力をそのまま貼らない。host (Claude) が読んで **3-5 行に要約** する:

- 結論
- なぜそう言えるか (cursor が挙げた根拠の核)
- 注意点 / 追加調査が必要な点
- 次の一手 (もしあれば)

要約後、最後に literal で次の一文を出力する:

```
↑この結果は Claude が要約します。Enter キーで次へ進むか、新規 prompt で別の指示を出してください。
```

## Trust Boundary

cursor は不透明なサブプロセスであり、Harness のガードレール (R01-R13) は内部に適用されない。read-only 委譲でも以下の前提条件を満たすこと。

### 必須前提

| 項目 | 内容 | 設定場所 |
|---|---|---|
| Secret 遮断 | `.cursorignore` で `.env` / `*.pem` / `*.key` / `.ssh` / `.aws` / `.git` を読取対象から除外 | repo root `.cursorignore` |
| Egress allowlist | `~/.claude/settings.json` の `sandbox.network.allowedDomains` に `*.cursor.sh` を追加 | user settings |
| Filesystem allowlist | 同 `sandbox.filesystem.allowWrite` に `~/.cursor` を追加 (cursor-agent が状態書込を行うため) | user settings |
| permissions.json | `~/.cursor/permissions.json` の `terminalAllowlist` / `mcpAllowlist` は read mode でも有効 (allowlist は best-effort、security boundary ではない) | user config |

詳細は `.claude/rules/cursor-cli-only.md` を参照。

### ask mode で省略できるもの

| 通常の cursor 委譲で必要 | ask mode では不要 | 理由 |
|---|---|---|
| 隔離 worktree | 不要 | cursor は書き込みできない |
| Lead diff review | 不要 | 差分が生まれない |
| cherry-pick | 不要 | 同上 |
| `worker-report.v1` / self_review 5 件 | 不要 | 実装をしないため |

### それでも残るリスク

- **読み取り漏洩**: `.cursorignore` を怠ると秘密ファイルが cursor 推論に渡る
- **誤った情報の鵜呑み**: cursor 出力は untrusted。Step 3 の要約で必ず host が判断軸を残す
- **allowlist 過信**: Cursor 公式は "Allowlists are best-effort convenience. They are not a security guarantee." と明言。allowlist に依存しない

## Topology

```
Lead (Claude) ──[cursor-companion.sh task]──> cursor-agent (--mode ask, locked read-only)
       │
       └──[Step 3: 3-5 行要約]──> User
```

Worker 介在なし。Reviewer 介在なし。`worker-report.v1` / `review-result.v1` 契約は発生しない。

## Related Skills / Rules

- `cursor-do` — 書込タスク委譲（worktree + Lead review + cherry-pick の full containment）
- `breezing --cursor` — Reviewer のみ cursor に逃がす lean second-opinion レーン
- `harness-review --cursor` — レビューを cursor (composer-2.5-fast) に second-opinion として依頼
- `.claude/rules/cursor-cli-only.md` — Cursor backend governance (trust boundary, prohibited flags)
