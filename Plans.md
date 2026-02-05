# Plans.md - Claude Code 2.1.30 対応プラン

## 概要

Claude Code が 2.1.30 にアップデートされました。新機能を Harness プラグインで活用するための改善プランです。

## 変更点サマリー

| カテゴリ | 変更内容 | Harness への影響 |
|---------|---------|-----------------|
| **Task tool メトリクス** | トークン数、ツール使用数、実行時間を表示 | ✅ 活用可能 |
| **PDF ページ範囲読み取り** | Read ツールに `pages` パラメータ追加 | ✅ ドキュメント系スキル強化 |
| **`/debug` コマンド** | セッションのトラブルシューティング | ✅ troubleshoot スキル連携 |
| **メモリ使用量 68% 削減** | `--resume` 時の最適化 | 🔵 恩恵を受ける |
| **OAuth Client 認証** | MCP サーバー認証強化 | 🔵 将来的に活用 |
| **Git log フラグ拡張** | `--format`, `--raw` 等 | ✅ CI/レビュースキル強化 |
| **Phantom "(no content)" 修正** | トークン無駄遣い解消 | 🔵 自動で恩恵 |
| **サブエージェント MCP アクセス修正** | SDK提供 MCP ツールの共有 | ✅ Codex 統合に影響 |

---

## Phase 1: 高優先度改善（即時効果）

### 1.1 Task tool メトリクス活用 `[feature]`

**背景**: Task tool 結果にトークン数、ツール使用数、実行時間が追加。

| Task | 内容 | Status |
|------|------|--------|
| 1.1.1 | emit-agent-trace.js に Task tool メトリクス取得ロジック追加 | `cc:DONE` |
| 1.1.2 | AgentTrace スキーマ v0.3.0 設計（metrics フィールド） | `cc:DONE` |
| 1.1.3 | ultrawork/parallel-workflows でのメトリクス集計表示 | `cc:DONE` |

**成果物**:
- AgentTrace にサブエージェント実行コストを記録
- `/ultrawork` 完了時にトータルコストを表示

---

### 1.2 `/debug` コマンドとの troubleshoot 連携 `[feature]`

**背景**: 新しい `/debug` コマンドがセッション診断に使える。

| Task | 内容 | Status |
|------|------|--------|
| 1.2.1 | troubleshoot スキルに `/debug` への誘導ルート追加 | `cc:DONE` |
| 1.2.2 | troubleshoot の診断フローに Claude Code 固有診断を追加 | `cc:DONE` |

**成果物**:
- 複雑な問題時に `/debug` を推奨する分岐
- VibeCoder 向けの「もっと詳しく診断して」→ `/debug` 連携

---

### 1.3 PDF ページ範囲読み取り活用 `[feature]`

**背景**: Read ツールで `pages: "1-5"` のようにページ範囲指定が可能に。

| Task | 内容 | Status |
|------|------|--------|
| 1.3.1 | notebookLM スキルでの PDF 活用ドキュメント追加 | `cc:DONE` |
| 1.3.2 | harness-review での大型ドキュメントレビュー対応 | `cc:DONE` |

**成果物**:
- 大型 PDF を効率的に扱うベストプラクティス
- ドキュメントレビュー時のページ範囲指定ガイド

---

## Phase 2: 中優先度改善（機能強化）

### 2.1 Git log フラグ拡張の活用 `[feature]`

**背景**: `--topo-order`, `--cherry-pick`, `--format`, `--raw` が read-only で使用可能に。

| Task | 内容 | Status |
|------|------|--------|
| 2.1.1 | harness-review での変更履歴分析強化 | `cc:DONE` |
| 2.1.2 | CI スキルでのコミット分析改善 | `cc:DONE` |
| 2.1.3 | release-harness でのリリースノート生成改善 | `cc:DONE` |

**成果物**:
- より詳細なコミット情報を活用したレビュー
- `--format` による構造化されたログ出力

---

