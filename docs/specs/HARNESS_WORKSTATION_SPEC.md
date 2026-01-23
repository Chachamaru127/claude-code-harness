# Harness Workstation 仕様書

> harness-ui を拡張し、全ての作業をUIから実行可能にする統合ワークステーション

---

## 概要

### ビジョン

```
現状: CLIベースの断片的な操作
      ↓
目標: UIからPlan→Work→Review→Evaluate全てを完結
      + Gateway制御プレーンで複数クライアント統合
```

### 価値提案

1. **統一されたワークフロー**: ダッシュボードから全フェーズを管理
2. **評価の可視化**: Scorecard/メトリクスをリアルタイムで確認
3. **ナレッジの一元管理**: SSOT（decisions.md, patterns.md）の閲覧・編集
4. **セッション管理**: 複数プロジェクト・複数ターミナルの並列管理
5. **Gateway統合**: 複数クライアント（CLI/Web/Slack/Discord）からの統一アクセス
6. **Canvas UI**: エージェント駆動のビジュアルワークスペース

---

## アーキテクチャ

### Gateway 制御プレーン（Clawdbot inspired）

```
                    ┌─────────────────────────────────────┐
                    │     Harness Gateway (port 37778)    │
                    │     WebSocket Control Plane         │
                    └──────────────┬──────────────────────┘
                                   │
        ┌──────────────┬───────────┼───────────┬──────────────┐
        │              │           │           │              │
   ┌────▼────┐   ┌─────▼────┐ ┌────▼────┐ ┌────▼────┐  ┌──────▼─────┐
   │   CLI   │   │  Web UI  │ │  Slack  │ │ Discord │  │  Webhook   │
   │ (claude)│   │(harness) │ │   Bot   │ │   Bot   │  │  (CI/CD)   │
   └─────────┘   └──────────┘ └─────────┘ └─────────┘  └────────────┘
```

**Gateway の役割**:
- セッション管理（複数クライアント間で共有）
- イベント配信（ログ、状態変更、通知）
- 認証・認可（APIキー、ペアリング）
- ツール実行の中継

### 現状 → 拡張後

```
現状 (3 pages):
┌─────────────────────────────────────────┐
│  Dashboard │ Work │ Settings            │
└─────────────────────────────────────────┘

拡張後 (7 pages + サイドパネル):
┌─────────────────────────────────────────────────────────────────────┐
│  Dashboard │ Work │ Canvas │ Evals │ Memory │ Skills │ Settings    │
└─────────────────────────────────────────────────────────────────────┘
       │         │       │       │       │         │
       │         │       │       │       │         └── スキル一覧 + レジストリ
       │         │       │       │       └── SSOT 閲覧・編集
       │         │       │       └── 評価実行・Scorecard
       │         │       └── ビジュアルワークスペース（NEW）
       │         └── ターミナル作業（既存）
       └── 概要・Plans・クイックアクション（既存拡張）
```

### コンポーネント階層

```
harness-ui/src/client/
├── App.tsx                    # ルーティング拡張
├── components/
│   ├── Dashboard/             # 既存拡張
│   │   ├── index.tsx
│   │   ├── PlansBoard.tsx     # 既存
│   │   ├── ProgressSummary.tsx # 既存
│   │   ├── QuickActions.tsx   # NEW: ワンクリックコマンド
│   │   └── HealthScore.tsx    # NEW: プロジェクト健全性
│   │
│   ├── Work/                  # 既存
│   │   ├── index.tsx
│   │   └── Terminal.tsx
│   │
│   ├── Evals/                 # NEW
│   │   ├── index.tsx          # 評価ページ
│   │   ├── Scorecard.tsx      # Scorecard 表示
│   │   ├── TaskRunner.tsx     # タスク実行UI
│   │   ├── ResultsTable.tsx   # 結果テーブル
│   │   ├── ComparisonChart.tsx # with/no-plugin 比較
│   │   └── TranscriptViewer.tsx # ログ分析
│   │
│   ├── Memory/                # NEW
│   │   ├── index.tsx          # メモリページ
│   │   ├── DecisionsView.tsx  # decisions.md 閲覧
│   │   ├── PatternsView.tsx   # patterns.md 閲覧
│   │   └── MarkdownEditor.tsx # 編集機能
│   │
│   ├── Skills/                # NEW
│   │   ├── index.tsx          # スキルページ
│   │   ├── SkillCard.tsx      # スキル表示
│   │   ├── SkillFilter.tsx    # カテゴリフィルタ
│   │   └── SkillDetail.tsx    # 詳細表示
│   │
│   └── shared/                # 共通
│       ├── CommandPalette.tsx # Cmd+K
│       ├── Sidebar.tsx        # サイドバー
│       └── StatusBar.tsx      # フッター状態
```

