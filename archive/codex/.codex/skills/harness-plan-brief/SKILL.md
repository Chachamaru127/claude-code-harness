---
name: harness-plan-brief
description: "Generate a Plan Brief HTML for non-engineer vibecoders before implementation starts. Searches harness-mem (project-only) for relevant past decisions, patterns, and Plans archive entries, then renders a single-file HTML artifact summarizing understanding, options, risks, acceptance criteria, and confidence. Use when the user requests a planning preview, a non-engineer-friendly summary before approval, or says: plan brief, planning preview, 計画概要, 計画レビュー. Do NOT load for: actual implementation, code review, release work."
description-en: "Generate a Plan Brief HTML for non-engineer vibecoders before implementation starts. Searches harness-mem (project-only) for relevant past decisions, patterns, and Plans archive entries, then renders a single-file HTML artifact summarizing understanding, options, risks, acceptance criteria, and confidence. Use when the user requests a planning preview, a non-engineer-friendly summary before approval, or says: plan brief, planning preview, 計画概要, 計画レビュー. Do NOT load for: actual implementation, code review, release work."
description-ja: "実装着手前に Plan Brief HTML を生成する。現プロジェクトのみで harness-mem を検索し (`strict_project: true`)、過去 decision / pattern / Plans archive から類似案件を抽出して `plan-brief-context.v1` schema に整形、`render-html.sh` で単独 HTML を生成しブラウザ自動 open する。Use when: 計画概要, 非エンジニア向け事前共有, 提案前 review。Do NOT load for: 実装作業, code review, release。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
argument-hint: "[task-description]"
user-invocable: true
---

# harness-plan-brief

非エンジニアの発注者・プロデューサー職向けに、Claude が着手しようとしている計画を **HTML 1 枚** で提示するスキル。
発注者の認知負荷ピーク (1) 計画理解の段階で使う。

## Quick Reference

- 「**Plan Brief を作って**」 → このスキル
- 「**実装前にざっくり整理**」 → このスキル
- 「**非エンジニア向けに計画を見せて**」 → このスキル

## 責任境界

| 範囲 | このスキルの責務 |
|------|-----------------|
| 検索 | **現プロジェクトのみ** (`project: <current>`, `strict_project: true` を必ず指定) |
| クロスプロジェクト | **やらない** (Phase 65.3 以降で `--cross-project-group <name>` flag で opt-in 解放) |
| 書き込み | やらない (Plan Brief 承認後の memory write は `plan-brief-record-decision.sh` の責務) |
| confidence 算出 | 65.1.3 で実装される `scripts/plan-brief-compile.sh` に委譲 |

## 入力

引数 `[task-description]` にユーザーの request を渡す。
引数なしの場合は対話形式で受け取る。

## 出力

| 出力 | パス | 形式 |
|------|------|------|
| Plan Brief HTML | `.claude/state/views/plan-brief-<timestamp>.html` | 単独で開ける HTML (no server, no JS framework) |
| Plan Brief context JSON | `.claude/state/views/plan-brief-<timestamp>.context.json` | `plan-brief-context.v1` schema |

## Schema: `plan-brief-context.v1`

```json
{
  "schema": "plan-brief-context.v1",
  "user_request": "string (ユーザーの request 原文)",
  "my_understanding": "string (Claude の理解を 1-3 段落で)",
  "options": [
    { "name": "string", "summary": "string", "pros": ["string"], "cons": ["string"] }
  ],
  "risks": [
    { "kind": "string", "severity": "info|warn|critical", "description": "string", "mitigation": "string" }
  ],
  "acceptance_criteria": [
    { "id": "string", "description": "string", "verifiable_by": "string" }
  ],
  "tdd_required": "yes|no|skip:<reason>",
  "confidence": 0,
  "confidence_evidence": ["string"],
  "related_decisions": [
    { "id": "string", "title": "string", "relevance": "string" }
  ],
  "similar_past_plans": [
    { "archive_path": "string", "phase": "string", "outcome": "cc:完了|cc:WIP|cc:TODO|skipped", "relevance": "string" }
  ],
  "project": "string",
  "generated_at": "ISO8601"
}
```

完全 schema は [`schemas/plan-brief-context.v1.schema.json`](${CLAUDE_SKILL_DIR}/schemas/plan-brief-context.v1.schema.json) を参照。

## Execution Flow

スキル起動時、Claude は以下の手順で動作する。

### Step 1: project name を解決

```bash
PROJECT_NAME="$(basename "$(git rev-parse --show-toplevel)")"
```

`PROJECT_NAME` が空 (git 外) の場合は `current` をデフォルトに使う。

### Step 2: harness-mem を **project-only** で検索する (default)

引数に `--cross-project-group <name>` flag が**ない**場合 (default behavior):

`mcp__harness__harness_mem_search` を **必ず** 以下のパラメータで呼び出す:

```
project: <PROJECT_NAME>
strict_project: true
query: <user request>
expand_links: true
limit: 5
```

