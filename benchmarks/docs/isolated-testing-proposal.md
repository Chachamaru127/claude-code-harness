# プラグイン分離テストの解決策

## 問題

`--plugin-dir` オプションはグローバルプラグイン（`~/.claude/settings.json`）を無効化しない。
真の「no-plugin」テストには、グローバル設定から完全に分離された環境が必要。

## 解決策

### 1. HOME ディレクトリオーバーライド（推奨・軽量）

Claude Code は `$HOME/.claude/` から設定を読み込む。
テスト時に `HOME` 環境変数を一時ディレクトリに変更することで、空の設定で起動できる。

```bash
# 一時的な HOME を作成
TEMP_HOME=$(mktemp -d)
mkdir -p "$TEMP_HOME/.claude"

# 空の設定で Claude を起動（プラグインなし）
HOME="$TEMP_HOME" claude --print "your prompt"

# クリーンアップ
rm -rf "$TEMP_HOME"
```

**メリット**:
- Docker 不要
- 軽量・高速
- 既存スクリプトに統合しやすい

**デメリット**:
- Claude の認証情報も読み込まれない可能性
- 初回起動時にログインを求められる可能性

**対策**: 認証トークンのみコピー

```bash
TEMP_HOME=$(mktemp -d)
mkdir -p "$TEMP_HOME/.claude"
# 認証情報のみコピー（設定・プラグインは除外）
cp ~/.claude/.credentials.json "$TEMP_HOME/.claude/" 2>/dev/null || true
HOME="$TEMP_HOME" claude --print "your prompt"
```

---

### 2. Docker 環境（最も確実）

完全に分離された環境で Claude Code を実行。

```dockerfile
# benchmarks/docker/Dockerfile
FROM node:20-slim

# Claude Code のインストール
RUN npm install -g @anthropic-ai/claude-code

# 作業ディレクトリ
WORKDIR /workspace

# 認証トークンはマウントで渡す
# docker run -v ~/.claude/.credentials.json:/root/.claude/.credentials.json

ENTRYPOINT ["claude"]
```

**実行方法**:

```bash
# イメージビルド
docker build -t claude-benchmark -f benchmarks/docker/Dockerfile .

# プラグインなしで実行
docker run --rm \
  -v ~/.claude/.credentials.json:/root/.claude/.credentials.json:ro \
  -v $(pwd)/benchmarks/test-project:/workspace \
  claude-benchmark --print "your prompt"

# プラグインありで実行
docker run --rm \
  -v ~/.claude/.credentials.json:/root/.claude/.credentials.json:ro \
  -v $(pwd):/plugin \
  -v $(pwd)/benchmarks/test-project:/workspace \
  claude-benchmark --plugin-dir /plugin --print "your prompt"
```

**メリット**:
- 完全な分離
- 再現性が高い
- CI/CD に適している

**デメリット**:
- Docker のインストールが必要
- 初期セットアップがやや複雑
- 実行時間が若干増加

---

### 3. XDG_CONFIG_HOME オーバーライド（検証が必要）

一部の CLI ツールは `XDG_CONFIG_HOME` を尊重する。

```bash
XDG_CONFIG_HOME=/tmp/test-config claude --print "your prompt"
```

**注意**: Claude Code がこの環境変数を尊重するかは未検証。

---

## 推奨アプローチ

### 開発・ローカルテスト向け: HOME オーバーライド

最も軽量で、既存のベンチマークスクリプトに統合しやすい。

### CI/CD 向け: Docker

完全な分離と再現性が保証される。GitHub Actions などで使用。

---

## 実装計画

1. **Phase 1**: HOME オーバーライド方式を `run-benchmark.sh` に実装
   - `--isolated` オプションを追加
   - 一時 HOME を作成し、認証情報のみコピー
   - テスト後にクリーンアップ

2. **Phase 2**: Docker 環境を構築
   - `benchmarks/docker/` に Dockerfile を配置
   - `benchmarks/scripts/run-benchmark-docker.sh` を作成
   - GitHub Actions ワークフローを追加

3. **Phase 3**: 検証
   - 両環境で同じプロンプトを実行し、プラグインが本当に無効化されているか確認
   - trace ログで `enabledPlugins` や `subagent_type` を検査

---

## 検証方法

プラグインが本当に無効化されているかを確認するには：

1. `--trace` で実行ログを取得
2. trace.jsonl 内で以下を検索:
   - `"enabledPlugins"` - 空配列であるべき
   - `"claude-harness:"` - no-plugin では出現しないはず
   - `"subagent_type": "claude-harness:*"` - no-plugin では出現しないはず

```bash
# プラグインが読み込まれていないことを確認
grep -c "claude-harness" trace.jsonl  # 0 であるべき
grep -c "enabledPlugins" trace.jsonl  # 空配列または未定義
```
