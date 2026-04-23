# Claude Code Harness — Plans.md

最終アーカイブ: 2026-04-19（Phase 44 + 45 + 46 → `.claude/memory/archive/Plans-2026-04-19-phase44-46.md`）
前回アーカイブ: 2026-04-17（Phase 37 + 41 + 42 + 43 → `.claude/memory/archive/Plans-2026-04-17-phase37-41-42-43.md`）

---

## 📦 アーカイブ

完了済み Phase は以下のファイルへ切り出し済み（git history にも残存）:

- [Phase 44 + 45 + 46](.claude/memory/archive/Plans-2026-04-19-phase44-46.md) — Opus 4.7 / CC 2.1.99-110 追従 "Arcana" (v4.2.0) + Plugin Manifest 公式準拠 + Worker 3 層防御 (#84-#87, v4.3.0)
- [Phase 37 + 41 + 42 + 43](.claude/memory/archive/Plans-2026-04-17-phase37-41-42-43.md) — Hokage 完全体 / Long-Running Harness / Go hot-path migration / Advisor Strategy
- [Phase 39 + 40 + 41.0](.claude/memory/archive/Plans-2026-04-15-phase39-40-41.0.md) — レビュー体験改善 / Migration Residue Scanner / Long-Running Harness Spike

---

## 🔖 Status マーカー凡例

PM ↔ Impl 運用で使用する標準マーカー:

| マーカー | 意味 | 誰が付ける |
|---------|------|-----------|
| `pm:依頼中` | PM がタスクを起票し、Impl へ依頼中 | PM |
| `cc:WIP` | Impl（Claude Code）が着手中 | Impl |
| `cc:完了` | Impl が作業完了し、PM の確認待ち | Impl |
| `pm:確認済` | PM が最終確認を完了 | PM |

**状態遷移**: `pm:依頼中 → cc:WIP → cc:完了 → pm:確認済`

**後方互換**: `cursor:依頼中` / `cursor:確認済` は `pm:依頼中` / `pm:確認済` の同義として扱う（Cursor PM 運用時の表記）。

---

## Phase 47: CLAUDE.md 構造見直し調査 [P2]

Purpose: CLAUDE.md が 141 行となり post-tool-use hook が分割検討を出している。実データ (関連 rules/docs への pointer 構造) を測定して、分割するか現状維持するかの判断材料を整える。実装はこの Phase では行わない（調査のみ）。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 47.1.1 | (a) CLAUDE.md 現行 141 行を section 単位で token 計測し、どのセクションが session-start 読込時に最もコストを食っているかをデータで出す（`wc -l` + 各セクションの行数表を `docs/claude-md-structure-audit.md` に記録）。(b) 他の harness repo (.claude/rules/ 配下 11 ファイル) に移せる section 候補を列挙（例: Permission Boundaries → `.claude/rules/permission-boundaries.md`、MCP Trust Policy → `.claude/rules/mcp-trust-policy.md` として再配置可能か）。(c) 分割した場合の CLAUDE.md side の pointer 方式（`@path/to/file.md` 参照 vs インラインコピー）を比較し、CC 2.1.111+ で `@` 記法が安定動作するかを `tests/test-claude-md-auto-include.sh` のような smoke test で確認（既存があれば参照、無ければ新設不要で観察のみ）。(d) 最終判断: 分割実装する/現状維持する のどちらかを rationale 付きで docs に記録 | (a) section 別 line 計測が docs/claude-md-structure-audit.md にある、(b) 分割候補 section が 2 つ以上列挙されている、(c) `@` 記法の可否が判定済み、(d) 判断と根拠が記録されている、(e) この Phase は調査のみで本体 CLAUDE.md は変更しない | - | cc:完了 [940fec14] |

---

## Phase 48: Session Monitor 能動監視化 [P2]

Purpose: `monitors/monitors.json` の description が掲げる 3 要素（harness-mem health / advisor/reviewer state / Plans.md drift）のうち、現時点で能動監視できているのは Plans.md の件数カウントと git 状態のみ。残り 2 要素（mem health、advisor drift）の検知ロジックと、Plans.md の閾値警告を `go/internal/session/monitor.go` に追加し、monitors manifest の description と実装の乖離を解消する。出力フォーマットは `⚠️ {category}: {detail}` の 1 行形式に統一し、Claude 側が重要度判定して PushNotification を送れるようにする。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 48.1.1 | `go/internal/session/monitor.go` の `MonitorHandler.Handle` に harness-mem health 呼び出しを追加する。`bin/harness mem health` サブコマンド（未実装なら同 Phase 内で新設）を `exec.Command` で起動、timeout 2 秒、exit code と JSON 出力から healthy/unhealthy を判定。unhealthy 時は stdout 末尾に `⚠️ harness-mem unhealthy: {reason}` の 1 行を出力し、session.json に `harness_mem: { healthy: bool, last_checked: <RFC3339>, last_error: string }` フィールドを追加する。timeout または exec 失敗時は healthy=unknown で握り潰し、monitor 全体は停止させない | (a) `session.json` に `harness_mem` フィールドが書かれる、(b) mem 不達時に stdout の最終行に `⚠️ harness-mem unhealthy:` プレフィックス行が出る、(c) `go/internal/session/monitor_test.go` に healthy / unhealthy / timeout の 3 ケースが追加され全部 pass、(d) `time go run ./go/cmd/harness hook session-monitor < /dev/null` が実 repo で 3 秒以内に完了する | - | cc:完了 [888b1953] |
| 48.1.2 | `MonitorHandler` に session.events.jsonl 読み取りと advisor/reviewer drift 検知を追加する。`.claude/state/session.events.jsonl` の末尾 200 行を読み、`advisor-request.v1` 型のイベントに対応する `advisor-response.v1` が TTL（既定 600 秒、`.claude-code-harness.config.yaml` の `orchestration.advisor_ttl_seconds` で上書き可）を超えて見つからない場合、stdout に `⚠️ advisor drift: request_id={id}, waiting {elapsed}s` を 1 行出力する。複数件存在する場合は最古の 1 件のみ表示。reviewer 側の `review-result.v1` 未応答も同じロジックで `⚠️ reviewer drift:` として検出する | (a) TTL 超過の advisor request が 1 件以上あれば `⚠️ advisor drift` 行が stdout に出る、(b) TTL 未満の request では警告行が出ない、(c) 対応する response が既に存在する request は検出対象外になる、(d) `config.yaml` の `orchestration.advisor_ttl_seconds` を 10 秒に設定したテストで 10 秒超が drift 扱いになる、(e) `monitor_test.go` に drift-hit / drift-miss / config-override の 3 ケース追加 | - | cc:完了 [888b1953] |
| 48.1.3 | `collectPlansState` に閾値判定を追加する。判定条件は (i) `WIP_COUNT >= wip_threshold`（既定 5）、(ii) Plans.md の `last_modified` が現在時刻から `stale_hours` 時間（既定 24）以上経過、のいずれか 1 つ以上が真の場合。該当時は stdout に `⚠️ plans drift: WIP={n}, stale_for={hours}h` を 1 行出力する。閾値は `.claude-code-harness.config.yaml` の `monitor.plans_drift.wip_threshold` / `monitor.plans_drift.stale_hours` で上書き可能。両キーとも未指定なら既定値を使い、設定読み取り失敗時は警告を出さずに continue する | (a) WIP=0 かつ 24h 以内更新なら警告行無し、(b) WIP >= 5 で `⚠️ plans drift: WIP=` プレフィックス行が出る、(c) 24h 超の stale で同じプレフィックス行が出る（WIP 件数と独立）、(d) config 未指定時に既定値 (5 / 24) が適用される、(e) `monitor_test.go` に wip-threshold-hit / stale-hit / below-threshold / config-override の 4 ケース追加 | - | cc:完了 [888b1953] |
| 48.2.1 | Phase 48 Reviewer minor 3 件の follow-up を次 minor にまとめて潰す。(i) `go/internal/session/monitor.go` の `checkPlansDrift` の `if staleHit { ... } return ...` 分岐（751-754 行）が完全に同じ `fmt.Sprintf` を 2 箇所で呼ぶ dead-code になっているため、分岐ごと削除して単一 return に統合する。(ii) 同ファイル `readAdvisorTTL`（691 行）と `readPlansDriftConfig`（763 行）で `filepath.Join(projectRoot, ...)` の結果を `filepath.Clean` で正規化し、パス構築の定石を揃える（projectRoot は内部由来のため symlink チェックは過剰防御として省略）。(iii) `go/internal/session/monitor_test.go` に `TestMonitorHandler_ReviewerDrift_Hit` / `_Miss` / `_ConfigOverride` の 3 ケースを追加し、実装済みの reviewer drift ロジック（monitor.go:641-675）が TTL 配下で動くこと・response 到着後は検出されないこと・config override が reviewer 側でも効くことを固定する | (a) `checkPlansDrift` の分岐が 1 行 return に統合され `go vet ./go/...` でも warning が増えない、(b) 両 config reader で `filepath.Clean` が適用されパスが正規化される、(c) `go test ./go/internal/session/... -run TestMonitorHandler_ReviewerDrift -v` が 3 ケース全て PASS、(d) 既存テスト全件無回帰（AdvisorDrift / PlansDrift / HarnessMem 等）、(e) `./tests/validate-plugin.sh` が全 PASS を維持、(f) CHANGELOG `[Unreleased]` の「既知の non-blocker」節をクローズ記述に差し替える | 48.1.1 / 48.1.2 / 48.1.3 | cc:完了 [bdbcb70d] |

---

## Phase 49: SessionStart resume-pack injection の配線欠損を修正 (XR-003) [P0]

Purpose: harness-mem は daemon / resume-pack API / shell hook scripts (`memory-session-start.sh`, `userprompt-inject-policy.sh`) まで整備されているのに、新 session で直前 session の summary が注入されない状態が 2026-04-19 に確認された。真因は「plugin に同梱されている shell scripts が `.claude-plugin/hooks.json` から一度も呼ばれていなかった」こと。当初は `cross-repo-session-bootstrap.sh` (governance 用 local-only hook) に quick fix を入れる方針で進めたが、関心分離違反かつ `.gitignore` で配布不可と判明し、owner を claude-code-harness plugin に確定。既存 shell scripts に wiring を追加するだけで解決する最小変更に切り替え。`harness-governance-private/XR-Registry.md` の **XR-003** として発番、harness-mem 側 Plans.md §90 と整合。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 49.1.1 | `.claude-plugin/hooks.json` に 2 箇所の shell script 呼び出しを追加する。(i) `SessionStart[matcher="startup\|resume"].hooks` 配列末尾に `bash "${CLAUDE_PLUGIN_ROOT}/scripts/hook-handlers/memory-session-start.sh"` (timeout 30, once=true) を追加 — 既存の `harness hook session-start` と `memory-bridge` (Go 実装) はそのまま残置し並走。(ii) `UserPromptSubmit[matcher="*"].hooks` の `memory-bridge` と `inject-policy` の間に `bash "${CLAUDE_PLUGIN_ROOT}/scripts/userprompt-inject-policy.sh"` (timeout 15) を挿入 — 先に shell 側で `.memory-resume-pending` flag を処理し `additionalContext` を出した後に既存の Go hook を走らせる | (a) `harness-mem` が healthy な状態で新 session を開くと、1 回目の `UserPromptSubmit` で直前 claude session の `# Session Handoff` summary が `additionalContext` に載る、(b) `memory-resume-pack.json` のタイムスタンプが新 session のたびに更新される、(c) daemon 不達 / `curl` / `jq` 欠損時は shell script が silent skip して既存の Go hooks と governance bootstrap を壊さない、(d) 既存の `harness hook session-start` / `memory-bridge` / `inject-policy` の出力 (decision approve / UserPromptSubmit stub) と `additionalContext` merge が競合しない、(e) `hooks/hooks.json` と `.claude-plugin/hooks.json` の dual sync が維持される、(f) `tests/test-memory-hook-wiring.sh` が両 hooks.json の Phase 49 エントリ有無と userprompt-inject-policy.sh の silent-skip を機械検証する | - | cc:完了 [be43a300] |
| 49.1.2 | harness-mem 側 follow-up `summary_only=true` mode が landed したら、plugin 側 shell script (`memory-session-start.sh` / `userprompt-inject-policy.sh`) の jq パイプラインを短縮できないか再検討 | 調査結果: claude-code-harness 側 `scripts/hook-handlers/memory-session-start.sh` は 7 行の薄いラッパーで harness-mem の同名スクリプトを `exec` 丸投げ、`scripts/userprompt-inject-policy.sh` は `memory-resume-context.md` を読むのみで `/v1/resume-pack` を直接呼ばない。したがって plugin 側に短縮対象となる jq パイプラインは存在せず no-op close。実短縮は harness-mem の `4a7cb36` (`hook_extract_meta_summary` / `hook_fetch_resume_pack_summary_only` 追加) が担い、wrapper の delegate 構造により plugin 側が自動継承する。cross-repo handoff: [harness-mem#70](https://github.com/Chachamaru127/harness-mem/issues/70) | 49.1.1, S90-002 | cc:完了 [no-op, harness-mem#70] |

---

## Phase 50: active watching 機能の 3-state 依存テスト規約化 [P2]

Purpose: v4.3.1 で Session Monitor に harness-mem active watching を追加した直後に、v4.3.3 hotfix として「`~/.claude-mem/` 不在で unhealthy 誤警告」regression を修正する必要があった。根本原因は「opt-in な外部依存に対して、未インストール状態のテストケースを最初から書いていなかった」こと。同じ形の regression が将来の active watching 機能（MCP server health, Codex daemon 監視など）で再発しないよう、テスト設計規約を `.claude/rules/` に明文化する。D40 / P29 で SSOT 昇格済みの tri-state 設計パターンの自然な運用ルール化。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 50.1.1 | `.claude/rules/active-watching-test-policy.md` を新規作成する。以下を含める: (a) 規約の適用範囲（「Session Monitor 等で外部プロセス / ファイル / daemon を watch するコードを新規追加する場合」を literal に列挙）、(b) 3 状態の定義と期待挙動（未インストール = `not-configured` で healthy=true + warning 無し、未起動 = `daemon-unreachable` 等で unhealthy + warning 有り、破損 = `corrupted` で unhealthy + warning 有り）、(c) 3 状態それぞれに対するテスト命名規約（`TestXxx_NotConfigured` / `TestXxx_Unreachable` / `TestXxx_Corrupted`）、(d) v4.3.3 hotfix を事例付録として参照 (`go/cmd/harness/mem.go` の `runMemHealthCheck` + `go/internal/session/monitor_test.go` の 3 テストを good example として link)、(e) D40 / P29 / `.claude/rules/migration-policy.md` との関係を 1 行で整理 | (a) `.claude/rules/active-watching-test-policy.md` が 80-150 行で存在、(b) 3 状態の命名規約が表形式で明示、(c) 事例付録に v4.3.3 の該当コミット SHA `23589344` と対象ファイル 2 つが link、(d) `CLAUDE.md` の Permission Boundaries / Test Tampering Prevention セクション周辺から新ルールへの pointer が 1 行追加される、(e) `./tests/validate-plugin.sh` 全 PASS、(f) 既存の opus-4-7-prompt-audit / test-quality / implementation-quality ルールと衝突しない | - | cc:完了 [0f16a3cc] |

---

## Phase 51: Claude Code / Codex upstream 追従 2026-04-20 [P1]

Purpose: Claude Code `2.1.112-2.1.114` と Codex `0.121.0` の一次情報を確認し、Harness に実装価値のある差分だけを hooks / Go / tests / docs に落とし込む。Feature Table 追記だけの `B: 書いただけ` を避け、少なくとも 1 件は実装または検証強化まで完了する。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 51.1.1 | Claude Code hooks docs の `AskUserQuestion` schema (`questions` + optional `answers`) と `PreToolUse.updatedInput` を Harness に取り込む。`hooks/hooks.json` / `.claude-plugin/hooks.json` に `PreToolUse[AskUserQuestion] -> harness hook ask-user-question-normalize` を追加し、Go handler で明示 answer source (`tool_input.answers` または `HARNESS_ASK_USER_QUESTION_ANSWERS`) のみを読み取る。`solo/team`、`scripted/exploratory`、`patch/minor/major` など既知同義語だけ option label へ正規化し、選択肢にない値・固有名詞・yes/no 承認判断は自動変換しない | (a) `go/internal/hookhandler/ask_user_question_normalizer.go` と unit test がある、(b) 両 hooks.json が同期し `AskUserQuestion` matcher を持つ、(c) `tests/test-claude-upstream-integration.sh` が wiring と handler 存在を検証、(d) `docs/CLAUDE-feature-table.md` と `CHANGELOG.md` に `A: 実装あり` として記録、(e) `go test ./go/internal/hookhandler/... -run AskUserQuestion` と upstream integration test が PASS | - | cc:完了 |
| 51.1.2 | Codex 0.121.0 の marketplace / MCP Apps / memory controls / secure devcontainer 差分を、今回の直接実装ではなく次回 Codex workflow 比較軸として整理する。Harness 側では marketplace source 管理、MCP Apps tool metadata、memory reset / cleanup と既存 harness-mem の責務衝突、secure devcontainer と sandbox policy の差分を調査タスクへ切り出す | (a) Feature Table Phase 51 追補に Codex 0.121.0 主要項目が `P: Plans 化` または `C: Codex 側調査済み` として分類済み、(b) 次回実装候補が setup / guardrails / memory / Codex workflow のどこに載るか明記、(c) 今回の `B: 書いただけ` が 0 件 | 51.1.1 | cc:完了 |
| 51.1.3 | `validate-plugin` 中の migration residue check がローカル専用・未追跡の `.agents/` skill mirror を配布対象として誤検出しないよう、`scripts/check-residue.sh` の grep 対象から `.agents` を除外する。配布対象の `skills/` / `agents/` / `codex/` は引き続きスキャン対象に残す | (a) `bash scripts/check-residue.sh` が `.agents/` 内のローカル skill を無視して PASS、(b) `./tests/validate-plugin.sh` の residue step が false positive で落ちない、(c) CHANGELOG に検証 hardening として記録 | 51.1.1 | cc:完了 |
| 51.1.4 | Claude Code 2.1.113 hardening を再分類し、`C: 自動継承` で済ませていた permission / sandbox 差分を Harness 側でも固定する。`.claude-plugin/settings.json` に `sandbox.network.deniedDomains` を追加し、Go guardrail で `find -delete` / `find -exec rm ...` と macOS dangerous rm paths を検出、wrapper 経由 `sudo` の回帰テストも追加する | (a) `.claude-plugin/settings.json` が `sandbox.network.deniedDomains` を持つ、(b) `go/internal/guardrail/helpers.go` に find deletion / macOS dangerous path detection がある、(c) `go/internal/guardrail/rules_test.go` に wrapper sudo / find deletion / macOS path coverage がある、(d) `tests/test-claude-upstream-integration.sh` が settings と guardrail coverage を検証、(e) Feature Table が `A: 実装あり` に更新済み | 51.1.1 | cc:完了 |
| 51.1.5 | upstream update 関連 Skills を Claude / Codex どちらから使っても同じ判断になるよう同期する。`claude-codex-upstream-update` は version-by-version 分解表を絶対ゲート化し、`cc-update-review` は Claude/Codex upstream review として A/C/P 判定・stale path 禁止・mirror drift 検出を追加する。PR 対象は `skills/` と `codex/.codex/skills/`、local-only 確認対象は `.agents/skills/` | (a) PR 対象 2 系統の `claude-codex-upstream-update/SKILL.md` が同期済み、(b) PR 対象 2 系統の `cc-update-review/SKILL.md` が同期済み、(c) local-only `.agents/skills/` も作業環境上で同内容に更新済み、(d) 存在しない Anthropic 側 Codex repo URL、旧 Codex plugin directory、旧 Codex feature-table path、旧 TypeScript guardrail path の参照が対象 2 Skills から消えている、(e) Skill 本文が 2.1.113 hardening と Codex 0.121/0.122-alpha の扱いを明記している | 51.1.4 | cc:完了 |
| 51.2.1 | Codex native skill model の P0 drift を修正する。`codex/.codex/skills/harness-work/SKILL.md` の `Agent(...)` / `SendMessage` / `claude-code-harness:worker` 風擬似コードを `spawn_agent` / `send_input` / `wait_agent` / `close_agent` の Codex native 表現へ置換し、`codex/.codex/skills/breezing/SKILL.md` の `user-invocable` と `allowed-tools` contract を明文化する | (a) Codex 版 harness-work が Claude Code Task tool 擬似コードを前提にしない、(b) Codex 版 breezing の frontmatter と本文の tool contract が一致、(c) `docs/skills-audit-2026-04-20.md` の P0 2 件が完了扱いに更新される | 51.1.5 | cc:TODO |
| 51.2.2 | memory / session-memory 系 Skills の path drift を修正する。`.agents/skills/memory` / `.agents/skills/session-memory` の `.Codex/` 置換 drift を除去し、`skills/session-memory` の存在しない `docs/MEMORY_POLICY.md` 参照と Codex mirror の `${CLAUDE_SESSION_ID}` 固定前提を session-init と整合させる | (a) `.Codex/memory`, `.Codex/state`, `~/.Codex` を正本扱いする記述が消える、(b) `docs/MEMORY_POLICY.md` 参照が実在 docs に更新されるか docs が新設される、(c) Codex session id の説明が Claude 固定でなくなる | 51.1.5 | cc:TODO |
| 51.2.3 | review / loop / release 系 Skills の mirror path policy を整理する。`harness-review` の `../../docs/ultrareview-policy.md` relative link、Codex `harness-loop` の `.claude/state/codex-loop/` 固定、`harness-release-internal` の `.agents/skills` mirror policy 未記載を見直す | (a) mirror 先で存在しない relative link が解消、(b) loop state path の Claude 共通 state / Codex native state の責務が明記、(c) `.agents/skills` を同期対象に含めるか生成物として除外するか方針が docs 化される | 51.2.2 | cc:TODO |
| 51.2.4 | media / announcement 系 Skills の metadata と対話 tool 前提を整理する。`generate-slide`, `generate-video`, `x-announce`, `x-article` の `user-invocable`, `disable-model-invocation`, `allowed-tools`, `AskUserQuestion` / Codex `request_user_input` 相当の扱いを実起動面に合わせる | (a) metadata と本文トリガーが矛盾しない、(b) Claude Code と Codex の対話入力 tool 差分が明記、(c) user-invocable false の skill がユーザー発話トリガー前提になっていない | 51.2.3 | cc:TODO |

---

## Phase 52: upstream update skill merge hardening 2026-04-21 [P1]

Purpose: Claude Code `2.1.116` と Codex `0.122.0` / `0.123.0-alpha.2` の一次情報を確認し、Phase 51 の upstream update skills を「実装を無理に作らず、diff-aware に分類できる」形へ統合強化する。Review findings 3 件（diff 取得不能、no-op cycle 不可、A/B/C/P 表記揺れ）を潰し、依存関係・デグレ・矛盾を snapshot と test で固定する。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 52.1.1 | `cc-update-review` を diff-aware review として強化する。`Bash` は read-only git inspection のみに使う前提を明記し、呼び出し元 diff が無い場合は自力で `git status` / `git diff -- docs/CLAUDE-feature-table.md` / `git diff --name-only` を確認する。分類見出しを A/B/C/P に揃える | (a) `allowed-tools` に `Bash` がある、(b) read-only git inspection 以外を禁止、(c) diff 未取得時に `B: 0` と推定しない、(d) `3カテゴリ` 表記が消えて A/B/C/P 表記に統一、(e) 3 mirror が同期 | 51.1.5 |  |
| 52.1.2 | `claude-codex-upstream-update` を no-op adaptation 対応にする。公式差分が全て妥当な `C` / `P` の場合、`A` を捏造せず、公式 URL・分解表・理由・Plans 化で完了できるようにする | (a) Skill 本文が no-op adaptation を許可、(b) 実装 / Plans / Feature Table / CHANGELOG / tests の更新対象が分類条件付きになっている、(c) Claude Code 2.1.116+ と Codex 0.122.0+ の確認観点がある、(d) 3 mirror が同期 | 51.1.5 |  |
| 52.1.3 | 2026-04-21 upstream snapshot を残す。Claude Code 2.1.116 と Codex 0.122.0 stable / 0.123.0-alpha.2 を version-by-version で分類し、Harness UX への直接実装・自動継承・Plans 化の判断を明記する | (a) `docs/upstream-update-snapshot-2026-04-21.md` がある、(b) 公式 URL と version-by-version table がある、(c) Claude 2.1.116 は主に C/P、Codex 0.122.0 は Phase 51.2 と連動する P、0.123.0-alpha.2 は推測実装しない P として記録、(d) Feature Table / CHANGELOG から参照される | 52.1.1, 52.1.2 |  |
| 52.1.4 | upstream integration test を拡張し、skill mirror drift と review findings の再発を検出する | (a) `tests/test-claude-upstream-integration.sh` が upstream skill 2 種の `skills/` / `codex/.codex/skills/` / `.agents/skills/` drift を検出、(b) diff-aware Bash guidance、A/B/C/P 見出し、no-op adaptation、2.1.116+ / 0.122.0+ watchlist を grep で固定、(c) upstream integration test が PASS | 52.1.3 |  |

---

## Phase 53: Claude Code 2.1.117-2.1.118 / Codex 0.123.0 最新追従 [P1]

Purpose: 2026-04-23 時点の公式 upstream で、ローカル実行環境は Claude Code `2.1.118` / Codex CLI `0.123.0` に更新済み。一方で Harness の snapshot / Feature Table / Plans は Phase 52 の Claude Code `2.1.116` + Codex `0.122.0` までで止まっている。Claude Code `2.1.117-2.1.118` と Codex `0.123.0` の差分を、ユーザー体験が良くなる理由と Harness 実装方針が分かる形で A/C/P 分類し、実装価値が高いものだけ hooks / release / setup / skills / tests に落とす。公式一次情報は Claude Code docs changelog (`https://code.claude.com/docs/en/changelog`) と OpenAI Codex releases (`https://github.com/openai/codex/releases`) を使う。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 53.1.1 | 2026-04-23 upstream snapshot を新規作成する。Claude Code `2.1.117`, `2.1.118` と Codex `0.123.0` を version-by-version で分解し、各項目に「こうよくなる」「Harness ではこう実装する / 自動継承する / Plans 化する」を書く。分類は `A: 実装`, `C: 自動継承`, `P: 将来タスク` に固定し、推測実装はしない | (a) `docs/upstream-update-snapshot-2026-04-23.md` がある、(b) 公式 URL と確認日が記録されている、(c) Claude Code `2.1.117-2.1.118` と Codex `0.123.0` の項目が表で分類されている、(d) `CHANGELOG.md` と `docs/CLAUDE-feature-table.md` から snapshot へ参照がある、(e) `B: 書いただけ` が 0 件である理由が明記されている | 52.1.4 | cc:TODO |
| 53.1.2 | Claude Code `type: "mcp_tool"` hook を小さく安全に試す。まず読み取り専用の診断用途に限定し、shell script を増やさず MCP tool を直接呼べるか検証する。候補は将来の MCP health check / resource list 診断で、外部状態を書き換える tool は対象外にする | (a) 対象 hook の用途が docs に明記されている、(b) `hooks/hooks.json` / `.claude-plugin/hooks.json` のどちらを変更するか、または今回は no-op にするかが snapshot に記録されている、(c) 実装する場合は `tests/test-claude-upstream-integration.sh` に `type: "mcp_tool"` の構造検証がある、(d) 書き込み系 MCP tool を hook から呼ばないことがテストまたは docs で固定されている | 53.1.1 | cc:TODO |
| 53.1.3 | `claude plugin tag` を `harness-release` の release flow に取り込む。`VERSION` と `.claude-plugin/plugin.json` の同期を確認した後、plugin version validation 付きで tag を作れるようにし、手動 `git tag` だけに依存しない導線にする | (a) `skills/harness-release/SKILL.md` または release reference に `claude plugin tag` の実行位置が明記されている、(b) `VERSION` と `.claude-plugin/plugin.json` 不一致時は tag に進まない説明がある、(c) dry-run / preflight で実行コマンドが見える、(d) release 関連テストまたは grep test が `claude plugin tag` guidance を検出する | 53.1.1 | cc:TODO |
| 53.1.4 | Auto Mode `"$defaults"` 対応を Harness の permission / sandbox 方針に反映する。標準の安全ルールを置き換えず、組み込み default に Harness 独自ルールを足す形へ説明とテンプレートを寄せる | (a) Auto Mode guidance が「既定を置換」ではなく「`"$defaults"` に追加」と説明している、(b) `.claude-plugin/settings.json` または template を変更する場合は既存 deny / ask / sandbox と矛盾しない、(c) `tests/test-claude-upstream-integration.sh` に `"$defaults"` を含む設定方針の grep または jq check がある、(d) 既存 guardrail の R05 / deniedDomains と二重責務にならない理由が記録されている | 53.1.1 | cc:TODO |
| 53.1.5 | Claude Code plugin / managed settings 周りを setup docs に反映する。plugin `themes/` directory、`DISABLE_UPDATES`、`blockedMarketplaces`、`strictKnownMarketplaces`、plugin dependency auto-resolve / missing dependency hints を、企業利用・安全な marketplace 運用向けの説明として整理する | (a) setup / plugin policy docs に各項目の用途がある、(b) `DISABLE_UPDATES` と `DISABLE_AUTOUPDATER` の違いが説明されている、(c) `blockedMarketplaces` / `strictKnownMarketplaces` は管理環境向けとして扱われ、通常ユーザー向け default に過剰適用しない、(d) plugin dependency auto-resolve は Harness 独自 resolver を重ねず本体に任せる方針が明記されている、(e) themes は実装する / 今回は P に留める の判断が snapshot にある | 53.1.1 | cc:TODO |
| 53.1.6 | Claude Code UX 変更の自動継承項目を docs 上で古い表現から更新する。`/cost` / `/stats` 統合後の `/usage`、`/resume` が `/add-dir` session を見つける改善、main-thread `--agent` の `mcpServers` 読み込み、forked subagent external build flag、stale large session summary、native `bfs` / `ugrep` search、高 effort default などを、Harness が wrapper を追加しない `C/P` として整理する | (a) `docs/CLAUDE-feature-table.md` の Phase 53 追補に C/P として入っている、(b) `/cost` / `/stats` の説明が必要箇所で `/usage` 中心に更新されている、(c) `--agent` + `mcpServers` は agents audit の後続候補として Plans または snapshot に残っている、(d) 本体改善へ Harness wrapper を重ねない理由が記録されている | 53.1.1 | cc:TODO |
| 53.2.1 | Codex `0.123.0` の setup / provider 追従を行う。built-in `amazon-bedrock` provider、更新済み model metadata、現在の `gpt-5.4` default を Codex setup guidance に反映し、古い固定モデル名や provider 前提を点検する | (a) Codex setup docs / skills に `amazon-bedrock` provider の扱いがある、(b) 古い固定モデル名が必要以上に残っていないことを `rg` で確認して記録する、(c) `gpt-5.4` default は Codex 本体の metadata として扱い、Harness 側で無理に固定しない方針が書かれている、(d) provider 変更が Claude 側の Bedrock guidance と矛盾しない | 53.1.1 | cc:TODO |
| 53.2.2 | Codex `/mcp verbose` と `.mcp.json` loading 改善を troubleshoot / setup に取り込む。普段の `/mcp` は速く、困った時だけ `/mcp verbose` で resources / resource templates / diagnostics を見る手順にする。plugin MCP loading は `mcpServers` と top-level server maps の両方を許す前提へ更新する | (a) troubleshoot / setup skill に `/mcp verbose` の診断手順がある、(b) `.mcp.json` の `mcpServers` 形式と top-level server map 形式の両方が説明されている、(c) Codex package test または upstream integration test が docs guidance を検出する、(d) Claude Code 側 MCP guidance と用語が混ざらない | 53.1.1 | cc:TODO |
| 53.2.3 | Codex realtime handoff / background agent 改善を `harness-loop` と `breezing` の長時間実行 guidance に反映する。background agents が transcript delta を受け取り、必要ない時は明示的に沈黙できる前提で、途中報告の頻度と silence policy を整理する | (a) `skills/harness-loop` / `codex/.codex/skills/harness-loop` または breezing docs に background agent の silence policy がある、(b) 長時間タスクで不要な通知を減らす説明がある、(c) advisor / reviewer drift 検知と矛盾しない、(d) 実装しない場合は C/P 判定の理由が snapshot にある | 53.1.1 | cc:TODO |
| 53.2.4 | Codex `remote_sandbox_config` と `codex exec` shared flags 継承を sandbox / execution policy に反映する。remote environment ごとの sandbox 要件を整理し、wrapper script 側で重複していた root shared flags を減らせるか確認する | (a) Codex sandbox policy に `remote_sandbox_config` の比較表がある、(b) `codex exec` wrapper / docs で重複フラグ削減可否が記録されている、(c) 変更する場合は既存 `--approval-policy` / `--sandbox` guidance の回帰テストがある、(d) 変更しない場合も Codex 本体の自動継承項目として snapshot に残っている | 53.1.1 | cc:TODO |
| 53.2.5 | Codex 0.123.0 の自動継承 bug fix を記録する。`/copy` after rollback、manual shell 中の follow-up queue、Unicode / dead-key input、stale proxy env、VS Code WSL keyboard など、Harness が直接実装しないが長時間作業 UX に効く項目を C としてまとめる | (a) snapshot に C 判定として記録されている、(b) Harness の long-running / session docs に影響がある項目だけ短く反映されている、(c) 直接実装しない理由が「本体修正を自動継承するため」と明記されている、(d) 無理な wrapper や workaround が追加されていない | 53.1.1 | cc:TODO |
| 53.3.1 | Phase 53 の記録と検証を閉じる。Feature Table / CHANGELOG / upstream integration test / validate-plugin の整合を取り、Phase 51.2 の既存 Codex-native skill audit TODO と重複するものは依存関係を明記する | (a) `docs/CLAUDE-feature-table.md` に Phase 53 追補がある、(b) `CHANGELOG.md` `[Unreleased]` に user-facing な追従内容がある、(c) `tests/test-claude-upstream-integration.sh` が Phase 53 snapshot と主要 guidance を検出する、(d) `bash tests/test-claude-upstream-integration.sh` と `./tests/validate-plugin.sh` または `bash tests/validate-plugin.sh` が PASS、(e) Phase 51.2 と重複する Codex mirror / path drift は依存関係として整理されている | 53.1.2, 53.1.3, 53.1.4, 53.1.5, 53.1.6, 53.2.1, 53.2.2, 53.2.3, 53.2.4, 53.2.5 | cc:TODO |

---
