# Scorecard 仕様書

Claude harness 評価スイート v1 の仕様を定義します。

> **参考**: [Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)

---

## 目的

変更のたびに「このハーネスはどれくらい良いか」を**客観的に**示せる状態を作る。

- **エージェント評価は曖昧になりがち**：「落ちなかった」だけでは品質は測れない
- **task/trial/grader を揃える**：雰囲気と自己満足で劣化しない仕組み
- **CI で計測可能**：外部に提示できる形で保存

---

## Suite 定義（v1）

### 対象タスク

| task | 説明 | grader | 重み |
|------|------|--------|------|
| `plan-feature` | Plans.md 計画作成 | outcome | 1.0 |
| `impl-utility` | ユーティリティ関数実装 | outcome | 1.0 |
| `impl-test` | テストファイル作成 | outcome | 1.0 |
| `impl-refactor` | レガシー JS → モダン TS | outcome | 1.0 |
| `review-security` | セキュリティレビュー | outcome | 1.0 |
| `review-quality` | 品質レビュー | outcome | 1.0 |
| `multi-file-refactor` | 複数ファイルリファクタ | outcome | 1.5 |
| `skill-routing` | スキル評価フロー | outcome + transcript | 1.5 |

### 除外タスク（v1 スコープ外）

- `complex-feature`: 実行時間が長く、試行回数確保が困難
- `parallel-review`: 上記同様
- `checklist-review`, `skill-activation-tests`, `improved-benchmark-v2`: 実験的タスク

---

## Trials（試行）

| 項目 | 値 | 理由 |
|------|----|------|
| 回数 | **3**（デフォルト、可変） | 非決定性を吸収する最小限 |
| 実行順序 | モード別一括 | CI 実装の簡素化（隔離環境でバイアス回避） |
| 隔離 | HOME 分離（`run-isolated-benchmark.sh`） | 混入防止 |

> **実行順序について**: 交互実行（no-plugin → with-plugin → ...）は理想的だが、CI 実装が複雑になる。
> HOME 分離による環境隔離でバイアスは十分に回避可能なため、モード別一括実行を採用。

---

## Graders（採点）

### Outcome Grader

**ファイル**: `benchmarks/scripts/grade-task.sh`

各タスクに対して、最終状態（ファイルの存在・内容）を機械的に判定。

**出力形式**:
```json
{
  "task": "plan-feature",
  "pass": true,
  "score": 0.85,
  "checks": [
    {"name": "plans_file_exists", "status": "pass", "required": true},
    {"name": "checkbox_task_count>=3", "status": "pass", "required": true},
    {"name": "mentions_key_requirements", "status": "fail", "required": true}
  ],
  "meta": {"project_dir": "..."}
}
```

### Transcript Grader（補助）

trace ファイル（`--output-format stream-json`）から以下を検出：

- **並列性**: `Task` tool の使用、`subagent_type` の検出
- **スキル起動**: `skill` キーワードの検出

> v1 では強制しない（チェックはするが pass/fail 判定には含めない）

---

## 集計指標

| 指標 | 計算方法 | 表示 |
|------|----------|------|
| **成功率 (Pass Rate)** | `grade.pass == true` の割合 | `%` |
| **Grade Score 平均** | `grade.score` の平均値 | `0.00 - 1.00` |
| **所要時間（中央値）** | `duration_seconds` の中央値 | `秒` |
| **推定コスト（中央値）** | `estimated_cost_usd` の中央値 | `$0.0000` |
| **Token 使用量（平均）** | `input_tokens + output_tokens` の平均 | `tokens` |

### コスト推定の前提

| 項目 | 値 |
|------|----|
| モデル | Claude 3.5 Sonnet |
| Input | $3 / MTok |
| Output | $15 / MTok |
| `cost_assumption` | `sonnet_3_5_input_3_per_mtok_output_15_per_mtok` |

> **重要**: これは**推定値**であり、実際の請求額ではありません。
> モデルの変更、キャッシュ、バッチ処理により実際のコストは異なります。

---

## メタ情報（必須）

Scorecard には以下のメタ情報を含める：

| 項目 | 取得元 | 例 |
|------|--------|-----|
| `harness_version` | `VERSION` ファイル | `2.7.6` |
| `harness_commit` | `git rev-parse HEAD` | `abc1234` |
| `generated_at` | 実行時刻（UTC） | `2026-01-11T12:00:00Z` |
| `os` | `uname -s` | `Darwin` / `Linux` |
| `os_version` | `uname -r` | `25.0.0` |
| `cost_assumption` | 固定文字列 | `sonnet_3_5_...` |
| `trials` | 試行回数 | `3` |
| `suite_version` | スイートバージョン | `v1` |

---

## 比較（plugin-on vs plugin-off）

### 比較対象

| モード | 説明 |
|--------|------|
| `isolated-with-plugin` | harness プラグイン有効 |
| `isolated-no-plugin` | プラグインなし（ベースライン） |

### 差分計算

```
改善率 = (no-plugin - with-plugin) / no-plugin × 100
```

