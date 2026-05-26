---
name: harness-accept
description: "Generate an Acceptance Demo HTML for non-engineer vibecoders right before ship/wait/reject decision. Reads back the acceptance_criteria that were stored as personal-preference.v1 by harness-plan-brief (joined by user_request_hash), then renders a single-file HTML showing each criterion as verified or unverified along with a ship/wait/reject recommendation. Use when the user asks for an acceptance review, wants to decide whether to ship a delivered task, or says: acceptance demo, accept demo, 受け入れ判断, 受入レビュー, ship/wait/reject 判定, 検収レビュー. Do NOT load for: implementation, code review, release work."
description-en: "Generate an Acceptance Demo HTML for non-engineer vibecoders right before ship/wait/reject decision. Reads back the acceptance_criteria that were stored as personal-preference.v1 by harness-plan-brief (joined by user_request_hash), then renders a single-file HTML showing each criterion as verified or unverified along with a ship/wait/reject recommendation. Use when the user asks for an acceptance review, wants to decide whether to ship a delivered task, or says: acceptance demo, accept demo, 受け入れ判断, 受入レビュー, ship/wait/reject 判定, 検収レビュー. Do NOT load for: implementation, code review, release work."
description-ja: "実装完了直後の受け入れ判断 (ship / wait / reject) 前に Acceptance Demo HTML を生成する。harness-plan-brief が `personal-preference.v1` で書き込んだ acceptance_criteria を `user_request_hash` 経由で取得し、各基準ごとに verified / unverified を表示。`recommendation` を ship / wait / reject の 3 値で算出し、根拠を HTML 上で可視化する。Use when: 受け入れ判断, 受入レビュー, ship/wait/reject 判定, 検収レビュー。Do NOT load for: 実装作業, code review, release。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
argument-hint: "[task-description]"
user-invocable: true
---

# harness-accept

非エンジニアの発注者・プロデューサー職向けに、実装完了タスクの受け入れ判断 (ship / wait / reject) を **HTML 1 枚** で提示するスキル。
発注者の認知負荷ピーク (3) 受け入れ判断の段階で使う。

Phase 65.1.x (`harness-plan-brief`) の対構造として動作し、Plan Brief で承認した `acceptance_criteria` を read 側で取り戻して評価する。

## Quick Reference

- 「**Acceptance Demo を作って**」 → このスキル
- 「**受け入れ判断したい**」 → このスキル
- 「**ship/wait/reject 判定**」 → このスキル

## 責任境界

| 範囲 | このスキルの責務 |
|------|-----------------|
| 検索 | **現プロジェクトのみ** (`project: <current>`, `strict_project: true` を必ず指定) |
| クロスプロジェクト | **やらない** (Phase 65.3 以降で `--cross-project-group <name>` flag で opt-in 解放) |
| Plan Brief 連携 | `user_request_hash` を join key として `personal-preference.v1` (Phase 65.1.4) を read |
| 書き込み | やらない (Acceptance 承認後の memory write は `accept-record-decision.sh` の責務) |
| recommendation 算出 | verified / 全 criteria の比率で 0.8 / 0.5 閾値判定。ロジックは `scripts/render-html.sh` 直前で計算 |

## 入力

引数 `[task-description]` にユーザーの request を渡す (Plan Brief 時と同じ文を使う)。
引数なしの場合は対話形式で受け取る。

## 出力

| 出力 | パス | 形式 |
|------|------|------|
| Acceptance Demo HTML | `.claude/state/views/accept-<timestamp>.html` | 単独で開ける HTML (no server, no JS framework) |
| Acceptance context JSON | `.claude/state/views/accept-<timestamp>.context.json` | `acceptance-context.v1` schema |

## Schema: `acceptance-context.v1`

