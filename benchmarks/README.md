# Claude harness ベンチマーク

プラグインの効果を定量的に測定するためのベンチマークスイートです。

## 測定対象

| メトリクス | 説明 |
|-----------|------|
| 処理時間 | タスク完了までの所要時間（秒） |
| ツール呼び出し回数 | 使用したツールの総数 |
| トークン消費量 | 入力/出力トークン数 |
| タスク成功率 | 正常に完了したタスクの割合 |

## タスクセット

プラグインの主要機能をテストする3カテゴリのタスク:

### 1. 計画タスク（Plan）
- `plan-feature.md` - 新機能の計画を Plans.md に作成
- プラグインの `/plan-with-agent` コマンドの効果を測定

### 2. 実装タスク（Work）
- `impl-utility.md` - ユーティリティ関数の実装
- `impl-test.md` - テストファイルの作成
- `impl-refactor.md` - 既存コードのリファクタリング
- プラグインの `/work` コマンドと並列実行の効果を測定

### 3. レビュータスク（Review）
- `review-security.md` - セキュリティレビュー
- `review-quality.md` - コード品質レビュー
- プラグインの `/harness-review` と並列サブエージェントの効果を測定

## 比較対象バージョン

- `latest` - 最新版（現在 v2.4.1）
- `no-plugin` - プラグインなし
- `v2.4.0` - 直前バージョン（並列サブエージェント対応）
- `v2.3.1` - スキル階層構造版
- `v2.0.0` - 初期メジャー版

> 注: バージョンはタグまたはコミットハッシュで管理。追加時は `scripts/fetch-versions.sh` の `VERSION_MAP` を更新。

## 使い方

### 1. 事前準備

```bash
# テスト用プロジェクトの初期化
cd benchmarks
./scripts/setup-test-project.sh

# 各バージョンのプラグインを準備（手動）
# ../versions/v2.4.1/  （最新）
# ../versions/v2.3.1/
# ../versions/v2.0.0/
```

### 2. ベンチマーク実行

```bash
# 単一タスク実行
./scripts/run-benchmark.sh --task plan-feature --version latest

# 全タスク実行（1バージョン）
./scripts/run-benchmark.sh --all --version latest

# 全バージョン比較
./scripts/run-benchmark.sh --all --compare

# tool_use / Task（サブエージェント）を観測したい場合（推奨）
./scripts/run-benchmark.sh --heavy --compare --trace
```

### 3. 結果分析

```bash
# レポート生成
./scripts/analyze-results.sh

# 出力: results/report-YYYYMMDD-HHMMSS.md
```

## ディレクトリ構造

```
benchmarks/
├── README.md           # このファイル
├── tasks/              # 固定タスク定義
│   ├── plan-feature.md
│   ├── impl-utility.md
│   ├── impl-test.md
│   ├── impl-refactor.md
│   ├── review-security.md
│   └── review-quality.md
├── scripts/            # 実行スクリプト
│   ├── setup-test-project.sh
│   ├── run-benchmark.sh
│   └── analyze-results.sh
├── results/            # 実行結果（JSON）
└── test-project/       # テスト用サンドボックス
```

## 測定方法

1. **A/Bスイッチ**: 同一タスクをプラグインあり/なしで交互に実行
2. **複数回実行**: 各タスクを3回実行し、中央値を採用
3. **固定シード**: 可能な限り再現性を確保

## 注意事項

- API呼び出しによる課金が発生します
- ネットワーク状況により結果が変動する可能性があります
- 初回実行時はキャッシュの影響で遅くなる場合があります