### 2.2 サブエージェント MCP アクセス修正への対応 `[bugfix]`

**背景**: SDK 提供 MCP ツールがサブエージェントで使えない問題が修正。

| Task | 内容 | Status |
|------|------|--------|
| 2.2.1 | Codex 統合での MCP ツール利用状況確認 | `cc:DONE` |
| 2.2.2 | task-worker エージェントでの MCP ツール利用ガイド追加 | `cc:DONE` |

**成果物**:
- サブエージェントでの MCP ツール活用パターン
- Codex 並列実行時の MCP ツール共有設定

---

### 2.3 メモリ最適化の活用 `[optimization]`

**背景**: セッション再開時のメモリ使用量が 68% 削減。

| Task | 内容 | Status |
|------|------|--------|
| 2.3.1 | session-memory スキルでの `--resume` 推奨強化 | `cc:DONE` |
| 2.3.2 | ultrawork での長時間セッション管理ガイド更新 | `cc:DONE` |

**成果物**:
- セッション再開を活用した効率的なワークフロー
- 長時間実行時のメモリ管理ベストプラクティス

---

## Phase 3: 低優先度改善（将来的な活用）

### 3.1 OAuth Client 認証の活用検討 `[research]`

**背景**: `claude mcp add --client-id --client-secret` で OAuth 認証設定が可能に。

| Task | 内容 | Status |
|------|------|--------|
| 3.1.1 | Slack MCP サーバー統合の検討 | `cc:DONE` |
| 3.1.2 | setup-tools での OAuth 設定ガイド追加 | `cc:DONE` |

**成果物**:
- OAuth 対応 MCP サーバーのセットアップガイド（codex-mcp-setup.md に追加完了）
- Slack 通知統合の可能性調査（範囲外として分離を記録）

---

### 3.2 Reduced Motion モードの活用 `[a11y]`

**背景**: 設定に reduced motion モードが追加。

| Task | 内容 | Status |
|------|------|--------|
| 3.2.1 | harness-ui でのアクセシビリティ設定ガイド追加 | `cc:DONE` |

**成果物**:
- アクセシビリティ設定の推奨構成

---

## Phase 4: ドキュメント更新

### 4.1 CHANGELOG 更新 `[docs]`

| Task | 内容 | Status |
|------|------|--------|
| 4.1.1 | 2.1.30 対応機能の CHANGELOG 記載 | `cc:DONE` |
| 4.1.2 | CLAUDE.md への新機能活用ガイド追加 | `cc:DONE` |

---

## 完了基準

- [x] Phase 1: 高優先度改善（Task tool メトリクス、/debug 連携、PDF）
- [x] Phase 2: 中優先度改善（Git log、MCP アクセス、メモリ最適化）
- [x] Phase 3: 低優先度改善（OAuth、Reduced Motion）
- [x] Phase 4: ドキュメント更新
- [ ] テスト検証
- [ ] リリース

---

## 技術決定事項

| 項目 | 決定 | 根拠 |
|------|------|------|
| Task tool メトリクス | AgentTrace v0.3.0 で対応 | 既存スキーマを拡張 |
| `/debug` 連携 | troubleshoot スキルから誘導 | 既存フローへの統合 |
| PDF ページ範囲 | notebookLM/harness-review で活用 | 大型ドキュメント対応 |
| サブエージェント MCP | Codex 統合で活用 | 並列レビューでの MCP 共有 |

---

## 優先度マトリクス

| Priority | Feature | Impact | Effort |
|----------|---------|--------|--------|
| 🔴 Required | Task tool メトリクス | High | Medium |
| 🔴 Required | `/debug` 連携 | High | Low |
| 🟡 Recommended | PDF ページ範囲 | Medium | Low |
| 🟡 Recommended | Git log フラグ | Medium | Low |
| 🟢 Optional | OAuth 認証 | Low | Medium |
| 🟢 Optional | Reduced Motion | Low | Low |

---