---

## ページ仕様

### 1. Dashboard（既存拡張）

**目的**: プロジェクト概要とクイックアクション

```
┌─────────────────────────────────────────────────────────────┐
│ [Project: my-app ▼]                         Connected ●    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Health Score │  │ Progress     │  │ Quick Actions│      │
│  │    85%       │  │ 12/20 tasks  │  │ [/plan]      │      │
│  │    ▲ +5%     │  │ ████░░ 60%   │  │ [/work]      │      │
│  └──────────────┘  └──────────────┘  │ [/review]    │      │
│                                       └──────────────┘      │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Plans.md                                             │   │
│  │ ┌─────────────────────────────────────────────────┐ │   │
│  │ │ ☑ Design API endpoints                          │ │   │
│  │ │ ⬜ Implement authentication                      │ │   │
│  │ │ ⬜ Write tests                                   │ │   │
│  │ └─────────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Common Terminal (Wall-打ち)                          │   │
│  │ $ claude /plan-with-agent ユーザー管理機能_         │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**新規コンポーネント**:
- `HealthScore`: 評価結果ベースのスコア
- `QuickActions`: `/plan`, `/work`, `/review` ワンクリック実行

### 2. Work（既存）

**目的**: ターミナルベースの作業

既存機能を維持。改善点:
- フルスクリーンターミナルモード
- 複数ターミナルのタブ切り替え

### 3. Canvas（新規 - Clawdbot A2UI inspired）

**目的**: エージェント駆動のビジュアルワークスペース

```
┌─────────────────────────────────────────────────────────────┐
│ Canvas                              [Layers ▼] [Export 📤] │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                                                     │   │
│  │     ┌──────────┐      ┌──────────┐                 │   │
│  │     │ Plans.md │─────▶│ src/     │                 │   │
│  │     │ ████████ │      │ auth.ts  │                 │   │
│  │     └──────────┘      └────┬─────┘                 │   │
│  │                            │                        │   │
│  │                       ┌────▼─────┐                 │   │
│  │                       │ tests/   │                 │   │
│  │                       │ auth.test│                 │   │
│  │                       └──────────┘                 │   │
│  │                                                     │   │
│  │  [+ Add Node]  [🔗 Connect]  [📝 Annotate]         │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Agent Log                                            │   │
│  │ 10:30 Created node: Plans.md                         │   │
│  │ 10:31 Connected: Plans.md → src/auth.ts              │   │
│  │ 10:32 Agent suggestion: "Add test coverage node"     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**機能**:
1. **ノードベースビュー**: ファイル、タスク、依存関係をノードとして可視化
2. **エージェント駆動**: Claudeが自動でノード追加・接続を提案
3. **リアルタイム同期**: ファイル変更がCanvasに即反映
4. **エクスポート**: SVG/PNG/Mermaid形式で出力

**ユースケース**:
- アーキテクチャの可視化
- タスク依存関係のマッピング
- コードフローの理解

**API エンドポイント**:
```typescript
// GET /api/canvas/:projectId - Canvas 状態取得
// PUT /api/canvas/:projectId - Canvas 状態更新
// POST /api/canvas/:projectId/nodes - ノード追加
// POST /api/canvas/:projectId/edges - エッジ追加
// GET /api/canvas/:projectId/export?format=svg - エクスポート
```

