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

# 最新バージョンを npm から取得（ネットワーク不可の場合は unknown）
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
codex update
\`\`\`

`codex update` が使えない古いインストールだけ、package manager の
versioned / pinned update flow にフォールバックしてください。

EOF
    fi
fi

# timeout / gtimeout チェック（macOS 互換性）
TIMEOUT_CMD=""
if command -v timeout &> /dev/null; then
    TIMEOUT_CMD="timeout"
elif command -v gtimeout &> /dev/null; then
    TIMEOUT_CMD="gtimeout"
fi

if [[ -z "$TIMEOUT_CMD" ]]; then
    cat << 'EOF'

⚠️ **timeout コマンドが見つかりません**

Codex CLI の並列レビューではタイムアウト制御に `timeout` コマンドを使用します。
macOS にはデフォルトで含まれていないため、以下でインストールしてください:

```bash
brew install coreutils
```

これにより `gtimeout` が使えるようになり、Harness が自動検出します。
未インストールでも Codex は動作しますが、タイムアウト制御が効きません。

EOF
else
    echo ""
    echo "**タイムアウトコマンド**: \`${TIMEOUT_CMD}\` ✅"
fi

cat << 'EOF'

セカンドオピニオンレビューを有効化するには:

```yaml
# .claude-code-harness.config.yaml
review:
  codex:
    enabled: true
    # model は通常省略し、Codex CLI の current default metadata に任せる
    # 固定が必要な検証や組織 allowlist がある場合だけ明示する
```

または `/codex-review` で個別に Codex レビューを実行

詳細: skills/codex-review/SKILL.md

EOF

exit 0