```json
{
  "schema": "acceptance-context.v1",
  "user_request": "string",
  "user_request_hash": "sha256 hex (Plan Brief 側の personal-preference.v1 と join)",
  "demo_artifacts": [
    { "kind": "video|screenshot|text", "path": "string" }
  ],
  "verified_criteria": [
    { "name": "string", "passed": true, "evidence": "string" }
  ],
  "tdd_verified": "yes|no|not-required|skip:<reason>",
  "unverified_caveats": ["string"],
  "past_issue_patterns": [
    { "pattern_id": "P5", "title": "string", "verified_in_current_task": true }
  ],
  "recommendation": "ship|wait|reject",
  "recommendation_evidence": ["string"],
  "project": "string",
  "generated_at": "ISO8601"
}
```

完全 schema は [`schemas/acceptance-context.v1.schema.json`](${CLAUDE_SKILL_DIR}/schemas/acceptance-context.v1.schema.json) を参照。

## Recommendation 算出ロジック

```
verified_count    = count of verified_criteria where passed=true
total_criteria    = count of verified_criteria
ratio             = verified_count / total_criteria  (total=0 のときは 0)

  ratio >= 0.8 → "ship"
  ratio >= 0.5 → "wait"
  ratio <  0.5 → "reject"
  total = 0    → "reject" (criteria 0 件は判定不能、安全側 reject)
```

評価根拠は `recommendation_evidence` に literal な数値で残す。
例: `"verified 4 件 / 全 5 件 (80%) → ship 閾値以上"`

## Execution Flow

スキル起動時、Claude は以下の手順で動作する。

### Step 1: project name と user_request_hash を解決

```bash
PROJECT_NAME="$(basename "$(git rev-parse --show-toplevel)")"
USER_REQUEST_HASH="$(printf '%s' "$USER_REQUEST" | sha256sum | awk '{print $1}')"
```

`PROJECT_NAME` が空 (git 外) の場合は `current` をデフォルトに使う。

### Step 2: harness-mem を **project-only** で検索し、Plan Brief 側 record を取得 (default)

引数に `--cross-project-group <name>` flag が**ない**場合 (default behavior):

`mcp__harness__harness_mem_search` を以下のパラメータで呼び出す:

```
project: <PROJECT_NAME>
strict_project: true
tags: ["personal-preference", "plan-brief-approval"]
limit: 10
```

> **重要**: `project` パラメータは**必須**。`strict_project: true` を指定し、cross-project な検索は**絶対に行わない**。

取得した record を `data.user_request_hash == <USER_REQUEST_HASH>` でフィルタし、最も新しい 1 件を選ぶ。
これが Plan Brief 時の承認内容 (chosen_option / acceptance_criteria 等) を保持している。

### Step 2 (alt): cross-project search (Phase 65.3.5 opt-in)

引数に `--cross-project-group <name>` flag が**ある**場合のみ、横断 group 内の他プロジェクトでの
類似 plan-brief-approval / acceptance-decision 履歴を取得する (D43 Option α):

```bash
MEMBERS_JSON="$(bash scripts/load-cross-project-groups.sh --group "<name>" 2>/dev/null)" || {
  echo "ERROR: cross-project group not found: <name>" >&2
  exit 1
}
```

`MEMBERS_JSON` が `[]` の場合は default の単一 project search に fallback。

`MEMBERS_JSON` が非空の場合、各 member project ごとに MCP search を 1 回発行:

```
for each project in MEMBERS_JSON:
  mcp__harness__harness_mem_search(
    project: <member>,
    strict_project: true,
    tags: ["personal-preference", "plan-brief-approval"],
    limit: 10
  )
```

結果を client 側でマージし、`data.user_request_hash == <USER_REQUEST_HASH>` でフィルタ。
hash 一致は基本的に同一 user request 由来のため複数 project での重複は稀だが、念のため id 単位で dedupe。

cross-project 由来の record を採用すると過去他案件の chosen_option / acceptance_criteria が混入する
可能性があるため、HTML 出力時は **`--with-redaction` flag を必ず使用** すること:

```bash
bash scripts/render-html.sh --template accept ... --with-redaction
```

