---
description: "[オプション] コードの安全なリファクタリング（テスト維持・段階的実行）"
description-en: "[Optional] Safe refactoring (test-preserved, incremental)"
---

# /refactor - 安全なリファクタリング

**コードの品質を改善しながら、機能を壊さない安全なリファクタリングを実行します。**

テストを維持しながら、段階的に変更を加えることで、リスクを最小化します。

## バイブコーダー向け（こう言えばOK）

- 「**このコードきれいにして**」→ このコマンド
- 「**〇〇の名前を変えたい**」→ 影響範囲を確認して安全にリネーム
- 「**重複してるコードをまとめて**」→ 共通化を提案・実行
- 「**この関数が長すぎる**」→ 適切な単位に分割

## できること（成果物）

1. **分析**: リファクタリング候補の特定と影響範囲の把握
2. **提案**: 安全なリファクタリング手順の提示
3. **実行**: テストを維持しながら段階的に変更
4. **検証**: 変更後のテスト実行と動作確認

---

## リファクタリングの種類

| 種類 | 説明 | リスク | LSP 活用 |
|------|------|--------|---------|
| **Rename** | 変数/関数/ファイル名の変更 | 低 | ✅ LSP Rename で安全に一括変更 |
| **Extract** | 関数/コンポーネント/定数の抽出 | 低〜中 | Find-references で使用箇所を確認 |
| **Move** | ファイル/関数の移動 | 中 | Find-references で影響範囲を把握 |
| **Inline** | 不要な抽象化の削除 | 中 | Find-references で使用箇所を確認 |
| **Simplify** | 複雑なロジックの簡略化 | 中〜高 | Go-to-definition で実装を確認 |
| **Restructure** | ディレクトリ構造の変更 | 高 | Diagnostics で変更後の問題を検出 |

---

## 🔧 LSP 機能の活用

リファクタリングでは LSP（Language Server Protocol）を**必須ツール**として活用します。

### LSP Rename による安全なリネーム

```
🔄 LSP Rename 実行

対象: formatDate → formatDateToJapanese

変更箇所:
├── src/utils/date.ts:15 (定義)
├── src/components/DateDisplay.tsx:5 (import)
├── src/components/DateDisplay.tsx:12 (使用)
├── src/components/EventCard.tsx:8 (import)
├── src/components/EventCard.tsx:23 (使用)
└── tests/utils/date.test.ts:3 (import)

合計: 6箇所を一括変更
→ 漏れなく安全にリネーム完了 ✅
```

### LSP Find-references による影響分析

リファクタリング前に必ず実行：

```
🔍 参照分析

対象: validateEmail 関数

参照箇所:
├── src/components/SignupForm.tsx:45
├── src/components/SettingsForm.tsx:23
├── src/api/auth/register.ts:12
└── tests/utils/validate.test.ts:8

→ 4箇所で使用中
→ テストあり ✅
→ リファクタリング可能
```

### LSP Diagnostics による変更後検証

```
リファクタリング後:

📊 LSP 診断結果

エラー: 0件 ✅
警告: 0件 ✅

→ 変更による問題なし
→ ビルド・テスト実行へ進む
```

### VibeCoder 向けの言い方

| やりたいこと | 言い方 |
|-------------|--------|
| 名前を変えたい | 「`getData` を `fetchUserData` にリネームして」 |
| 使用箇所を調べたい | 「この関数はどこで使われてる？」 |
| 変更後のエラーをチェック | 「リファクタリング後に診断して」 |

詳細: [docs/LSP_INTEGRATION.md](../../docs/LSP_INTEGRATION.md)

---

## 実行フロー

### Step 1: 対象の特定

ユーザーの指示を確認：

> 🎯 **何をリファクタリングしますか？**
>
> 1. **特定のファイル/関数** - 「`src/utils/helpers.ts` の `formatDate` を整理して」
> 2. **特定のパターン** - 「重複しているバリデーションをまとめて」
> 3. **全体的な改善** - 「コードの品質を上げたい」
>
> 指示がない場合は、コードベースを分析して候補を提案します。

### Step 2: 影響範囲の分析

```bash
# 参照箇所の検索
grep -r "関数名" --include="*.ts" --include="*.tsx"

# インポート関係の確認
grep -r "from.*ファイル名" --include="*.ts" --include="*.tsx"

# テストファイルの確認
find . -name "*.test.ts" -o -name "*.spec.ts" | xargs grep "関数名"
```

### Step 3: リファクタリング計画の提示

> 📋 **リファクタリング計画**
>
> **対象**: `src/utils/helpers.ts` の `formatDate` 関数
>
> **変更内容**:
> 1. 関数を `src/utils/date.ts` に移動
> 2. より明確な名前 `formatDateToJapanese` に変更
> 3. オプション引数を追加してフォーマットを選択可能に
>
> **影響範囲**:
> - `src/components/DateDisplay.tsx` (import 変更)
> - `src/pages/Dashboard.tsx` (import 変更)
> - `src/utils/__tests__/helpers.test.ts` (テスト移動)
>
> **リスク**: 低（参照箇所が限定的、テストあり）
>
> **実行しますか？** （はい / いいえ / 修正）

