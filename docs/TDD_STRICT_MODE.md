# TDD Strict Mode

テスト駆動開発（TDD）を強制するモード。v2.14.0 からデフォルトで有効。

---

## 概要

TDD Strict Mode は、すべての実装タスクに対して RED-GREEN-REFACTOR サイクルを強制します。

### The Iron Law

> **NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST**
>
> 失敗するテストなしに本番コードを書いてはならない

---

## 有効化・無効化

### デフォルト（有効）

```yaml
# .claude-code-harness.config.yaml
tdd:
  mode: "strict"  # default
```

### 無効化する場合

```yaml
tdd:
  mode: "off"        # TDD 言及なし
  # or
  mode: "recommended"  # 推奨のみ（強制しない）
```

---

## RED-GREEN-REFACTOR サイクル

### 🔴 RED Phase

1. テストファイルを作成
2. 1つのテストケースを書く
3. テスト実行 → **失敗を確認**
4. 「正しい理由で」失敗していることを確認

```typescript
// 例: src/validators/email.test.ts
test('validateEmail returns true for valid email', () => {
  expect(validateEmail('test@example.com')).toBe(true);
});

// 実行 → ReferenceError: validateEmail is not defined
// ✅ 正しい失敗（機能がまだない）
```

### 🟢 GREEN Phase

1. テストを通す**最小限**のコードを書く
2. 「動く」ことだけを目指す
3. テスト実行 → **全パスを確認**

```typescript
// 例: src/validators/email.ts
export function validateEmail(email: string): boolean {
  return email.includes('@');  // 最小限の実装
}

// 実行 → ✓ 1 test passed
```

### 🔄 REFACTOR Phase

1. コードを整理
2. **テストはグリーンのまま**維持
3. コミット

```typescript
// 例: より堅牢な実装に改善
export function validateEmail(email: string): boolean {
  const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return regex.test(email);
}

// 実行 → ✓ 1 test passed (still green)
// git commit -m "feat: add email validation"
```

---

## 違反時の対応

| 違反パターン | 対応 |
|-------------|------|
| テスト前にコードを書いた | **該当コード全削除** → テストから書き直し |
| テストが即座にパスした | RED Phase 失敗 → やり直し |
| 「今回だけ例外」 | **認めない** |
| 参照用にコード保持 | **認めない** |

---

## TDD が必須の場面

| 場面 | 必須度 |
|------|--------|
| 新機能実装 | ★★★ |
| バグ修正 | ★★★ |
| リファクタリング | ★★★ |
| API 変更 | ★★★ |

## TDD 例外（明示的な許可が必要）

| 場面 | 理由 |
|------|------|
| 設定ファイル | ロジックなし |
| 生成コード | 自動生成 |
| 使い捨てプロトタイプ | ユーザーが明示的に許可した場合のみ |

---

## よくある質問

### Q: TDD は時間がかかるのでは？

A: 短期的には追加工数がありますが、以下の理由で長期的には時間を節約します:
- バグの早期発見
- リファクタリングへの安心感
- ドキュメントとしてのテスト
- 回帰テストの自動化

### Q: 「今回だけ」例外を認めてほしい

A: 認めません。1回の例外が習慣になります。どうしても TDD が合わない場合は `tdd.mode: "off"` に設定してください。

### Q: テストが書きにくいコードはどうする？

A: テストが書きにくい = 設計に問題がある可能性。依存性注入、関心の分離などを検討してください。

---

## 関連ドキュメント

- [skills/tdd-strict/SKILL.md](../skills/tdd-strict/SKILL.md) - TDD Strict スキル詳細
- [skills/tdd-strict/references/](../skills/tdd-strict/references/) - RED/GREEN/REFACTOR 各フェーズの詳細
