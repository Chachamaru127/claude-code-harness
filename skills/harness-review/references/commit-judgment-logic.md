# コミット判定ロジック

harness-review の最終判定（APPROVE / REQUEST CHANGES / REJECT / STOP）を出力するためのロジック。

## 判定基準

| 判定 | 条件 | 次のアクション |
|------|------|---------------|
| **STOP** | 検証（lint/test/build）失敗 or 環境エラー | 手動修正 → 再実行 |
| **REJECT** | Critical: ≥1 | 手動対応必要 |
| **REQUEST CHANGES** | Critical: 0, High: ≥1 または Medium: >3 | 自動修正 → 再判定 |
| **APPROVE** | Critical: 0, High: 0, Medium: ≤3 | コミット OK |

### Severity 定義

| Severity | 定義 | 例 |
|----------|------|-----|
| **Critical** | セキュリティ脆弱性、データ損失リスク | SQL インジェクション、認証バイパス |
| **High** | 重大なバグ、パフォーマンス問題 | 無限ループ、N+1 クエリ |
| **Medium** | コード品質問題、ベストプラクティス違反 | 未使用変数、不適切な命名 |
| **Low** | スタイル、軽微な改善提案 | フォーマット、コメント追加 |

## 判定フロー

```
検証結果収集
    ↓
検証失敗 → STOP
    ↓
Severity 集計
    ├── Critical >= 1 → REJECT
    ├── High >= 1 || Medium > 3 → REQUEST CHANGES
    └── それ以外 → APPROVE
    ↓
判定出力
```

## 出力形式

### APPROVE

```markdown
### 🎯 How to Achieve A

**Decision**: APPROVE
**Grade**: A
**A Grade Criteria**:
- Critical: 0 ✅
- High: 0 ✅
- Medium: ≤3 ✅
**Required fixes**: None
**次のアクション**: `git commit` でコミット可能
```

### REQUEST CHANGES

```markdown
### 🎯 How to Achieve A

**Decision**: REQUEST CHANGES
**Grade**: [grade]
**A Grade Criteria**:
- Critical: 0 [status]
- High: 0 [status]
- Medium: ≤3 [status]
**Required fixes**:
1. [file:line] - [issue] → [fix]
```

### REJECT

```markdown
### Manual Intervention Required

**Decision**: REJECT
**Grade**: F
**Reason**: Critical issues require manual review and fix
**Critical issues**: ...
```

### STOP

```markdown
### Verification Failed

**Decision**: STOP
**Grade**: N/A (blocked)
**Failure Type**: [lint_failure | test_failure | environment_error]
**Failed command**: ...
**Required fixes**: ...
```

## 自動修正ループ

**重要**: REQUEST CHANGES は自動修正ループを即時開始し、ユーザー確認は行わない。

REQUEST CHANGES 判定時の自動修正フロー:

```
REQUEST CHANGES 判定
    ↓
修正案を生成
    ↓
Claude が修正実行
    ↓
再度レビュー → 判定
    │
    ├── APPROVE → 完了
    ├── REQUEST CHANGES → ループ（最大3回）
    └── REJECT → 手動対応
```

### リトライ上限到達時

```markdown
## ⚠️ 自動修正上限に到達

3回の自動修正を試みましたが、以下の問題が残っています:

| # | Severity | ファイル | 内容 |
|---|----------|---------|------|
| 1 | High | `src/api/users.ts:34` | N+1 クエリ |

**推奨アクション**:
1. 手動で上記を修正
2. 再度 `/harness-review` を実行

> 💡 複雑な問題は自動修正が困難な場合があります
```

## Codex モードとの統合

Codex モード時は、レビュータイプに応じた4つのエキスパートからの指摘を集約して判定:

```
Codex 並列レビュー（レビュータイプごとに4エキスパート）

Code Review:
    ├── Security Expert → findings[]
    ├── Performance Expert → findings[]
    ├── Quality Expert → findings[]
    └── Accessibility Expert → findings[]

Plan Review:
    ├── Clarity Expert → findings[]
    ├── Feasibility Expert → findings[]
    ├── Dependencies Expert → findings[]
    └── Acceptance Expert → findings[]

Scope Review:
    ├── Scope-creep Expert → findings[]
    ├── Priority Expert → findings[]
    ├── Feasibility Expert → findings[]
    └── Impact Expert → findings[]

    ↓
全 findings を Severity で集計
    ↓
判定基準に基づいて判定
```

## 設定による制御

`.claude-code-harness.config.yaml`:

```yaml
review:
  judgment:
    enabled: true      # 判定を出力するか
    auto_fix: true     # REQUEST CHANGES 時に自動修正
    max_retries: 3     # 自動修正の最大回数
```

## 関連ファイル

- `skills/harness-review/SKILL.md` - レビュースキル本体
- `skills/codex-review/references/codex-parallel-review.md` - Codex 並列呼び出し
- `commands/optional/codex-mode.md` - Codex モード切り替え
