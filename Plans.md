# Claude Code Harness — Plans.md

最終アーカイブ: 2026-03-08（Phase 17〜24 → `.claude/memory/archive/Plans-2026-03-08-phase17-24.md`）

---

## Maintenance: PR58 pre-merge stabilization

作成日: 2026-03-11
目的: PR #58 の docs / CI / mirror 整合を修正し、merge 可否を再判定できる状態に戻す

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| M3 | Auto Mode ドキュメント誤記、README/CHANGELOG の版ズレ、validate-plugin の baseline 破綻、opencode mirror ドリフトを修正する | `validate-plugin.sh` / `check-consistency.sh` / `node scripts/build-opencode.js` / `core` テストが通り、PR #58 の残ブロッカーが整理されている | - | cc:完了 [cb625b12] |

---

## Maintenance: Claude-mem MCP 削除

作成日: 2026-03-08
目的: Claude-mem を MCP として接続する経路と、その前提ドキュメント/検証導線を repo から外す

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| M1 | Claude-mem MCP ラッパー・セットアップ/検証スクリプト・Cursor向け参照を削除し、残る文言を整合させる | `rg` で対象参照が実運用ファイルから消えている | - | cc:完了 |
| M2 | `harness-mem` を維持したまま、旧メモリ名称の user-facing 文言を live な setup/hook/skill から除去する | `rg` で対象参照が live 設定・主要スキルから消えている。内部互換パスは除く | M1 | cc:完了 |

---

## Phase 25: ソロモード PM フレームワーク強化

作成日: 2026-03-08
起点: pm-skills (phuryn/pm-skills) との比較分析 — ソロモードでの PM 思考フレームワーク欠如を特定
目的: ソロモード（Claude Code 単独運用）で PM 不在を補う「構造化された自問機構」を既存スキルに埋め込む

### 背景

- ハーネスは 2-Agent（Cursor PM + Claude Code Worker）前提で設計されたため、ソロモードでは PM 側の思考フレームワークが薄い
- pm-skills は 65 スキル / 36 チェーンワークフローで PM の思考構造化（Discovery, Strategy, Execution）をカバー
- ハーネスの強み（Evals 必須化、Plans.md マーカー、ガードレール）と pm-skills の強み（フレームワーク適用、段階的チェックポイント）は補完関係
- 新規スキル/コマンドは作らず、全て既存スキルの拡張として実装する

### 完了条件

1. harness-plan create の優先度判定が Impact × Risk の 2 軸マトリクスになっている
2. Plans.md テーブルに DoD カラムが追加され、create 時に自動生成される
3. harness-review の Plan Review に Value 軸が追加されている
4. harness-plan sync にレトロスペクティブ機能が統合されている
5. breezing の Phase 0 に構造化 3 問チェックが定義されている
6. harness-work Solo フローにタスク背景確認ステップが追加されている
7. Plans.md テーブルに Depends カラムが追加され、breezing が依存グラフを活用できる

### 優先度マトリクス

| 優先度 | Phase | 内容 | タスク数 | 依存 |
|--------|-------|------|---------|------|
| **Required** | 25.0 | Plans.md フォーマット拡張（DoD + Depends カラム） | 3 | なし |
| **Required** | 25.1 | harness-plan create 強化（2 軸マトリクス + DoD 自動生成） | 3 | 25.0 |
| **Required** | 25.2 | harness-review Plan Review 拡張（Value 軸） | 2 | なし |
| **Recommended** | 25.3 | harness-plan sync レトロ機能 | 2 | なし |
| **Recommended** | 25.4 | breezing Phase 0 構造化 + harness-work Solo 背景確認 | 3 | 25.0 |
| **Required** | 25.5 | 統合検証・バージョン・リリース | 3 | 25.0〜25.4 |

合計: **16 タスク**

---

### Phase 25.0: Plans.md フォーマット拡張 [P0]

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 25.0.1 | `harness-plan/references/create.md` の Plans.md 生成テンプレート（Step 6）を `| Task | 内容 | DoD | Depends | Status |` の 5 カラムに拡張 | テンプレートが 5 カラム形式になっている | - | cc:完了 |
| 25.0.2 | `harness-plan/references/sync.md` の差分検出ロジックを 5 カラム形式に対応させる（3 カラム Plans.md との後方互換を維持） | 旧 3 カラム Plans.md でもエラーなく動作する | 25.0.1 | cc:完了 |
| 25.0.3 | `harness-plan/SKILL.md` の Plans.md フォーマット規約セクションを 5 カラムに更新し、DoD / Depends の記法ガイドを追記 | SKILL.md 内のフォーマット規約が新テンプレートと一致 | 25.0.1 | cc:完了 |

