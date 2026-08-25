# Claude Code Harness — Plans.md

最終アーカイブ: 2026-07-23（Phase 62-116 → `.claude/memory/archive/Plans-2026-07-23-phase62-116.md`）
前回アーカイブ: 2026-05-29（Phase 80/81/82/84 → `.claude/memory/archive/Plans-2026-05-29-phase80-84.md`）

---

## North Star（3 層の野望）

この task ledger 全体が目指す到達点。古い順（土台 → てっぺん）。詳細契約は `spec.md` を正本とし、ここは参照ブロック。

- **L1 判断専念**: AI が plan / 実装 / 比較 / 検証 evidence を準備し、operator（人間）は最終判断のみ行う（`spec.md` Purpose / Users And Workflows）。
- **L2 ツール非依存（tool-agnostic）**: 同一 Harness（R01-R13 guardrails + plan/work/review/release）が Claude / Codex / Cursor の「どれからでも」効く。1 つの policy engine が 3 host を native hook 経由で adjudicate する（複製でなく routing）。2 つの向きを対等にサポート — #1 harness が駆動（Lead が他ツールを engine として spawn）/ #2 host から使う（Codex/Cursor「から」harness を使う）（`spec.md` Execution Backend Contract / Host Adapter）。
- **L3 協調（collaboration, 将来の本丸）**: 複数ツールが同一プロジェクトを、人間をコピペ係にせず協調する。Mode 1 = 完全自律オーケストレーション（v1 は Lead=Claude 固定、Codex/Cursor は外向き spawn API 無し）。Mode 2 = 人間在席の peer co-drive（live notice messaging）。フル peer-Lead 協調は段階導入で後回し（Phase 92 Purpose / `spec.md` Mode 1/Mode 2）。

> ~~既知 follow-up: delivery hook gen 未配線~~ **解消済み (2026-07-21 訂正)**: `GenerateDeliveryHooksJSON` は Phase 105.9 [b82143fe] で `harness gen` に配線済みだった（このメモ自体が stale だった）。identity placeholder no-op は Phase 121.2（`--from-env` runtime 解決）で解消、Claude host の Stop 配線は Phase 121.3 で追加。Mode 2 turn 境界 delivery は 3 host に配達される（live monitor は opt-in・既定 OFF）。

---

## 📦 アーカイブ

完了済み Phase は以下のファイルへ切り出し済み（git history にも残存）:

- [Phase 62-116](.claude/memory/archive/Plans-2026-07-23-phase62-116.md) — CC 2.1.112+ 追従 / 3-surface HTML / backend resolver + Cursor 昇格 / Session Coordination / Zero-Base Redesign + Plan B stage a-c (Phase 92-103) / S1-S5 gate + v5.0.0-v5.1.0 release 線 (Phase 104-114) / LSP 配線 / test-wiring auditor。Breezing 自律完走契約 (2026-06-12 承認) は運転規約として本ファイルに残置
- [Phase 80/81/82/84](.claude/memory/archive/Plans-2026-05-29-phase80-84.md) — Claude 2.1.143-2.1.152 + Codex 0.131-0.134 upstream refresh / Cursor CCH Adapter candidate / cursor-agent CLI workflow smoke 検証 (candidate, 配布なし) / harness-review closeout fixes + Cursor ACP boundary record
- [Phase 63/64/66-71/73-76/78/79](.claude/memory/archive/Plans-2026-05-29-phase63-79.md) — stale harness-mem 参照整理 / Plans archive-aware / 3-surface HTML cross-project safety 関連 / Open Issue closeout / Codex 0.130 / harness-review TeamAgent + lightweight / Hokage Core boundary / R03 break-glass / Superpowers tool-first onboarding / repo-health gates / README front door / spec.md+Plans.md co-required / Dependabot benchmark / harness-plan team gates
- [Phase 47-61](.claude/memory/archive/Plans-2026-05-08-phase47-61.md) — Session Monitor 能動監視 / XR-003 / 3-state 依存テスト規約 / CC 2.1.112-2.1.126 + Codex 0.121-0.128 upstream 追従 / Issue #105 English default + Japanese opt-in / External Issue closeout / Skill orchestration design contract / harness-mem managed companion (v4.6.0-v4.7.0) / Sandbagging-Aware Weak-Supervision Harness
- [Phase 44 + 45 + 46](.claude/memory/archive/Plans-2026-04-19-phase44-46.md) — Opus 4.7 / CC 2.1.99-110 追従 "Arcana" (v4.2.0) + Plugin Manifest 公式準拠 + Worker 3 層防御 (#84-#87, v4.3.0)
- [Phase 37 + 41 + 42 + 43](.claude/memory/archive/Plans-2026-04-17-phase37-41-42-43.md) — Hokage 完全体 / Long-Running Harness / Go hot-path migration / Advisor Strategy
- [Phase 39 + 40 + 41.0](.claude/memory/archive/Plans-2026-04-15-phase39-40-41.0.md) — レビュー体験改善 / Migration Residue Scanner / Long-Running Harness Spike

---

## マーカー凡例

PM ↔ Impl 運用で使用する標準マーカー:

| マーカー | 意味 | 誰が付ける |
|---------|------|-----------|
| `pm:requested` / `pm:依頼中` | PM がタスクを起票し、Impl へ依頼中 | PM |
| `cc:todo` / `cc:TODO` | Impl の未着手タスク | Impl |
| `cc:wip` / `cc:WIP` | Impl（Claude Code）が着手中 | Impl |
| `cc:done` / `cc:完了` | Impl が作業完了し、PM の確認待ち | Impl |
| `pm:approved` / `pm:確認済` | PM が最終確認を完了 | PM |
| `cc:withdrawn` | Impl が判断で取り下げたタスク（superseded / 別タスクで吸収）。breezing は cc:withdrawn を pickup しない | Impl |

**状態遷移**: 新規・更新時の正規出力は `pm:requested → cc:todo → cc:wip → cc:done → pm:approved`。既存 `pm:依頼中 → cc:TODO → cc:WIP → cc:完了 → pm:確認済` も read-compatible。`cc:withdrawn` は terminal state（再開しない）。

**後方互換**: `cursor:依頼中` / `cursor:確認済` は `pm:依頼中` / `pm:確認済` の同義として扱う（Cursor PM 運用時の表記）。

---

## Breezing 自律完走契約（2026-06-12 ユーザー承認 — 実装セクション運転規約）

`/breezing all --cursor` が**途中の人間判断なしに実装セクションを完走する**ための運転規約。ユーザー指示（2026-06-12「途中で聞かれてもわからないから実装は終わらせてほしい。レビューとチェックは後でまとめてやる」）に基づく事前承認の記録。

**スコープ 2 分割**:
- **実装セクション**（breezing 完走対象）: 93.1.1 / 93.1.2 / 93.2.1 / 93.3.1-93.3.5 / 92.5.1-92.5.3 / 92.6.1-92.6.4 / 95.1.1-95.1.3 / 95.2.1-95.2.3 / 95.4.1 / 96.1.1-96.1.4 ＋ 旧 backlog（88.1 / 88.3 / 72.1.2-72.1.6 / 83.7）
- **検証セクション**（ユーザー review window、breezing は触らない）: 93.3.6 / 95.5.1 / 96.1.5 / 96.1.6（いずれも `[lane:release]` e2e・公開 claim 更新）＋ Phase 94（92.4.x、user GO 待ち scope 外）

**mid-run 質問禁止 + 分岐既定値**:
- 実装セクション中は AskUserQuestion を使わない。分岐は以下の既定値で進める
- review REQUEST_CHANGES → 最大 3 回修正 → 未収束は Status に `blocked(理由)` 注記 + **次タスクへ続行**（停止しない）
- companion 起動失敗 → 1 回 retry → 失敗なら blocked + 続行
- blocked 一覧は最終報告に集約しユーザー review へ渡す

**Risk Gate 事前承認**（92.6.4 / 96.1.4、2026-06-12 ユーザー指示による）: breezing は停止せず実装してよい。ただし 3 条件を厳守: (i) default-OFF / opt-in 設計を変えない（auto-approve は 96.1.3 実装後も default OFF）、(ii) 実ユーザー設定ファイル（`~/.claude/settings*.json`・実 repo の `.claude/settings.local.json`）への実書込はせず fixture/tempdir 内 test で検証、(iii) 5 カテゴリ floor・fingerprint 封じ込め・deny ルールの弱体化を伴わない。逸脱が必要になったらそのタスクだけ blocked にして続行。

**共有ファイル lane**（Invariant 1 運用）: `skills/harness-work/` / `skills/breezing/` / `agents/*.md` を編集するタスクは **prose lane として直列**: 92.5.3 → 88.1 → 88.3 → 72.1.2 → 72.1.3 → 72.1.4 → 72.1.5 → 72.1.6。Go core lane（92.5.1-2 / 92.6.x / 95.1.x / 95.2.x / 96.1.x）とは並列可。93.3.1 / 93.3.4 も breezing/review SKILL を触るため prose lane タスクとは同時実行しない。`Plans.md` / `CHANGELOG.md` / `spec.md` は worker 編集禁止（Lead が統合時に編集）。

**推奨 wave 順**（Depends 整合済み）: W1: 93.1.1 ∥ 93.1.2 ∥ 93.2.1 ∥ 83.7 → W2: 93.3.1 → (93.3.2 ∥ 93.3.4) → 93.3.3 → 93.3.5 → W3: 92.5.1 → 92.5.2 → 92.5.3 → W4: 92.6.1 → 92.6.2 → (92.6.3 ∥ 92.6.4) ∥ prose lane（88.1 → 88.3 → 72.1.2-72.1.6） → W5: (95.1.1 → 95.1.2 → 95.1.3) ∥ (95.2.2 → 95.2.1) → 95.2.3 → 95.4.1 → W6: (96.1.1 ∥ 96.1.4) → 96.1.2 → 96.1.3

**終了条件**: 実装セクション全タスクが `cc:done` または `blocked(理由)`。最終報告 = 全 commit hash + blocked 一覧 + 検証セクション（93.3.6 → 95.5.1 → 96.1.5 → 96.1.6）への引き継ぎ手順。

---


## Archived Phases

Phase 132-133 (2026-08-10 〜 2026-08-14、全 task `cc:done`) は
[.claude/memory/archive/Plans-2026-08-14-phase132-133.md](.claude/memory/archive/Plans-2026-08-14-phase132-133.md) に退避。
学びは decisions.md D58-D61 と patterns.md P41-P43 へ昇格済み。

Phase 125-131 (2026-07-26 〜 2026-08-08、全 task `cc:done`) は
[.claude/memory/archive/Plans-2026-08-08-phase125-131.md](.claude/memory/archive/Plans-2026-08-08-phase125-131.md) に退避。
Phase 130 は task 表として起票されず、CHANGELOG `[Unreleased]` にのみ記録。

Phase 119-124 (2026-07-19 〜 2026-07-25、全 task `cc:done`) は
[.claude/memory/archive/Plans-2026-07-30-phase119-124.md](.claude/memory/archive/Plans-2026-07-30-phase119-124.md) に退避。
それ以前は `.claude/memory/archive/Plans-*.md` を参照。

## Phase 134: 検証チェーン配線修理 — HOTL 本実装 (2026-08-15 起票)

**Purpose**: Phase 101 (U0-U7 検証スパイク、全 `cc:done`) の後続本実装。検証機構は大半実装済みだが継ぎ目 3 箇所で切れている: 入口 (`reviewer_profile` 既定 `static`、risk_flags 自動昇格なし) / 中間 (`PENDING_BROWSER` が `combine_verdict()` で無言縮退) / 出口 (`harness-accept` が実行 artifact を機械読みせず LLM 再申告)。加えて scope leash (`go/internal/scopeleash/`) が standalone spike のまま未配線。外部ソース (Matt Pocock evals 思想 / mugi_uno Playwright Screencast / しまぶー再調査ループ) の取り込み先。設計正本: `~/.claude/plans/cch-users-tachibanashuuta-downloads-ai-lively-eclipse.md`。

**設計原則**: (1) evidence 種を足すときは取得不能時の縮退規則 (Accept surface でどう見えるか) をセットで定義する。(2) 各配線に「効いていることを証明する観測点」を必ず付ける (D58「配線した ≠ 効いている」)。(3) fail-visible: 未検証は止めないが passed 扱いにせず recommendation を wait/reject 側へ倒す。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 134.1 | `[lane:gate]` 入口: risk_flags → reviewer_profile 自動昇格 + ratchet。昇格テーブル (security-sensitive→runtime 以上 / ux-regression→browser 以上 / data-migration→runtime 以上、強さ順 static<runtime<browser) を `scripts/enrich-sprint-contract.sh` の `--risk` ハンドラに実装。`scripts/ensure-sprint-contract-ready.sh` の `--approve` 時に最低 profile を再計算し下回れば fail-closed (exit 5)。意図的 static 固定は `--profile-override-reason` 必須で `review.reviewer_notes` に記録 | (a) RED: `--risk security-sensitive` のみで approve が素通りする現状実測 → 修正後 exit 5, (b) `--risk security-sensitive` → approve で profile が runtime 以上へ自動昇格 (jq 確認), (c) 昇格テーブル外 flag (例 perf-sensitive) で profile 不変の negative test, (d) `bash tests/validate-plugin.sh` PASS | - | cc:done [c771707d; 昇格テーブル + ratchet exit 5。RED 実測 (risk のみで approve 素通り) → GREEN。negative: perf-sensitive 不変] |
| 134.2 | `[lane:gate]` fail-visible producer: `scripts/write-review-result.sh` に `pending_validations: [{layer, reason}]` 配列を追加 (additive、v1 互換)。`browser_verdict` が PENDING_BROWSER/SKIPPED/DOWNGRADE_TO_STATIC のとき `{layer:"browser"}`、runtime artifact が SKIPPED かつ profile≠static のとき `{layer:"runtime"}` を積む。`combine_verdict()` の verdict 語彙は変えない | (a) RED: 現状出力に `pending_validations` キーが無い実測, (b) PENDING_BROWSER fixture で `pending_validations[0].layer=="browser"`, (c) APPROVE/APPROVE 通常ケースで `pending_validations: []` の regression test, (d) 既存 write-review-result 系テスト PASS | - | cc:done [c771707d; pending_validations additive 追加。PENDING_BROWSER/SKIPPED/DOWNGRADE_TO_STATIC で layer 記録、APPROVE 通常系は [] の回帰 test 付き] |
| 134.3 | `[lane:fast]` worker-report.v1 の永続化: `agents/worker.md` の完了時プロトコルに「self_review 全項目 `verified: true` + evidence 非空になった時点で commit 前に `.claude/state/review/<task-id>.worker-report.json` へ Write する」を追記。`verified: false` が残る場合は書かない。ミラー同期 | (a) worker.md に永続化手順と命名規則が明記, (b) `bash scripts/sync-skill-mirrors.sh --check` PASS (agents ミラーがあれば同期), (c) `bash scripts/ci/check-consistency.sh` PASS | - | cc:done [c771707d; worker.md に .claude/state/review/<task-id>.worker-report.json 永続化手順を追記。verified:false 残存時は書かない] |
| 134.4 | `[lane:gate]` 出口の evidence 機械接続: 新規 `scripts/accept-collect-evidence.sh <task-id>` (read-only) が 4 artifact (`.claude/state/review/<task-id>.worker-report.json` / `.claude/state/review-result.json` [task.id 一致時のみ採用] / `<task-id>.runtime-review.json` / `<task-id>.browser-result.json`) を読み正規化 JSON を返す。`skills/harness-accept/SKILL.md` Step 4 を「artifact から引用する (新規主張を作らない)。artifact 欠損 or pending_validations 該当 criteria は `passed: false` + 実状態を evidence に転記 + `unverified_caveats` 追記」に書き換え。Recommendation ロジックに「pending 該当 criteria が 1 件以上なら ship にしない (wait に丸める)」を追加 | (a) artifact 全揃いタスクで evidence が artifact 引用になる, (b) PENDING_BROWSER 状態で該当 criteria `passed: false` + recommendation が ship にならない, (c) worker-report 欠損の旧タスクでもエラーで落ちず「該当なし」を返す互換 test, (d) acceptance-context.v1 schema 非破壊 | 134.2, 134.3 | cc:done [c771707d; accept-collect-evidence.sh (read-only、task.id 鮮度チェック)。SKILL.md Step 4 を artifact 引用 + pending prefix 規約に書換。pending 補正で 80% でも wait を fixture 実測 (RED→GREEN)] |
| 134.5 | `[lane:gate]` `[tdd:required]` scope leash 配線 (U0 本実装、advisory 開始): `go/internal/hookhandler/sprint_contract.go` の生成時に `scopeleash.InferScopeFromPlan` を呼び `declared_scope` を sprint-contract.json に焼き込む。`go/internal/guardrail/pre_tool.go` の runtimefloor ブロック直後に Write/Edit/MultiEdit の scope 判定を追加: `harness.toml [scope_leash] enforce_level = off\|warn\|enforce` (既定 warn)、空 scope は即 skip、warn は `.claude/state/scope-leash.jsonl` 記録 + additionalContext、enforce は deny。DroppedScope は既存 stop-evaluator ハンドラ拡張で advisory 通知 (新規 hook 登録なし) | (a) declared_scope が契約生成時に埋まる, (b) RED→GREEN: 配線前は scope-leash.jsonl が生成されない実測 → warn で記録される, (c) enforce 時のみ deny の positive/negative test, (d) 空 scope で一切発火しない誤爆防止 test, (e) `cd go && go test ./...` PASS + gofmt/vet clean | - | cc:done [c771707d; declared_scope 焼き込み + evaluatePreTool に warn/enforce 判定 (空 scope skip)。scope-leash.jsonl 記録と enforce deny を test 実測。DroppedScope は stop-evaluator 拡張] |
| 134.6 | `[lane:fast]` Playwright Screencast evidence: `scripts/browser-review-runner.sh` の playwright route 実行後に `test-results/**/*.webm` を探索し `browser-review-result.v1` に `artifacts: [{kind:"video", path}]` を積む。縮退規則: 録画なし → `kind:"text"` + note「use.video 未設定の可能性」/ playwright 以外 route → `artifacts: []`。`accept-collect-evidence.sh` が `kind:"video"` を `demo_artifacts` へ流し込み、`templates/html/accept.html.template` に video レンダリング分岐を追加 | (a) 録画ありで `artifacts[].kind=="video"`, (b) 録画なしで `kind:"text"` + note (縮退規則の実測), (c) Accept HTML に video 埋め込み/リンクが出る render test | 134.2, 134.4 | cc:done [c771707d; playwright route で *.webm 探索 → artifacts[].kind=video、縮退 (録画なし=text+note / 他 route=[])。accept HTML に video 埋め込み。3 分岐 fixture 実測] |
| 134.7 | `[lane:fast]` `[tdd:skip:docs-only]` 再調査ループ: harness-plan のタスク案確定直前 + harness-review の verdict 確定直前に「より良い案がないか徹底的に再調査 (圏外の別系統案も 1 つ検討)、無ければ推奨案を維持」を 1 回限定で差し込む。閾値ロジック不変更。ミラー同期 | (a) 該当 reference に再調査 1 回ステップが Step 番号体系と整合して記載, (b) `bash scripts/sync-skill-mirrors.sh --check` PASS | - | cc:done [c771707d; harness-plan / harness-review に再調査 1 回 (圏外案 1 つ含む) を差し込み。閾値ロジック不変更、mirror 同期済み] |
| 134.8 | `[lane:gate]` 検証の検証: `scripts/ci/check-verification-chain-wiring.sh` 新設 (scopeleash import [go list -deps] / pending_validations 存在 / SKILL.md の collect-evidence 呼び出し / 昇格テーブル / ratchet の 5 点)。実効性契約テスト 3 本: `tests/test-risk-flag-escalation.sh` / `tests/test-pending-browser-visible.sh` (PENDING_BROWSER → passed:false → ship にならない end-to-end) / `tests/test-scope-leash-fires-on-security-diff.sh` (実バイナリへ payload 投入し warn 記録 / enforce deny を実測)。`tests/validate-plugin.sh` にセクション追加 | (a) 3 本の契約テストが配線前 RED / 配線後 GREEN の実測記録つき, (b) `bash tests/validate-plugin.sh` 全体 PASS, (c) `bash scripts/ci/check-consistency.sh` PASS | 134.1-134.6 | cc:done [c771707d; check-verification-chain-wiring.sh (5 点) + 契約テスト 3 本を validate-plugin.sh section 22 に配線。各テスト RED (欠落再現) → GREEN 実測。binary 再ビルド後に実バイナリ probe] |

## Phase 135: 日本語 writing lint (2026-08-15 起票)

**Purpose**: yugen_matuni 方式 (PostToolUse で書き込み直後に NG パターン照合 → 「文ごと書き直し + グッドパターン」を advisory 返却、Stop で全体再検査、指摘→ルール自動ドラフト→人間ワンタップ承認) を CCH に実装。エンジン = CCH (`go/internal/writinglint/`)、辞書データ = 個人層 (`~/.claude/writing-lint/rules.jsonl`) の分離。failure-codifier の human-approval 原則を維持 (提案は自動、昇格は人間 CLI のみ)。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 135.1 | `[lane:gate]` `[tdd:required]` writinglint エンジン + writing-rule.v1 schema: `go/internal/writinglint/` に rule.go (id/pattern/good/scenes/enabled/severity) / dict.go (JSONL ロード + パス解決: config `writing_lint.dict_path` > env `CLAUDE_WRITING_LINT_DICT` > `~/.claude/writing-lint/rules.jsonl`) / scan.go (`ScanText`: シーン絞り込み→正規表現照合) / structural.go (文末 3 連続・敬体常体混在の純関数)。`templates/schemas/writing-rule.v1.json` 新設 | (a) 辞書 fixture でヒット/シーン絞り/文末 3 連続/混在の positive・negative fixture テスト green, (b) `cd go && go test ./internal/writinglint/...` PASS + gofmt/vet clean | - | cc:done [c771707d; writinglint パッケージ (rule/dict/scan/structural) + writing-rule.v1。fixture positive/negative green] |
| 135.2 | `[lane:gate]` PostToolUse ハンドラ: `go/internal/hookhandler/posttooluse_writing_lint.go` (quality_pack 型)。対象 `.md`/`.txt` + ひらがな含有ゲート。専用除外リスト (`docs/` は対象に含める、quality_pack の isExcludedPath は再利用しない)。config `writing_lint.enabled` (既定 false) / `scene` / `structural`。additionalContext に「該当文を丸ごと書き直し + グッドパターン」上位 5 件キャップ + 超過数明記、辞書未検出時は一度だけ diagnostics。advisory (exit 0 固定)。`main.go` に `case "writing-lint":`、hooks.json 2 ファイル + `sync-plugin-cache.sh` | (a) 辞書ヒット `.md` fixture で additionalContext に警告 + グッドパターン, (b) `.go`/`.ts` でスキップ, (c) enabled:false (既定) でスキップ, (d) `jq` で hooks.json 2 ファイルの PostToolUse 一致 + `tests/test-hooks-sync.sh` PASS | 135.1 | cc:done [c771707d; PostToolUse writing-lint (advisory、既定 off、ひらがなゲート、上位 5 件キャップ、辞書欠損 diagnostics)。hooks 2 ファイル同期] |
| 135.3 | `[lane:gate]` Stop 全体再検査: `go/internal/hookhandler/stop_writing_lint.go` (stop_session_evaluator 型)。`.claude/state/changed-files.jsonl` の `.md` を再スキャンし severity: major 残存なら初回 Stop で `decision:"block"`、再入 (`stop_hook_active`) は warning のみで通過。minor のみは block しない。`main.go` に `case "writing-lint-stop":`、Stop 配列へ独立エントリ追加 + 2 ファイル同期 | (a) major 残存 fixture で初回 block → 再入 approve のテスト (TestStopWritingLint_ReentryAllowsStopWithWarning), (b) minor のみで初回から block しない, (c) `cd go && go test ./internal/hookhandler/... -run WritingLint` PASS | 135.2 | cc:done [c771707d; stop_writing_lint (major 残存で初回 block、stop_hook_active 再入は警告のみ、minor は block しない)。再入 test 付き] |
| 135.4 | `[lane:fast]` 指摘→ルール登録ループ: `templates/schemas/writing-rule-proposal.v1.json` (status: pending/approved/rejected)。drafter は skill (`skills/japanese-writing-drafter/`) — 会話内で operator が日本語表現を直したのを検知したら `~/.claude/writing-lint/proposals.jsonl` へ proposal 追記 (書き込みはこの skill 経由のみ)。承認は `scripts/writing-rule-approve.sh --id` 1 発で rules.jsonl へ昇格、`scripts/writing-rule-list.sh` で pending 一覧 | (a) pending 1 件 fixture → approve 実行 → rules.jsonl 反映 + status: approved のテスト, (b) 昇格後の再スキャンで新ルールがヒットする回帰テスト, (c) 自動昇格経路が存在しない (human CLI のみ) | 135.1 | cc:done [c771707d; japanese-writing-drafter skill + writing-rule-approve/list.sh。proposal→承認→rules.jsonl 反映→再スキャンヒットの回帰 test。自動昇格経路なし] |
| 135.5 | `[lane:fast]` シーン切替 + schema 正式化: config `writing_lint.scene` 単一キー (ルール側 `scenes: []` 空なら全適用、code-comment は stretch でスコープ外明記)。`claude-code-harness.config.schema.json` に `writing_lint` と既存非公式 `quality_pack` を同時収録 (additionalProperties: false 維持)、config template へ追記、`tests/validate-plugin.sh` に schema 検証追加 | (a) 既存 config (quality_pack 含む) が新 schema でバリデーション PASS, (b) writing_lint セクション付き設定例も PASS, (c) `bash tests/validate-plugin.sh` PASS | 135.2 | cc:done [c771707d; writing_lint.scene + schema に writing_lint / quality_pack 正式収録。check-config-schema.sh を section 23 に配線 (配線は 134.8 担当が実施)] |

## Phase 136: surface チェリーピック (2026-08-15 起票)

**Purpose**: みのるん html-share の AWS インフラは導入せず、既存 cognitive-load 3 surface に安く足せるアイデアのみチェリーピック。diagram-design は接続点 1 文のみ。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 136.1 | `[lane:fast]` スマホ viewport: `templates/html/accept.html.template` / `plan-brief.html.template` / `progress.html.template` に orchestration.html.template と同じ viewport meta + レスポンシブ最小 CSS を横展開 | (a) `grep -l viewport templates/html/*.template` で対象 3 枚に追加確認, (b) `bash tests/validate-plugin.sh` PASS | - | cc:done [c771707d; accept/plan-brief/progress に viewport + レスポンシブ CSS 横展開] |
| 136.2 | `[lane:fast]` 承認待ちキュー表示: progress surface に writing lint pending proposal 件数 + コピペ用 `writing-rule-approve.sh --id X` コマンド文字列を表示 (押せるボタンではない旨明記)。`progress-snapshot.v1` に optional フィールド `writing_lint_pending` 追加 (additive) | (a) pending fixture で render した HTML に approve コマンド文字列が出る, (b) pending 0 件でセクション非表示, (c) schema additive 変更のみ | 135.4, 136.1 | cc:done [c771707d; progress に承認待ちキュー (件数 + コピペ用 approve コマンド、0 件で非表示)。progress-snapshot.v1 に additive フィールド] |
| 136.3 | `[lane:fast]` `[tdd:skip:docs-only]` diagram-design 接続点: surface 系 SKILL.md に「`diagram-design` skill がインストールされていれば図の描画に使う。無ければ静的レイアウトのまま」の 1 文追加。コードなし。ミラー同期 | (a) 該当 SKILL.md に 1 文追加, (b) `bash scripts/sync-skill-mirrors.sh --check` PASS | - | cc:done [c771707d; plan-brief SKILL.md に diagram-design 接続点 1 文] |

## Phase 137: ループエンジニアリング施策 (2026-08-15 起票)

**Purpose**: まさお 5 記事 (eval-loop / run-goal-loop / 検品パターン / foyer / 注意力) のうち、CCH に効く部品 3 つだけを既存契約に接ぐ。score 型 eval-loop の全面導入は見送り (verdict ベース review loop と続行判定の契約が二重化、機能系成果物には過剰という原著者実測)。グッドハート対策 (基準弱体化検知) と目標ドリフト対策 (依頼文再注入) は CCH 既存実装 (test-quality.md / sprint-contract) で充足済みのため相互参照のみ。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 137.1 | `[lane:fast]` `[tdd:skip:docs-only]` 採点設計規律: harness-plan の references に「DoD / acceptance_criteria を機械○×の床 (テスト・字数・exit code) / LLM 観点採点 (構成・訴求) / 本質 doc 参照の 3 層に翻訳する」規律を追加。判定法 =「アルバイトの人がチェックリストで○×を付けられるか」。曖昧形容詞 (良い/ちゃんとした) の検出時は翻訳を促す。ミラー同期 | (a) reference 追加 + harness-plan SKILL.md から参照, (b) `bash scripts/sync-skill-mirrors.sh --check` PASS | - | cc:done [c771707d; criteria-design.md (3 層翻訳 + アルバイト○×テスト + 曖昧形容詞の翻訳促し)。SKILL.md から参照] |
| 137.2 | `[lane:fast]` blind 受け手検査 (run-goal-loop 型): harness-accept に optional step — ship 判定直前に「採点基準・合格ライン・途中経過を渡さない fresh fork 評価者」へ依頼文 + 成果物 + 読者像のみを渡し「信じられるか / 役に立つか」を返させる。説得系/文書系成果物のみ、機能系スキップ。結果は Accept surface に「内側スコアとの乖離」表示 (乖離大なら wait 側へ)。accept.html.template / acceptance-context schema の受け口追加を含む。`blind-judge.md` は流用検討、合わなければ新規 reference | (a) 内側高得点 + blind 低評価 fixture で乖離表示 + recommendation が wait 側へ, (b) 機能系タスクでステップがスキップされる, (c) schema additive のみ | 134.4, 136.1 | cc:done [c771707d; blind-evaluator reference 新設 (blind-judge.md は review 文脈専用のため流用せず)。説得系のみ発動、乖離で wait 側へ。fixture: case-blind-divergence / case-functional-skip] |
| 137.3 | `[lane:fast]` `[tdd:skip:docs-only]` 評価者 4 契約の明文化: `agents/reviewer.md` に「①fresh context で採点 ②採点基準を書き換えない ③絶対評価 (前回比でなく) ④報告でなく実物を自分で開く」を 4 契約として一覧化 (①②④は既存実装の明文化、③は新規)。test-quality.md / test-wiring-auditor との相互参照を張る。ミラー同期 | (a) reviewer.md に 4 契約一覧, (b) 相互参照リンクが有効, (c) `bash scripts/ci/check-consistency.sh` PASS | - | cc:done [c771707d; reviewer.md に評価者 4 契約 (③絶対評価が新規)。test-quality / workflow-test-wiring へ相互参照] |

## Phase 138: 汎用 feedback ルール + count 段階付け + PR evidence pack (2026-08-15 起票)

**Purpose**: 外部 2 ソースの変形吸収。(1) zenn.dev/nozomi720 の feedback 管理システム — 指摘をルール化して永続化し、指摘回数 count で強制力を段階付け、UserPromptSubmit 注入 / PreToolUse 検査で機械強制。「operator が同じ指摘を二度しない」を writing (Phase 135) 以外の全行動へ一般化する。実例: 「rm は単独コマンドで」という指摘は prompt では worker に守られなかった (2026-08-15 実測 2 回) — feedback rule なら PreToolUse で機械警告になる。(2) builders.ramp.com "integrations that write themselves" — LLM はビルド時 (ルール起草・ドキュメント解釈)、実行時は決定論的 (regex / スクリプト) という分離原則と、「コードではなく実行記録 (artifact) を信頼する」= PR への実行記録添付。

**設計原則 (Ramp)**: LLM の仕事はルールの起草と意味理解まで。実行時の判定は regex / 整数比較 / exit code の決定論に限る。信頼の根拠はコードの見た目ではなく実プロバイダー/実バイナリに対する実行記録。

**変形の統治判断 (D67)**: count による強制力の**自動**昇格はしない。count は昇格を「提案」するだけで、warn→ask の昇格も承認 CLI 経由、deny への昇格は operator 手動のみ (deny-baseline / self-audit の「deny 面は人間 only」原則を維持)。データ駆動ルールの強制力上限は ask (deny は Go compiled rules のみ)。ルールファイルは AI も編集できるため、deny をデータに持たせると改ざんで deny 回避の攻撃面が開く。

**Depends**: Phase 135.4 (writing-rule proposal loop) の完成。writing 専用機構を汎用 feedback へ一般化する形で実装し、二重実装を避ける。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 138.1 | `[lane:gate]` feedback-rule.v1 schema + 基盤: `templates/schemas/feedback-rule.v1.json` (id / pattern [regex] / check_type [command-regex \| file-adjacency] / good / count / severity [warn\|ask] / enabled / scope)。ルール置き場は個人層 `~/.claude/feedback/rules.jsonl` (writing lint と同じ config > env > 既定パス解決)。違反 log `.claude/state/feedback-violations.jsonl` (append-only、count 自動更新なし)。proposal → 承認 CLI は 135.4 の writing-rule-approve.sh を一般化して共用 | (a) schema + パス解決 + 違反 log の fixture テスト green, (b) 135.4 との共用部の回帰テスト PASS, (c) `cd go && go test ./...` PASS + gofmt/vet clean | 135.4 | cc:todo |
| 138.2 | `[lane:gate]` `[tdd:required]` データ駆動 PreToolUse guard: 承認済み feedback rules を読み Bash command regex / file-adjacency を検査する handler (quality_pack / writing-lint 型)。判定は severity どおり warn (additionalContext) または ask。**deny は返さない** (実装レベルで上限を clamp し、テストで pin する)。違反時は violations.jsonl へ記録 | (a) warn rule で additionalContext + violations 記録, (b) ask rule で ask 判定, (c) severity: deny がルールに書かれていても ask に clamp される負性テスト, (d) ルール 0 件・辞書欠損で完全素通り, (e) 実バイナリ probe (stdin payload) で warn/ask を実測 | 138.1 | cc:todo |
| 138.3 | `[lane:fast]` count 昇格の提案機構: violations.jsonl から rule 別 count を集計し、閾値 (3 回 = ask 昇格 proposal、5 回 = operator への deny 検討通知) 到達で昇格 proposal を生成。適用は承認 CLI のみ。progress surface の承認待ちキュー (136.2) に統合表示 | (a) count 3 fixture で ask 昇格 proposal 生成, (b) 自動適用経路が存在しない (承認 CLI のみ), (c) deny は proposal でなく「operator 検討通知」で止まる | 138.1, 136.2 | cc:todo |
| 138.4 | `[lane:fast]` UserPromptSubmit 注入: count ≥ 3 の確定ルールを budget (3000 字) 内で UserPromptSubmit hook から注入 (count 降順、超過分は件数のみ通知)。D66 (context を汚さない節度) とのトレードオフを budget で固定 | (a) 確定ルール fixture で注入が budget 内, (b) 対象 0 件で注入なし, (c) hooks.json 2 ファイル同期 + tests/test-hooks-sync.sh PASS | 138.1 | cc:todo |
| 138.5 | `[lane:fast]` PR evidence pack (Ramp「artifact を信頼」): harness-release / review flow の PR 作成時に、実行記録の要約 (review-result verdict + pending_validations + RED→GREEN 実測記録 + 契約テスト結果 + artifact パス) を PR body へ自動添付する。レビュアー (人間 / codex) がコードの見た目でなく実行記録で判断できる状態にする | (a) fixture で PR body に evidence pack セクションが生成される, (b) artifact 欠損時は「未検証」明示 (fail-visible と同型), (c) 既存 PR 作成 flow の回帰なし | 134.2, 134.4 | cc:todo |
| 138.6 | `[lane:gate]` 検証の検証: `scripts/ci/check-feedback-rule-wiring.sh` + 実効性契約テスト (warn / ask / deny-clamp の 3 系を実バイナリ probe で実測、UserPromptSubmit 注入の budget 上限テスト)。validate-plugin.sh へ配線 | (a) 配線前 RED / 配線後 GREEN の実測記録, (b) `bash tests/validate-plugin.sh` PASS, (c) `bash scripts/ci/check-consistency.sh` PASS | 138.1-138.5 | cc:todo |

**共有ファイル lane (Invariant 1)**: `tests/validate-plugin.sh` の owner は 134.8 / 135.5 (この順で直列)。`Plans.md` / `CHANGELOG.md` は worker 編集禁止 (Lead が統合時に編集)。hooks.json 2 ファイルの owner は 135.2 → 135.3 (直列)。`skills/harness-accept/` は 134.4 → 134.6 → 137.2 の順で直列。prose lane (skills/agents md) は 134.3 → 134.7 → 136.3 → 137.1 → 137.3 で直列可 (異なるファイルなら並列も可)。生成物 (binary / mirror) は統合後に trunk で 1 回再生成 (Invariant 3)。

---

## Phase 139: D70 Codex Breezing worker route (2026-08-22 起票)

**Purpose**: Codex Breezing の実装 Worker だけを managed `worker` role の
`gpt-5.6-luna` / `max` へ固定し、レビュー・Advisor・deep と generic
`standard`（`gpt-5.6-sol` / `xhigh`）を混線させない。Native Codex は
`.codex/agents/worker.toml`、managed reviewer は `reviewer.toml`、companion は
中央 tier を正本とする。Codex の current default も `lite` の
`gpt-5.4-mini` / `low` から `gpt-5.6-luna` / `low` へ移行する。

**Current-default boundary**: ChatGPT sign-in retirement guidance と承認済み
user policy を、Harness の current routed default を新世代へ統一する判断根拠とする。
これは API-key 利用者まで upstream forced retirement の対象になったという主張ではなく、
Harness の routing default を更新する契約である。provider/API/HOME/install の操作は
この task に含めない。

**Spec result**: Spec delta — execution-backends / distribution の sub-spec に、
`hosts.toml` → `harness gen` が managed Codex worker/reviewer profiles を生成し、
setup が user/project の `agents/{worker,reviewer}.toml` へ activation する狭い配布契約を追加する。
`spec.md` の North Star、HOTL、provider/API 境界、generic `standard` の意味は
変更しない。D70 は role routing、companion の effort 表現、ミラーと検証配線の
運用契約であり、モデル品質・費用・実環境の保証を追加しない。

Native profile の仕様根拠は OpenAI の [Codex Subagents 設定](https://developers.openai.com/codex/subagents)。
この Phase の実装・fixture 検証は provider/API/HOME/install を実行しない。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 139.1 | `[lane:gate]` `[tdd:required]` D70 worker route: managed `worker.toml` を `agent_type: worker` で選び、Native worker は `gpt-5.6-luna` / `max`、companion の全 Breezing call-site は `CODEX_MODEL_TIER=worker` を pin。generic `standard` は `gpt-5.6-sol` / `xhigh`、`lite` / explorer は Luna/low のまま明示し、review / advisor / deep route と混線させない。managed `reviewer.toml` は worker と別 role として生成・activation する。official companion が受け付けない max は raw `codex exec -c model_reasoning_effort="max"` へ fail-visible に正規化する | worker/reviewer profile の name/description/developer instructions/model/effort、native spawn shape、worker call-site pin、lite migration、generic/review/advisor/deep 分離、invalid route と non-primary write の provider/ledger 前 fail-closed を確認。未取得の provider/API/HOME/install evidence は主張しない | D70 operator decision (`.claude/memory/decisions.md:431-448`) | cc:done [focused/full green; dual review APPROVE] |
| 139.2 | `[lane:gate]` `[tdd:required]` routed review transport: review ごとの local app-server proxy が `model` / `review_model` / `model_reasoning_effort` を `codex app-server --stdio` に注入し、official companion envelope を保持する。`review --commit` は provider dispatch 前に fail-closed。companion + proxy の成功時だけ orchestration ledger の successful delegation として記録し、reject / transport failure は数えない。TERM/INT は companion と proxy へ同時転送し、最大 1 秒待機 → KILL → reap。POSIX Unix socket と Windows named-pipe fixture/static 境界を明示する | config injection、official envelope、`--commit` reject、ledger 成功条件、child 消滅、signal lifecycle の focused checks を final rerun で確認。Windows live provider/app-server は未観測として扱う | 139.1 | cc:done [focused/full green; dual review APPROVE] |
| 139.3 | `[lane:gate]` `[tdd:required]` Codex setup/distribution contract: local/remote setup の config と backup destination preflight を skills/rules/agents/project `AGENTS.md` より先に実行する。Harness 所有の legacy root `[notify]` は setup form と distributed-template form の 2 形態だけを backup + atomic migration し、custom/ambiguous shape は backup を含め no-mutation fail。`[features] multi_agent = true` と `default_mode_request_user_input = true` を欠落時に追加し、明示値は保持する。Claude/Codex dist は worker/reviewer profile と review proxy の runtime-helper closure を一緒に配布する。Codex dist は fingerprint 実行に必要な `bin/harness` launcher・4 platform binary・`VERSION` も同梱する | local/remote preflight、backup destination failure の全 target 不変、exact notify 2 形態、custom/ambiguous no-mutation、feature defaults、generated profile activation、両 host dist の helper closure、Codex dist 単体の no-provider routed task 起動を確認。live HOME/install は行わず、Windows named-pipe live support は claim しない | 139.1, 139.2 | cc:done [focused/full green; dual review APPROVE] |

**D70 TDD evidence**: `2026-08-22T19:44:53+0900` に変更前 baseline
`8d74739aaeee8dad3290828711189d9efc6a2787` を `git archive HEAD` と
export-ignore 対象 subtree の `git archive HEAD:<subtree>` から一時領域へ復元し、
現行 focused test だけを overlay して RED を再実行した。実測 command / literal は次の通り。

- `bash tests/test-model-routing.sh` → `router help must advertise the dedicated worker tier`
- `bash tests/test-codex-package.sh` → `missing: codex/.codex/agents/worker.toml` / `reviewer.toml`
- `bash tests/test-codex-setup-local.sh` → `expected file to exist: .../agents/worker.toml`
- `bash tests/test-host-plugin-dist.sh` → `claude missing scripts/codex-companion.sh`
- `bash tests/test-breezing-codex-worker-route.sh` → `managed Codex worker agent profile is missing`
- `bash tests/test-codex-reviewer-route.sh` → `review companion argv must preserve pair: -c model="gpt-5.6-sol"`
- `bash tests/test-codex-setup-remote.sh` → `agents/worker.toml: No such file or directory`
- `bash tests/test-run-advisor-consultation.sh` / `bash tests/test-advisor-config.sh` → expected Sol, actual `gpt-5.4`
- `GOWORK=off go test ./cmd/harness ./internal/hostgen ...` → `AgentProfiles undefined` / `GenerateAgentProfile undefined`
- final review で追加した non-primary write fixture は実装修正前に
  `bash tests/test-model-routing.sh` → `non-primary write rejection must not emit a delegation ledger entry`
  を確認し、guard を ledger より前へ戻した後に GREEN を確認した

同一 focused tests と full checks の GREEN、final review、commit はそれぞれ完了後に
別 evidence として確定する。repo-supported `tdd-red-log` は runtime-only/gitignored のため、
tracked RED はこの Plans section を正本とする。

**D70 GREEN / review evidence**: 同一 worktree で routing、worker、reviewer、
setup local/remote、Codex package 27/27、host distribution、Advisor、Codex loop 42/42、
Claude upstream integration を再実行して GREEN。`go test ./...`、`go vet ./...`、
`harness gen --check`、skill mirror、consistency、全4 platform binary rebuild、
binary/source drift、ShellCheck、`git diff --check` も GREEN。`tests/validate-plugin.sh` は
147 pass / 0 warning / 0 failure。AI residual scan は APPROVE / major 0。
Regression/Security reviewer と Skeptic reviewer の最終判定はいずれも APPROVE / blocking 0。
provider/API、実 HOME/install、実 Windows named pipe、実 provider model selection は未実行・未観測。

**Current route evidence / boundary**: live routing は Codex `lite` を
`gpt-5.6-luna` / `low`、generic `standard`・review・advisor・deep を
`gpt-5.6-sol` / `xhigh`、専用 worker を Luna/max とする。ChatGPT sign-in
retirement guidance と user policy は current default migration の判断根拠であり、
API-key 利用者に upstream forced retirement が及ぶという evidence ではない。Native
reviewer の managed `reviewer.toml` と effective Sol/xhigh wiring、worker routing/help
を含む実装対象は current worktree で focused/full checks と dual review を通過した。
完了判定は profile の存在だけでなく、setup/distribution、review transport、fail-closed、
lifecycle、ledger の実行 evidence を含む。

---

## Phase 140: guardrail defer 方式 — ask の「停止」を「保留キュー + 続行」に置き換える (2026-08-22 起票)

**Purpose**: operator 裁定 (2026-08-22): 無人 run が確認プロンプトで序盤停止するのが最悪の結果。ask は「人間がその場にいる対話ターン」専用に格下げし、無人時は (a) 安全そうなら warn で自走 (v5.10.0 実装済み)、(b) operator 条件 (本番影響 / main への不可逆 / root 外) に触れる可能性がある操作は**実行せずスキップして他の作業を継続**し、戻った operator が保留一覧を一括レビューする。機構の核: hook の deny は run を止めない (エージェントに理由が返り続行する。2026-08-22 に floor deny 2 回で実測)。止めるのは ask だけ。

**優先順 (operator 裁定 2026-08-25)**: 次スプリントの先頭。Phase 141 (外部吸収レビュー由来) より先に着手する。根拠: 2026-08-24 の設計レビュー (`docs/reports/2026-08-24-cch-harness-review.html`) で、HOTL の残る穴のうち「無人 run が ask で序盤停止する」が最大と判定。vibe-kanban が既定 `--dangerously-skip-permissions` で解いている問題を、確認を消さずに解く CCH の答えがこの Phase。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 140.1 | `destructive_delete: defer` 追加: R05 の確認相当場面で ask の代わりに deny を返し、reason に行動契約 (「保留キューに積んだ / 再試行禁止 / 他タスクを継続 / 終了時に保留一覧を報告」) を埋め込む。操作は `.claude/state/deferred-ops.jsonl` (timestamp / session_id / rule_id / command / 判定理由) へ追記 | (a) defer 設定で deny + キュー 1 行の実バイナリ probe, (b) 同一コマンド再試行でキューが重複せず deny 継続, (c) 既存 ask/warn 挙動の regression なし | - | cc:todo |
| 140.2 | 保留キューの承認 flow: `bin/harness deferred list / approve <id>` CLI。approve は既存 plan preapproval (`ConsumePlanPreapproval`) と同じ consume 機構で「次の 1 回」を通す。progress surface に保留 N 件 + コピペ用 approve コマンドを表示 (136.2 の承認待ちキュー表示と同型) | (a) approve 後の再実行が allow になる probe, (b) 未 approve は deny のまま, (c) surface 表示の render test | 140.1 | cc:todo |
| 140.3 | エージェント自主停止の禁止文言: harness-release / breezing / harness-work の SKILL.md に「background 待ちで停止しない (停止すると background 子は残らない)」「『検証を待ちます』『確認します』で turn を終えない。同期実行で待つか、保留として報告して次へ進む」を AUTOSTART pattern と同じ literal 列挙で追加。2026-08-22 の release run で 2 回発生した停止パターンが再現ケース | (a) 該当 SKILL.md に禁止文言, (b) mirror 同期 PASS | - | cc:todo |
| 140.4 | defer を他の configurable ask へ一般化するか判定: R12 (main push) は operator 例外として ask 維持が既定。R04 は work-mode で既にカバー。判定結果と根拠を decisions.md へ記録 | (a) decisions.md に判定エントリ | 140.1 | cc:todo |

---

## Phase 141: 外部吸収レビュー 2026-08-24 の反映 — 記憶の修理 / 注入棚卸し / 辞書稼働 / ルール引退提案 / native 重複点検 (2026-08-25 起票)

**Purpose**: `/muscle` による設計レビュー (`docs/reports/2026-08-24-cch-harness-review.html`、調査 4 系統 + 独立反証パス) の operator 承認 5 件を計画へ載せる。
レビューの結論は「統治層の設計は正しい (競合 5 製品に同等の統治層なし)。問題は運用の 3 穴 = 記憶の中身が空 / 日本語 lint の辞書が空 / 無人 ask 停止 (Phase 140)」。
Hermes Agent (NousResearch) からは「可逆性の厚さが自律の許可量を決める」原理のうち **安全な半分 (usage telemetry + 引退提案)** だけを取る。承認なしの自動採用は D67 維持で不採用 (D71)。

**Spec result**: Spec skip reason — 5 件とも既存契約 (HOTL 不変条件 1/2/6、D62 fail-visible、D64 辞書分離、D67 強制力上限、D68 実行記録を信頼) の範囲内で `spec.md` の変更を伴わない。141.2 の責任境界変更は handoff 起票止まりで、spec 変更は handoff 承認後に別 task として起票する。

**team_validation_mode**: subagent (調査 4 系統 + 独立反証 1 系統。反証で 1 件不採用・3 件縮小を確定済み)。

**設計原則**: (1) 各配線に「効いていることを証明する観測点」を付ける (D58)。(2) 縮退は fail-visible (D62)。止めずに「未注入」「未検証」を可視化する。(3) データ駆動ルールの強制力上限は ask、自動昇格・自動 archive・削除経路は作らない (D67 / D71)。(4) 棚卸しは計測ファースト (P43)。安全装置系 hook は削減候補から除外する。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 141.1 | `[lane:gate]` `[tdd:required]` resume pack 品質ゲート: UserPromptSubmit の resume 注入経路 (`scripts/userprompt-inject-policy.sh` / memory-bridge) に決定論の空判定を追加。Decisions / Open Loops / Next Actions / Latest Exchange が全て「not captured」「No ... captured」相当、または Overview が `elicitation_event: {}` のみなら empty と判定し、本文を注入せず「resume pack が空のため未注入 (source session / generated_at)」の 1 行マーカーだけを additionalContext に出す。閾値・語彙は script 内定数で固定 | (a) RED: このセッションで実測した空要約 fixture (`Overview: elicitation_event: {}` / `User: not captured`) がそのまま注入される現状を実測, (b) 空 fixture で本文未注入 + マーカー出力, (c) 中身あり fixture は従来どおり 32KB 上限で注入 (回帰), (d) `tests/validate-plugin.sh` へ配線 (D53) | - | cc:todo |
| 141.2 | `[lane:fast]` `[tdd:skip:docs-only]` harness-mem への handoff 起票: `docs/rules/cross-repo-handoff.md` の workflow で依頼書を作る。内容 = (i) session summary が空要約になる (141.1 の fixture を添付), (ii) ingest `ok:true` で `entries_imported: 0` (D55), (iii) `mem_search` 8 秒 timeout → `safe_lexical_fallback`, (iv) 責任境界監査: セッション近傍の記憶は CC native auto-memory (machine-local、既定 ON) に寄せ、harness-mem は cross-tool / cross-machine 検索に限定する案。**実装・他 repo への書き込みはしない** | (a) handoff 文書が所定の場所に作成され operator 承認待ち状態, (b) 4 項目それぞれに実測 evidence (コマンドと出力) が添付, (c) `docs/reports/README.md` 相当の索引に記録 | 141.1 | cc:todo |
| 141.3 | `[lane:fast]` context 予算の棚卸し: `skills/maintenance` に `context` サブコマンド (実体は `scripts/context-budget-audit.sh`) を追加。注入源ごとの実測サイズ (CLAUDE.md / rules / MEMORY.md / hooks の additionalContext / UserPromptSubmit injectors) と、同一 directive の重複注入 (例: 言語指示が 1 ターンに 2 回) を検出してレポートする。**enforcement / guardrail 系 hook (pre-tool / permission / runtime floor) は削減候補から除外する固定リスト**を script 内に持つ。削減の実行はしない (レポートのみ) | (a) 実測レポートが生成され、このセッションの起動時 94.7k token 相当の内訳が再現できる, (b) 言語 directive 二重注入 fixture で重複が検出される, (c) guardrail 系 hook が候補に出ない negative test, (d) `bash scripts/sync-skill-mirrors.sh --check` PASS | - | cc:todo |
| 141.4 | `[lane:fast]` 日本語 writing lint 辞書の seeding: `~/.claude/rules/japanese-writing-core.md` の決定論的部分集合 (LLM 空句リスト、em ダッシュ、中黒並列など literal / 正規表現でマッチできるもの) を `writing-rule-proposal.v1` として `~/.claude/writing-lint/proposals.jsonl` へ生成する `scripts/writing-rule-seed.sh`。**自動一括承認はしない** (承認は既存 `writing-rule-approve.sh --id` を 1 件ずつ)。文脈依存で誤検知しうる語 (「重要」等) は seed 対象外とし、候補一覧に理由付きで残す。`writing_lint.enabled` の有効化手順を docs に追記 | (a) seed 実行で proposal が N 件生成され、rules.jsonl は書き換わらない (自動昇格経路なし、135.4 の既存 test で pin), (b) 1 件 approve → rules.jsonl 反映 → 再スキャンでヒットする回帰 (135.4 test 再利用), (c) 除外語リストが理由付きで出力される, (d) 有効化手順 doc | 135.4 | cc:todo |
| 141.5 | `[lane:gate]` `[tdd:required]` ルール usage telemetry + 引退提案 (Hermes curator の安全な半分): writing lint (将来は feedback rules も) のヒット時に `use_count` / `last_used_at` を個人層 sidecar (`~/.claude/writing-lint/.usage.json`。辞書本体は書き換えない) へ記録。閾値 (既定 90 日未使用、`use_count == 0` は登録から 90 日の猶予) で「archive 提案」を proposals.jsonl に生成する。**実行は承認 CLI のみ、archive は `.archive/` へ移動して復元可、削除経路は作らない**。全 mutation を append-only ledger (`~/.claude/writing-lint/.ledger.jsonl`、actor + before/after ハッシュ) に記録 | (a) ヒット時に usage が更新される, (b) 90 日 fixture で archive 提案が生成される, (c) 自動 archive / 自動削除の経路が存在しない negative test, (d) archive → restore の往復 test, (e) ledger に actor と hash が残る, (f) `cd go && go test ./internal/writinglint/...` PASS + gofmt/vet clean | 141.4 | cc:todo |
| 141.6 | `[lane:fast]` `[tdd:skip:docs-only]` CC native 機能との重複点検を定期化: `docs/research/official-feature-inventory-2026-06.md` を 2026-08 版へ更新 (Dynamic Workflows / Agent Teams experimental 既定 OFF / worktree isolation 4 種チェック / `/code-review ultra` / auto-memory machine-local / 28 hook events / scheduled tasks 3 層)。各行に「CCH は利便性として採用 / 統治境界としては委譲しない」の既存判定を明記。`CLAUDE.md:14` の「Opus 4.7」表記を現行世代へ修正。更新周期 (CC minor 追従時) を upstream-update 系 skill の手順に 1 行追加 | (a) inventory が 2026-08 版に更新, (b) CLAUDE.md 表記修正, (c) `bash scripts/ci/check-consistency.sh` PASS, (d) 「委譲して薄くする」判断は本 task に含めない (1 件ずつ別起票) ことが明記 | - | cc:todo |
| 141.7 | `[lane:gate]` 検証の検証: 141.1 / 141.3 / 141.5 の実効性契約テスト (空 resume 未注入 / 重複注入検出 / 自動 archive 経路なし) を `tests/validate-plugin.sh` に配線。各テストは配線前 RED / 配線後 GREEN の実測記録つき | (a) 3 本の契約テストが RED→GREEN 記録つき, (b) `bash tests/validate-plugin.sh` 全体 PASS, (c) `bash scripts/ci/check-consistency.sh` PASS | 141.1, 141.3, 141.5 | cc:todo |

**共有ファイル lane (Invariant 1)**: `tests/validate-plugin.sh` の owner は 141.7 のみ。`skills/maintenance/` は 141.3、`skills/japanese-writing-drafter/` と `go/internal/writinglint/` は 141.4 → 141.5 の順で直列。`Plans.md` / `CHANGELOG.md` / `spec.md` は worker 編集禁止 (Lead が統合時に編集)。生成物 (binary / mirror) は統合後に trunk で 1 回再生成 (Invariant 3)。

**レビューで挙がったが本 Phase に含めない候補 (未起票、operator 判断待ち)**: (i) runtime floor secret-read の誤検知: jq のフィールド参照構文 `.key` が拡張子パターン `*.key` に一致して read-only コマンドが deny された (2026-08-24 に 1 回、2026-08-25 の Plans.md 追記コマンド中に 1 回、計 2 回実測)。command 文字列走査を「ファイル引数の位置にある token」に限定する精緻化が候補。(ii) 配布先 (installed plugin) で `.claude-plugin/settings.json` の permissions deny が読まれていない可能性の実測検証。効いていなければ死んだ deny リストを同梱していることになる。(iii) `docs/research/official-feature-inventory` の内容を踏まえた機構層の個別委譲判断。
