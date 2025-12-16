---
name: ccp-work-impl-feature
description: "Plans.md のタスクに基づいて機能を実装する。/workコマンドが実行された場合、またはPlans.mdに実装待ちのタスクがある場合に使用します。"
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash"]
metadata:
  skillport:
    category: worker
    tags: [implementation, coding, feature]
    alwaysApply: false
---

# Work Implementation Feature

Plans.md で計画されたタスクを実際に実装するスキル。
コードを書き、ファイルを生成し、動作するソフトウェアを作成します。

---

## 入力

- **Plans.md**: 実装すべきタスク一覧
- **リポジトリコンテキスト**: 技術スタック、既存コード
- **対象タスク**: 実装する具体的なタスク

---

## 出力

- **実装されたコード**: ファイルの作成・編集
- **Plans.md の更新**: タスク状態の変更
- **完了報告**: 何を実装したかのサマリー

---

## 実行手順

### Step 1: タスクの確認

```bash
cat Plans.md | grep -A 5 "cc:WIP\|cc:TODO"
```

対象タスクを特定し、状態を `cc:WIP` に更新

### Step 2: 実装方針の決定

```
1. 関連する既存コードを確認
2. 必要なファイル・変更箇所を特定
3. 実装の順序を決定
```

### Step 3: コードの実装

#### ファイル作成の場合

```bash
# ディレクトリ確認
ls -la src/components/

# Write ツールで新規ファイル作成
```

#### ファイル編集の場合

```bash
# Read ツールで既存内容を確認
# Edit ツールで必要な部分のみ変更
```

### Step 4: 動作確認

```bash
# TypeScript の場合
npx tsc --noEmit

# ビルド確認
npm run build

# 開発サーバー起動
npm run dev
```

### Step 5: タスク完了処理

Plans.md を更新：

```markdown
# 変更前
- [ ] タスク名 `cc:WIP`

# 変更後
- [x] タスク名 `cc:完了` ({{日付}})
```

---

## 実装パターン集

### React コンポーネント

```typescript
// src/components/features/FeatureName.tsx
import { useState } from 'react'

interface FeatureNameProps {
  // props 定義
}

export function FeatureName({ ...props }: FeatureNameProps) {
  const [state, setState] = useState<Type>(initialValue)

  return (
    <div>
      {/* 実装 */}
    </div>
  )
}
```

### API エンドポイント（Next.js）

```typescript
// src/app/api/endpoint/route.ts
import { NextResponse } from 'next/server'

export async function GET() {
  // 実装
  return NextResponse.json({ data: result })
}
```

### ユーティリティ関数

```typescript
// src/lib/utils.ts
export function utilityFunction(input: InputType): OutputType {
  // 実装
  return output
}
```

---

## 品質基準

### 1. 型安全

- `any` を避ける
- 適切な型定義を行う

### 2. エラーハンドリング

```typescript
try {
  // 処理
} catch (error) {
  console.error('Error:', error)
  // 適切なエラー処理
}
```

### 3. コメント

- 複雑なロジックには説明を追加
- TODO は残さない（実装するか削除）

---

## 完了報告フォーマット

```markdown
## ✅ 実装完了

**タスク**: {{タスク名}}

### 変更ファイル
| ファイル | 変更内容 |
|---------|---------|
| `{{path}}` | {{変更概要}} |

### 動作確認
- ビルド: ✅ 成功
- 開発サーバー: ✅ 起動確認

### 次のタスク
「{{次のタスク名}}」を続けますか？
```

---

## 注意事項

- **1タスク1フォーカス**: 複数タスクを混ぜない
- **こまめにコミット**: 意味のある単位で
- **テスト可能な状態を維持**: 中間状態でもビルドが通ること