### Phase 25.1: harness-plan create 強化 [P1]

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 25.1.1 | `harness-plan/references/create.md` の Step 5 を 2 軸マトリクス（Impact × Risk）に拡張。高 Impact × 高 Risk のタスクに `[needs-spike]` マーカーを自動付与し、spike タスクを自動生成 | Step 5 が 2 軸で評価され、高リスクタスクに spike が付く | 25.0.1 | cc:完了 |
| 25.1.2 | `harness-plan/references/create.md` の Step 6 で DoD カラムをタスク内容から自動推論して生成するロジックを追加 | 生成された Plans.md の全タスクに DoD が埋まっている | 25.0.1 | cc:完了 |
| 25.1.3 | `harness-plan/references/create.md` の Step 6 で Depends カラムをフェーズ内の依存関係から自動推論して生成するロジックを追加 | 依存のないタスクは `-`、依存ありは タスク番号が入る | 25.0.1 | cc:完了 |

### Phase 25.2: harness-review Plan Review 拡張 [P2] [P]

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 25.2.1 | `harness-review/SKILL.md` の Plan Review フローに Value 軸を追加（5 軸目: ユーザー課題との紐付き、代替手段の検討、Elephant 検出） | Plan Review が 5 軸（Clarity / Feasibility / Dependencies / Acceptance / Value）で評価される | - | cc:完了 |
| 25.2.2 | `harness-review/SKILL.md` の Plan Review で DoD カラム・Depends カラムの品質チェックを追加（空欄検出、検証不能な DoD の警告） | DoD 未記入タスクが警告される | - | cc:完了 |

### Phase 25.3: harness-plan sync レトロ機能 [P3] [P]

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 25.3.1 | `harness-plan/references/sync.md` に `--retro` フラグ対応を追加。完了タスクの振り返り（見積もり精度、ブロック原因パターン、スコープ変動）を出力 | `sync --retro` で振り返りサマリーが表示される | - | cc:完了 |
| 25.3.2 | `harness-plan/SKILL.md` の argument-hint と sync サブコマンド説明に `--retro` を追記 | SKILL.md に --retro の説明がある | 25.3.1 | cc:完了 |

### Phase 25.4: breezing Phase 0 構造化 + harness-work Solo 背景確認 [P4]

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 25.4.1 | `breezing/SKILL.md` の Phase 0: Planning Discussion に構造化 3 問チェック（スコープ確認、依存関係確認、リスクフラグ）を定義 | Phase 0 に 3 つの具体的チェック項目がある | 25.0.1 | cc:完了 |
| 25.4.2 | `harness-work/SKILL.md` の Solo フロー Step 1 と Step 2 の間に Step 1.5（タスク背景 30 秒確認）を追加。目的と影響範囲を推論表示し、自信がない場合のみ 1 問確認 | Solo フローに背景確認ステップが存在する | - | cc:完了 |
| 25.4.3 | `breezing/SKILL.md` の Phase 0 で Depends カラムを読み取り、依存グラフに基づくタスク割り当て順序を自動決定するロジックを追加 | Depends が空のタスクから先に Worker に割り当てられる | 25.0.1 | cc:完了 |

### Phase 25.5: 統合検証・バージョン・リリース [P5]

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 25.5.1 | `./tests/validate-plugin.sh` + `./scripts/ci/check-consistency.sh` 全体検証 | 全検証パス | 25.0〜25.4 | cc:完了 |
| 25.5.2 | VERSION バンプ + plugin.json 同期 + CHANGELOG 追記 | バージョンが同期されている | 25.5.1 | cc:完了 |
| 25.5.3 | GitHub Release 作成 | リリースが公開されている | 25.5.2 | cc:TODO |

---

## Phase 26: まさお理論適用 — 状態中心アーキテクチャへの転換

作成日: 2026-03-08
起点: まさお氏「マクロハーネス・ミクロハーネス・Project OS」3要素理論の分析
目的: 会話中心の運用から状態中心の運用へ転換し、自律実行の信頼性とセッション継続性を向上

### 背景

- まさお理論の3要素（マクロ/ミクロ/Project OS）と Harness を対照分析
- ミクロハーネス（breezing, guardrails, Agent Teams）は成熟済み — アップデート不要
- マクロハーネス（計画・監視・再計画）と Project OS（状態基盤）にギャップあり
- 3エージェント（Red Team / Architect / PM-UX）による多角的レビューで以下を確定:
  - KPI/Story 層は P0 から降格（ソロ開発では「管理」より「自動化」が優先）
  - Plans.md フォーマット変更は統一設計を先行（競合変更の防止）
  - プログレスフィード（breezing 中の進捗可視化）を新規追加

### 設計原則（3エージェント議論から導出）

