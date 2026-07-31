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

---

## Phase 128: hard floor の実バイパス 2 件を塞ぐ (PR #246 レビューの副産物、operator 承認 2026-07-30) [P0]

Purpose: 外部 PR #246 のセキュリティレビュー中に、**現在の main に実在するフロア回避経路 2 件**を発見し、いずれも実測で確認した。#246 の採否とは独立に、単独で修正すべき最優先事項として起票する。

**回避経路 A — AI が自力で secret-read hard floor を外せる (P0)**。3 段の実測がすべて成立している。(1) `.claude-code-harness.config.json` は deny リストに無く AI が書ける (`.claude-plugin/settings.json` の deny 22 件を機械確認、`claude-code-harness.config` のヒット 0 件。hook 実測でも Write 判定は「判定なし = 通る」)。(2) `configSecretAllowPatterns` (`go/internal/runtimefloor/runtimefloor.go:340-361`) は**絶対パス宣言にだけ** `pathUnderWorktree` 境界チェックがあり、**相対パス宣言には無い** (`out = append(out, filepath.Join(rootAbs, filepath.Clean(p)))`)。(3) Go でパス計算を実測: `../outside/a` → `/Users/op/outside/a`、`../../../../etc/a` → `/etc/a` と作業ツリー外へ出る。したがって AI が `{"runtimefloor":{"secretAllow":["../../../../etc/shadow"]}}` を自分で書けば、spec.md が「いかなる設定・環境変数・permission mode でも上書きできない」と定める secret-read フロアを自力で無効化できる。

**回避経路 B — main への強制 push が確認をすり抜ける (P1)**。`protectedBranchRefPattern` が force refspec の先頭 `+` を剥がさないため、トークン `+main` がパターンに一致しない。hook 実測: `git push origin main` → `ask`、`git push origin +main` → **判定なし (素通り)**、`git push origin +refs/heads/main` → **判定なし**。R06 の `--force` フラグ検出は別ロジックのためこの短縮形を拾わない。

**A の修正は 2 層必要**。境界チェック (128.1) だけでは、宣言を作業ツリー内に丸めるだけで「AI が自分で `.env` を宣言して読む」経路が残る。設定ファイル自体を保護面に載せる (128.3) ことで、フロアを広げる操作に人間を戻す。128.3 は `go/internal/policy/helpers.go` の `protectedPathRules` を触るため Constitution 条項 (spec.md: `rules.go` は untouchable class / human-only) に該当し、Phase 112.19 / 126.6 と同じ operator explicit adoption ゲート (128.4) を置く。

Spec delta: `spec.md` の runtime floor 節へ「project config 由来の secretAllow 宣言は絶対 / 相対を問わず worktree 境界内に制限される」を追記し、protected path 節へ `.claude-code-harness.config.json` を追加 (128.1 / 128.3 の DoD)。128.2 は文書化済み契約 (protected branch への直接 push は ask) の実装追随なので Spec skip reason: bugfix、product contract の追加なし。