### 4. Evals（新規）

**目的**: 評価の実行と結果の可視化

```
┌─────────────────────────────────────────────────────────────┐
│ Evals                                     [Run All] [Run ▼]│
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Latest Scorecard (v1)              2026-01-18 10:30 │   │
│  │ ┌──────────────────────────────────────────────────┐│   │
│  │ │           with-plugin    no-plugin    Δ         ││   │
│  │ │ Pass Rate     87.5%        62.5%     +25.0%     ││   │
│  │ │ Avg Score      0.82         0.65     +0.17      ││   │
│  │ │ Time (med)    45.2s        62.1s     -27.2%     ││   │
│  │ │ Cost (med)   $0.023       $0.031     -25.0%     ││   │
│  │ └──────────────────────────────────────────────────┘│   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Task Results                                         │   │
│  │ ┌────────────────┬────────┬────────┬──────────────┐│   │
│  │ │ Task           │ Status │ Score  │ Duration     ││   │
│  │ ├────────────────┼────────┼────────┼──────────────┤│   │
│  │ │ plan-feature   │ ✓ PASS │ 0.95   │ 32.1s        ││   │
│  │ │ impl-utility   │ ✓ PASS │ 0.88   │ 41.2s        ││   │
│  │ │ review-security│ ✗ FAIL │ 0.45   │ 55.3s   [▶]  ││   │
│  │ └────────────────┴────────┴────────┴──────────────┘│   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Transcript Viewer                  [review-security] │   │
│  │ ─────────────────────────────────────────────────── │   │
│  │ 10:30:01 | Tool: Read | file: src/auth.ts           │   │
│  │ 10:30:05 | Tool: Grep | pattern: password           │   │
│  │ 10:30:12 | [ERROR] Security check failed            │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**機能**:
1. **Scorecard 表示**: 最新の評価結果をサマリー表示
2. **タスク実行**: 個別タスク or 全タスクの実行
3. **結果テーブル**: タスクごとの Pass/Fail、スコア、時間
4. **比較チャート**: with-plugin vs no-plugin のビジュアル比較
5. **Transcript Viewer**: 失敗時のログ分析

**API エンドポイント**:
```typescript
// GET /api/evals/scorecards - Scorecard 一覧
// GET /api/evals/scorecards/:id - Scorecard 詳細
// POST /api/evals/run - 評価実行
// GET /api/evals/transcripts/:id - Transcript 取得
```

### 4. Memory（新規）

**目的**: SSOT の閲覧・編集

```
┌─────────────────────────────────────────────────────────────┐
│ Memory                           [decisions] [patterns] [+]│
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ decisions.md                              [Edit ✏️]  │   │
│  │ ─────────────────────────────────────────────────── │   │
│  │ # アーキテクチャ決定                                 │   │
│  │                                                       │   │
│  │ ## 2026-01-15: 3層アーキテクチャ採用                 │   │
│  │ - Skills → Rules → Hooks                            │   │
│  │ - 理由: 関心の分離と段階的強制                       │   │
│  │                                                       │   │
│  │ ## 2026-01-10: YAML frontmatter 標準化               │   │
│  │ - description + description-en 必須                  │   │
│  │ - name フィールド禁止                                │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ patterns.md                               [Edit ✏️]  │   │
│  │ ─────────────────────────────────────────────────── │   │
│  │ # 再利用パターン                                     │   │
│  │                                                       │   │
│  │ ## ファイル変更時の検証                              │   │
│  │ ```bash                                              │   │
│  │ npm run build && npm test                            │   │
│  │ ```                                                  │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**機能**:
1. **Markdown 表示**: decisions.md, patterns.md のレンダリング
2. **インライン編集**: 編集モードで直接修正
3. **履歴表示**: git diff による変更履歴
4. **検索**: コンテンツ検索

**API エンドポイント**:
```typescript
// GET /api/memory/decisions - decisions.md 取得
// PUT /api/memory/decisions - decisions.md 更新
// GET /api/memory/patterns - patterns.md 取得
// PUT /api/memory/patterns - patterns.md 更新
// GET /api/memory/history/:file - 変更履歴
```