1. **「管理」ではなく「自動化」を増やす** — 管理層を厚くするとユーザーが管理層を管理する逆説に陥る
2. **半自動→全自動の段階的移行** — 精度が安定するまでは提案→承認のフロー
3. **Plans.md 変更は一括設計してから実装** — 同じファイル群への競合変更を防ぐ
4. **任意フィールドをデフォルトにする** — 運用されない必須項目は害悪
5. **既存インフラを活用する** — 新しい仕組みより既存 hooks/skills の拡張を優先

### 優先度マトリクス

| 優先度 | Phase | 内容 | タスク数 | 依存 |
|--------|-------|------|---------|------|
| **Required** | 26.0 | 失敗→再チケット化フロー（半自動MVP） | 3 | なし |
| **Required** | 26.1 | harness-sync --snapshot | 3 | なし |
| **Recommended** | 26.2 | Artifact 軽量紐付け + プログレスフィード | 4 | なし |
| **Optional** | 26.3 | Plans.md v3 フォーマット統一設計 | 3 | 26.2 |
| **Required** | 26.4 | 統合検証・バージョン・リリース | 3 | 26.0〜26.3 |

合計: **16 タスク**

---

### Phase 26.0: 失敗→再チケット化フロー（半自動MVP） [P0] [P]

Purpose: 自己修正ループ失敗時に「止まるだけ」から「次の一手を提案してくれる」へ転換

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 26.0.1 | `harness-work/SKILL.md` の自己修正ループ終了処理に失敗原因分析ステップを追加。3回 STOP 時に失敗ログの要約 + 推奨アクション + 修正タスク案を生成 | 3回STOPで原因分析と修正タスク案が出力される | - | cc:完了 |
| 26.0.2 | 修正タスク案のユーザー承認フローを追加。承認時に Plans.md へ `cc:TODO` で自動追加、却下時はスキップ | 承認→Plans.md 追加、却下→スキップが動作する | 26.0.1 | cc:完了 |
| 26.0.3 | 全自動昇格条件を `decisions.md` に D30 として記録（提案採用率 80%+ で全自動化を検討） | D30 が記録されている | 26.0.1 | cc:完了 |

### Phase 26.1: harness-sync --snapshot [P0] [P]

Purpose: セッション再開時の「どこまでやったっけ」問題の根本解決

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 26.1.1 | `harness-sync/SKILL.md` に `--snapshot` サブコマンドを追加。Plans.md の WIP/TODO カウント + 最新 3 コミット + 未解決ブロッカーを 1 出力に集約 | `/harness-sync --snapshot` で状態サマリーが得られる | - | cc:完了 |
| 26.1.2 | `harness-sync/references/sync.md` に snapshot 生成ロジックを追加。Plans.md + 直近の decisions.md エントリ + git log を読み取り | snapshot が Plans.md 以外の状態も含む | 26.1.1 | cc:完了 |
| 26.1.3 | `harness-sync/SKILL.md` の argument-hint と sync サブコマンド説明に `--snapshot` を追記 | SKILL.md に --snapshot の説明がある | 26.1.1 | cc:完了 |

### Phase 26.2: Artifact 軽量紐付け + プログレスフィード [P1] [P]

Purpose: タスク完了の追跡性向上 + breezing 中のユーザー体験改善

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 26.2.1 | `harness-work/SKILL.md` のタスク完了処理で、`cc:完了` マーカー更新時に直近の commit hash を Status 内に付与（例: `cc:完了 [a1b2c3d]`） | タスク完了時に commit hash が自動付与される | - | cc:完了 |
| 26.2.2 | `harness-plan/references/sync.md` の差分検出ロジックを `cc:完了 [hash]` 形式に対応させる（後方互換: hash なしでもエラーなし） | 旧形式 Plans.md でもエラーなく動作する | 26.2.1 | cc:完了 |
| 26.2.3 | `breezing/SKILL.md` の Lead フローに、Worker タスク完了時の 1 行プログレスサマリー出力を追加（「Task 3/7 完了: ユーザー認証 API 実装」形式） | breezing 実行中にタスク完了ごとに進捗が表示される | - | cc:完了 |
| 26.2.4 | `scripts/hook-handlers/task-completed.sh` に進捗サマリー出力を追加（既存 TaskCompleted hook 基盤を活用） | TaskCompleted hook で進捗情報が出力される | 26.2.3 | cc:完了 |

### Phase 26.3: Plans.md v3 フォーマット統一設計 [P2]

