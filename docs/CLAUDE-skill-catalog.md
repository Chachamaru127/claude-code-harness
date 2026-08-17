# スキルカタログ

スキル階層構造・全カテゴリ一覧・開発用スキルの参照ドキュメント。

## スキル評価フロー

> 💡 重いタスク（並列レビュー、CI修正ループ）では、スキルが `agents/` のサブエージェントを Task tool で並列起動します。

**作業を開始する前に、必ず以下のフローを実行すること:**

1. **評価**: 利用可能なスキルを確認し、今回の依頼に該当するものがあるか評価
2. **起動**: 該当するスキルがあれば、Skill ツールで起動してから作業開始
3. **実行**: スキルの手順に従って作業を進める

```
ユーザーの依頼
    ↓
スキルを評価（該当するものがあるか？）
    ↓
YES → Skill ツールで起動 → スキルの手順に従う
NO  → 通常の推論で対応
```

## スキル階層構造

スキルは `skills/<name>/SKILL.md` を本体とし、必要に応じて `references/` 配下に
補助ファイルを持つフラット構成です。配布対象スキルの完全な一覧と説明は、下の
「全スキルカテゴリ一覧」（`skills/*/SKILL.md` から自動生成）を参照してください。

**使い方:**
1. 依頼に該当するスキルを Skill ツールで起動
2. スキルがユーザーの意図に応じて適切な `references/` をロード
3. 手順に従って作業実行

## 全スキルカテゴリ一覧

下表は `skills/*/SKILL.md` の frontmatter から自動生成される。手で編集せず、
`harness gen docs` を実行して更新する（`harness gen docs --check` で CI 固定）。

