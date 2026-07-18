# Cross-Repo Handoff Workflow (claude-code-harness ↔ harness-mem)

claude-code-harness と sibling repo `harness-mem` の間で発生する責任境界の調整・契約変更・実装移管を、再現可能な形で記録する SSOT。

本文書は decisions.md D42 (`claude-code-harness ↔ harness-mem 責任境界 + Cross-repo Handoff Workflow`) の codifiable な policy 部分を抽出したもの。decisions.md は per-developer の local SSOT (gitignore 対象) であるため、共有が必要な policy は本ファイルに置く。

## なぜこのルールが必要か

claude-code-harness Phase 65 Phase A 完走時のレビューで、ユーザーから「本来 harness-mem 側に実装するべきものを claude-code-harness 側で実装していたら、(i) claude-code-harness から除外し、(ii) harness-mem 側に分かりやすく Issue を上げる」運用期待が示された。

実態は (i) は完了済み (Phase 60 の managed companion 化、Phase 63 の dead default 整理) だが、(ii) は GitHub Issue ではなく harness-mem repo の `Plans.md §NNN` という sibling-repo Plans SSOT 方式で運用されていた。GitHub Issue は #70 (Phase 49.1.2 follow-up) の 1 件のみ。

ユーザー期待 (GitHub Issue) と運用実態 (Plans.md SSOT) の差分は「ポリシー未文書化」が原因。本ルールで正式運用として固定し、再発を防ぐ。

## 3 層 Redaction の責任境界 (Phase 65 cross-project safety)

| Layer | 内容 | 実装層 | 理由 |
|---|---|---|---|
| Layer 1 | privacy filter (`<private>` strip) + project scope (`strict_project: true`) | **harness-mem server 側** | mem の出口で全 client (CC / Codex / opencode) を一律ガード。`include_private=false` default |
| Layer 2a | 辞書ベース固有名詞 redaction (`client-redaction.yaml`) | **claude-code-harness client 側** | project-local config の解釈は presentation layer の責任。server に schema 解釈を持たせると企業ごと redaction policy が server 設定面に漏れる |
| Layer 2b | NER (kuromoji 等の Japanese tokenizer) | **claude-code-harness client 側** | server 依存膨張回避: ONNX embedding (multilingual-e5) が既に重く、JP tokenizer 追加は cold start (~5ms) と memory footprint を毀損 |
| Layer 3 | HTML 生成直前最終 scan | **claude-code-harness client 側** | render-html.sh は client にしかない (rendering pipeline 上にしか置けない) |

将来 server 側 PII redaction フラグを希望する場合は `redact_profile` パラメータの opt-in 設計として harness-mem 側 §111 以降で再検討の余地あり。

### Phase 65.3 実装決定事項 (D43)

Phase 65.3 着手前の mem 側との coordination で確定した実装制約:

| 制約 | 内容 | 根拠 |
|---|---|---|
| MCP cross-project は N-call | `mcp__harness__harness_mem_search` の MCP schema は `project: string` 単一値のみ exposed (`projects: [array]` も `strict_project: boolean` も MCP には無い)。cross-project 検索は client が member ごとに 1 回ずつ MCP call し、結果を client 側でマージ・dedupe する | mem 側 mcp-server schema 確認 (`mcp-server/src/tools/memory.ts:297-341`) |
| client-redaction.yaml は PiiRule 互換 | client 側 dict schema (`client-redaction.v1`) は mem 側既存 `pii-filter.ts` の `PiiRule[]` schema と field 名を互換にする (`rule_id`, `pattern`, `replace_with` 等)。完全共通化 (npm package) は将来 follow-up | 重複実装回避 + Cross-client 一貫性節への upgrade path 確保 |
| `[REDACTED_*]` 二重置換ガード | server 側 `event-recorder.ts:redactContent` が email / API key / hex を `[REDACTED_*]` に置換済み。client Layer 2 redact は既存 mark を**再置換しない** sentinel ガードを必須 | 二重置換による情報破損防止 |
| applied_filters 注記方針 | mem 側 `applied_filters` meta は未実装 (内部 audit のみ)。Phase 65.3.6 audit log は Layer 2/3 (client) のみ記録し、Layer 1 (server) は「server default + 内部 audit に依存」と明示注記 | mem 側未実装を確認、今フェーズ blocking ではない |