team_validation_mode: subagent (PR #246 のセキュリティレビューを独立 reviewer が実施し、その findings を Lead が全件実測で再検証。Security = 3 段の回避経路を hook 実測とパス計算で確認 / Architecture = 修正層を floor・policy・deny リストの 3 択から評価し 2 層構成を選択 / QA = 対照実験を DoD 化 / Skeptic = 「相対パス宣言は実害があるのか」に対し `/etc/a` への到達を実測して反証 / Product = 配布ユーザーへの影響は締める方向のみ)。unknown_data: `.claude-code-harness.config.json` を `deny` にするか `ask` にするかは実装時に両方を実測して決める (現時点では deny 推奨。理由は `.claude/settings*` と同格の扱いで、operator の手動編集は常に可能なため)。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 128.1 | `[lane:gate]` `[tdd:required]` `[security]` **回避経路 A の核**: `configSecretAllowPatterns` の相対パス分岐に、絶対パス分岐と同じ `pathUnderWorktree` 境界チェックを追加する。`filepath.Join` 後の解決済みパスで判定し、作業ツリー外に出る宣言は `continue` で捨てる (fail-safe = 宣言を無視、全 deny は維持)。symlink 経由の迂回も塞ぐか実装時に評価する | (a) RED 実測: 相対宣言 `../<name>` が作業ツリー外の絶対パスとして許可リストに載ることを現行実装で確認し、解決後パスを引用, (b) 修正後は同じ宣言が捨てられ、当該パスの読取が deny に戻ることを hook 実測で確認, (c) 作業ツリー**内**の相対宣言 (`secrets/x`) は従来どおり許可される非退行 test, (d) 絶対パス宣言の既存挙動 (境界内は許可 / 外は無視) の非退行 test, (e) `cd go && go test ./internal/runtimefloor/...` PASS (floor 免除 env を export したまま。c856ecec で TestMain が自前 unset するため), (f) Spec delta: runtime floor 節へ境界制限を追記 | - | cc:done [7702ca45; RED 実測: 相対宣言 `../<name>` が worktree 外の絶対パスとして許可リストに載ることを確認 (パス計算で `../../../../etc/a` → `/etc/a`)。両分岐を解決後パスで境界判定するよう統一し、symlink 迂回も `secretAllowSymlinkStaysInWorktree` で塞いだ。**Lead レビューで 1 度差し戻し**: 初版は許可リストに解決後の実体パスを保存しており、(i) 宣言したパスが自分の宣言に一致しなくなる退行と (ii) 宣言していない実体パスが許可される緩和が同時に発生していた。Lead が probe で両方を実測 (`declared -> allowed=false` / `undeclared target -> allowed=true`) して差し戻し、修正後は同じ probe で `declared=true` / `undeclared=false` を確認。symlink 解決は pass/deny 判定にのみ使い、許可リストには宣言由来のパスを保存する形に是正。副産物として macOS の `/var` → `/private/var` symlink により root 側も解決しないと既存宣言が全て誤 deny される問題も修正。config 系 7 test 全 PASS (symlink 3 ケース新規)。spec.md は元から「相対パスはプロジェクトルート配下に解決」と書いており、新制約の追加ではなく仕様どおりへの是正] |
| 128.2 | `[lane:gate]` `[tdd:required]` `[security]` **回避経路 B**: protected branch 判定でトークン先頭の force refspec `+` を剥がしてから照合する。`normalizeGitToken` を拡張するか照合前に `strings.TrimPrefix(t, "+")` を入れるかは実装時に選ぶ。R11 (`git reset --hard`) 側と R12 (直接 push) 側の両方に効かせる | (a) RED 実測: `git push origin +main` / `+refs/heads/main` が現行実装で「判定なし (素通り)」になることを hook 実測で確認, (b) 修正後は両者が `ask` になり、`git push origin main` の既存 `ask` も変わらない, (c) `+` を含むが保護対象でない refspec (`+feature/x`) は従来どおり素通りする非退行 test, (d) R11 側でも `git reset --hard +main` 相当の扱いを確認, (e) `cd go && go test ./internal/policy/...` PASS | - | cc:done [7702ca45; RED 実測 (hook): `git push origin +main` / `+refs/heads/main` がいずれも「判定なし = 素通り」。`normalizeGitToken` で先頭 `+` を除去し、修正後は両者 ask、`git push origin main` の既存 ask は不変、保護外の `+feature/x` は素通り維持を実測。R11 (`git reset --hard +main`) も同時に deny 化。実装 8 行 + テスト 50 行] |
| 128.3 | `[lane:gate]` `[tdd:required]` `[security]` **回避経路 A の 2 層目**: `.claude-code-harness.config.json` (と `.yaml` 変種) を `protectedPathRules` に追加し、Write/Edit を人間の判断に戻す。この 1 ファイルが `runtimefloor.secretAllow` を通じて hard floor の適用範囲を決めるため、AI が自由に書ける状態は floor の非上書き契約と両立しない。`deny` と `ask` の両方を実測し、`.claude/settings*` と同格の `deny` を既定とする (operator の手動編集は常に可能。`releaseAuto` の切替が手動になる UX コストは受容する) | (a) RED 実測: 現行実装で当該ファイルへの Write が「判定なし = 通る」ことを hook 実測で確認 (deny 22 件に不在であることも引用), (b) 修正後は deny (または裁定した水準) になることを hook 実測で確認, (c) 同ディレクトリの無関係ファイルが巻き込まれない非退行 test, (d) `deny` / `ask` 両案の実測結果を比較して選択理由を 1 行残す, (e) `cd go && go test ./internal/policy/...` PASS, (f) Spec delta: protected path 節へ追記 | 128.1 | cc:done [7702ca45; RED 実測 (hook): `.claude-code-harness.config.json` への Write が「判定なし = 通る」(deny 22 件に不在も grep で確認)。`protectedPathRules` に deny レベルで追加し、修正後は .json / .yaml とも deny、雛形 `claude-code-harness.config.example.json` と `README.md` は誤爆せず通ることを実測。**deny を選んだ根拠は実測**: `ask` に降格すると selfaudit の deny surface に含まれないため将来の削除を機械検知できない (Worker が両案を実測して発見)。selfaudit.go は R02/R03 の baseline hash 2 行のみ更新 (deny 追加に伴う機械的更新)] |
| 128.4 | `[lane:gate]` `[tdd:skip:human-adoption-gate]` operator 明示採択 (Phase 112.19 / 126.6 型): 128.1-128.3 が変更した `go/internal/policy/helpers.go` / `go/internal/runtimefloor/runtimefloor.go` の diff を operator が review し明示 adopt する。Constitution 条項 (untouchable class は human-only) の充足。今回の変更はすべて**締める方向**のみで、deny/ask を緩める箇所はゼロであることを差分で提示する | (a) operator の採択記録 (日時 + 対象 commit SHA) を本 task の Status に記載, (b) 「緩める変更ゼロ」を `git diff` で機械的に示した根拠を併記 | 128.1, 128.2, 128.3 | cc:done [operator explicitly adopted 2026-07-31; 対象 commit 7702ca45。変更は go/internal/policy/helpers.go (+17) / selfaudit.go (+4-2) / runtimefloor.go (+59) / test 2 ファイル (+225) / spec.md (+27)。**緩める変更ゼロの機械的根拠**: go/ 全体の削除は 4 行のみで、内訳は (1) token 正規化を `+` 除去付きへ置換 (より厳しく)、(2) 相対パス append を境界チェック付きへ置換 (より厳しく)、(3)(4) deny パターン追加に伴う R02/R03 baseline hash の機械的更新。deny/ask ルールの削除・弱体化はゼロ。selfaudit.go への接触は Phase 126 では無かったが、hash を更新しないと hook が「deny surface 変更」として判定自体を拒否するため機械的に必須。spec.md は元から「相対パスはプロジェクトルート配下に解決」と記載しており、新制約の追加ではなく仕様どおりへの是正。operator へは差分統計・削除行全列挙・hook 実測表・検証結果を提示のうえ採択を得た] |
| 128.5 | `[lane:release]` `[tdd:skip:verification]` 検証 + 配布物 + closeout: `go/scripts/build-all.sh` で 4-platform binary 再生成 (`bin/harness` は shim のため `-o bin/harness` 禁止)、`scripts/ci/check-binary-source-drift.sh` ローカル green、新 test を `tests/validate-plugin.sh` へ配線、CHANGELOG `[Unreleased]` に Security 節として追記 (回避経路と塞ぎ方を before/after で) | (a) `bash tests/validate-plugin.sh` 0 failed (floor 免除 env を export したまま), (b) drift gate green, (c) `bash scripts/ci/check-consistency.sh` 全パス, (d) VERSION / `.claude-plugin/plugin.json` / `harness.toml` 非接触を `git diff --name-only` で確認, (e) PR closeout (事前承認済み: push + PR 作成 + CI green 確認 + merge。merge 前に 128.4 の採択を確認) | 128.4 | cc:done [476ea403 (PR #282 merged to main, 1f085a35); CHANGELOG [Unreleased] に Security 節を新設し 2 経路を before/after + 実測表で記述。VERSION / plugin.json / harness.toml 非接触を git diff で確認、4-platform 再ビルド + drift gate OK、skill mirror in-sync。必須 CI 8 件すべて pass (validate / test-go / CodeQL / actionlint / 4-platform build)。merge 後の main 上で `+main` → ask / `+feature/x` → 素通り / 設定ファイル書込 → deny を再実測] |
| 128.6 | `[lane:fast]` `[tdd:skip:no-code-change]` PR #246 の closeout: レビュー結論 (critical 3 件で as-is マージ不可、ただし問題提起は正当で脆弱性 2 件の発見に繋がった) を作者向けに説明してクローズする。採用した部分 (本 Phase の 2 件) と、再実装に回した部分 (`paths.protected` / R16、`git.protected_branches` 加算)、見送った部分 (`allow_rm_rf`) を切り分けて伝える。rebase 依頼はしない (117 commit 差 + Phase 126 が R05/R12 のコア実装を書き換えており、こちらで再実装する方が速く安全) | (a) #246 に日本語でなく英語のコメント (作者は英語話者) で 3 分類を明示, (b) 本 Phase の 2 件が #246 由来であることを明記して credit する, (c) #246 が CLOSED になる | 128.5 | cc:done [#246 を英語コメント付きでクローズ。3 分類を明示: (i) 採用済み = 脆弱性 2 件の修正を #282 で main へ (作者へ credit)、(ii) 再実装 = paths.protected / R16 と protected_branches 加算 (設計は妥当だが RuntimeFloorConfig への ReleaseAuto 追加と Phase 126 shellscan との調整が必要)、(iii) 保留 = allow_rm_rf (RemovalContextIndeterminate を壊さない再設計待ち)。closeout 理由も 3 点実測付きで提示: コンパイル不能 (hasDangerousFindDelete 等が存在しない) / 自 repo の releaseAuto が strict parser で弾かれ全 Write が deny 化 / CI 未生成のため binary 検証不能。rebase 依頼はしない旨と理由も明記] |

事前確認 (plan-time pre-approval):
- 事項: external-send — `git push origin <branch>` + `gh pr create` + CI green 確認 + `gh pr merge --squash`
  理由: 128.5 DoD (e) の PR closeout に必要
  scope: Phase 128 / Task 128.5
  承認: approved (2026-07-30 operator、`/harness-plan したあと /breezing`)
- 事項: external-send — `gh pr comment` + `gh pr close` (対象: PR #246)
  理由: 128.6 DoD (a)(c) の closeout に必要
  scope: Phase 128 / Task 128.6
  承認: approved (同上)
- secret-read: なし (回避経路の検証は fixture パスと hook 判定の観測のみで行い、実在する秘密ファイルは読まない)
- destructive: なし

対象外と裁定 (黙って落とさないための明示):
- **dependabot PR 9 件** (#276 #275 #274 #273 #272 #271 #264 #260 #241): 依存バージョン更新のみで本 Phase のセキュリティ修正と無関係。混ぜるとレビュー面が膨らみ、脆弱性修正の出荷が遅れる。本 Phase 完了後に別スコープでまとめて処理する
- **#246 の `paths.protected` / R16 再実装**: 設計は妥当だが、現行 main への載せ替えが必要で規模が大きい。先に脆弱性 2 件を出荷する方が価値が高い。Phase 129 以降で扱う
- **#246 の `allow_rm_rf`**: Phase 126 の `shellscan.RemovalContextIndeterminate` を壊さない再設計が必要。保留