Purpose: 将来の KPI/Story/Artifact カラム追加を一括設計し、競合変更を防止

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 26.3.1 | Plans.md v3 フォーマット仕様を設計。任意 Purpose 行（Phase ヘッダー）+ Artifact 表記の標準化 + 影響ファイル一覧を文書化 | 仕様書が作成され、影響ファイル一覧がある | - | cc:完了 |
| 26.3.2 | `harness-plan/references/create.md` の Plans.md 生成テンプレートに任意 Purpose 行を追加。デフォルトでは入力を求めない | Purpose 行が生成可能（省略可）。既存 Plans.md との後方互換維持 | 26.3.1 | cc:完了 |
| 26.3.3 | `decisions.md` に D31 として Plans.md v3 フォーマット設計判断を記録 | D31 が記録されている | 26.3.1 | cc:完了 |

### Phase 26.4: 統合検証・バージョン・リリース [P3]

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 26.4.1 | `./tests/validate-plugin.sh` + `./scripts/ci/check-consistency.sh` 全体検証 | 全検証パス | 26.0〜26.3 | cc:完了 |
| 26.4.2 | VERSION バンプ + plugin.json 同期 + CHANGELOG 追記 | バージョンが同期されている | 26.4.1 | cc:完了 |
| 26.4.3 | GitHub Release 作成 | リリースが公開されている | 26.4.2 | cc:完了 [56cdd77] |

---

## Phase 27: まさお理論適用の実装整合ハードニング

作成日: 2026-03-10
起点: `56cdd777 feat: state-centric architecture with masao theory` のレビュー
目的: Phase 26 で導入した「状態中心」機能のうち、説明先行になっている部分を実装・再開導線・追跡性まで含めて本当に閉じる

### 背景

- まさお理論との方向性自体は正しいが、「説明ではできること」と「実ランタイムで起きること」に一部ズレがある
- 特に「失敗→再チケット化」は TaskCompleted hook 側で修正タスク追加まで到達しておらず、実質は原因分析 + エスカレーション止まり
- `--snapshot` は保存設計までは入ったが、セッション再開時の自動読込・比較は未接続
- Project OS の最小要件（目的 / 受け入れ条件 / 上流参照 / 成果物リンク）のうち、上流参照がまだ薄い

### 優先度マトリクス

| 優先度 | Phase | 内容 | タスク数 | 依存 |
|--------|-------|------|---------|------|
| **Required** | 27.0 | 失敗→再チケット化の実ランタイム実装 | 3 | なし |
| **Required** | 27.1 | snapshot の再開導線接続 | 2 | なし |
| **Recommended** | 27.2 | Project OS 最小トレーサビリティ補強 | 3 | 27.1 |

合計: **8 タスク**

---

### Phase 27.0: 失敗→再チケット化の実ランタイム実装 [P0]

Purpose: Phase 26 の「次の一手をチケットとして残す」を説明ではなく実動作にする

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 27.0.1 | `scripts/hook-handlers/task-completed.sh` に `.fix` タスク案の構造化出力を追加し、失敗カテゴリ・元タスク番号・DoD・Depends を machine-readable に返す | 3回失敗時に修正タスク案が JSON もしくは安定フォーマットで取得できる | - | cc:完了 |
| 27.0.2 | 修正タスク案を `Plans.md` へ安全に追記する承認フローを実装する（承認時のみ追加、重複追加防止） | 承認で `.fix` タスクが1回だけ追加され、却下時は Plans.md が変化しない | 27.0.1 | cc:完了 |
| 27.0.3 | `skills/harness-work/SKILL.md` / `CHANGELOG.md` / `.claude/memory/decisions.md` の再チケット化説明を実装と一致させ、回帰検証を追加する | 「提案まで」「承認後追加」「全自動」の境界が全ファイルで一致し、再現手順がある | 27.0.2 | cc:完了 |

### Phase 27.1: snapshot の再開導線接続 [P0]

Purpose: 保存した状態を次セッションで本当に使えるようにして、状態中心アーキテクチャを閉じる

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 27.1.1 | `session-init` / `session-resume.sh` 系に最新 snapshot 読込を追加し、再開時に前回との差分サマリーを表示する | snapshot がある状態で再開すると差分サマリーが出る。ない場合は静かにスキップする | - | cc:完了 |
| 27.1.2 | `harness-sync --snapshot` の初回保存・2回目比較・再開時読込の検証手順を `tests/` またはドキュメント化された再現スクリプトとして固定する | 手順どおりに snapshot 保存→比較→再開確認を再現できる | 27.1.1 | cc:完了 |
| 27.1.3 | `session-init` と usage 記録フックの stdout ノイズを分離し、hook 出力が JSON 本体だけになることを回帰検証する | `session-init` / usage tracking が telemetry を出しても hook stdout が壊れず、直接実行の検証がある | 27.1.2 | cc:完了 |

### Phase 27.2: Project OS 最小トレーサビリティ補強 [P1]

Purpose: 「なぜこのチケットがあるか」を上流へ辿れる最小フォーマットを、管理過多にならない範囲で足す
