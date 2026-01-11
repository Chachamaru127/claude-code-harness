#!/bin/bash
# check-codex.sh - Codex 利用可能性チェック（once hook 用）
# /harness-review 初回実行時に一度だけ実行される
#
# Usage: ./scripts/check-codex.sh

set -euo pipefail

# プロジェクト設定ファイルのパス
CONFIG_FILE=".claude-code-harness.config.yaml"

# 既に codex.enabled が設定されているか確認
if [[ -f "$CONFIG_FILE" ]]; then
    if grep -q "codex:" "$CONFIG_FILE" 2>/dev/null; then
        # 既に設定済みの場合は何もしない
        exit 0
    fi
fi

# Codex CLI がインストールされているか確認
if ! command -v codex &> /dev/null; then
    # Codex がない場合は何もしない
    exit 0
fi

# Codex のバージョンを取得
CODEX_VERSION=$(codex --version 2>/dev/null | head -1 || echo "unknown")

# 最新バージョンを npm から取得（タイムアウト 3秒）
LATEST_VERSION=$(npm show @openai/codex version 2>/dev/null || echo "unknown")

# バージョン比較用の関数
version_lt() {
    [ "$1" != "$2" ] && [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]
}

# Codex が見つかった場合、ユーザーに通知
cat << EOF

🤖 Codex が検出されました

**インストール済みバージョン**: ${CODEX_VERSION}
**最新バージョン**: ${LATEST_VERSION}
EOF

# バージョンが古い場合は警告
if [[ "$LATEST_VERSION" != "unknown" && "$CODEX_VERSION" != "unknown" ]]; then
    # バージョン文字列から数字部分を抽出
    CURRENT_NUM=$(echo "$CODEX_VERSION" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "0.0.0")
    LATEST_NUM=$(echo "$LATEST_VERSION" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "0.0.0")

    if version_lt "$CURRENT_NUM" "$LATEST_NUM"; then
        cat << EOF

⚠️ **Codex CLI が古いバージョンです**

アップデートするには:
\`\`\`bash
npm update -g @openai/codex
\`\`\`

または Claude に「Codex をアップデートして」と依頼してください。

EOF
    fi
fi

cat << 'EOF'

セカンドオピニオンレビューを有効化するには:

```yaml
# .claude-code-harness.config.yaml
review:
  codex:
    enabled: true
    model: gpt-5.2-codex  # 推奨モデル
```

または `/codex-review` で個別に Codex レビューを実行

詳細: skills/codex-review/SKILL.md

EOF

exit 0