## Codex レビュー検証結果

### ✅ 採用した指摘

| 指摘 | 対応 | 検証結果 |
|------|------|---------|
| OAuth 手順が弱い | 3.1 で対応 | codex-mcp-setup.md に具体的手順がない → 追記必要 |
| メモリ最適化の具体化 | 2.3 で対応 | session-control で `--resume` 多用 → 恩恵説明追加 |

### ❌ 不採用とした指摘（Harness で該当なし）

| 指摘 | 検証結果 |
|------|---------|
| 大型 PDF `@` 参照対応 | Harness で PDF `@` 参照を使用していない |
| TaskStop 結果表示対応 | "Task stopped" をパースするコードなし |
| `/model` 即時実行対応 | 依存するワークフローなし |
| Slack MCP 統合 | 範囲外、別企画として分離 |

---

# Harness 紹介資料・動画アップデートプラン

## 概要

Harness v2.17.x の価値を「成果ベース」で伝える紹介資料と動画を作成する。

### 核心メッセージ（一文）

> **「AIコーディングの手戻りを80%削減し、品質を担保する自律型ワークフロー」**

### 成果物

1. **NotebookLM用スライドYAML** - 2案（ミニマル案 + エディトリアル案）
2. **紹介動画**（音声付き） - 90秒ティザー

---

## 訴求設計（Codexレビュー反映）

### ストーリー構造: 成果 → 仕組み → 証拠 → CTA

| 現行（NG） | 改善後（OK） |
|-----------|-------------|
| 問題→機能→機能→機能 | 成果→仕組み→証拠→CTA |
| 機能の羅列 | 成果ベースの一文 |
| 証拠なし | Before/After + 数字 |

### ターゲット別訴求

| ターゲット | 刺さる軸 | 訴求ポイント |
|-----------|---------|-------------|
| **開発者** | すぐ使える・手戻り削減 | 3コマンドで即導入、レビュー自動化 |
| **チームリード** | 標準化・品質一貫性 | チーム全員が同じワークフロー |
| **経営層** | リスク低減・ROI | 手戻り80%削減、予測可能な開発速度 |

---

## Phase A: スライド資料（10枚・成果ベース構成）

| Task | 内容 | Status |
|------|------|--------|
| A.1 | `/notebookLM slides` でヒアリング＆YAML生成 | `cc:DONE` |

**スライド構成（改善版）**:

| No. | スライド | 内容 |
|-----|---------|------|
| 1 | 表紙 | 一文の成果メッセージ |
| 2 | 痛み | AI暴走で発生する具体損失（手戻り、品質低下） |
| 3 | 約束 | 「手戻り80%削減、品質担保」の一文 |
| 4 | 仕組み | Plan → Work → Review |
| 5 | 証拠 | Before/After の具体結果 |
| 6 | 差別化 | 他のAI支援との違い（自律型ワークフロー） |
| 7 | 代表機能1 | /ultrawork（成果と直結） |
| 8 | 代表機能2 | 4視点レビュー（成果と直結） |
| 9 | 導入方法 | 3ステップで即導入 |
| 10 | CTA | 具体的な次の一手 |

---

## Phase B: 紹介動画（10-12分フル紹介）

| Task | 内容 | Status |
|------|------|--------|
| B.1 | `/generate-video` でシナリオ確認＆生成 | `cc:DONE` |

### カラーパレット（ハイブリッド）

**Cyberpunk + Corporate可読性**:
- 背景: `#0A0A0F`（ダークベース）
- 本文: 白（可読性）
- 強調: `#00F5FF`（シアン）+ `#FF6B35`（オレンジ）
- マゼンタ: **使わない**（安っぽく見える）

### シーン構成（10-12分フル紹介）

