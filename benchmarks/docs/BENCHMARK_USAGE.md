# ベンチマーク実行ガイド

## 概要

このベンチマークスイートは、Claude harness プラグインのサブエージェント並列起動機能（v2.4.x）を検証します。

## 前提条件

1. **ANTHROPIC_API_KEY** が環境変数として設定されていること
2. macOS の場合、`coreutils` をインストール（`brew install coreutils`）するとベター

## 分離テスト（推奨）

### HOME オーバーライド方式

グローバルプラグインを完全に無効化した状態でテストします。

```bash
cd /path/to/claude-code-harness

# プラグインなし（真の no-plugin）
./benchmarks/scripts/run-isolated-benchmark.sh --task parallel-review

# プラグインあり
./benchmarks/scripts/run-isolated-benchmark.sh --task parallel-review --with-plugin
```

**オプション**:
- `--task <name>`: タスク名（必須）
- `--with-plugin`: プラグインを有効化
- `--plugin-path <path>`: プラグインのパス（デフォルト: このリポジトリ）
- `--iterations <n>`: 実行回数
- `--api-key <key>`: API キー（環境変数が設定されていない場合）
- `--no-trace`: trace を無効化

### Docker 方式（CI/CD 向け）

完全に分離された Docker 環境でテストします。

```bash
cd /path/to/claude-code-harness

# Docker イメージをビルド
./benchmarks/docker/run-docker-benchmark.sh --build

# プラグインなし
./benchmarks/docker/run-docker-benchmark.sh --task parallel-review

# プラグインあり
./benchmarks/docker/run-docker-benchmark.sh --task parallel-review --with-plugin
```

## 利用可能なタスク

| タスク | 説明 | 重さ |
|--------|------|------|
| `plan-feature` | 機能計画タスク | 軽量 |
| `impl-utility` | ユーティリティ実装タスク | 軽量 |
| `parallel-review` | 並列コードレビュー | 重量 |
| `complex-feature` | 複合機能実装 | 重量 |

## 結果の確認

結果は `benchmarks/results/` ディレクトリに保存されます。

```bash
# 結果ファイルの確認
ls -la benchmarks/results/

# JSON 結果の表示
cat benchmarks/results/*.json | jq .

# 分析スクリプトの実行
./benchmarks/scripts/analyze-results.sh
```

### 主要メトリクス

| メトリクス | 説明 | 期待値 |
|-----------|------|--------|
| `tool_use_count` | ツール呼び出し総数 | - |
| `task_tool_use_count` | Task ツール呼び出し数 | プラグインあり: > 0 |
| `subagent_type_count` | サブエージェントタイプ数 | プラグインあり: > 0 |
| `plugin_agent_detected` | プラグインエージェント検出数 | no-plugin: 0 |
| `grade.pass` | 最小 grader による成功判定（outcome/transcript） | - |
| `grade.score` | 最小 grader のスコア（0〜1） | - |

## 検証ポイント

### 1. 分離が機能しているか

```bash
# no-plugin テストでプラグインが検出されていないこと
grep -c 'claude-harness:' benchmarks/results/*isolated-no-plugin*.trace.jsonl
# → 0 であるべき
```

### 2. プラグインが機能しているか

```bash
# with-plugin テストで Task ツールが呼ばれていること
grep -c '"name":"Task"' benchmarks/results/*with-plugin*.trace.jsonl
# → > 0 であるべき
```

### 3. 並列サブエージェントが起動しているか

```bash
# subagent_type が検出されていること
grep 'subagent_type' benchmarks/results/*with-plugin*.trace.jsonl | head -5
```

## トラブルシューティング

### API キーエラー

```
⚠ 認証情報が見つかりません
```

→ `export ANTHROPIC_API_KEY=your_key` を実行

### timeout コマンドがない（macOS）

```
timeout: command not found
```

→ `brew install coreutils` を実行（gtimeout が使用される）

### プラグインが検出されない

1. プラグインパスが正しいか確認
2. `.claude-plugin/plugin.json` が存在するか確認
3. `--verbose` オプションで詳細ログを確認

## CI/CD での使用

GitHub Actions での使用例:

```yaml
- name: Run Benchmark
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  run: |
    ./benchmarks/docker/run-docker-benchmark.sh --build
    ./benchmarks/docker/run-docker-benchmark.sh --task parallel-review
    ./benchmarks/docker/run-docker-benchmark.sh --task parallel-review --with-plugin
```
