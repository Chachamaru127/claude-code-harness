# Strategy Analyzer

`/work all` 実行時に Plans.md を分析し、最適な実行戦略を自動判定するエンジン。

## Overview

```text
/work all (or /work 1-10)
    ↓
Phase 0.5: Strategy Analysis（Phase 1 の前に実行）
  1. Plans.md 解析 → タスクメタデータ抽出
  2. 依存グラフ構築 → 複雑度スコア算出
  3. ファイル競合率 + 独立タスク率 算出
  4. 失敗履歴確認（work.log.jsonl）
  5. 推奨戦略判定 → ユーザーに提示
    ↓
ユーザー承認 → 選択した戦略で Phase 1 へ
```

## 判定基準

### 入力シグナル

| シグナル | 取得方法 | 重み |
|---------|---------|------|
| タスク数 | Plans.md の未完了タスク数 | 高 |
| 独立タスク率 | 依存グラフから算出（blockedBy なし / 全タスク） | 高 |
| ファイル競合率 | 同一ファイルを編集するタスクペア数 / 全ペア数 | 中 |
| 依存チェーン最大深度 | 依存グラフの最長パス | 中 |
| タスク種別の多様性 | UI + API + テスト等の混在度 | 低 |
| 失敗履歴 | work.log.jsonl の iteration 失敗回数 | 高（存在時） |

### 戦略判定ロジック

```text
入力シグナル
    ↓
breezing 推奨チェック:
  (a) タスク数 >= 4 かつ 独立タスク率 >= 60%
  OR (b) 依存チェーン最大深度 >= 3 かつ タスク数 >= 3
  OR (c) タスク種別が 3 カテゴリ以上（UI + API + テスト等）
  OR (d) 過去 2 回以上の iteration で同一タスクが失敗
    ↓
  いずれか該当 → recommended: "breezing"
  該当なし → 従来の戦略選択（direct / parallel）
```

### 従来の戦略選択（breezing 非推奨時）

| タスク数 | 依存関係 | 戦略 |
|---------|---------|------|
| 1 | - | direct（直接実装） |
| 2-3 | 独立 | parallel（サブエージェント並列） |
| 2-3 | 依存あり | sequential（直列実装） |
| 4+ | - | parallel + auto-iteration |

## 判定出力スキーマ

```json
{
  "recommended": "direct" | "parallel" | "breezing",
  "reasoning": [
    "5 タスク中 4 タスクが独立（独立タスク率 80%）",
    "UI変更 + API変更 + テスト追加が混在（3カテゴリ）",
    "Implementer 2並列 + Reviewer 独立レビューで品質確保可能"
  ],
  "cost_estimate": {
    "direct": "N/A（タスク数超過）",
    "parallel": "~80k tokens",
    "breezing": "~440k tokens (5.5x)"
  },
  "confidence": "high" | "medium",
  "metrics": {
    "task_count": 5,
    "independent_ratio": 0.8,
    "file_conflict_ratio": 0.1,
    "max_dependency_depth": 2,
    "category_diversity": 3,
    "past_failures": 0
  }
}
```

## breezing 推奨条件（詳細）

### (a) 高独立率 + 十分なタスク数

```text
条件: task_count >= 4 AND independent_ratio >= 0.6
理由: Implementer 並列 + Reviewer 独立レビューの恩恵が大きい
confidence: high（両条件とも数値で判定可能）
```

### (b) 深い依存チェーン

```text
条件: max_dependency_depth >= 3 AND task_count >= 3
理由: 依存チェーンの管理が複雑 → Lead の調整能力が必要
confidence: medium（依存チェーンの管理が /work でも可能な場合あり）
```

### (c) タスク種別の多様性

```text
条件: category_diversity >= 3
カテゴリ判定:
  - UI: コンポーネント作成、スタイル変更、レイアウト
  - API: エンドポイント、ミドルウェア、データベース
  - テスト: テストケース作成、テストインフラ
  - インフラ: CI/CD、設定ファイル、スクリプト
理由: 異なる専門領域の実装 → 独立 Reviewer の多角的視点が有効
confidence: medium（1人でも対応可能な場合あり）
```

### (d) 反復失敗からのエスカレーション

```text
条件: 同一タスクが 2 回以上の iteration で失敗
取得: work.log.jsonl から task_failed イベントをグループ化
理由: /work の自己学習では解決できない構造的問題の可能性
  → Reviewer の独立視点で設計問題を検出できる
confidence: high（実績ベースの判定）
```

## 非推奨条件（breezing を推奨しない場合）

以下のいずれかに該当する場合、breezing は推奨しない:

| 条件 | 理由 |
|------|------|
| `--no-breezing` フラグ指定 | ユーザーの明示的拒否 |
| タスク数 1-2 | breezing のオーバーヘッドが大きすぎる |
| Agent Teams 未有効化 | 技術的に実行不可 |
| confidence: "medium" かつ metrics が境界値付近 | 誤推奨リスク回避 |

## コスト見積もりロジック

team-composition.md のトークン倍率テーブルを参照:

```text
parallel 見積もり:
  base = task_count × 16k tokens/task（平均）
  overhead = base × 0.2（調整・レビュー）
  total = base + overhead

breezing 見積もり:
  discuss = (task_count >= 5) ? "+1.5x" : "0"（Phase 0）
  impl = task_count × 16k（Implementer）
  review = impl × 0.3（Reviewer）
  lead = impl × 0.5（Lead 調整）
  total_multiplier = team-composition.md の倍率テーブル参照
  total = parallel_estimate × total_multiplier
```

> **注**: 見積もりは「概算」と明記する。実際のトークン消費はタスク複雑度に大きく依存。

## Agent Teams 未有効化時のフォールバック

breezing 推奨だが Agent Teams が未有効化の場合:

```text
📋 タスク分析結果:
  5個のタスク（4個が独立）
  → breezing モードが最適ですが、Agent Teams が有効化されていません。

セットアップ手順:
  settings.json に以下を追加:
  { "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }

現在の選択肢:
  [parallel で実行]  [1つずつ実行]  [Agent Teams を有効化して再実行]
```

## 実行タイミング

Strategy Analysis は以下のタイミングで実行:

1. `/work all` または `/work N-M`（4+ タスク）の Phase 0 完了後
2. `/work`（引数なし）で「全部」を選択後
3. **実行しない**: 1-3 タスク、`--no-breezing` 指定時、`--sequential` 指定時