| 時間 | セグメント | 視覚効果 | 内容 |
|------|-----------|----------|------|
| 0:00-0:20 | 結果提示 | `Split-screen` | **Before/Afterを先に見せる** |
| 0:20-1:30 | コアループ | `3D Parallax` | Plan → Work → Review |
| 1:30-2:30 | /ultrawork | `ProgressBar` + 実演 | 自動反復デモ |
| 2:30-3:30 | 45スキル | `Particles` | 自動ロードの仕組み |
| 3:30-4:30 | Codex並列 | `ProgressBar` ×5 | 最大5並列実行 |
| 4:30-5:30 | 4視点レビュー | `3D Parallax` | セキュリティ/パフォーマンス/品質/保守性 |
| 5:30-6:30 | 2-Agent連携 | `Split-screen` | PM↔実装役の連携 |
| 6:30-7:30 | セッション管理 | 最小限演出 | メモリ永続化 |
| 7:30-8:30 | Worktree最適化 | 最小限演出 | 自動スキップ |
| 8:30-10:30 | **1ユースケース完走** | 実演中心 | 時間短縮の証明 |
| 10:30-12:00 | 導入判断+CTA | `Particles(収束)` | 次のアクション |

### 視覚設計の原則

| 原則 | 理由 |
|------|------|
| **最初の20秒で結末を見せる** | 先に結果を見せて興味を引く |
| **各セグメント60-90秒** | 長すぎると離脱 |
| **進捗バー常時表示** | 今どこかを明示 |
| **数字は必ずアニメ** | 静的数値は読まれない |
| **意味のある演出のみ** | 開発者は無意味な派手さを嫌う |

---

## 完了基準

- [x] Phase A: スライドYAML 2案完成
  - 成果物: `remotion/src/deep-dive/` (Remotion コンポーネント)
  - 検証: 10セクション構成、必須項目（タイトル、痛み、仕組み、CTA）を含む

- [x] Phase B: 紹介動画（10-12分フル紹介動画）完成
  - 成果物: `docs/video/harness-intro-narration.md` (ナレーション原稿)
  - 検証: 10-12分相当、セクション構成完備
  - **スコープ変更**: 2026-02-04 90秒ティザー → 10-12分フル紹介に拡張（理由: 全機能紹介のため）

---

## 参考資料

- 既存スライド: `docs/images/slides/2.6.0/`
- NotebookLMスキル: `skills/notebookLM/`
- generate-videoスキル: `skills/generate-video/`

---

# プラグイン配布対象外ファイルの整理

## 概要

Claude Code Harness プラグインとして配布すべきでないファイル/フォルダを .gitignore に追加し、ルート直下のフォルダ構成を整理する。

## 現状分析

### ルート直下のフォルダ一覧