- **正の値**: プラグインによる改善（時間短縮、コスト削減）
- **負の値**: プラグインによるオーバーヘッド
- **0 付近**: 有意な差なし

> 時間/コストは揺れるため、外向けには「同条件での相対差」を中心に報告する。

---

## 失敗の扱い

- **失敗 trial は破棄しない**: scorecard に失敗理由・checks を残す
- **成功で上書きしない**: 失敗ログ・再現手順は保存
- **退化を検出したら task 化**: 評価スイートに追加してから直す

---

## Scorecard 出力形式

### JSON（機械可読）

```json
{
  "meta": {
    "suite_version": "v1",
    "harness_version": "2.7.6",
    "harness_commit": "abc1234",
    "generated_at": "2026-01-11T12:00:00Z",
    "os": "Darwin",
    "os_version": "25.0.0",
    "cost_assumption": "sonnet_3_5_input_3_per_mtok_output_15_per_mtok",
    "trials": 3
  },
  "summary": {
    "with_plugin": {
      "pass_rate": 0.875,
      "grade_score_avg": 0.82,
      "duration_median_seconds": 45.2,
      "estimated_cost_median_usd": 0.0234,
      "total_trials": 24
    },
    "no_plugin": {
      "pass_rate": 0.625,
      "grade_score_avg": 0.65,
      "duration_median_seconds": 62.1,
      "estimated_cost_median_usd": 0.0312,
      "total_trials": 24
    },
    "comparison": {
      "pass_rate_diff": 0.25,
      "duration_improvement_pct": 27.2,
      "cost_improvement_pct": 25.0
    }
  },
  "tasks": [
    {
      "task": "plan-feature",
      "with_plugin": {"pass_rate": 1.0, "grade_score_avg": 0.95, "duration_median": 32.1},
      "no_plugin": {"pass_rate": 0.67, "grade_score_avg": 0.72, "duration_median": 41.3}
    }
  ],
  "trials": [
    {"task": "plan-feature", "mode": "with-plugin", "iteration": 1, "pass": true, "score": 0.95, "duration": 32.1, "checks": [...]}
  ]
}
```

### Markdown（人間可読）

```markdown
# Claude harness Scorecard

## メタ情報

| 項目 | 値 |
|------|-----|
| Suite Version | v1 |
| Harness Version | 2.7.6 |
| Commit | abc1234 |
| Generated | 2026-01-11T12:00:00Z |

## サマリー

| 指標 | with-plugin | no-plugin | 差分 |
|------|-------------|-----------|------|
| 成功率 | 87.5% | 62.5% | +25.0% |
| Grade Score 平均 | 0.82 | 0.65 | +0.17 |
| 所要時間（中央値） | 45.2s | 62.1s | -27.2% |
| 推定コスト（中央値） | $0.0234 | $0.0312 | -25.0% |

## タスク別詳細
...
```

---

## 再現手順

### ローカル実行

```bash
# 1. 依存確認
command -v jq python3 bc

# 2. API キー設定（いずれか）
export ANTHROPIC_API_KEY="sk-..."
# または claude login 済み

# 3. スイート実行（with-plugin）
for task in plan-feature impl-utility impl-test impl-refactor review-security review-quality multi-file-refactor skill-routing; do
  for i in 1 2 3; do
    ./benchmarks/scripts/run-isolated-benchmark.sh --task "$task" --with-plugin
  done
done

# 4. スイート実行（no-plugin）
for task in plan-feature impl-utility impl-test impl-refactor review-security review-quality multi-file-refactor skill-routing; do
  for i in 1 2 3; do
    ./benchmarks/scripts/run-isolated-benchmark.sh --task "$task"
  done
done

# 5. Scorecard 生成
./benchmarks/scripts/generate-scorecard.sh
```

### CI 実行

```bash
# GitHub Actions workflow_dispatch で実行
# → artifact として scorecard/report/trace を保存
```

---

## コミット時の注意事項

### 混入事故の防止

ベンチマーク関連の変更をコミットする際、他の作業中ファイル（harness-ui 等）が混入しないよう注意:

```bash
# 1. 対象ファイルのみをステージング（推奨）
git add docs/SCORECARD_SPEC.md benchmarks/scripts/generate-scorecard.sh .github/workflows/benchmark.yml

# 2. ステージング内容を確認
git diff --cached --stat

# 3. 問題なければコミット
git commit -m "feat(eval): ..."
```

**禁止パターン**:
- ❌ `git add .` や `git add -A`（作業中ファイルが混入する）
- ❌ `git commit -a`（同上）

### 生成物のコミット禁止

以下は `.gitignore` で除外されており、コミットしてはならない:

- `benchmarks/results/` - 結果ファイル（JSON, Markdown, trace）
- `benchmarks/test-project/` - テスト用プロジェクト
- `benchmarks/versions/` - バージョン別キャッシュ

---

## 変更履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|---------|
| v1 | 2026-01-11 | 初版（8タスク、trials=3、outcome grader 中心） |