### 6. Skills（新規 - Registry拡張）

**目的**: スキルの一覧・管理 + レジストリからのインストール

```
┌─────────────────────────────────────────────────────────────┐
│ Skills                [Installed] [Registry] [Filter ▼]    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─ Installed ──────────────────────────────────────────┐  │
│  │ ┌────────────────┐  ┌────────────────┐  ┌───────────┐│  │
│  │ │ planning    ✓  │  │ reviewing   ✓  │  │ testing ✓ ││  │
│  │ │ ───────────────│  │ ───────────────│  │ ──────────││  │
│  │ │ 📝 plan        │  │ 🔍 code-review │  │ 🧪 tdd    ││  │
│  │ │ 📋 decompose   │  │ 🔒 security    │  │ ✅ test   ││  │
│  │ └────────────────┘  └────────────────┘  └───────────┘│  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─ Registry (HarnessHub) ──────────────────────────────┐  │
│  │ ┌────────────────────────────────────────────────────┐│  │
│  │ │ 🌐 api-design          by @community    [Install] ││  │
│  │ │ 🔐 owasp-security      by @official     [Install] ││  │
│  │ │ 📊 metrics-dashboard   by @community    [Install] ││  │
│  │ └────────────────────────────────────────────────────┘│  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Skill Detail: code-review                 [Disable]  │   │
│  │ ─────────────────────────────────────────────────── │   │
│  │ Description: コードレビューを実行する                │   │
│  │ Allowed Tools: Read, Grep, Edit, Bash                │   │
│  │ Triggers: /harness-review, explicit request          │   │
│  │ Version: 1.2.0  |  Author: @official                 │   │
│  │                                                       │   │
│  │ [View Source] [Update Available: 1.3.0]              │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**機能**:
1. **スキル一覧**: カテゴリ別にグループ化
2. **フィルタリング**: カテゴリ、キーワードでフィルタ
3. **詳細表示**: スキルの内容、許可ツール、トリガー
4. **状態表示**: アクティブ/非アクティブ
5. **レジストリ連携**: HarnessHub からスキルをブラウズ・インストール（NEW）
6. **バージョン管理**: スキルの更新通知・アップグレード（NEW）
7. **有効/無効切替**: プロジェクト単位でスキルを制御（NEW）

**API エンドポイント**:
```typescript
// GET /api/skills - インストール済みスキル一覧
// GET /api/skills/:id - スキル詳細
// GET /api/skills/categories - カテゴリ一覧
// POST /api/skills/:id/enable - スキル有効化
// POST /api/skills/:id/disable - スキル無効化
// GET /api/registry/skills - レジストリからスキル検索
// POST /api/registry/skills/:id/install - スキルインストール
// POST /api/skills/:id/upgrade - スキルアップグレード
```

### 7. Settings（既存拡張 + 統合設定）

**追加項目**:
- 評価設定（trials 数、タイムアウト）
- UI テーマ
- キーボードショートカット設定
- **通知連携**（NEW）
- **Gateway 設定**（NEW）

```
┌─────────────────────────────────────────────────────────────┐
│ Settings                                                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─ General ────────────────────────────────────────────┐  │
│  │ Theme:        [Dark ▼]                               │  │
│  │ Language:     [日本語 ▼]                              │  │
│  │ Shortcuts:    [Customize...]                         │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─ Integrations（Clawdbot inspired）───────────────────┐  │
│  │                                                       │  │
│  │ Slack         [Connect]     ○ Disconnected           │  │
│  │ Discord       [Connect]     ○ Disconnected           │  │
│  │ Webhook       [Configure]   ● 2 endpoints active     │  │
│  │                                                       │  │
│  │ ─────────────────────────────────────────────────── │  │
│  │ Notification Rules:                                  │  │
│  │ ┌────────────────────────────────────────────────┐  │  │
│  │ │ On: Task Complete  → Slack #dev-notifications │  │  │
│  │ │ On: Review Fail    → Discord @maintainers     │  │  │
│  │ │ On: Eval Complete  → Webhook (CI)             │  │  │
│  │ └────────────────────────────────────────────────┘  │  │
│  │ [+ Add Rule]                                         │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─ Gateway ────────────────────────────────────────────┐  │
│  │ Port:         37778                                  │  │
│  │ API Key:      [Regenerate]   hns_****...****         │  │
│  │ Paired:       3 clients (CLI, Web, Slack)            │  │
│  │                                                       │  │
│  │ Security:                                            │  │
│  │ ☑ Require pairing for new clients                   │  │
│  │ ☑ Auto-approve local connections                    │  │
│  │ ☐ Allow remote access (Tailscale)                   │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─ Evals ──────────────────────────────────────────────┐  │
│  │ Default trials:    [3 ▼]                             │  │
│  │ Timeout (seconds): [300]                             │  │
│  │ Model:             [claude-sonnet-4-20250514 ▼]           │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