| フォルダ | 状態 | 配布対象 | 判定理由 |
|---------|------|---------|---------|
| `.claude-plugin/` | Git追跡済 | ✅ 配布 | プラグインマニフェスト |
| `.claude/` | 部分追跡 | ✅ 部分配布 | rules のみ配布 |
| `.cursor/` | 未追跡 | ❌ 除外 | ローカル開発用 |
| `.github/` | Git追跡済 | ✅ 配布 | CI/CD 設定 |
| `.githooks/` | Git追跡済 | ✅ 配布 | Git フック |
| `.serena/` | 未追跡 | ❌ 除外済 | MCP ローカル設定 |
| `.opencode/` | 未追跡 | ❌ 除外済 | OpenCode ローカル |
| `.cache/` | 未追跡 | ❌ 除外 | キャッシュ |
| `.playwright-mcp/` | 未追跡 | ❌ 除外済 | テスト用 |
| `agents/` | Git追跡済 | ✅ 配布 | サブエージェント定義 |
| `app/` | 未追跡 | ❌ 除外 | 実験的コード（未使用） |
| `benchmarks/` | 未追跡 | ❌ 除外済 | ベンチマーク |
| `codex/` | Git追跡済 | ✅ 配布 | Codex CLI 統合 |
| `commands/` | Git追跡済 | ✅ 配布 | レガシーコマンド |
| `docs/` | 部分追跡 | ✅ 部分配布 | 公開ドキュメントのみ |
| `frontend/` | 未追跡 | ❌ 除外 | 実験的コード（未使用） |
| `harness-ui/` | Git追跡済 | ✅ 配布 | UI コンポーネント |
| `harness-ui-archive/` | 未追跡 | ❌ 除外済 | 廃止版 |
| `hooks/` | Git追跡済 | ✅ 配布 | ライフサイクルフック |
| `image/` | 未追跡 | ❌ 除外 | X投稿用画像（ローカル） |
| `mcp-server/` | 未追跡 | ❌ 除外済 | MCP サーバー（別配布） |
| `opencode/` | Git追跡済 | ✅ 配布 | OpenCode 統合 |
| `profiles/` | Git追跡済 | ✅ 配布 | プロファイル |
| `remotion/` | 未追跡 | ❌ 除外済 | 動画生成（ローカル） |
| `scripts/` | Git追跡済 | ✅ 配布 | スクリプト |
| `skills/` | Git追跡済 | ✅ 配布 | スキル定義 |
| `src/` | 未追跡 | ❌ 除外 | 実験的コード（未使用） |
| `templates/` | Git追跡済 | ✅ 配布 | テンプレート |
| `tests/` | Git追跡済 | ✅ 配布 | テスト |
| `Users/` | 未追跡 | ❌ 削除 | 誤作成（絶対パス残骸） |
| `workflows/` | Git追跡済 | ✅ 配布 | ワークフロー |

### ルート直下のファイル一覧

| ファイル | 状態 | 配布対象 | 判定理由 |
|---------|------|---------|---------|
| `CC-harness.code-workspace` | 未追跡 | ❌ 除外 | VS Code workspace（ローカル） |
| `TEST_CURSOR_INTEGRATION.md` | Git追跡済 | ❓ 検討 | テストドキュメント |
| `DEVELOPMENT_FLOW_GUIDE.md` | Git追跡済 | ✅ 配布 | 開発ガイド |
| `IMPLEMENTATION_GUIDE.md` | Git追跡済 | ✅ 配布 | 実装ガイド |

---

## Phase 1: .gitignore 追加項目

| Task | 内容 | Status |
|------|------|--------|
| 1.1 | `.cache/` を .gitignore に追加 | `cc:DONE` |
| 1.2 | `app/` を .gitignore に追加（実験的コード） | `cc:DONE` |
| 1.3 | `frontend/` を .gitignore に追加（実験的コード） | `cc:DONE` |
| 1.4 | `src/` を .gitignore に追加（実験的コード） | `cc:DONE` |
| 1.5 | `image/` を .gitignore に追加（X投稿用画像） | `cc:DONE` |
| 1.6 | `*.code-workspace` を .gitignore に追加 | `cc:DONE` |

---

## Phase 2: 不要フォルダの削除

| Task | 内容 | Status |
|------|------|--------|
| 2.1 | `Users/` フォルダを削除（誤作成の絶対パス残骸） | `cc:DONE` |

---

## Phase 3: 検証

| Task | 内容 | Status |
|------|------|--------|
| 3.1 | `git status` で変更確認 | `cc:DONE` |
| 3.2 | `./tests/validate-plugin.sh` で構造検証 | `cc:DONE` |

---

## 完了基準

- [x] Phase 1: .gitignore 追加完了
- [x] Phase 2: 不要フォルダ削除完了
- [x] Phase 3: 検証完了

---

## 補足: 配布対象の判定基準

| 基準 | 配布対象 | 配布対象外 |
|------|---------|-----------|
| プラグイン機能 | ✅ | - |
| 開発者向けドキュメント | ✅ | - |
| ローカル開発用ファイル | - | ❌ |
| 実験的・未完成コード | - | ❌ |
| 個人用アセット（画像等） | - | ❌ |
| IDE 設定 | - | ❌ |
| 別途配布するコンポーネント | - | ❌ |