将来 cross-project N-call のレイテンシが実運用で問題化したら **XR-005** (MCP schema に `projects: [array]` + `strict_project: boolean` 追加) として harness-mem §111 で起票する。

### Phase 65.3 完走報告 (2026-05-09)

Phase C 7 タスクは 1 セッション内で完走、Cross-Contract 変更ゼロで claude-code-harness 内に完結。

| Phase | task | commit | 主要成果物 | テスト |
|---|---|---|---|---|
| C-1 | 65.3.1 | `4a014137` | `.claude/rules/cross-project-groups.yaml` SSOT + `scripts/load-cross-project-groups.sh` (yaml → JSON validator) + `docs/cross-project-groups-schema.md` | 21 PASS |
| C-2 | 65.3.2 | `5152bed2` | `.claude/rules/client-redaction.yaml` (PiiRule 互換 schema) + `scripts/redact-by-dictionary.sh` Layer 2a + 二重置換ガード | 26 PASS |
| C-3 | 65.3.3 | `20a4478f` | `scripts/redact-by-ner.sh` Layer 2b (fugashi tokenizer + fail-open) | 22 PASS |
| C-4 | 65.3.4 | `0ae3f40a` | `scripts/render-html.sh --with-redaction` Layer 3 final scan + `scripts/final-scan-redaction.py` | 16 PASS |
| C-5 | 65.3.5 | `09377eb9` | `harness-plan-brief` / `harness-accept` SKILL.md に `--cross-project-group <name>` flag opt-in (D43 Option α: MCP N-call) | 18 PASS |
| C-6 | 65.3.6 | `272a8f33` | `cross-project-audit.v1` audit log + `scripts/cross-project-audit-log.sh` + HTML 監査サマリ表示 | 21 PASS |
| C-7 | 65.3.7 | `c05d6ef8` | e2e validation (3-member group + 全層通し + envelope + sentinel guard) | 21 PASS |

**累計**: 7 feat commit + 7 chore commit = 14 commit、145 assertion 全 PASS、`./tests/validate-plugin.sh` は 51 → 58 (+7)、`bash scripts/ci/check-consistency.sh` 全合格。

D43 4 判断パッケージは全て初期設計どおり機能し、想定外の制約や手戻りは発生しなかった。

**未起票 follow-up trigger 一覧** (発動条件達成時のみ harness-mem §111 で起票):
- XR-005: MCP schema に `projects: [array]` + `strict_project: boolean` 追加 — N-call レイテンシが実運用で問題化したら
- (旧仮称 §110-S110-006): `applied_filters` meta 実装 — client から server-side filter 適用を可視化する需要が出たら ※実 §110 S110-006 は本 Phase C closure record として消費済 (下記)
- PiiRule 共通化 npm package: Cross-client 一貫性が真に必要になったら (mem 側 PiiRule schema reference は下記参照)

### Phase 65.3 closure ack (harness-mem 側受領、2026-05-10)

harness-mem セッションが Phase C 完走報告を **§110 内 S110-006** として
受領 (Cross-Contract 変更ゼロを確認)。新 §111 は不要、§110 配下に統合
される SSOT 運用方針となった。

| 項目 | mem 側 commit | 内容 |
|---|---|---|
| content commit | `8b34ecb` | S110-006 Phase C closure record + 6 invariant 衝突 review (0 件) + PiiRule reference 一覧 |
| hash backfill | `ad4ba56` | S110-006 cc:完了 [8b34ecb] |
| (任意 follow-up) | (S110-007 候補) | envelope contract に「signals に PII を含めない」を documentation 化 — mem 側で受ける範囲、claude-code-harness 側起票不要 |

