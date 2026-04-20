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