<!-- BEGIN GENERATED SKILL CATALOG (harness gen docs) -->
<!-- Auto-generated from skills/*/SKILL.md frontmatter. Do not edit by hand; run `harness gen docs`. -->

## スキルカタログ一覧

| スキル | 説明 |
|--------|------|
| agent-browser | Browser automation through the repo agent-browser CLI. Explicit helper for navigation, forms, screenshots, scraping, and web-app checks. Prefer Browser Use or Playwright when available. Do NOT load for: sharing URLs, embedding links, or editing screenshot files. |
| breezing | Team execution mode — backward-compatible alias for harness-work with team orchestration. Composer/composer 2.5 maps to the cursor backend. |
| cc-update-review | Quality guardrail for Claude/Codex update integration. Detects doc-only Feature Table additions and requires implementation or explicit planning. Internal use only. |
| ci | CI red? Call us. Pipeline fire brigade deploys. Use when user mentions CI failures, build errors, test failures, or pipeline issues. Do NOT load for: local builds, standard implementation work, reviews, or setup. |
| cursor-ask | Read-only delegate to cursor-agent (Composer) for questions, investigation, design discussion, and adversarial sanity checks. No worktree, no cherry-pick, no Lead diff review — cursor-agent is locked to ask mode and cannot write. Use when user says: ask cursor, cursor sanity check, get a second opinion, adversarial review, design discussion, investigate with cursor, cursor:ask. Do NOT load for: implementation, refactor, file edits, commit/push work, anything requiring write access (use cursor:do or breezing --cursor instead). |
| cursor-do | Delegate a single write task to Cursor Composer via cursor-companion.sh inside an isolated worktree, then Lead-review the diff and cherry-pick. Use when user invokes cursor:do, says delegate to cursor, have composer write it, refactor with cursor, hand a file edit to Composer. Do NOT load for: planning, code review only, read-only investigation, or multi-task team runs (use breezing --cursor or cursor:ask instead). |
| cursor-review | Run a Cursor Composer review as an advisory second opinion while keeping the primary review verdict on the host brain. Use when user invokes cursor:review, asks Cursor to review, or wants composer to sanity-check a diff. Cursor never owns APPROVE/REQUEST_CHANGES. |
| cursor-setup | Configure and verify the Cursor backend for Claude Code Harness. Use when user invokes cursor:setup, wants Cursor as the local default implementation backend, or asks to check Cursor plugin/agent readiness. Distribution default remains opt-in; only local env/user settings are changed when explicitly requested. |
| failure-codifier | Extract recurring failure patterns from breezing orchestration logs and Judgment Ledger, emit failure-rule.v1 proposals with confidence scores. SSOT promotion to patterns.md or decisions.md is proposal-only — human-approval-required. Use when user mentions failure codifier, failure patterns, self-learning loop, codify failures, or failure-rule proposals. Do NOT load for: direct SSOT edits, auto-promotion, or implementation unrelated to failure analysis. |
| harness-accept | Generate an Acceptance Demo HTML for non-engineer vibecoders right before ship/wait/reject decision. Reads back the acceptance_criteria that were stored as personal-preference.v1 by harness-plan-brief (joined by user_request_hash), then renders a single-file HTML showing each criterion as verified or unverified along with a ship/wait/reject recommendation. Use when the user asks for an acceptance review, wants to decide whether to ship a delivered task, or says: acceptance demo, accept demo, 受け入れ判断, 受入レビュー, ship/wait/reject 判定, 検収レビュー. Do NOT load for: implementation, code review, release work. |
| harness-loop | Long-running task loop using /loop (Claude Code dynamic mode) and ScheduleWakeup to re-enter with fresh context on each wake-up. Internally invokes harness-work through Agent. Trigger: long-running, loop, wake-up, autonomous. Do NOT load for: one-shot task execution, review, release, planning. |
| harness-plan | HAR: Research-backed, team-validated task planning, Plans.md management, progress sync. Trigger: create a plan, add tasks, update Plans.md, mark complete, check progress. Do NOT load for: implementation, review, release. |
| harness-plan-brief | Generate a Plan Brief HTML for non-engineer vibecoders before implementation starts. Searches harness-mem (project-only) for relevant past decisions, patterns, and Plans archive entries, then renders a single-file HTML artifact summarizing understanding, options, risks, acceptance criteria, and confidence. Use when the user requests a planning preview, a non-engineer-friendly summary before approval, or says: plan brief, planning preview, 計画概要, 計画レビュー. Do NOT load for: actual implementation, code review, release work. |
| harness-progress | Generate a Progress Tracker HTML for non-engineer vibecoders to glance at session progress (cc:WIP / cc:TODO / cc:完了 counts, percentage, elapsed/estimated minutes, cost so far/estimate, drift alerts). Uses Plans.md as source of truth, renders a single-file HTML with auto-regeneration support. Use when user asks for progress overview, session status snapshot, dashboard, or says: progress tracker, 進捗確認, 進捗ボード, dashboard. Do NOT load for: actual implementation, code review, release work. |
| harness-release | Generic release automation for projects using Keep a Changelog + GitHub. Single confirmation gate then end-to-end automation: bump detection, CHANGELOG promotion, PR/main merge, tag, GitHub Release. Trigger: release, version bump, publish. Do NOT load for: implementation, review, planning, setup. |
| harness-review | HAR: Multi-angle code, plan, scope review. Security/quality check. Trigger: review, code review, plan review, scope analysis. Do NOT load for: implementation, new features, bugfix, setup, release. |
| harness-setup | HAR: Project init, tool setup, agent config, memory setup, skill mirror sync. Trigger: setup, init, new project, CI/Codex setup, harness-mem, mirror. Do NOT load for: implementation, review, release, planning. |
| harness-sync | HAR: Sync Plans.md with implementation. Drift detect, marker update, retrospective. Trigger: sync-status, where am I, check progress. --snapshot for snapshots. Do NOT load for: planning, implementation, review, release. |
| harness-work | HAR: Execute Plans.md tasks from single task to full parallel team run. Trigger: implement, execute, do everything, breezing, team run, parallel, composer, composer 2.5. Do NOT load for: planning, review, release, setup. |
| japanese-writing-drafter | Detect when the operator corrects the agent's Japanese phrasing mid-conversation (rewrites a sentence, calls out a style problem, says 'this wording is bad, say it like X instead') and draft a pending writing-rule proposal into ~/.claude/writing-lint/proposals.jsonl for later human review. This skill is the ONLY writer of proposals.jsonl — it never edits rules.jsonl and never sets status to anything but pending. Promotion to rules.jsonl only happens via the human-run scripts/writing-rule-approve.sh. Use when user mentions writing-rule proposal, 表現を直して, 文体を直して, その言い方はNG, writing lint 提案, 指摘をルール化して. Do NOT load for: approving or rejecting proposals (use scripts/writing-rule-approve.sh), listing pending proposals (use scripts/writing-rule-list.sh), or scanning text against the existing dictionary (the writinglint engine / PostToolUse hook does that). |
| maintenance | File cleanup and archiving. Tidies up bloated Plans.md, session-log.md, old logs, and state files. Trigger: /maintenance, cleanup, archive, organize, split session-log. Do NOT load for: implementation, review, release, new feature development. |
| memory | Manage SSOT, memory, and cross-tool memory search. Guardian of decisions.md and patterns.md. Use when user mentions memory, SSOT, decisions.md, patterns.md, merging, migration, SSOT promotion, sync memory, save learnings, memory search, harness-mem, past decisions, or record this. Do NOT load for: implementation work, reviews, ad-hoc notes, or in-session logging. |

<!-- END GENERATED SKILL CATALOG (harness gen docs) -->

## 開発用スキル（非公開）

以下のスキルは開発・実験用であり、リポジトリには含まれません（.gitignore で除外）：

```
skills/
├── test-*/      # テスト用スキル
└── x-promo/     # X投稿作成スキル（開発用）
```

これらのスキルは個別の開発環境でのみ使用し、プラグイン配布には含めないこと。

## 関連ドキュメント

- [CLAUDE.md](../CLAUDE.md) - プロジェクト開発ガイド（概要）
- [docs/CLAUDE-feature-table.md](./CLAUDE-feature-table.md) - Claude Code 新機能活用テーブル
- [docs/CLAUDE-commands.md](./CLAUDE-commands.md) - 主要コマンド一覧
- [.claude/rules/skill-editing.md](../.claude/rules/skill-editing.md) - スキルファイル編集ルール
