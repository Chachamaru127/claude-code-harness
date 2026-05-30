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

## Narration Rules (UX Hard Contract)

このスキルは「起動 → 委譲開始」を 3 秒以内に進めるため、中間ナレーションを禁ずる。違反した skill は UX 不合格として扱う。

- **過去経緯の振り返り禁止**: 「先ほど止まった」「以前 X した」を語らない
- **事前宣言禁止**: 「使い方を確認します」「次は X を確認します」を出さない。tool call 自体が宣言
- **同じ事実の 2 回言い換え禁止**: cursor-companion の確認結果を後段で再度説明しない
- **中間ステータスラベル禁止**: 「実行中」「実行済み」「次は…」を出さない
- **★ Insight ブロック禁止 (起動シーケンス中)**: Explanatory style を一時停止する。Insight は最終 report で 1 回のみ可
- **最初の text は 1 行のみ**: `🚀 cursor / composer-2.5-fast / ask` 形式で first text として 1 秒以内に出す

違反例:
```
× 「cursor に質問を投げる準備をします」→ bash → 「投げます」
× 「ask モードは読み取り専用なので安全です」と再説明
× ★ Insight ──── まず cursor の状態を確認します: ...
```

正常例:
```
🚀 cursor / composer-2.5-fast / ask
```

## Execution Flow

### Step 0: Narration check

上記 Narration Rules を厳守する。3 秒以内に Step 1 へ。

### Step 1: 1-line banner

最初の text として **1 行だけ** 出す:

```
🚀 cursor / composer-2.5-fast / ask
```

`composer-2.5-fast` は `scripts/model-routing.sh --host cursor --role worker --field model` で解決される値の代表表記。実際の resolved model は cursor-companion 側のログに出る。

### Step 2: cursor-companion 直接実行

`$ARGUMENTS` を質問文として渡す。**`--write` は絶対に付けない**:

```bash
bash scripts/cursor-companion.sh task "<question>"
```

実装例:

```bash
QUESTION="$ARGUMENTS"
if [ -z "$QUESTION" ]; then
  echo "ERROR: question required. Usage: /cursor:ask \"<your question>\"" >&2
  exit 1
fi

bash scripts/cursor-companion.sh task "$QUESTION"
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