**通知連携の仕組み**:
```
イベント発生 → Gateway → 通知ルール評価 → 配信
                              │
            ┌─────────────────┼─────────────────┐
            ▼                 ▼                 ▼
         Slack API      Discord API       Webhook POST
```

---

## 共通機能

### Command Palette（Cmd+K）

```
┌─────────────────────────────────────────────────────────────┐
│ > Run command...                                            │
│ ─────────────────────────────────────────────────────────── │
│  /plan-with-agent   Start planning with agent              │
│  /work              Start work phase                        │
│  /harness-review    Run code review                         │
│  eval:run           Run evaluation suite                    │
│  memory:decisions   Open decisions.md                       │
│  memory:patterns    Open patterns.md                        │
└─────────────────────────────────────────────────────────────┘
```

### Status Bar

```
┌─────────────────────────────────────────────────────────────┐
│ 🟢 Connected │ my-app │ Phase: WORK │ 3 terminals │ v2.7.6 │
└─────────────────────────────────────────────────────────────┘
```

---

## 型定義拡張

```typescript
// src/shared/types.ts への追加

// Page 拡張
export type Page = 'dashboard' | 'work' | 'evals' | 'memory' | 'skills' | 'settings';

// Scorecard 型
export interface Scorecard {
  id: string;
  meta: ScorecardMeta;
  summary: ScorecardSummary;
  tasks: TaskResult[];
  trials: TrialResult[];
}

export interface ScorecardMeta {
  suite_version: string;
  harness_version: string;
  harness_commit: string;
  generated_at: string;
  os: string;
  os_version: string;
  cost_assumption: string;
  trials: number;
}

export interface ScorecardSummary {
  with_plugin: ModeStats;
  no_plugin: ModeStats;
  comparison: Comparison;
}

export interface ModeStats {
  pass_rate: number;
  grade_score_avg: number;
  duration_median_seconds: number;
  estimated_cost_median_usd: number;
  total_trials: number;
}

export interface Comparison {
  pass_rate_diff: number;
  duration_improvement_pct: number;
  cost_improvement_pct: number;
}

export interface TaskResult {
  task: string;
  with_plugin: { pass_rate: number; grade_score_avg: number; duration_median: number };
  no_plugin: { pass_rate: number; grade_score_avg: number; duration_median: number };
}

export interface TrialResult {
  task: string;
  mode: 'with-plugin' | 'no-plugin';
  iteration: number;
  pass: boolean;
  score: number;
  duration: number;
  checks: Check[];
}

export interface Check {
  name: string;
  status: 'pass' | 'fail';
  required: boolean;
}

// Memory 型
export interface MemoryFile {
  path: string;
  content: string;
  lastModified: string;
}

// Skill 型
export interface Skill {
  id: string;
  name: string;
  description: string;
  category: string;
  allowedTools: string[];
  content: string;
  triggers: string[];
}
```

---

## サーバー拡張

### 新規ルート

```typescript
// src/server/routes/evals.ts
// src/server/routes/memory.ts
// src/server/routes/skills.ts
```

