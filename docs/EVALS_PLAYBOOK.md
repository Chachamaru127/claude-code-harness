## 目的

このドキュメントは **claude-code-harness 自体を継続的に改善するための評価（eval）運用**を定義します。
「実装した」「動いた」で止めず、変更のたびに **改善/退化を検出できる体制**を作るのが目的です。

評価の考え方は、Anthropic の整理（task/trial/grader/transcript/outcome）に準拠します：
[`Demystifying evals for AI agents`](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)

---

## 用語（このリポジトリでの対応）

- **task**: 1つの評価ケース（例: `benchmarks/tasks/plan-feature.md`）
- **trial**: task の1回の実行（非決定性があるので複数回回す）
- **grader**: 採点ロジック（コード/モデル/人間）
- **transcript**: 試行の軌跡（例: `--output-format stream-json` の trace）
- **outcome**: 最終状態（ファイルの中身、生成物、テスト結果、フックの出力など）
- **eval harness**: task を回し、記録し、採点し、集計する仕組み（例: `benchmarks/scripts/run-*.sh`）
- **agent harness**: モデルが道具を使って行動する足場（Claude Code + このプラグイン）

---

## いま使うべき評価レイヤ（Swiss cheese で重ねる）

### 1) 決定的チェック（最優先・毎回）

目的: “壊してない” を最速で保証する（再現性が高い）。

- **構造/整合性**: `./tests/validate-plugin.sh`、`./scripts/ci/check-consistency.sh`
- **品質ガードレール**: `./tests/test-quality-guardrails.sh`
- **フック系**: `./tests/test-*.sh`（対象に応じて）

> これらは outcome grader（成果物）に近い。ここが弱いとベンチの数字はノイズになる。

### 2) エージェント実行ベンチ（定期・変更が大きい時）

目的: “エージェントとして良くなったか” を測る（非決定性込み）。

- **分離実行（対照実験を成立させる）**: `./benchmarks/scripts/run-isolated-benchmark.sh`
  - `--with-plugin` あり/なしで比較できる
  - HOME 分離でグローバル設定の混入を避ける
- **結果集計**: `./benchmarks/scripts/analyze-results.sh`

> ベンチは transcript を残して後から読む。数字だけで結論を出すと誤る。

### 3) 人間レビュー（週次・失敗時）

目的: grader が取りこぼす品質劣化を拾う（文章品質、過剰設計、逸脱など）。

- 代表的な trial の transcript をサンプリングして読む
- “失敗パターン” は **task化して suite に追加**（評価の複利）

---

## 非決定性に勝つ運用（最低ライン）

- **trials**: 原則 3回（最低でも2回）
- **集計**: 成功率 + 所要時間中央値（平均は外れ値に弱い）
- **比較**: 実行順序を固定しない（交互 or ランダム化）  
  例: no-plugin → with-plugin → no-plugin → with-plugin …
- **隔離**: 比較が絡む評価は HOME 分離/コンテナで混入を避ける

---

## Plan → Work → Review に eval を組み込む（運用ルール）

### Plan（計画）

- 受入条件は **測定可能（Yes/No）** に書く
- 受入条件ごとに **grader（outcome/transcript）** を紐づける
- “実装タスク” と同列に **eval タスク（テスト/検証追加）** を置く

（Cursor 側は `.cursor/commands/plan-with-cc.md` のテンプレを使う）

### Work（実装）

- まず eval を通すために必要な “土台” を作る（テスト/検証の追加）
- 実装は outcome を変える。transcript を良く見せるのは無価値（＝言い訳）

### Review（レビュー/判定）

- 決定的チェック → ベンチ（必要なら）→ transcript サンプリング の順で判定する
- 退化が出たら “直す” ではなく **task化して suite に固定**してから直す

---

## 失敗の扱い（ここを甘くすると評価は死ぬ）

- “成功で上書き” をしない（失敗ログ・再現手順は保存する）
- “達成したことにする” をしない（テスト改ざん/基準緩和/ノイズ化）
- 失敗を “仕様の明文化（task化）” に変換する

