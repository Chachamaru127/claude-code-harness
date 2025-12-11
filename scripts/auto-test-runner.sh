#!/bin/bash
# auto-test-runner.sh - ファイル変更時の自動テスト実行
# PostToolUse フックから呼び出される

set +e  # エラーで停止しない

# 変更されたファイルを取得
CHANGED_FILE="${1:-}"
TOOL_NAME="${2:-}"

# テスト対象外のファイル
EXCLUDED_PATTERNS=(
    "*.md"
    "*.json"
    "*.yml"
    "*.yaml"
    ".gitignore"
    "*.lock"
    "node_modules/*"
    ".git/*"
)

# テスト実行が必要かどうか判定
should_run_tests() {
    local file="$1"

    # ファイルが空の場合はスキップ
    [ -z "$file" ] && return 1

    # 除外パターンに一致する場合はスキップ
    for pattern in "${EXCLUDED_PATTERNS[@]}"; do
        if [[ "$file" == $pattern ]]; then
            return 1
        fi
    done

    # テストファイル自体の変更
    if [[ "$file" == *".test."* ]] || [[ "$file" == *".spec."* ]] || [[ "$file" == *"__tests__"* ]]; then
        return 0
    fi

    # ソースコードファイルの変更
    if [[ "$file" == *.ts ]] || [[ "$file" == *.tsx ]] || [[ "$file" == *.js ]] || [[ "$file" == *.jsx ]]; then
        return 0
    fi

    if [[ "$file" == *.py ]]; then
        return 0
    fi

    if [[ "$file" == *.go ]]; then
        return 0
    fi

    if [[ "$file" == *.rs ]]; then
        return 0
    fi

    return 1
}

# テストコマンドを検出
detect_test_command() {
    # package.json がある場合
    if [ -f "package.json" ]; then
        if grep -q '"test"' package.json 2>/dev/null; then
            echo "npm test"
            return 0
        fi
    fi

    # pytest
    if [ -f "pytest.ini" ] || [ -f "pyproject.toml" ] || [ -d "tests" ]; then
        if command -v pytest &>/dev/null; then
            echo "pytest"
            return 0
        fi
    fi

    # go test
    if [ -f "go.mod" ]; then
        echo "go test ./..."
        return 0
    fi

    # cargo test
    if [ -f "Cargo.toml" ]; then
        echo "cargo test"
        return 0
    fi

    return 1
}

# 関連するテストファイルを検出
find_related_tests() {
    local file="$1"
    local basename="${file%.*}"
    local dirname=$(dirname "$file")

    # テストファイルのパターン
    local test_patterns=(
        "${basename}.test.ts"
        "${basename}.test.tsx"
        "${basename}.test.js"
        "${basename}.test.jsx"
        "${basename}.spec.ts"
        "${basename}.spec.tsx"
        "${basename}.spec.js"
        "${basename}.spec.jsx"
        "${dirname}/__tests__/$(basename "$basename").test.ts"
        "${dirname}/__tests__/$(basename "$basename").test.tsx"
        "test_${basename##*/}.py"
        "${basename##*/}_test.go"
    )

    for pattern in "${test_patterns[@]}"; do
        if [ -f "$pattern" ]; then
            echo "$pattern"
            return 0
        fi
    done

    return 1
}

# メイン処理
main() {
    # テスト実行が必要かチェック
    if ! should_run_tests "$CHANGED_FILE"; then
        exit 0
    fi

    # テストコマンドを検出
    TEST_CMD=$(detect_test_command)
    if [ -z "$TEST_CMD" ]; then
        exit 0
    fi

    # 関連テストファイルを検出
    RELATED_TEST=$(find_related_tests "$CHANGED_FILE")

    # 状態ファイルに記録
    STATE_DIR=".claude/state"
    mkdir -p "$STATE_DIR"

    # テスト推奨を記録
    cat > "${STATE_DIR}/test-recommendation.json" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "changed_file": "$CHANGED_FILE",
  "test_command": "$TEST_CMD",
  "related_test": "$RELATED_TEST",
  "recommendation": "テストの実行を推奨します"
}
EOF

    # 通知を出力
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🧪 テスト実行推奨"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📁 変更ファイル: $CHANGED_FILE"
    if [ -n "$RELATED_TEST" ]; then
        echo "🔗 関連テスト: $RELATED_TEST"
    fi
    echo "📋 推奨コマンド: $TEST_CMD"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

main
