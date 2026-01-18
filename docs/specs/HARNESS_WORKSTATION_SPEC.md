# Harness Workstation 仕様書

> harness-ui を拡張し、全ての作業をUIから実行可能にする統合ワークステーション

---

## 概要

### ビジョン

```
現状: CLIベースの断片的な操作
      ↓
目標: UIからPlan→Work→Review→Evaluate全てを完結
```

### 価値提案

1. **統一されたワークフロー**: ダッシュボードから全フェーズを管理
2. **評価の可視化**: Scorecard/メトリクスをリアルタイムで確認
3. **ナレッジの一元管理**: SSOT（decisions.md, patterns.md）の閲覧・編集
4. **セッション管理**: 複数プロジェクト・複数ターミナルの並列管理

---

## アーキテクチャ

### 現状 → 拡張後

```
現状 (3 pages):
┌─────────────────────────────────────────┐
│  Dashboard │ Work │ Settings            │
└─────────────────────────────────────────┘

拡張後 (6 pages + サイドパネル):
┌─────────────────────────────────────────────────────────────┐
│  Dashboard │ Work │ Evals │ Memory │ Skills │ Settings     │
└─────────────────────────────────────────────────────────────┘
       │         │       │       │         │
       │         │       │       │         └── スキル一覧・状態
       │         │       │       └── SSOT 閲覧・編集
       │         │       └── 評価実行・Scorecard
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

### 3. Evals（新規）

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

### 5. Skills（新規）

**目的**: スキルの一覧と状態確認

```
┌─────────────────────────────────────────────────────────────┐
│ Skills                     [All ▼] [Filter: planning ✕]    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐│
│  │ planning       │  │ reviewing      │  │ testing        ││
│  │ ───────────────│  │ ───────────────│  │ ───────────────││
│  │ 📝 plan        │  │ 🔍 code-review │  │ 🧪 tdd         ││
│  │ 📋 decompose   │  │ 🔒 security    │  │ ✅ test-first  ││
│  │ 🎯 scope       │  │ 📊 quality     │  │ 🔄 regression  ││
│  └────────────────┘  └────────────────┘  └────────────────┘│
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Skill Detail: code-review                            │   │
│  │ ─────────────────────────────────────────────────── │   │
│  │ Description: コードレビューを実行する                │   │
│  │ Allowed Tools: Read, Grep, Edit, Bash                │   │
│  │ Triggers: /harness-review, explicit request          │   │
│  │                                                       │   │
│  │ Content:                                              │   │
│  │ ```markdown                                          │   │
│  │ # Code Review Skill                                  │   │
│  │ レビュー時は以下の観点で確認...                      │   │
│  │ ```                                                  │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**機能**:
1. **スキル一覧**: カテゴリ別にグループ化
2. **フィルタリング**: カテゴリ、キーワードでフィルタ
3. **詳細表示**: スキルの内容、許可ツール、トリガー
4. **状態表示**: アクティブ/非アクティブ

**API エンドポイント**:
```typescript
// GET /api/skills - スキル一覧
// GET /api/skills/:id - スキル詳細
// GET /api/skills/categories - カテゴリ一覧
```

### 6. Settings（既存拡張）

**追加項目**:
- 評価設定（trials 数、タイムアウト）
- UI テーマ
- キーボードショートカット設定

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

### Phase 1: 基盤整備
- [ ] Page 型拡張、ナビゲーション更新
- [ ] 共通コンポーネント（CommandPalette, StatusBar）
- [ ] API ルート基盤

### Phase 2: Evals ページ
- [ ] Scorecard 表示
- [ ] タスク実行 UI
- [ ] 結果テーブル
- [ ] Transcript Viewer

### Phase 3: Memory ページ
- [ ] Markdown 表示
- [ ] インライン編集
- [ ] 履歴表示

### Phase 4: Skills ページ
- [ ] スキル一覧
- [ ] フィルタリング
- [ ] 詳細表示

### Phase 5: Dashboard 拡張
- [ ] HealthScore
- [ ] QuickActions
- [ ] 統合ビュー

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

## 関連ドキュメント

- [harness-ui ルール](../../.claude/rules/harness-ui.md)
- [UI スキル制約](../../skills/ui/references/ui-skills.md)
- [Scorecard 仕様](../SCORECARD_SPEC.md)
- [評価 Playbook](../EVALS_PLAYBOOK.md)