詳細は `.claude/rules/cross-repo-handoff.md` の「Phase 65.3 実装決定事項 (D43)」を参照。

### Step 3: 過去の問題パターンを取得 (Phase 65.2.2 委譲)

```bash
bash scripts/accept-past-issues.sh --project "$PROJECT_NAME" --task "$USER_REQUEST" > "$PAST_ISSUES_JSON"
```

このスクリプトは patterns.md (P1-P33) と過去の `acceptance-context.v1` record を semantic search し、
最大 3 件の `past-issue.v1` を返す。各々 `verified_in_current_task: bool` 付き。

### Step 4: verified_criteria を組み立てる

Plan Brief 時の acceptance_criteria 各項目について、現タスクの状態を評価する。
ユーザー (もしくは Claude) が「verify した evidence」を提示し、`evidence` 文字列を埋める。

`evidence` が空文字列の場合、HTML 上で警告表示される (DoD c)。

TDD が必要な task では、Acceptance Demo に `TDD verified: yes|no` の 1 行を必ず出す。
TDD 不要または skip の場合は `TDD verified: not-required` または `TDD verified: skip:<reason>` と表示する。
`yes` にできるのは `.claude/state/tdd-red-log/<task-id>.jsonl` の Red 証跡、または literal failing test output が確認できる時だけ。

### Step 5: recommendation を算出する

上記「Recommendation 算出ロジック」に従って ship / wait / reject を決定する。

### Step 6: HTML を生成する

`scripts/render-html.sh` (Phase 65.1.1) を `templates/html/accept.html.template` で呼ぶ:

```bash
bash scripts/render-html.sh \
  --template accept \
  --data "$CONTEXT_JSON" \
  --out "$HTML_OUT"
```

### Step 7: ブラウザで自動 open する

`scripts/plan-brief-open.sh` (Phase 65.1.2 で導入された **汎用 OS dispatcher**) を再利用:

```bash
bash scripts/plan-brief-open.sh "$HTML_OUT"
```

> **注**: スクリプト名に「plan-brief」が入っているが、実体は OS 別 browser open dispatcher で kind 中立。
> Phase 65.1.2 で先に導入されたため historical name。Layer 3 (HTML 直前最終 scan) 等の他用途でも再利用される。
> `BROWSER=true` の env が設定されている場合 (CI 環境)、open は **skip** され `printf` で path だけ出力する。

### Step 8: ユーザー判断待ち

「ship / wait / reject の recommendation を採用するか、override するか」を確認する。
判断後の memory write は別スキル (`accept-record-decision.sh`、Phase 65.2.3) の責務。

## 失敗時の挙動

| 失敗 | 挙動 |
|------|------|
| `mcp__harness__harness_mem_search` 不達 | 警告を表示し、`verified_criteria` を空配列で続行 (recommendation = reject) |
| Plan Brief 側 record が見つからない | warning を出し、`verified_criteria` を空配列で続行 |
| `git rev-parse --show-toplevel` 失敗 | `PROJECT_NAME=current` で続行 |
| `accept-past-issues.sh` 失敗 | `past_issue_patterns: []` で続行 (best-effort) |
| `render-html.sh` 失敗 | エラーを stderr に出力し exit 1 |

## Related

- `harness-plan-brief` (Phase 65.1.2) — 計画段階の対構造スキル。本スキルは Plan Brief 時の `personal-preference.v1` を `user_request_hash` で join して read
- `scripts/accept-past-issues.sh` (Phase 65.2.2) — 過去の問題パターン取得 (read side)
- `scripts/accept-record-decision.sh` (Phase 65.2.3) — 承認 memory write (`acceptance-decision.v1`)
- `scripts/render-html.sh` (Phase 65.1.1) — HTML テンプレートエンジン
- `scripts/plan-brief-open.sh` (Phase 65.1.2) — 汎用 OS browser dispatcher
- `harness-progress` skill (Phase 65.4.1) — 進行管理スキル (3 surface のうち真ん中)
