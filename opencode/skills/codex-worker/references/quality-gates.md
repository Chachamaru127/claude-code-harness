# Quality Gates

Orchestrator による Worker 成果物の品質検証。

## Overview

```
Worker 完了
    │
    ├─ Gate 1: 証跡検証
    │     - AGENTS_SUMMARY 存在確認
    │     - ハッシュ照合
    │
    ├─ Gate 2: 構造チェック
    │     - lint (ESLint/Prettier)
    │     - type-check (TypeScript)
    │
    ├─ Gate 3: テスト
    │     - npm test
    │     - 改ざん検出
    │
    └─ 全ゲート通過 → マージへ
```

## Gates

### Gate 1: 証跡検証 (evidence)

Worker が AGENTS.md を読み、証跡を出力したか確認。

**検証内容**:
- `AGENTS_SUMMARY:` 行の存在
- ハッシュ値（SHA256 先頭8文字）の照合

**失敗時**:
- 証跡欠落: 即失敗 → 手動対応
- ハッシュ不一致: 再実行（最大3回）

### Gate 2: 構造チェック (structure)

コードの構造的な品質を検証。

**検証内容**:
```bash
npm run lint
npm run type-check  # TypeScript プロジェクトの場合
```

**失敗時**:
- lint エラー: 自動修正指示 → 再実行
- type エラー: 修正指示 → 再実行（最大3回）

### Gate 3: テスト (test)

テストの実行と改ざん検出。

**検証内容**:
```bash
npm test
```

**改ざん検出パターン**:
- `it.skip()`, `test.skip()` への変更
- アサーションの削除・緩和
- eslint-disable コメントの追加
- テスト期待値のハードコード

**失敗時**:
- テスト失敗: 修正指示 → 再実行（最大3回）
- 改ざん検出: 即座に中断 → 手動対応

## Severity Levels

| レベル | 例 | 対応 |
|--------|-----|------|
| **Critical** | 改ざん検出、証跡欠落 | 即座に中断 → 手動対応 |
| **High** | テスト失敗、型エラー | 修正指示 → 再実行（最大3回） |
| **Medium** | lint エラー | 自動修正指示 → 再実行 |
| **Low** | 警告のみ | 続行（ログ記録） |

## Skip Gate

誤検知や特殊ケースでゲートをスキップ:

```bash
./scripts/codex-worker-quality-gate.sh --skip-gate evidence
./scripts/codex-worker-quality-gate.sh --skip-gate structure
./scripts/codex-worker-quality-gate.sh --skip-gate test
```

**監査ログ**:
スキップ時は `.claude/state/gate-skips.log` に記録:
```
{ISO8601-UTC}	{gate}	{reason}	{user}
```

理由（`--reason`）は必須。

## Usage

### 基本実行

```bash
./scripts/codex-worker-quality-gate.sh --worktree ../worktrees/worker-1
```

### オプション

| オプション | 説明 | 必須 |
|-----------|------|------|
| `--worktree PATH` | 検査対象の worktree | Yes |
| `--skip-gate GATE` | 特定ゲートをスキップ | No |
| `--reason TEXT` | スキップ理由（--skip-gate と併用） | Yes* |

### 出力形式

```json
{
  "status": "passed" | "failed" | "critical",
  "gates": {
    "evidence": {"status": "passed" | "failed" | "critical", "details": "..."},
    "structure": {"status": "passed" | "failed", "details": "..."},
    "test": {"status": "passed" | "failed" | "critical", "details": "..."}
  },
  "skipped": [],
  "errors": []
}
```

**status の意味**:
- `passed`: 全ゲート通過
- `failed`: 再試行可能な失敗（ハッシュ不一致、テスト失敗など）
- `critical`: 即座に中断が必要（証跡欠落、改ざん検出）

## Integration with ultrawork

`ultrawork --codex` は各 Worker 完了後に自動でゲートを実行:

```
Worker 完了
    ↓
codex-worker-quality-gate.sh
    ↓
全ゲート通過? → Yes → マージ
               → No → 再実行 or 手動対応
```

## Related

- [worker-execution.md](./worker-execution.md) - Worker 実行フロー
- [parallel-strategy.md](./parallel-strategy.md) - 並列実行戦略
- [../../../.claude/rules/test-quality.md](../../../.claude/rules/test-quality.md) - テスト品質ルール