### Step 4: 段階的な実行

**重要**: 一度にすべてを変更せず、段階的に実行

```
Step 4.1: テストが通ることを確認
Step 4.2: 最小限の変更を実行
Step 4.3: テスト実行
Step 4.4: 次の変更へ（テストが通れば）
Step 4.5: 最終確認
```

各ステップでテストを実行し、失敗したら即座に停止。

### Step 5: 変更の検証

```bash
# テスト実行
npm test

# 型チェック
npm run typecheck

# Lint
npm run lint

# ビルド確認
npm run build
```

---

## 安全原則

### 1. テストファースト

- リファクタリング前にテストが通ることを確認
- テストがない場合は、まずテストを追加することを提案

### 2. 小さなステップ

- 一度に大きな変更をしない
- 各ステップでコミット可能な状態を維持

### 3. 後方互換性

エクスポートされている API を変更する場合：

```typescript
// 古い名前を維持（deprecated として）
/** @deprecated Use formatDateToJapanese instead */
export const formatDate = formatDateToJapanese;

// 新しい名前をエクスポート
export function formatDateToJapanese(date: Date): string {
  // ...
}
```

### 4. 変更の追跡

- すべての変更を Plans.md に記録
- 大きなリファクタリングは別ブランチで実行

---

## よくあるリファクタリングパターン

### 1. 関数の抽出

```typescript
// Before
function processUser(user: User) {
  // バリデーション（10行）
  // 変換（10行）
  // 保存（10行）
}

// After
function processUser(user: User) {
  validateUser(user);
  const transformed = transformUser(user);
  saveUser(transformed);
}
```

### 2. 重複の排除

```typescript
// Before: 3箇所に同じロジック
const formattedDate1 = `${date.getFullYear()}/${date.getMonth() + 1}/${date.getDate()}`;

// After: 共通関数
import { formatDate } from '@/utils/date';
const formattedDate1 = formatDate(date);
```

### 3. マジックナンバーの定数化

```typescript
// Before
if (retryCount > 3) { ... }

// After
const MAX_RETRY_COUNT = 3;
if (retryCount > MAX_RETRY_COUNT) { ... }
```

### 4. 条件分岐の簡略化

```typescript
// Before
if (status === 'active') {
  return true;
} else if (status === 'pending') {
  return true;
} else {
  return false;
}

// After
return ['active', 'pending'].includes(status);
```

---

## 注意事項

- **テストがないコードは慎重に**: リファクタリング前にテスト追加を検討
- **公開 API の変更は慎重に**: 後方互換性を維持するか、段階的に移行
- **一度に多くを変えない**: 問題発生時に原因特定が困難になる
- **Plans.md に記録**: 大きなリファクタリングはタスクとして管理

---

## 関連コマンド

- `/harness-review` - リファクタリング後のコードレビュー
- `/validate` - 変更後の検証（テスト・ビルド・Lint）
- `/auto-fix` - 自動修正可能な問題の解決

---

## ⚡ 並列実行の判断ポイント

複数ファイルのリファクタリングでは、**独立性**を判断して並列実行を決定します。

### 並列実行すべき場合 ✅

| 条件 | 理由 |
|------|------|
| 複数の独立したファイルをリネーム | 互いに影響しない |
| 異なるディレクトリの同種リファクタリング | 依存関係なし |
| 大量のファイルに同じ変更を適用 | 時間短縮効果大 |

**例: 並列実行可能なケース**
```
リファクタリング対象:
├── src/components/Header.tsx  (リネーム)
├── src/components/Footer.tsx  (リネーム)
└── src/components/Sidebar.tsx (リネーム)

→ 3ファイルとも独立 → 並列実行 ✅
```

### 直列実行すべき場合 ⚠️

| 条件 | 理由 |
|------|------|
| 共通関数の抽出 + それを使う側の変更 | 依存関係あり |
| ファイル移動 + import 更新 | 順序が重要 |
| 型定義の変更 + 型を使う側の変更 | 依存関係あり |

**例: 直列実行が必要なケース**
```
リファクタリング対象:
1. src/utils/date.ts を作成（新規）
2. src/components/DateDisplay.tsx から import

→ 1 が完了しないと 2 ができない → 直列実行 ⚠️
```

### 自動判断ロジック

```
リファクタリング対象ファイル >= 3 かつ
ファイル間の依存関係なし かつ
同種の変更（Rename/Extract など）
→ 並列実行

上記以外 → 直列実行（安全優先）
```

### 並列リファクタリングの実行例

```bash
# 3ファイルを並列でリネーム
/refactor --parallel rename Header,Footer,Sidebar to AppHeader,AppFooter,AppSidebar
```
