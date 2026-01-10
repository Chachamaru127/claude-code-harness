# ======================================
# Claude Code 分離ベンチマーク環境
# ======================================
#
# グローバルプラグインを完全に無効化した状態で
# Claude Code ベンチマークを実行するための Docker 環境
#
# ビルド:
#   docker build -t claude-benchmark -f benchmarks/docker/Dockerfile .
#
# 実行（プラグインなし）:
#   docker run --rm \
#     -v ~/.claude/.credentials.json:/root/.claude/.credentials.json:ro \
#     -v $(pwd)/benchmarks/test-project:/workspace \
#     claude-benchmark --print "your prompt"
#
# 実行（プラグインあり）:
#   docker run --rm \
#     -v ~/.claude/.credentials.json:/root/.claude/.credentials.json:ro \
#     -v $(pwd):/plugin:ro \
#     -v $(pwd)/benchmarks/test-project:/workspace \
#     claude-benchmark --plugin-dir /plugin --print "your prompt"

FROM node:20-slim

# 必要なツールのインストール
RUN apt-get update && apt-get install -y \
    git \
    curl \
    bc \
    && rm -rf /var/lib/apt/lists/*

# Claude Code のインストール
RUN npm install -g @anthropic-ai/claude-code

# 作業ディレクトリ
WORKDIR /workspace

# 空の Claude 設定ディレクトリを作成（プラグインなし）
RUN mkdir -p /root/.claude

# 認証情報はマウントで渡す（セキュリティのため）
# docker run -v ~/.claude/.credentials.json:/root/.claude/.credentials.json:ro

# デフォルトのエントリーポイント
ENTRYPOINT ["claude"]

# デフォルトの引数（オーバーライド可能）
CMD ["--help"]