### 新規サービス

```typescript
// src/server/services/scorecard-parser.ts
// src/server/services/memory-manager.ts
// src/server/services/skill-catalog.ts
```

---

## 実装フェーズ

### Phase 1: 基盤整備 + Gateway
- [ ] Page 型拡張、ナビゲーション更新
- [ ] 共通コンポーネント（CommandPalette, StatusBar）
- [ ] API ルート基盤
- [ ] **Gateway 制御プレーン基盤**（NEW）
- [ ] **WebSocket イベント配信システム**（NEW）

### Phase 2: Evals ページ
- [ ] Scorecard 表示
- [ ] タスク実行 UI
- [ ] 結果テーブル
- [ ] Transcript Viewer

### Phase 3: Memory ページ
- [ ] Markdown 表示
- [ ] インライン編集
- [ ] 履歴表示

### Phase 4: Skills ページ + Registry
- [ ] スキル一覧
- [ ] フィルタリング
- [ ] 詳細表示
- [ ] **HarnessHub レジストリ連携**（NEW）
- [ ] **スキルインストール/更新**（NEW）

### Phase 5: Dashboard 拡張
- [ ] HealthScore
- [ ] QuickActions
- [ ] 統合ビュー

### Phase 6: Canvas（NEW）
- [ ] ノードベースビュー基盤
- [ ] ファイル/タスクノード表示
- [ ] エッジ（依存関係）管理
- [ ] エージェント提案機能
- [ ] エクスポート（SVG/Mermaid）

### Phase 7: Integrations（NEW）
- [ ] Slack 連携（OAuth + Bot）
- [ ] Discord 連携（Bot）
- [ ] Webhook 配信
- [ ] 通知ルールエンジン

### Phase 8: Advanced（Future）
- [ ] 音声統合（Voice Wake）
- [ ] モバイルアプリ連携
- [ ] リモートアクセス（Tailscale）

---

## 技術制約（既存ルール準拠）

- ❌ `any` 型禁止（`unknown` を使用）
- ✅ 関数コンポーネント + 明示的な Props 型
- ✅ `useMemo`, `useCallback` で不要な再計算防止
- ✅ 空の catch ブロック禁止
- ✅ `npm run build` で変更後ビルド確認
- ✅ Tailwind CSS デフォルト値を使用
- ✅ アニメーションは `transform`/`opacity` のみ
- ✅ グラデーション・紫色禁止

---

## 競合分析・参考

### Clawdbot（参考）

| 機能 | Clawdbot | Harness Workstation | 取り入れ方 |
|------|----------|---------------------|-----------|
| Gateway | ✅ ws://127.0.0.1:18789 | ✅ ws://127.0.0.1:37778 | 制御プレーンとして採用 |
| マルチチャンネル | ✅ 11+ (WhatsApp等) | ✅ 3 (Slack/Discord/Webhook) | 開発者向けに絞って実装 |
| Canvas/A2UI | ✅ エージェント駆動UI | ✅ ノードベースビュー | 簡易版として実装 |
| 音声統合 | ✅ Voice Wake | △ Future | Phase 8 で検討 |
| スキルレジストリ | ✅ ClawdHub | ✅ HarnessHub | 同等機能として実装 |
| デバイス統合 | ✅ macOS/iOS/Android | ✗ 対象外 | 開発ワークステーション特化 |

### 差別化ポイント

```
Clawdbot:     パーソナルAIアシスタント（汎用）
              ↓
Harness:      開発者向けワークステーション（特化）
              + 評価機構（Scorecard）
              + SSOT管理（Memory）
              + Plan→Work→Reviewワークフロー
```

---

## 関連ドキュメント

- [harness-ui ルール](../../.claude/rules/harness-ui.md)
- [UI スキル制約](../../skills/ui/references/ui-skills.md)
- [Scorecard 仕様](../SCORECARD_SPEC.md)
- [評価 Playbook](../EVALS_PLAYBOOK.md)
- [Terminal 仕様](./TERMINAL_SPEC.md)
