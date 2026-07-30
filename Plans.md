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

Phase 119-124 (2026-07-19 〜 2026-07-25、全 task `cc:done`) は
[.claude/memory/archive/Plans-2026-07-30-phase119-124.md](.claude/memory/archive/Plans-2026-07-30-phase119-124.md) に退避。
それ以前は `.claude/memory/archive/Plans-*.md` を参照。

---

## Phase 125: Stop hook 無限ブロック修正 (Issue #269、operator 起票 2026-07-26) [P1]

Purpose: v5.3.1 の Stop hook (`go/internal/hookhandler/stop_session_evaluator.go:73-94`) は Plans.md の WIP > 0 で無条件 `decision: block` を返し、再入 (`stop_hook_active: true`) でも判定を変えない。調査のみのセッションでは WIP を減らす正当手段がなく、実測 12 連続発火でセッション終了不能 (cx-harness、WIP 32 件)。Issue #269 期待動作案 1 (再入上限) を採用: 初回 Stop は従来どおり block (marker 遷移の nudge 価値を維持)、再入時 (`stop_hook_active=true`) は WIP が残っていても systemMessage 警告 + `ok: true` で停止を許可する。状態ファイル不要 (stop_hook_active が CC 側の再入シグナル)。既存テスト `StoppedStateDoesNotBypassWIP` 等の期待値変更は Issue #269 を根拠とする意図的仕様変更として commit に明記する (test-quality: 弱体化ではなく仕様更新)。案 2 (session が Plans.md に触れたか) / 案 3 (config knob) は今回見送り、再発時の follow-up とする。Spec skip reason: hook 挙動の bugfix で product contract の追加なし。team_validation_mode: not_required_lightweight。unknown_data: なし。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 125.1 | `[lane:gate]` `[tdd:required]` Stop 再入時 (stop_hook_active=true) は WIP 残でも警告 + 停止許可へ変更。初回 block は維持。コード内コメント (「ホスト側 block cap が最終ガード」の破れた前提) も実態に合わせ更新 | (a) RED: 「stop_hook_active=true + WIP>0 → ok:true + systemMessage 警告」を期待するテストが現実装で fail する実測記録, (b) 初回 (stop_hook_active=false) の block 非退行, (c) 既存テストの期待値変更は Issue #269 参照付きで最小限, (d) `cd go && go test ./internal/hookhandler/... -count=1` PASS + gofmt clean, (e) Issue #269 へ修正 commit を参照するコメント投稿 (close は release 後) | - | cc:done [026524d3; RED 実測 "ReentryAllowsStopWithWarning FAIL decision=block" 引用確認。既存 StopHookActiveProgressPolicy の期待値変更は Issue #269 根拠で最小限。hookhandler 18.8s PASS + binary rebuild + drift gate OK] |

---

## Phase 126: 止まらないモード — worktree-scoped no-stop (operator 裁定 2026-07-27) [P1]

