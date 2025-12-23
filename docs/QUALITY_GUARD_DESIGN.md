# Quality Guard 設計書

> **ステータス**: 設計完了（実装はオプション）
> **関連**: [D9: テスト改ざん防止の3層防御戦略](.claude/memory/decisions.md#d9-テスト改ざん防止の3層防御戦略)

## 概要

第3層（Hooks による技術的強制）の設計ドキュメントです。
第1層（Rules）と第2層（Skills）で効果が不十分な場合に実装します。

## 設計

### 検出対象ファイルパターン

```bash
# テストファイル
TEST_PATTERNS=(
  "*.test.ts" "*.test.tsx" "*.test.js" "*.test.jsx"
  "*.spec.ts" "*.spec.tsx" "*.spec.js" "*.spec.jsx"
  "*.test.py" "test_*.py" "*_test.py"
  "*.test.go" "*_test.go"
  "**/tests/**" "**/__tests__/**"
)

# 設定ファイル（緩和禁止）
CONFIG_PATTERNS=(
  ".eslintrc*" ".prettierrc*" "eslint.config.*"
  "tsconfig.json" "tsconfig.*.json"
  "biome.json" ".stylelintrc*"
  "jest.config.*" "vitest.config.*" "pytest.ini" "pyproject.toml"
)

# CI/CD ファイル
CI_PATTERNS=(
  ".github/workflows/*.yml" ".github/workflows/*.yaml"
  ".gitlab-ci.yml" "Jenkinsfile"
  ".circleci/*"
)
```

### 段階的導入計画

| Phase | 動作 | 対象 | 導入時期 |
|-------|------|------|----------|
| Phase 1 | `ask`（確認） | テストファイルの skip 化 | 即時可能 |
| Phase 2 | `ask`（確認） | lint/CI 設定の緩和 | 効果測定後 |
| Phase 3 | `deny`（拒否） | 全パターン | 十分な実績後 |

### 実装案（pretooluse-guard.sh への追加）

```bash
# ===== Quality Guard: テスト/設定改ざん検出 =====
# 環境変数で有効化: QUALITY_GUARD_ENABLED=true

is_test_file() {
  local path="$1"
  case "$path" in
    *.test.ts|*.test.tsx|*.test.js|*.test.jsx) return 0 ;;
    *.spec.ts|*.spec.tsx|*.spec.js|*.spec.jsx) return 0 ;;
    *.test.py|test_*.py|*_test.py) return 0 ;;
    *.test.go|*_test.go) return 0 ;;
    **/tests/*|**/__tests__/*) return 0 ;;
  esac
  return 1
}

is_lint_config() {
  local path="$1"
  case "$path" in
    .eslintrc*|.prettierrc*|eslint.config.*) return 0 ;;
    tsconfig.json|tsconfig.*.json) return 0 ;;
    biome.json|.stylelintrc*) return 0 ;;
  esac
  return 1
}

is_ci_config() {
  local path="$1"
  case "$path" in
    .github/workflows/*.yml|.github/workflows/*.yaml) return 0 ;;
    .gitlab-ci.yml|Jenkinsfile|.circleci/*) return 0 ;;
  esac
  return 1
}

if [ "${QUALITY_GUARD_ENABLED:-false}" = "true" ]; then
  if is_test_file "$REL_PATH"; then
    emit_ask "[Quality Guard] テストファイルを変更しようとしています。
テストの改ざん（skip化、アサーション削除）ではなく、実装の修正が正しい対応です。
変更理由を確認してください: $REL_PATH"
  fi

  if is_lint_config "$REL_PATH"; then
    emit_ask "[Quality Guard] lint/formatter 設定を変更しようとしています。
ルールの緩和ではなく、コードの修正が正しい対応です。
変更理由を確認してください: $REL_PATH"
  fi

  if is_ci_config "$REL_PATH"; then
    emit_ask "[Quality Guard] CI/CD 設定を変更しようとしています。
チェックの無効化ではなく、テスト/ビルドの修正が正しい対応です。
変更理由を確認してください: $REL_PATH"
  fi
fi
```

### 有効化方法

```bash
# 環境変数で有効化
export QUALITY_GUARD_ENABLED=true

# または .claude/settings.local.json で設定
{
  "env": {
    "QUALITY_GUARD_ENABLED": "true"
  }
}
```

### ホワイトリスト（正当な変更を許可）

```json
// .claude/state/quality-guard-whitelist.json
{
  "allowed_patterns": [
    "tests/fixtures/*",
    "**/*.test.ts:add_test_case"
  ],
  "reason_required": true
}
```

## テスト計画

### 単体テスト

```bash
# tests/test-quality-guard.sh

# テストファイル検出テスト
test_detect_test_file() {
  assert_true is_test_file "src/utils.test.ts"
  assert_true is_test_file "tests/integration/api.spec.js"
  assert_false is_test_file "src/utils.ts"
}

# 設定ファイル検出テスト
test_detect_lint_config() {
  assert_true is_lint_config ".eslintrc.js"
  assert_true is_lint_config "tsconfig.json"
  assert_false is_lint_config "package.json"
}
```

### 統合テスト

```bash
# テストファイル変更時に ask が返ることを確認
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/foo.test.ts"}}' | \
  QUALITY_GUARD_ENABLED=true ./scripts/pretooluse-guard.sh | \
  grep -q '"permissionDecision":"ask"'
```

## ユーザー体験への影響

### 正当な変更がブロックされるケース

| ケース | 対応 |
|--------|------|
| 新規テスト追加 | ask で確認、承認後に通過 |
| テストリファクタリング | ask で確認、承認後に通過 |
| CI 設定の改善 | ask で確認、承認後に通過 |

### 軽減策

- Phase 1 では `ask`（確認のみ）で運用し、deny は避ける
- ホワイトリスト機能で正当なパターンを除外可能
- 環境変数で簡単に無効化可能

## 次のアクション

1. [ ] 第1層・第2層の効果を測定（1-2週間運用）
2. [ ] 効果が不十分な場合のみ Phase 1 を実装
3. [ ] ユーザーフィードバックを収集
4. [ ] 必要に応じて Phase 2, 3 へ進む
