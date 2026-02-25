# まさおハーネス理論ベンチマーク改善プラン

作成日: 2026-02-23
基準: `docs/research/masaoharness-benchmark-report.md`（5 Opus 4.6 エージェントによる精密評価）
現在スコア: CC 182/200 (91.0%, Level 5.5) / Codex 143/200 (71.5%, Level 4.0)

---

## 優先度マトリクス

| 優先度 | Phase | 対象 Level | 改善幅 | 難度 |
|--------|-------|-----------|--------|------|
| **Required** | 13.1 | L5 自動検証 | +2.0pt | 中 |
| **Required** | 13.2 | L1 CLAUDE.md | +2.0pt | 低 |
| **Recommended** | 13.3 | L1-2 Codex | +5.0pt | 中 |
| **Optional** | 13.4 | L6 オーケスト | +1.5pt | 高 |

---

## Phase 13.1: 自動検証ループ強化（Level 5: 80% → 88%）[P1]

仕様確認済み: TaskCompleted exit 2 で拒否可能、async hook で非ブロッキング実行可能、Hooks からの spawn は不可（feedback 注入で代替）。

### 13.1.1 TaskCompleted 品質ゲート [feature:quality]

| Task | 内容 | Status |
|------|------|--------|
| 13.1.1.1 | `task-completed.sh` にテスト結果参照を追加: auto-test-runner の結果ファイルを確認 → 未実行/失敗時 exit 2（テスト実行自体は async hook 側で行い、hook 内での長時間実行を回避） | cc:完了 |
| 13.1.1.2 | `.claude/state/task-quality-gate.json` で失敗カウントを管理（タスク ID 別） | cc:完了 |
| 13.1.1.3 | 3回連続失敗で exit 0 + stderr にエスカレーションレポートを出力（D21 自動化） | cc:完了 |
| 13.1.1.4 | エスカレーションレポートのフォーマット定義（原因分類 + 推奨アクション + 試行履歴） | cc:完了 |

### 13.1.2 テスト改ざん検知パターン追加

| Task | 内容 | Status |
|------|------|--------|
| 13.1.2.1 | assertion weakening 検知: `toBe` → `toBeTruthy`, `toEqual` → `toBeDefined` のパターン追加 | cc:完了 |
| 13.1.2.2 | timeout 値の大幅引き上げ検知: `jest.setTimeout(30000)` 等 | cc:完了 |
| 13.1.2.3 | catch-all assertion 検知: `expect(true).toBe(true)` 等の無意味テスト | cc:完了 |
| 13.1.2.4 | Python: `pytest.mark.skip` / `unittest.skip` デコレータ検知 | cc:完了 |

### 13.1.3 auto-test-runner.sh の実行モード追加