**6 invariant 衝突 review 結果** (mem 側で確認、衝突 0 件):
- `<private>` strip / Layer 2/3 重複: 衝突なし (server 削除後は client から見えない設計)
- `[REDACTED_*]` sentinel format: 衝突なし (mem 側は大文字 `EMAIL` / `KEY` / `SECRET` / `HEX`、client 側 regex `[A-Za-z0-9_]+` で両対応)
- envelope `validateProseContainsSignals`: 実用上衝突なし (S110-007 候補で envelope contract 側を documentation 化、claude-code-harness 側 client-redaction.yaml に防御的注記追加で対応)
- cross-project N-call rate limit: 衝突なし (mem 側 rate limit 設定なし、N=5-10 想定で問題なし)
- Cross-project privacy tag merge: 衝突なし (server は project ごと独立 filter、merge は client 責務)
- audit log structure: 衝突なし (Phase 65.3.6 client 側完結)

### PiiRule schema 公式参照 (mem 側 commit `8b34ecb` 共有、npm package 化起票時の参照点)

`mcp-server/src/pii/pii-filter.ts` の PiiRule 仕様 (将来 npm package 化を起票する際の参照点として固定):

| 種別 | パス | 内容 |
|---|---|---|
| TS SoT | `mcp-server/src/pii/pii-filter.ts:15-20` | `interface PiiRule { name: string; pattern: string; replacement: string }` |
| TS SoT | `mcp-server/src/pii/pii-filter.ts:22-24` | `interface PiiRulesFile { rules?: PiiRule[] }` |
| 関数 export | `mcp-server/src/pii/pii-filter.ts:33, 50, 69-85, 92` | `applyPiiFilter` / `loadPiiRules` / `DEFAULT_PII_RULES` / `getActivePiiRules` |
| .d.ts | `mcp-server/dist/pii/pii-filter.d.ts:1-6` | コンパイル版宣言 |
| 環境変数 | `docs/environment-variables.md:102-111, 302-303` | `HARNESS_MEM_PII_FILTER` / `HARNESS_MEM_PII_RULES_PATH` |
| 公式仕様 doc | `docs/specs/vps-team-deploy-spec.md:57, 260-285` | TEAM-006 PII フィルタリング (例 JSON は `:270-275` インライン) |
| Contract test | `mcp-server/tests/unit/pii-filter.test.ts:1-56` | 5 ケース (phone JP / email / LINE_ID / 複合 / 空ルール) |
| Usage 例 | `mcp-server/src/tools/memory.ts:13, 1067-1068` | `record_checkpoint` 内適用 |

**重要 caveat**: README / OpenAPI には PiiRule component schema なし、JSON Schema として独立 export なし。
npm package 化を起票する際は **schema export と公式 doc 整備を同時にスコープ化** すること (mem 側勧告)。

### Cross-client 一貫性の担保方針

「Codex 等の他 client から呼ばれた時にも redact が効く」要件は **client 側で shared library (npm package or sub-module) を共通化** する方針で対応する。server 側 MCP API 出口で redact しない理由:

- 将来の team sharing (`harness_mem_share_to_team`) で「正しい原文を返す」契約が破れ、可逆性を失う
- server を「presentation policy free」に保つことで、client diversity (CC / Codex / opencode / 将来の third-party client) を阻害しない

代わりに harness-mem は `mcp__harness__harness_mem_search` の response meta に `applied_filters` (例: `privacy_filter` / `project_scope`) を含める拡張を必要に応じて提供する (harness-mem §110 follow-up または §111 で起票)。

## XR-Registry の廃止（operator 裁定 2026-07-16）

管理 repo `harness-governance-private` の XR-Registry.md は **2026-07-16 に廃止**が裁定された
（同 repo の `.git` 破損発見を契機に、backup 整備ではなく廃止を選択）。以後:

- cross-repo 起票は**経路 A（harness-mem `Plans.md §NNN`）に一本化**する。XR 番号の新規採番はしない
- 既存の XR-000〜XR-005 の記録ファイルは歴史記録として残る（新規参照はしない）
- claude-code-harness ↔ harness-mem の連携は頻度が高い。handoff の宛先・DoD・evidence は
  常に harness-mem 側 Plans.md に置き、本ルールの経路 A 手順に従う

## Cross-repo Handoff の 2 経路

claude-code-harness ↔ harness-mem の handoff は以下の 2 経路を使い分ける。

### 経路 A: harness-mem repo の `Plans.md §NNN` (sibling-repo Plans SSOT)