Purpose: operator 裁定 (2026-07-27、AskUserQuestion 一括確認 ×2): 「worktree 内の作業は原則確認不要、main への不可逆な操作は plan 時に前倒し確認、途中停止させない」。Level 1 (user settings env: `HARNESS_RUNTIME_FLOOR_EGRESS=off` + `HARNESS_RUNTIME_FLOOR_SECRET_ALLOW` へ `~/orca/workspaces/` 追加) は 2026-07-27 適用済み。本 Phase は Level 2 = 本体実装。team_validation_mode: subagent (Security/Skeptic + Architecture/QA の 2 独立検証で REQUEST_CHANGES 6 件 → 全反映済み)。検証で floor の実バイパス (GNU 長形式 `rm --recursive` が worktree-escape 検出をすり抜ける。R05 側 `hasDangerousRmRf` は検出) を発見したため、126.1 の守り強化を筆頭に置く。さらに本 Phase 起票時、Plans.md への heredoc append が worktree-escape floor に誤検知 deny される実測 (heredoc 本文中の rm 文字列を実行コマンドと誤認) が出ており、126.1 で heredoc 除外も扱う。Reject: secretWorktreeAllow (worktree 動的 secret 許可) は operator 裁定で撤回 — 適用済み env prefix で目的達成済み、spec「named paths のみ」契約 (spec.md:82-94) と矛盾、symlink 攻撃面の追加に見合う便益なし。新 worktree root 追加時の env 1 行追記運用を 126.3 の docs に含める。Constitution 条項 (spec.md: rules.go は untouchable class / human-only) は Phase 112.19 前例 (operator explicit adoption) に従い 126.6 のゲートで満たす。Spec delta: docs/spec/operations-memory-and-collaboration.md の floor 節へ rm 検出カバレッジ統合を追記 (126.1 DoD)、spec.md の auto-approve scope 節へ R04 scratch / R05 worktree スコープ緩和と preapproval v2 消費契約を追記 (126.3/126.4/126.5 DoD)。unknown_data: harness-mem daemon 不応答 (timeout) のため過去判断照会は repo 一次資料 (Plans archive / CHANGELOG / spec) のみで実施 (not_observed != absent)。実装注意: Level 1 適用済み環境では `HARNESS_RUNTIME_FLOOR_*` env が floor テストを誤 FAIL させる実測があるため、go test は env unset / `t.Setenv` で隔離して実行する。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 126.1 | `[lane:gate]` `[tdd:required]` `[security]` rm 検出ロジック統合 (守り強化): `go/internal/runtimefloor` の `rmRecursivePattern` を `go/internal/policy/helpers.go` `hasDangerousRmRf` と同等カバレッジ (GNU 長形式 `--recursive` 等) へ拡張し、危険 rm 判定 + target 抽出を共有実装に統合 (新規下位 pkg 切出し or runtimefloor export。policy の stdlib+hookproto 依存方針を崩す場合は下位 pkg を選ぶ)。併せて worktree-escape 走査に heredoc 本文除外 (`stripNonExecutableText` 相当) を適用し、本文中の rm 文字列での誤検知を解消。2 系統の乖離を pin する同値性テストを追加 | (a) RED: GNU 長形式の再帰 rm + worktree 外 path が現行 floor で Stopped=false になる実測記録 → 修正後 deny, (b) R05 判定と floor 判定のカバレッジ同値性 test, (c) heredoc 本文に rm 文字列を含む cat append が deny されない test, (d) `cd go && go test ./internal/runtimefloor/... ./internal/policy/...` PASS (HARNESS_RUNTIME_FLOOR_* unset で実行), (e) `tests/test-3cli-hook-floor.sh` 15 case 非退行, (f) Spec delta: floor 節へ rm カバレッジ統合を追記 | - | cc:done [5fe9c41e; RED 実測: 作業ツリー外を対象に GNU 長形式は通常 ask / WorkMode approve、find の削除式も同様だったものが修正後は両モードとも deny。秘密読取側のインタプリタ heredoc バイパス (修正前 approve) も同時に deny 化。誤検知 (文書 heredoc 本文での拒否) 解消。go/pkg/shellscan 新設で判定を統合し同値性テストで pin。runtimefloor/policy/shellscan PASS、gofmt+vet clean、3CLI floor 15/15、既存期待値の変更なし] |
| 126.2 | `[lane:gate]` `[tdd:required]` guardrail/floor 発火 audit ログ: `EvaluateRules` が発火 rule ID を返す API 変更 + `EvaluatePreTool` の記録漏れしない単一チョークポイント化。`.claude/state/audit/guardrail-fires.jsonl` へ flock 付き JSONL append (hookhandler `withFileLock` パターンを下位 pkg 化して guardrail から利用)。記録フィールドは timestamp/host/category/rule-id/pattern/decision/コマンド SHA-256+長さのみで、コマンド全文は書かない。secret-read/money-billing 発火時は hash 以外の command 由来フィールドも省略 | (a) floor deny / rule ask / rule deny の 3 種が 1 行ずつ記録される test, (b) 並行書込 (同時 2 プロセス) で行破損なし test, (c) 生コマンド文字列が log に現れない negative test, (d) `rules_test.go` への API 変更影響は意図的変更として commit message に明記, (e) go test PASS | - | cc:done [9f41944b; .claude/state/audit/guardrail-fires.jsonl へ flock 付き追記。実測: floor deny / 規則 ask が 1 行ずつ記録され純 approve は非記録、秘密ファイル名・パス断片の漏れゼロ (negative test + 実測の両方で確認)、secret-read/money-billing はハッシュと長さも省略。EvaluatePreTool を内部関数化して 2 経路の記録漏れを解消。go test ./... 0 FAIL、gofmt+vet clean、windows クロスコンパイル成功。既存テストは fixture 隔離のみで期待値変更なし] |
| 126.3 | `[lane:gate]` `[tdd:required]` R04 scratch skip: OS scratch 領域判定 (`allowlistedTempRoots` 相当: /tmp, /private/tmp, /var/tmp, $TMPDIR, ~/.cache, ~/Library/Caches) を policy から参照可能な共有実装にし、R04 は scratch 配下への Write/Edit を approve に変更。WorkMode バイパスとの併存関係 (work run 中=WorkMode で全スキップ、対話中=scratch のみスキップ) を docs 明記。新 worktree root 追加時の `HARNESS_RUNTIME_FLOOR_SECRET_ALLOW` env 追記運用も同 docs に記載 | (a) `TestR04_WriteOutsideProject` (/tmp→ask) の期待値変更を意図的仕様変更として commit に明記, (b) scratch 外 (例 $HOME 直下) への Write は従来どおり ask の非退行 test, (c) go test PASS, (d) docs 追記 + Spec delta (auto-approve scope 節), (e) mirror in-sync | - | cc:done [126.3 実装; Lead レビューで 2 件差し戻し後 green。(1) macOS 既定 TMPDIR が root 側の未解決で漏れていた critical を修正 (実測 ask→approve)、(2) 126.2 audit_test の fixture が本変更で前提崩壊したため期待値を緩めず fixture 差替。実測 12 項目すべて期待どおり (一時領域=approve / HOME 直下・Desktop=ask / 一時領域内 symlink→外部=ask / Desktop・Documents の削除=deny 非退行)。go test ./... 0 FAIL、gofmt+vet clean] |
| 126.4 | `[lane:gate]` `[tdd:required]` `[security]` R05 worktree スコープ化: 126.1 の共有 target 抽出を使い、全 target が `EvalSymlinks` 後の real path で ProjectRoot(=worktree) 内なら ask スキップ。target 抽出不能・symlink 解決失敗・判定不能は fail-safe で ask 維持。untracked ファイル損失リスク (worktree 内の再帰削除は git 復旧不能な生成物を消しうる) を docs 明記 | (a) worktree 内再帰削除 → approve / worktree 外 → floor deny / 判定不能 → ask の 3 分岐 test, (b) symlink (worktree 内 link → 外実体) が skip されない test, (c) go test PASS, (d) Spec delta (auto-approve scope 節) | 126.1 | cc:done [126.4 実装; 実測 13 項目すべて期待どおり。worktree 内 (絶対/相対) は approve、Desktop/Documents は deny 非退行、複数対象で 1 つ外なら deny、worktree 内 symlink→外部と対象抽出不能は ask 維持。仕様追記の安全側条件 (外部 cd 後の相対削除 / パイプライン / バックグラウンド / バッククォート生成) も実装と一致を個別確認。go test ./... 0 FAIL、gofmt+vet clean。codex プロセスは全体テスト待機中に停止したため Lead が検証を引き継いだ] |
| 126.5 | `[lane:gate]` `[tdd:required]` plan-preapproval v2 + R12 限定 runtime 配線: `templates/schemas/plan-preapproval.v2.json` 新設 (TTL/expiry + consumed + scope 完全一致契約。v1 は additionalProperties:false のため別 schema)。guardrail に fail-safe reader (file 不在/壊れ/期限切れ/scope 不一致 → 従来 ask) を追加し、R12 の ask を「approved + 未消費 + scope 一致 + 正規化完全一致 command」でのみ抑制、使用時に consumed 遷移。runtime floor 5 カテゴリへの配線は対象外と明文化 (floor 非上書き原則維持)。`scripts/plan-preapproval.sh` は v2 対応 + `tests/test-shell-lint.sh` の対象リストへ追加 | (a) e2e: 承認済み push → R12 ask 抑制 / 未承認 → ask 従来どおり / 期限切れ・消費済み → ask 復活 test, (b) fail-safe (JSON 壊れ → ask) test, (c) schema v2 validation test, (d) shellcheck green, (e) go test PASS, (f) Spec delta (preapproval v2 消費契約) | - | cc:done [126.5 実装; plan-preapproval.v2 (expires_at 必須 / max_uses 既定 10 / uses) 新設、active-task.json による scope 解決、R12 の ask 手前に抑制判定を挿入。実測 12 項目すべて期待どおり (承認一致=抑制 / 期限切れ・回数超過・scope 不一致・解決不能・破損・v1=ask / 余分な引数・承認外 remote=ask / floor 対象=deny で承認は floor を上書きしない / uses が 1 増加)。apply-secret-allow の scope 未検証欠陥も修正。shellcheck 対象に追加。go test は既存の負荷依存 flaky 1 件のみ (単独 0.4s PASS、メイン checkout でも同様)] |
| 126.6 | `[lane:gate]` `[tdd:skip:human-adoption-gate]` operator 明示採択 (Phase 112.19 型): 126.1-126.5 が変更した `go/internal/policy/rules.go` / `selfaudit.go` 関連 diff を operator が review し明示 adopt する。AI-authored completion ではこの task を満たせない | (a) operator の採択記録 (日時 + 対象 commit SHA) を本 task の Status に記載 | 126.1, 126.2, 126.3, 126.4, 126.5 | cc:done [operator explicitly adopted 2026-07-28; 対象 commit 5fe9c41e (126.1) / 9f41944b (126.2) / 39433b43 (126.3) / 19f6d4ec (126.4) / 9728032a (126.5)。rules.go の変更は 5 箇所 (package doc / R04 一時領域 skip / R05 worktree スコープ / R12 preapproval 抑制 / RuleID 付与) で、判定を弱めるのは R04・R05・R12 の 3 箇所のみ。selfaudit.go は未変更、R01/R06/R10/R11/R15 の deny・runtime floor 5 カテゴリ・deny-baseline は非接触をoperator が差分提示のうえ確認して採択] |
| 126.7 | `[lane:release]` `[tdd:skip:verification]` 検証 + 配布物: `go/scripts/build-all.sh` で 4-platform binary 再生成 (bin/harness は shim のため出力先に指定しない)、`scripts/ci/check-binary-source-drift.sh` ローカル green、新テストを `tests/validate-plugin.sh` へ配線、CHANGELOG `[Unreleased]` 追記 | (a) `bash tests/validate-plugin.sh` 0 failed, (b) drift gate green, (c) `scripts/ci/check-consistency.sh` PASS, (d) PR closeout (事前承認済み: push + PR 作成 + CI green 確認 + merge。merge 前に 126.6 採択を確認) | 126.6 | cc:done [bd9e6ee3 (PR #277 merged to main); 4 プラットフォーム再ビルド + drift gate OK、CHANGELOG [Unreleased] に Phase 126 エントリ、skill mirror 再同期 (in-sync)、refactor で位置がずれた upstream-integration pin を新しい実装位置へ追随 (保証内容は不変、共有入口も検査に追加)。validate-plugin 125 合格/2 失敗 (2 件は本 Phase を含まないベースでも失敗する既存分、新規失敗ゼロ)、check-consistency 全 24 通過、CI 全 check pass (4 platform build / CodeQL / test-go / validate)] |

事前確認 (plan-time pre-approval):
- 事項: external-send — `git push origin <branch>` + `gh pr create` + CI green 確認 + `gh pr merge --merge` (完全自動。merge 前に 126.6 の operator 採択を挟む)
  理由: 126.7 DoD (d) の PR closeout に必要
  scope: Phase 126 / Task 126.7
  承認: approved (2026-07-27 operator、AskUserQuestion 一括確認)
- secret-read: なし (テストは mktemp fixture のみ)
- destructive: なし

---

## Phase 127: BSD 非互換 mktemp テンプレートの一掃 (operator 承認 2026-07-30) [P2]

Purpose: BSD (macOS) の `mktemp` は X が**末尾にある場合しか置換しない**。`mktemp /tmp/foo-XXXXXX.json` のように拡張子が続く形式は乱数化されず、テンプレートそのままの literal path を返してそのファイルを作る (実測 2026-07-30: `mktemp /tmp/zz6-XXXXXX.json` → `/tmp/zz6-XXXXXX.json`)。GNU (Linux/CI) は末尾以外の X も置換するため **CI では一切再現せず、macOS ローカル限定**の障害になる。実害は Phase 126 直後に顕在化した: `scripts/hook-handlers/posttool-progress-regen.sh` が同形式を使っており、2026-07-27 から残っていた `/tmp/progress-snap-XXXX.json` により mktemp が EEXIST で失敗し続け、hook が `regenerated:true` を返しながら HTML も state file も更新しない状態が 3 日間継続していた (`test-progress-regen.sh` / `test-progress-e2e.sh` の計 4 assertion が失敗。Phase 126.7 が「本 Phase を含まないベースでも失敗する既存分 2 件」と記録したものの正体)。この 1 件は commit c856ecec で修正済み。本 Phase は残る 9 箇所 (全域を厳密走査した確定値。すべて `tests/` 配下で `scripts/` `hooks/` `go/` には無い) を同形式へ統一し、再発を機械検査で止める。

現時点で `/tmp` に残骸は 0 件のため 9 箇所とも緑だが、潜在障害が 2 つ残る。(1) `tests/test-accept-record.sh` / `tests/test-harness-accept.sh` は trap 後始末が無く、中断で残骸を残す = 以降永久に赤化する (progress-regen で実証済みの経路)。(2) literal path は一意性が無いため、並行実行時に同一 path を掴んで相互汚染する。

lint baseline: `tests/test-shell-lint.sh` (shellcheck `--severity=error` の高リスク subset) が存在するが、対象 6 ファイルは subset 外であり、かつ **shellcheck はこの書式を検出しない**ことを実測確認済み (probe `mktemp /tmp/foo-XXXXXX.json` に対し findings ゼロ)。したがって shellcheck への委譲は不可で、専用の検出 gate が必要。

team_validation_mode: manual-pass (サブエージェント未使用 — 本セッションは AgentTool を明示要求時のみ使う運用のため。Product / Architecture / Security / QA / Skeptic の 5 観点を単独で分けて評価済み。Security: assertion の削除・弱体化はゼロで、非一意 temp path を塞ぐのは安全側。Skeptic: 「現在全部緑なら不要では」に対しては上記 (1)(2) が反証となる)。Spec skip reason: shell の可搬性 bugfix であり、ユーザーに見える振る舞い・API・データモデル・権限・課金・外部連携のいずれも変えない。root `spec.md` に一時ファイル生成の規約は無い (実測: `mktemp` / 一時ファイル の記載ゼロ)。unknown_data: なし (9 箇所と検出ロジックを実測で確定済み)。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 127.1 | `[lane:gate]` `[tdd:required]` 検出 gate 先行 + 9 箇所の統一。(i) `tests/validate-plugin.sh` に「mktemp テンプレートの X が末尾でない箇所」を `scripts/` `tests/` `hooks/` `go/` 全域で検出する gate を追加 (`.claude/rules/workflow-test-wiring.md` 準拠 = 配線の正本は validate-plugin.sh、`.github/workflows/` は触らない)。(ii) 検出された 9 箇所を末尾 X 形式へ統一。既存の主流書式に合わせ `"${TMPDIR:-/tmp}/<name>.XXXXXX"` を使う (repo 内 59 箇所が TMPDIR 参照)。拡張子は 9 箇所とも消費側が path としてしか使わないため落としてよい (実測確認済み)。消費側が拡張子を要求する箇所が見つかった場合のみ `mktemp -d` + ディレクトリ内の固定名ファイルへ置換する。(iii) trap 後始末が無い `tests/test-accept-record.sh` / `tests/test-harness-accept.sh` に後始末を追加する | (a) RED: gate 追加直後に 9 件を検出して fail する実測記録 (件数と file:line を引用), (b) 9 箇所修正後に gate が green かつ検出 0 件, (c) 対照実験: 修正前テンプレートの literal path を `/tmp` に置いた状態で対象 6 ファイルの test が全て通ることを実測 (progress-regen で使った手法と同じ), (d) 既存 assertion の削除・弱体化ゼロ (差分は追加と 1 行置換のみであることを diff で提示), (e) `bash tests/validate-plugin.sh` 0 failed (floor 免除 env を export したまま実行), (f) `bash scripts/ci/check-consistency.sh` 全パス | - | cc:done [e28076a9; RED 実測「9 件検出して exit 1」→ 修正後 検出 0 件。対照実験で旧 literal path を一時領域に置くと、ベース版は `mktemp: mkstemp failed on /tmp/plan-brief-test-XXXXXX.html: File exists` で停止し修正版は通過 (バグの再現と解消を両方実測)。削除 9 行はすべて mktemp 行でアサーションの弱体化ゼロ。validate-plugin 129 pass / 0 fail (floor 免除 env を外さず実行)、check-consistency 全 24 通過。独立 reviewer APPROVE (critical/major 0、消費側 9 箇所の拡張子非依存を独立に再確認)。Worker が API 529 で中断 + worktree の base が古かったため Lead が正味差分のみ取り込んで検証を完走。副産物: test-harness-accept.sh / test-harness-plan-brief.sh が `user-invocable: true` を期待するが実 SKILL.md は false という既存乖離を発見 (両 test は validate-plugin.sh 未配線。本 Phase 範囲外のため未修正)] |
| 127.2 | `[lane:release]` `[tdd:skip:verification]` 検証 + closeout: CHANGELOG `[Unreleased]` の Fixed へ追記 (macOS 限定の非一意 temp path と、再発を止める検査の追加)、skill mirror in-sync 確認、PR closeout。`go/` の変更は無い見込みのため binary rebuild は不要 (変更が入った場合のみ 4-platform 再生成 + drift gate) | (a) CHANGELOG `[Unreleased]` に before/after が読めるエントリ, (b) `bash tests/validate-plugin.sh` 0 failed + `bash scripts/ci/check-consistency.sh` 全パス, (c) VERSION / `.claude-plugin/plugin.json` / `harness.toml` が未変更であることを `git diff --name-only` で確認, (d) PR closeout (事前承認済み: push + PR 作成 + CI green 確認 + merge) | 127.1 | cc:done [325b1e46 (PR #279 merged to main, 94d19f2e); CHANGELOG [Unreleased] Fixed に Phase 127 エントリを before/after 付きで追記。VERSION / plugin.json / harness.toml 非接触を git diff で確認、go/ 未変更のため 4-platform rebuild 不要、skill mirror in-sync (codex/opencode)。必須 CI 8 件すべて pass (validate / test-go / CodeQL / actionlint / 4-platform build)。merge 後の main 上で検出テストが green を再確認。CodeRabbit は必須外のため待たず merge] |

| 127.3 | `[lane:gate]` `[tdd:required]` 127.1 の副産物として発見した既存乖離の解消: 3 surface skill (`harness-plan-brief` / `harness-progress` / `harness-accept`) の frontmatter が `user-invocable: false` だが、`docs/cognitive-load-surfaces.md` は 3 つとも `/harness-<name>` を発注者が打つコマンドとして記載し、3 つとも `argument-hint` を持つ。`test-harness-plan-brief.sh` / `test-harness-accept.sh` は `user-invocable: true` を要求しており、SKILL.md と同一 commit (b523dee1 / e62c7027) で生まれた自己矛盾。両 test が `validate-plugin.sh` 未配線だったため約 2 ヶ月検知されなかった。frontmatter を `true` へ揃え、2 test を配線し、`harness-progress` には同 pin を test に追加する | (a) RED: 2 test の配線直後に各 1 件 (`user-invocable: true` missing) で fail する実測、progress は pin 追加直後に fail する実測, (b) 修正後 3 test すべて green, (c) Cursor 配布は `user-invocable: true` を `false` へ正規化する契約 (`build-host-plugin-dist.sh`) を壊さないことを `test-host-plugin-dist.sh` / `test-cursor-adapter-candidate.sh` で実測, (d) skill mirror 再同期して in-sync, (e) `bash tests/validate-plugin.sh` 0 failed, (f) `bash scripts/ci/check-consistency.sh` 全パス | 127.1 | cc:done [RED 実測: plan-brief PASS=31 FAIL=1 / accept PASS=65 FAIL=1 (いずれも原因は `user-invocable: true` missing の 1 件のみ)、progress は pin 追加直後に exit 1。修正後は plan-brief 32/0、accept 66/0、progress 0 fail。配布層は test-host-plugin-dist / test-cursor-adapter-candidate ともに PASS で Cursor 正規化 (正規表現による全ファイル置換、固定リストではない) が機能。mirror 再同期して in-sync (codex/opencode)。validate-plugin 131 pass / 0 fail (129 → 131 は新規配線 2 件分)、check-consistency 全 24 通過。削除は 6 行すべて `user-invocable: false` (本体 3 + mirror 3)、アサーションは 10 行追加のみで弱体化ゼロ。`agent-browser` も false + argument-hint だが slash 文書化がなく programmatic 呼び出し専用のため対象外と裁定] |

事前確認 (plan-time pre-approval):
- 事項: external-send — `git push origin <branch>` + `gh pr create` + CI green 確認 + `gh pr merge --merge` (完全自動)
  理由: 127.2 DoD (d) / 127.3 の PR closeout に必要
  scope: Phase 127 / Task 127.2, 127.3
  承認: approved (2026-07-30 operator、「両方Yes」+ 127.3 は「検証して解決して」)
- secret-read: なし
- destructive: なし (対照実験は `/tmp` 配下に fixture を置いて消すのみ。作業ツリー外への破壊操作は含まない)