| Task | 内容 | Status |
|------|------|--------|
| 13.1.3.1 | `HARNESS_AUTO_TEST=run` 環境変数で実行モードを切り替え可能に | cc:完了 |
| 13.1.3.2 | `async: true` を hooks.json に追加し非ブロッキング実行（[async hook 仕様](https://code.claude.com/docs/en/hooks)） | cc:完了 |
| 13.1.3.3 | テスト結果を `additionalContext` で Claude に自動フィードバック | cc:完了 |

### 13.1.4 CI 復旧の自律性向上

**仕様制約**: Hooks からエージェント spawn は不可。feedback 注入で Lead に判断を委ねる方式に修正。

| Task | 内容 | Status |
|------|------|--------|
| 13.1.4.1 | PostToolUse (Bash matcher) で `git push` / `gh pr` 後の CI ステータスを非同期チェック | cc:完了 |
| 13.1.4.2 | CI 失敗検知時に `additionalContext` で「ci-cd-fixer の spawn を推奨」メッセージを注入 | cc:完了 |
| 13.1.4.3 | `ci-cd-fixer.md` のプロンプトに「CI 失敗の自動検知シグナル受信時の対応手順」を追加 | cc:完了 |

---

## Phase 13.2: CLAUDE.md 電報体最適化（Level 1: 88% → 96%）[P3]

仕様確認済み: 全提案はドキュメント整理のみ（仕様依存なし）。120行目標はスキルバジェット2%スケーリング（CC 2.1.32+）と整合。

### 13.2.1 references/ へのコンテンツ移管

| Task | 内容 | Status |
|------|------|--------|
| 13.2.1.1 | `docs/CLAUDE-feature-table.md` 新規作成: Feature Table 全20行を移管 | cc:完了 |
| 13.2.1.2 | `docs/CLAUDE-skill-catalog.md` 新規作成: スキル階層ツリー + 全カテゴリ表 + 開発用スキル（計31行） | cc:完了 |
| 13.2.1.3 | `docs/CLAUDE-commands.md` 新規作成: 主要コマンド表 + ハンドオフ（計21行） | cc:完了 |

### 13.2.2 CLAUDE.md 本文の圧縮

| Task | 内容 | Status |
|------|------|--------|
| 13.2.2.1 | Feature Table → 上位5機能のみ残し「詳細: docs/CLAUDE-feature-table.md」リンク追加 | cc:完了 |
| 13.2.2.2 | スキルカテゴリ表 → 頻出5カテゴリ（work/breezing/review/setup/memory）のみ残し「詳細: docs/CLAUDE-skill-catalog.md」リンク追加 | cc:完了 |
| 13.2.2.3 | テスト方法セクション → コマンド2行 +「詳細: docs/」リンクに圧縮 | cc:完了 |
| 13.2.2.4 | コマンド表 → 主要6コマンドのみ残し残りは docs/ リンク | cc:完了 |
| 13.2.2.5 | 開発ルール → commit 種別リストを短縮、CHANGELOG 詳細は rules/ 参照へ | cc:完了 |
| 13.2.2.6 | テスト改ざん防止 → rules/ リンクのみに圧縮（3行） | cc:完了 |

### 13.2.3 検証

| Task | 内容 | Status |
|------|------|--------|
| 13.2.3.1 | 圧縮後の CLAUDE.md が 120行以下であることを確認 | cc:完了 |
| 13.2.3.2 | 移管先ドキュメントからの CLAUDE.md 逆参照が正しいことを確認 | cc:完了 |

---

## Phase 13.3: Codex CLI 経路のルール注入強化（Level 1: 60% → 72%, Level 2: 64% → 76%）[P2]

### 仕様検証結果

| 提案 | Codex 仕様 | 実現可否 | 修正 |
|------|-----------|---------|------|
| `base-instructions` で rules/ 自動注入 | ❌ `base-instructions` は Codex に存在しない概念 | ⚠️ 修正必要 | **AGENTS.md 階層に統合** |
| codex exec 後の SSOT 自動追記 | `codex exec` は stdout に結果を出力（[公式](https://developers.openai.com/codex/cli/reference/)） | ✅ 実現可能 | ラッパースクリプトで後処理 |
| Agent Memory bridge | Codex にはセッション間メモリ機構なし | ✅ 実現可能 | ラッパーで `.claude/memory/` に書き戻し |

### 13.3.1 AGENTS.md へのルール統合

Codex は `AGENTS.md` を階層的に読み込む（[Codex Rules 仕様](https://developers.openai.com/codex/rules)）。`.claude/rules/` の内容を `codex/.codex/AGENTS.md` に統合する。

| Task | 内容 | Status |
|------|------|--------|
| 13.3.1.1 | `scripts/codex/sync-rules-to-agents.sh` 新規作成: `.claude/rules/*.md` → `codex/.codex/AGENTS.md` への自動変換 + ハッシュ比較で SSOT ドリフト検知 | cc:完了 |
| 13.3.1.2 | `test-quality.md` のテスト改ざん禁止パターンを AGENTS.md 形式に変換 | cc:完了 |
| 13.3.1.3 | `implementation-quality.md` の形骸化実装禁止パターンを AGENTS.md 形式に変換 | cc:完了 |
| 13.3.1.4 | `codex-cli-only.md` の Codex 固有ルールを AGENTS.md に統合 | cc:完了 |

### 13.3.2 Codex exec ラッパーによるメモリ永続化

| Task | 内容 | Status |
|------|------|--------|
| 13.3.2.1 | `scripts/codex/codex-exec-wrapper.sh` 新規作成: codex exec の前処理（ルール注入）と後処理（結果記録）を自動化 | cc:完了 |
| 13.3.2.2 | 後処理: stdout から構造化マーカー `[HARNESS-LEARNING]` 付き行のみ抽出（非構造化出力の誤解析を回避） | cc:完了 |
| 13.3.2.3 | 抽出結果を `.claude/memory/codex-learnings.md` に flock 付きアトミック追記 + シークレットフィルタ（token/key/password パターン除去） | cc:完了 |
| 13.3.2.4 | `codex-implementer.md` の codex exec 呼び出しをラッパー経由に変更 | cc:完了 |

### 13.3.3 Codex .rules ファイル整備

Codex は `./codex/rules/` 配下の `.rules` ファイルでコマンド実行ポリシーを制御できる（[execpolicy 仕様](https://developers.openai.com/codex/cli/reference/)）。

| Task | 内容 | Status |
|------|------|--------|
| 13.3.3.1 | `codex/.codex/rules/harness.rules` を拡充: package.json の scripts.test のみ auto-allow（任意コマンド連結は deny） | cc:完了 |
| 13.3.3.2 | 危険コマンド（rm -rf, git push --force）を deny に追加 | cc:完了 |
| 13.3.3.3 | `codex execpolicy check` で全ルールの動作検証 | cc:完了 |

### 13.3.4 検証

| Task | 内容 | Status |
|------|------|--------|
| 13.3.4.1 | `codex exec` でルール統合版 AGENTS.md が正しく読み込まれることを確認 | cc:完了 |
| 13.3.4.2 | ラッパースクリプト経由の codex exec でメモリ書き戻しが動作することを確認 | cc:完了 |
| 13.3.4.3 | `.rules` ファイルの execpolicy check で全パターンが期待通りの判定を返すことを確認 | cc:完了 |

---

## Phase 13.4: Level 6 動的オーケストレーション強化（Level 6: 88% → 94%）[P4]

### 仕様検証結果

| 提案 | Claude Code 仕様 | 実現可否 | 修正 |
|------|-----------------|---------|------|
| 自動チーム構成 | Planner の max_parallel は参考情報扱い | ✅ 実現可能 | execution-flow.md のロジック拡張 |
| APPROVE → auto-commit Hook | PostToolUse で SendMessage を match 可能 | ⚠️ リスク高 | **Phase C のフロー改善に変更** |
| シグナル消費側の自動注入 | UserPromptSubmit hook で systemMessage 注入可能 | ✅ 実現可能（低コスト） | cc:完了 |

### 13.4.1 シグナル消費側の自動注入（最低コスト改善）

| Task | 内容 | Status |
|------|------|--------|
| 13.4.1.1 | `scripts/hook-handlers/breezing-signal-injector.sh` 新規作成: `breezing-signals.jsonl` を読んで未消費シグナルを `systemMessage` に注入 | cc:完了 |
| 13.4.1.2 | `hooks.json` の `UserPromptSubmit` に signal-injector を追加（breezing-active.json 存在時のみ発火） | cc:完了 |
| 13.4.1.3 | シグナル消費済みフラグの管理（flock + tmp-rename でアトミック更新、consumed_at タイムスタンプ） | cc:完了 |

### 13.4.2 Planner フィードバックによるチーム自動構成

| Task | 内容 | Status |
|------|------|--------|
| 13.4.2.1 | `planning-discussion.md` に Planner の `parallelism_assessment.max_parallel` を Lead が参照する手順を追加 | cc:完了 |
| 13.4.2.2 | `execution-flow.md` の Implementer 数自動決定ロジックを拡張: `max(1, min(planner_max_parallel, --parallel N, 5))` でスターブ防止 | cc:完了 |
| 13.4.2.3 | `team-composition.md` に Extended 構成（5 Impl）のコスト見積もりを追加 | cc:完了 |

### 13.4.3 Phase C コミット判断の効率化

**仕様制約**: PostToolUse の SendMessage matcher で APPROVE を検知し auto-commit する方式は誤検知リスクが高い（Reviewer の返答フォーマット依存）。代わりに、Phase C の Lead 判断フローを効率化する。

| Task | 内容 | Status |
|------|------|--------|
| 13.4.3.1 | `execution-flow.md` Phase C に「APPROVE 検知 → 即座に統合検証 → コミット」のファストパスを追加 | cc:完了 |
| 13.4.3.2 | `review-retake-loop.md` の APPROVE 判定結果を `.claude/state/review-result.json` に自動記録（task-completed.sh から） | cc:完了 |
| 13.4.3.3 | Phase C 冒頭で `review-result.json` を読み、全 APPROVE かつ対象コミットハッシュが HEAD と一致する場合のみファストパス許可 | cc:完了 |

---

## Phase 13.5: ミラー同期 + 検証 + リリース

| Task | 内容 | Status |
|------|------|--------|
| 13.5.1 | `bash -n` 全新規スクリプト構文チェック | cc:完了 |
| 13.5.2 | ミラー同期: `rsync -av --delete skills/ codex/.codex/skills/` + `opencode/skills/` | cc:完了 |
| 13.5.3 | `./tests/validate-plugin.sh && ./scripts/ci/check-consistency.sh` 検証 | cc:完了 |
| 13.5.4 | `.claude/memory/decisions.md` に D25: まさお理論ベンチマーク改善 を記録 | cc:完了 |
| 13.5.5 | CHANGELOG.md + CHANGELOG_ja.md エントリ追加 | cc:完了 |
| 13.5.6 | バージョンバンプ + コミット | cc:完了 |

検証: TaskCompleted exit 2 動作 / 改ざん検知 12+ パターン / CLAUDE.md 120行以下 / AGENTS.md 統合 / メモリ書き戻し / シグナル注入 / validate-plugin + check-consistency 全パス

対象外: APPROVE auto-commit Hook（誤検知リスク）/ Codex base-instructions（仕様不在）/ ポジティビティバイアス対抗（別Phase）

---

## Phase 14: release-har スキル再設計 — 「速さ」と「配信品質」の両立（v2）

作成日: 2026-02-23（v2: ディベート統合後の改訂版）
起点: AI 系 OSS ベストプラクティス分析 + 5 リポジトリ実地調査 + 3 エージェントディベート
目的: 「変更から配布物までの一連を事故らず作る」スキルへの進化

### 調査に基づく設計原則（旧プランから修正）

| 原則 | 旧プランの問題 | ディベート後の方針 | 根拠 |
|------|--------------|------------------|------|
| **差別化の核心** | ルールベース分類のみ（semantic-release と同じ） | **Claude が diff を読んで変更の本質を要約** | エコシステムAgent: 唯一の差別化点 |
| SemVer 自動判定 | Recommended | **Required に昇格**。引数指定時は確認なし | 実用主義Agent: 止まらない体験 |
| Dry-run | Recommended | **Required に昇格**。全出力プレビュー | 3Agent全員合意 |
| バージョン同期 | **欠如していた** | Pre-flight に sync-version.sh check を組込 | 品質Agent: claude-mem/ecc で実被害 |
| 多チャネル配信 | P3（3チャネル） | **X告知文のみ、`--announce` オプション** | 折衷: 拡散起点だが強制は過剰 |
| README lint | P3 | **削除**（harness-review の責務） | 3Agent全員合意: 単一責任原則違反 |
| Highlights抽出 | コミット数・ファイル数で判定 | **Claude の読解力で diff 要約** | 3Agent全員合意: 量的指標は不正確 |
| references/ | 4ファイル新規作成 | **2ファイルに縮小**（テンプレート + フォーマット） | 実用主義Agent: SKILL.md内記述で十分な部分あり |

### 優先度マトリクス

| 優先度 | Phase | 内容 | タスク数 |
|--------|-------|------|---------|
| **Required** | 14.1 | Pre-flight + 変更分析エンジン | 5 |
| **Required** | 14.2 | Release Notes 品質（diff 要約 = 差別化の核） | 3 |
| **Required** | 14.3 | SemVer 自動判定 + dry-run | 3 |
| **Recommended** | 14.4 | テンプレート整備 + SKILL.md 再構成 | 3 |
| **Optional** | 14.5 | X 告知文（`--announce`） | 1 |
| Required | 14.6 | 検証 + 同期 | 2 |

合計: **17 タスク**（旧 31 → 55% 削減）

### 削除したタスク（理由）

| 旧タスク | 削除理由 | 判定Agent |
|---------|---------|-----------|
| 14.1.3 change-classification.md | SKILL.md内の分類ロジック記述で十分 | 実用主義 |
| 14.1.4 announcement-templates.md | 汎用テンプレートは使えないか具体すぎて適用不可 | 実用主義 |
| 14.2.2 PR ベース分析（gh依存） | 汎用スキルの前提（GitHub以外も対象）と矛盾 | 3Agent合意 |
| 14.2.5 New Contributors 自動生成 | 著者名表記ゆれで誤検知。GitHub標準機能で代替可 | 3Agent合意 |
| 14.3.2 Highlights コミット数判定 | 量的指標でユーザー重要度は判定不可 | 3Agent合意 |
| 14.6.1 Discussions 告知文 | ROI不明。調査5プロジェクトで誰も実装していない | 実用主義 |
| 14.6.3 Discord 告知文 | 同上 | 実用主義 |
| 14.7.1〜7.3 README lint 全3件 | release の責務外。harness-review に委譲 | 3Agent合意 |
| 14.8.1 x-release-harness 同期 | 最小変更のため個別同期不要。14.6で一括検証 | 実用主義 |
| 14.8.2 ミラー同期 | release-har の機能ではなくリリース作業。Phase 13.5 と重複 | エコシステム |

---

### Phase 14.1: Pre-flight + 変更分析エンジン [P1]

現行 Step 1 の `git log --oneline -10` → 前タグからの全変更を構造的に取得・分類。

| Task | 内容 | Status |
|------|------|--------|
| 14.1.1 | **Pre-flight チェック追加**: バージョンファイル同期確認（`sync-version.sh check` 相当）、未コミット変更の警告、`gh` コマンド存在確認（なければ git log のみで続行） | cc:完了 |
| 14.1.2 | Step 1 を拡張: `git log --format="%h\|%s\|%an\|%ad" --date=short vPREV..HEAD` で前タグからの全変更を取得 | cc:完了 |
| 14.1.3 | Conventional Commits 分類ロジック: `feat/fix/docs/perf/refactor/test/chore` → カテゴリマッピング + `BREAKING CHANGE:` / `!:` の自動検出 | cc:完了 |
| 14.1.4 | Compare リンク自動生成: `https://github.com/OWNER/REPO/compare/vPREV...vNEW`（`gh` 存在時のみ、なければスキップ） | cc:完了 |
| 14.1.5 | 分析サマリの表示: 「feat: N件、fix: M件、breaking: K件、contributors: L名」を一覧表示 | cc:完了 |

### Phase 14.2: Release Notes 品質（差別化の核心）[P1]

**Claude が diff を読んで変更の本質を理解し、ユーザー向け Release Notes を生成。** これが semantic-release/Changesets にはできない唯一の差別化点。

| Task | 内容 | Status |
|------|------|--------|
| 14.2.1 | **diff 要約機能**: `git diff vPREV..HEAD` の内容を Claude が読み、「このリリースの本質は何か」を Highlights（最大3つ）として 1-3 文で要約。Before/After テーブルも同時生成 | cc:完了 |
| 14.2.2 | Release Notes 構造: Highlights → Breaking Changes（移行手順）→ Notable Changes（カテゴリ別）→ Full Changelog（compare リンク）の 4 セクション。`.claude/rules/github-release.md` と整合 | cc:完了 |
| 14.2.3 | フッター統一: `Generated with [Claude Code](https://claude.com/claude-code)` を必ず付与 | cc:完了 |

### Phase 14.3: SemVer 自動判定 + dry-run [P1]

| Task | 内容 | Status |
|------|------|--------|
| 14.3.1 | SemVer 自動判定: Breaking → MAJOR、feat → MINOR、fix/docs/refactor のみ → PATCH。判定根拠を「N件のfeat, K件のfix → MINOR提案」形式で表示。引数指定（`patch`/`minor`/`major`）時は確認なしで採用 | cc:完了 |
| 14.3.2 | dry-run をデフォルト前段に: CHANGELOG 差分、Release Notes 全文、タグ名をプレビュー → 「この内容で実行しますか？」→ Yes で本実行 | cc:完了 |
| 14.3.3 | 0.x.y 時の特殊処理: メジャーバージョン 0 の場合は MINOR でも破壊的変更を許容（SemVer 仕様準拠） | cc:完了 |

### Phase 14.4: テンプレート整備 + SKILL.md 再構成 [P2]

| Task | 内容 | Status |
|------|------|--------|
| 14.4.1 | `references/release-notes-template.md` 新規作成: 4 セクション構造テンプレート（Highlights / Breaking / Notable / Full Changelog）+ Before/After テーブル例 | cc:完了 |
| 14.4.2 | `references/changelog-format.md` 新規作成: Keep a Changelog 1.1.0 準拠フォーマット + Harness 固有の Before/After テーブル規約 | cc:完了 |
| 14.4.3 | SKILL.md 本文を再構成: Pre-flight → 分析 → diff要約 → SemVer判定 → dry-run → 実行の新フローに書き直し。references/ への参照を追加 | cc:完了 |

### Phase 14.5: X 告知文（`--announce`）[P3]

| Task | 内容 | Status |
|------|------|--------|
| 14.5.1 | `--announce` オプション: X 向け 280 文字以内の告知文を Release Notes から自動生成。Highlights の 1 行要約 + リリースリンク。デフォルト OFF | cc:完了 |

### Phase 14.6: 検証 + 同期

| Task | 内容 | Status |
|------|------|--------|
| 14.6.1 | `./tests/validate-plugin.sh && ./scripts/ci/check-consistency.sh` で構造検証 + `.claude/rules/github-release.md` を新テンプレートと整合 | cc:完了 |
| 14.6.2 | CHANGELOG.md + CHANGELOG_ja.md エントリ追加 + バージョンバンプ | cc:完了 |

検証: Pre-flight のバージョン同期チェック / diff 要約の品質 / SemVer 自動判定の正確性 / dry-run の全出力プレビュー / validate-plugin + check-consistency 全パス

### リスク評価

| リスク | 深刻度 | 軽減策 |
|--------|--------|--------|
| 初回リリース（前タグなし）で Pre-flight 失敗 | 中 | タグ 0 件時は `--all` にフォールバック |
| Breaking change 検出漏れ（Conventional Commits 未使用プロジェクト） | 高 | diff 要約で Claude が意味的に検出。完全自動判定ではなくユーザー確認を挟む |
| diff が巨大すぎて要約が不正確 | 中 | `--stat` で変更概要を先に取得し、重要ファイルのみ diff を読む |

対象外: CI/CD パイプライン統合（Release Drafter / Towncrier / Changesets）/ README lint（harness-review の責務）/ ミラー同期（リリース作業で別途実施）

---

## Phase 15: Documentation Cleanup — README / CHANGELOG 品質正規化

作成日: 2026-02-23
起点: release-har Step 5.5 設計に伴うドキュメント品質監査
目的: README バッジ・数値の実態反映 + CHANGELOG リンク定義修復 + 翻訳漏れ補完

### Phase 15.1: CHANGELOG リンク定義修復 [P1]

| Task | 内容 | Status |
|------|------|--------|
| 15.1.1 | CHANGELOG.md: 欠落している 23+ バージョンの compare リンク定義を末尾に追加（`[X.Y.Z]: https://github.com/.../compare/vPREV...vX.Y.Z` 形式） | cc:完了 |
| 15.1.2 | CHANGELOG_ja.md: EN版と同等のリンク定義を追加（EN版よりさらに欠落が多い） | cc:完了 |

### Phase 15.2: CHANGELOG_ja.md 翻訳漏れ補完 [P1]

| Task | 内容 | Status |
|------|------|--------|
| 15.2.1 | CHANGELOG_ja.md に5バージョン分の翻訳エントリを追加: `2.20.1`, `2.17.6`, `2.17.1`, `2.17.0`, `2.16.21`（EN版の内容を日本語化） | cc:完了 |

### Phase 15.3: README バージョン・数値更新 [P1]

| Task | 内容 | Status |
|------|------|--------|
| 15.3.1 | README.md / README_ja.md: バージョンバッジを `2.23.2` → 現在の VERSION に更新 | cc:完了 |
| 15.3.2 | README.md / README_ja.md: スキル数バッジ・本文を `45` → 実態 (`41`) に更新 | cc:完了 |
| 15.3.3 | README.md / README_ja.md: エージェント数を `8` → 実態 (`11`) に更新、Architecture セクションも修正 | cc:完了 |

### Phase 15.4: CHANGELOG 非標準見出し整理 [P3]

| Task | 内容 | Status |
|------|------|--------|
| 15.4.1 | CHANGELOG.md / CHANGELOG_ja.md: `### Internal` セクション見出しを Keep a Changelog 準拠の `### Changed` に統合（既存の `### Changed` がある場合はマージ） | cc:完了 |

### Phase 15.5: 検証 + コミット

| Task | 内容 | Status |
|------|------|--------|
| 15.5.1 | `./tests/validate-plugin.sh && ./scripts/ci/check-consistency.sh` で構造検証 | cc:完了 |
| 15.5.2 | CHANGELOG.md / CHANGELOG_ja.md に Phase 15 のエントリ追加 + コミット | cc:完了 |

---

## Phase 16: 透明エスカレーション UX — `/work` から `/breezing` への自動提案

作成日: 2026-02-25
起点: Phase 13-15 完了後の残存ギャップ分析 + Claude Code 仕様検証
目的: `/work` を「考えるエントリポイント」に昇格。「何を使うか」の判断負担をユーザーから取り除く

### 設計原則

> **ユーザーは「何を作るか」だけ決める。「どう作るか」はシステムが提案し、ユーザーが承認する。**

### Phase 16.1: Strategy Analyzer（戦略分析エンジン）[P1]

| Task | 内容 | Status |
|------|------|--------|
| 16.1.1 | `references/strategy-analyzer.md` 新規作成: タスク分析 → 推奨戦略判定のロジック仕様。判定基準: (1) タスク数 (2) 依存グラフの複雑度 (3) ファイル競合率 (4) 推定並列効率 | cc:完了 |
| 16.1.2 | 判定出力スキーマ定義: `{ recommended, reasoning, cost_estimate, confidence }` | cc:完了 |
| 16.1.3 | breezing 推奨条件の明文化: (a) 4+タスク かつ 独立タスク率 60%以上 (b) 依存チェーンが3段以上 (c) UI+API+テストの混在 (d) 2回以上の iteration 失敗履歴あり | cc:完了 |

### Phase 16.2: Scope Dialog の拡張 — 戦略提案 UI [P1]

| Task | 内容 | Status |
|------|------|--------|
| 16.2.1 | `scope-dialog.md` に「Strategy Recommendation」セクション追加: breezing 推奨時の AskUserQuestion 仕様 | cc:完了 |
| 16.2.2 | AskUserQuestion の options 定義（markdown preview で理由+コスト見積もり表示） | cc:完了 |
| 16.2.3 | ユーザーが breezing を選択 → Skill tool で `/breezing` を invoke（引数引き継ぎ） | cc:完了 |
| 16.2.4 | `breezing_auto_approve: true` 設定対応: `.claude-code-harness.config.yaml` の `work.breezing_auto_approve` | cc:完了 |

### Phase 16.3: Failure-Driven Escalation（失敗時エスカレーション）[P2]

| Task | 内容 | Status |
|------|------|--------|
| 16.3.1 | `auto-iteration.md` に「Escalation to Breezing」セクション追加: 2回連続 iteration で同一タスクが失敗 → breezing 提案 | cc:完了 |
| 16.3.2 | エスカレーション理由の動的生成: 失敗履歴から「なぜ breezing が有効か」を説明 | cc:完了 |
| 16.3.3 | エスカレーション承認後: work-active.json を保存 → Skill tool で `/breezing` invoke（失敗履歴引き継ぎ） | cc:完了 |

### Phase 16.4: `/work` SKILL.md の戦略選択ロジック更新 [P1]

| Task | 内容 | Status |
|------|------|--------|
| 16.4.1 | Auto Strategy Selection テーブルに breezing 行追加 | cc:完了 |
| 16.4.2 | Options に `--no-breezing` 追加: breezing 提案を抑制するオプション | cc:完了 |
| 16.4.3 | Completion Tip の条件分岐更新 | cc:完了 |

### Phase 16.5: `/breezing` 側のインバウンド対応 [P2]

| Task | 内容 | Status |
|------|------|--------|
| 16.5.1 | breezing SKILL.md に「Invoked from /work」セクション追加（Phase 0 のスコープ確認スキップ） | cc:完了 |
| 16.5.2 | `execution-flow.md` の Phase A Step 2 に「/work 経由の場合は範囲確認をスキップ」条件追加 | cc:完了 |
| 16.5.3 | 引き継ぎデータ形式の定義: `/work` → `/breezing` に渡す情報スキーマ | cc:完了 |

### Phase 16.6: 検証 + 同期

| Task | 内容 | Status |
|------|------|--------|
| 16.6.1 | `/work all` → breezing 推奨 → 承認 → breezing 実行の E2E フロー確認 | cc:完了 |
| 16.6.2 | `/work all --no-breezing` で breezing 提案が出ないことを確認 | cc:完了 |
| 16.6.3 | `breezing_auto_approve: true` 設定で確認ダイアログがスキップされることを確認 | cc:完了 |
| 16.6.4 | ミラー同期 + validate-plugin + check-consistency | cc:完了 |
| 16.6.5 | CHANGELOG.md + CHANGELOG_ja.md エントリ + バージョンバンプ | cc:完了 |