**用途**: Cross-Contract changes (詳細 DoD が必要、複数セッションで参照される handoff)

**例**:
- §106 (companion contract handoff、Phase 60 で起票、cc:完了)
- §107 (checkpoint cold-start handoff、cc:完了)
- §110 (Cross-repo Handoff Workflow Codification、本ルールの相対側、harness-mem 側で codification 完了)

**手順**:
1. claude-code-harness 側で「mem 側に implementation を移すべき」と判断したら、Plans.md に section を追加 (例: §111)
2. section 内に必要な DoD を箇条書き (受け入れ条件、技術制約、参照すべき claude-code-harness 側 commit hash)
3. claude-code-harness 側の関連箇所 (skills/scripts/docs) を **同一 PR で除外** (Phase 60 の `1f4d9133`, `5373d50d` パターン)
4. 必要なら本ルール `.claude/rules/cross-repo-handoff.md` の表に新行を追加

### 経路 B: GitHub Issue

**用途**: Cross-Runtime long-running follow-ups (複数セッション・複数 PR に跨る検討、外部参加者への露出が必要なもの)

**例**: harness-mem #70 (Phase 49.1.2 follow-up)

**手順**:
1. `gh issue create --repo Chachamaru127/harness-mem --title "..." --body "..."` で起票
2. claude-code-harness 側からは関連箇所に `# See harness-mem#NN` のコメントだけ残す (実装はしない)
3. harness-mem 側で issue が close されたら、claude-code-harness 側で本ルールの参照を更新

## 判断軸 (どちらを使うか)

| 観点 | A: Plans.md §NNN | B: GitHub Issue |
|---|---|---|
| 詳細 DoD が必要か | ✓ 詳細 DoD を書ける | △ Issue body は流動的 |
| 複数セッションで参照されるか | ✓ Plans.md は永続 SSOT | △ Issue は時間経過で読みにくい |
| 外部参加者への露出が必要か | △ repo collaborator のみ | ✓ public repo なら外部から見える |
| 実害がない closeout-only か | ✓ 軽量 | △ Issue を立てると closeout 工数が発生 |
| long-running cross-runtime か | △ Plans.md は cross-runtime 向き弱い | ✓ Issue が適切 |

迷ったら **経路 A (Plans.md §NNN)** を default とする。理由: 過去 4 件の handoff のうち 3 件 (Phase 60, 63, 65) が Plans.md SSOT で完了しており、運用実績がある。GitHub Issue は #70 1 件のみ。

## 過去の境界調整実績 (retroactive 起票しない)

以下の過去 handoff は **本ルールで「Plans.md §NNN は GitHub Issue と等価」と確定した**ため、retroactive な GitHub Issue 起票はしない:

- Phase 60 (managed companion 化) — harness-mem Plans.md §106
- Phase 63 (dead default 整理) — harness-mem Plans.md §107
- Phase 65.3 (3 層 redaction の owner 確認) — 本ルール表 + harness-mem Plans.md §110

将来の境界変更時は本ルールの 2 経路から選択する。

## 関連

- claude-code-harness `.claude/memory/decisions.md` D42 (本ルールの local SSOT 元、gitignore 対象)
- claude-code-harness `.claude/rules/migration-policy.md` (Phase 60 削除済み概念の handoff 記録手順)
- harness-mem `docs/claude-harness-companion-contract.md:84-96` (Cross-repo Handoff Workflow セクション、harness-mem 側相対)
- harness-mem `.claude/memory/patterns.md:230` (P7 Non-Application Conditions に Plans.md SSOT 例外追記)
- harness-mem Plans.md §110 (Cross-repo Handoff Workflow Codification、本ルールの相対側)

## 見直し条件

- **Trigger A**: server 側で PII redaction を opt-in 提供する API (例: `redact_profile` parameter) が harness-mem §111+ で実装された時 — Layer 2 の owner を再検討
- **Trigger B**: cross-client 一貫性のための shared library が npm 化された時 — Cross-client 一貫性節を更新
- **Trigger C**: harness-mem `mcp__harness__harness_mem_search` の response meta に `applied_filters` が追加された時 — Layer 1 検証経路を更新
