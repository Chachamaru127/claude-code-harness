# コミット判定ロジック

harness-review の最終判定（APPROVE / REQUEST CHANGES / REJECT）を出力するためのロジック。

## 判定基準

| 判定 | 条件 | 次のアクション |
|------|------|---------------|
| **APPROVE** | Critical: 0, High: 0, Medium: ≤3 | コミット OK |
| **REQUEST CHANGES** | Critical: 0, High: ≥1 または Medium: >3 | 自動修正 → 再判定 |
| **REJECT** | Critical: ≥1 | 手動対応必要 |

### Severity 定義

| Severity | 定義 | 例 |
|----------|------|-----|
| **Critical** | セキュリティ脆弱性、データ損失リスク | SQL インジェクション、認証バイパス |
| **High** | 重大なバグ、パフォーマンス問題 | 無限ループ、N+1 クエリ |
| **Medium** | コード品質問題、ベストプラクティス違反 | 未使用変数、不適切な命名 |
| **Low** | スタイル、軽微な改善提案 | フォーマット、コメント追加 |

## 判定フロー

```
レビュー結果収集
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
## 🚦 コミット判定: APPROVE ✅

**判定理由**: 重大な問題なし

| Severity | 件数 |
|----------|------|
| Critical | 0 |
| High | 0 |
| Medium | 2 |
| Low | 5 |

📝 **Low/Medium の指摘**（任意対応）:
- [Medium] `src/utils/helpers.ts:45` - 未使用の import
- [Medium] `src/components/Form.tsx:78` - any 型の使用

**次のアクション**: `git commit` でコミット可能です
```

### REQUEST CHANGES

```markdown
## 🚦 コミット判定: REQUEST CHANGES 🟡

**判定理由**: 修正可能な問題あり

| Severity | 件数 |
|----------|------|
| Critical | 0 |
| High | 2 |
| Medium | 4 |
| Low | 3 |

📝 **修正が必要な項目**:

| # | Severity | ファイル | 内容 | 修正案 |
|---|----------|---------|------|--------|
| 1 | High | `src/api/users.ts:34` | N+1 クエリ | `include` で事前取得 |
| 2 | High | `src/pages/login.tsx:56` | XSS 脆弱性 | `sanitize()` を追加 |

**自動修正を実行しますか？** [Y/N]

> 自動修正後、再度レビューを実行して判定します（最大3回）
```

### REJECT

```markdown
## 🚦 コミット判定: REJECT ❌

**判定理由**: 重大なセキュリティ問題

| Severity | 件数 |
|----------|------|
| Critical | 1 |
| High | 3 |
| Medium | 2 |
| Low | 1 |

🚨 **Critical な問題**:

| # | ファイル | 内容 | 影響 |
|---|---------|------|------|
| 1 | `src/api/auth.ts:45` | SQL インジェクション | データ漏洩リスク |

**手動対応が必要です**:
1. 上記の Critical 問題を修正
2. 再度 `/review` を実行

> ⚠️ 自動修正は Critical 問題には対応しません（安全のため）
```

## 自動修正ループ

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
2. 再度 `/review` を実行

> 💡 複雑な問題は自動修正が困難な場合があります
```

## Codex モードとの統合

Codex モード時は、各エキスパートからの指摘を集約して判定:

```
Codex 並列レビュー
    ├── Security Expert → findings[]
    ├── Accessibility Expert → findings[]
    ├── Performance Expert → findings[]
    ├── Quality Expert → findings[]
    ├── SEO Expert → findings[]
    ├── Architect Expert → findings[]
    ├── Plan Reviewer Expert → findings[]
    └── Scope Analyst Expert → findings[]
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

- `skills/review/SKILL.md` - レビュースキル本体
- `skills/codex-review/references/codex-parallel-review.md` - Codex 並列呼び出し
- `commands/optional/codex-mode.md` - Codex モード切り替え