> **重要**: `project` パラメータは**必須**。空文字列や `null` を渡してはならない。
> `strict_project: true` を指定し、cross-project な検索は**絶対に行わない**。
> 必要なら `tags` filter で `decision` / `pattern` を絞ってもよいが、`project` は固定。

過去 decision (D1-D41) / pattern (P1-P33) / Plans archive 28 件から類似案件を最大 5 件取得する。

### Step 2 (alt): cross-project search (Phase 65.3.5 opt-in)

引数に `--cross-project-group <name>` flag が**ある**場合のみ:

D43 Option α (MCP N-call) に従い、以下の手順で cross-project 検索を行う。

```bash
# (a) group → member projects に解決 (yaml SSOT)
MEMBERS_JSON="$(bash scripts/load-cross-project-groups.sh --group "<name>" 2>/dev/null)" || {
  echo "ERROR: cross-project group not found: <name>" >&2
  exit 1
}
# MEMBERS_JSON は ["proj1","proj2",...] 形式の JSON 配列
```

`MEMBERS_JSON` が `[]` (空配列) の場合は warning を出して default の単一 project search に fallback。

`MEMBERS_JSON` が非空の場合、**各 member project に対して MCP search を 1 回ずつ発行** する:

```
for each project in MEMBERS_JSON:
  mcp__harness__harness_mem_search(
    project: <member>,
    strict_project: true,
    query: <user request>,
    expand_links: true,
    limit: 5
  )
```

各 search 結果を **client 側でマージ・dedupe (id 単位)・relevance_score 降順 sort** し、最大 5 件に絞る。
合計呼び出し数が多くなる (group が 5 project なら 5 回) ため、レイテンシは増える点に注意。

> **D43 判断 1 の根拠**: MCP tool schema には `projects: [array]` も `strict_project: false` も
> exposed されていないため、横断検索は client 側 N-call が唯一の選択肢。
> 詳細は `.claude/rules/cross-repo-handoff.md` の「Phase 65.3 実装決定事項 (D43)」参照。

cross-project 結果には Layer 2/3 (Phase 65.3.2-65.3.4) の redaction を必ず通すこと:
- HTML レンダリング時に `bash scripts/render-html.sh ... --with-redaction` を使用
- これにより辞書 + NER + final scan の 3 段で固有名詞が漏れない

### Step 3: context JSON を組み立てる

`scripts/plan-brief-compile.sh` (Phase 65.1.3 で実装) を使って、
mem search 結果から `plan-brief-context.v1` schema 準拠の JSON を構築する。

65.1.3 が未実装の段階では、Claude が直接 jq で以下を組み立てる:

```bash
jq -n \
  --arg req "$USER_REQUEST" \
  --arg proj "$PROJECT_NAME" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    schema: "plan-brief-context.v1",
    user_request: $req,
    my_understanding: "(まだ未着手)",
    options: [],
    risks: [],
    acceptance_criteria: [],
    confidence: 0,
    confidence_evidence: ["(stub) 65.1.3 で算出ロジック実装"],
    tdd_required: "no",
    related_decisions: [],
    similar_past_plans: [],
    project: $proj,
    generated_at: $ts
  }' > "$CONTEXT_JSON"
```

### Step 4: HTML を生成する

`scripts/render-html.sh` (Phase 65.1.1) を `templates/html/plan-brief.html.template` で呼ぶ:

HTML には TDD 判定を 1 行で表示する。
形式は `tdd_required: yes`、`tdd_required: no`、または `tdd_required: skip:<reason>` のいずれかにする。

```bash
bash scripts/render-html.sh \
  --template plan-brief \
  --data "$CONTEXT_JSON" \
  --out "$HTML_OUT"
```

### Step 5: ブラウザで自動 open する

`scripts/plan-brief-open.sh` で OS 別 dispatch:

```bash
bash scripts/plan-brief-open.sh "$HTML_OUT"
```

`BROWSER=true` の env が設定されている場合 (CI 環境)、open は **skip** され `printf` で path だけ出力する。

### Step 6: ユーザー承認待ち

「この理解で実装に進んでよいか」を確認する。
承認後の memory write は別スキル (Phase 65.1.4 の `plan-brief-record-decision.sh`) の責務。

## 失敗時の挙動

| 失敗 | 挙動 |
|------|------|
| `mcp__harness__harness_mem_search` 不達 | 警告を表示し、`related_decisions` / `similar_past_plans` を空配列で続行 |
| `git rev-parse --show-toplevel` 失敗 | `PROJECT_NAME=current` で続行 |
| `render-html.sh` 失敗 | エラーを stderr に出力し exit 1 |
| `plan-brief-open.sh` 失敗 | HTML path を stdout に出力するだけで exit 0 (browser open は best-effort) |

## Related

- `scripts/render-html.sh` (Phase 65.1.1) — HTML テンプレートエンジン
- `scripts/plan-brief-compile.sh` (Phase 65.1.3) — context compilation
- `scripts/plan-brief-record-decision.sh` (Phase 65.1.4) — 承認 memory write
- `harness-accept` skill (Phase 65.2.1) — 受け入れ判断スキル (対構造)
- `harness-progress` skill (Phase 65.4.1) — 進行管理スキル (対構造)
