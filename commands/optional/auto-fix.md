---
description: "[オプション] レビュー指摘事項の自動修正"
---

# /auto-fix - レビュー指摘事項の自動修正

`/harness-review`で検出された問題を自動的に修正します。

**機能**:
- ✅ セキュリティ脆弱性の修正
- ✅ パフォーマンス問題の改善
- ✅ コード品質の向上
- ✅ アクセシビリティ対応の追加

---

## 使用するスキル

このコマンドは以下のスキルを活用します：

- `ccp-review-apply-fixes` - レビュー指摘の自動修正
- `ccp-error-recovery` - エラー復旧
- `ccp-verify-build` - 修正後のビルド検証

---

## 💡 バイブコーダー向けの使い方

**このコマンドは、レビューで指摘された問題を自動的に修正します。**

- ✅ 技術的な知識がなくても、問題を解決できる
- ✅ クライアントに提出する前に、コードを完璧にできる
- ✅ 修正内容を説明してくれるので、学習にもなる

**受託開発で重要**: 修正内容をクライアントに報告できる形式で出力します

---

## 使い方

```
/auto-fix
```

→ 直近のレビュー結果を基に自動修正

```
/auto-fix security
```

→ セキュリティ問題のみ修正

```
/auto-fix performance
```

→ パフォーマンス問題のみ修正

---

## 実行フロー

### Step 1: レビュー結果の確認

直近の`/harness-review`コマンドの結果を確認します。

```bash
# レビュー結果ファイルを探す
find .claude -name "review-*.md" -type f | sort -r | head -1
```

レビュー結果がない場合:

> ⚠️ **レビュー結果が見つかりません。**
>
> まず `/harness-review` を実行してください。

**処理を中断**

### Step 2: 修正対象の選択

ユーザーの入力を確認。入力がない場合は質問：

> 🎯 **どの問題を修正しますか？**
>
> 1. すべて（推奨）
> 2. セキュリティのみ
> 3. パフォーマンスのみ
> 4. 品質のみ
> 5. アクセシビリティのみ
>
> 番号で答えてください（デフォルト: 1）

**回答を待つ**

### Step 3: 修正の実行

選択された問題を自動的に修正します。

#### セキュリティ問題の修正例

**問題**: XSS脆弱性（ユーザー入力をエスケープせずに表示）

**修正前**:
```typescript
<div dangerouslySetInnerHTML={{ __html: userInput }} />
```

**修正後**:
```typescript
import DOMPurify from 'isomorphic-dompurify'

<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(userInput) }} />
```

**説明**:
- `DOMPurify`を使用してXSS攻撃を防止
- ユーザー入力を安全にサニタイズ

#### パフォーマンス問題の修正例

**問題**: 不要な再レンダリング

**修正前**:
```typescript
function UserList({ users }) {
  return (
    <div>
      {users.map(user => (
        <UserCard key={user.id} user={user} />
      ))}
    </div>
  )
}
```

**修正後**:
```typescript
import { memo } from 'react'

const UserCard = memo(function UserCard({ user }) {
  return <div>{user.name}</div>
})

function UserList({ users }) {
  return (
    <div>
      {users.map(user => (
        <UserCard key={user.id} user={user} />
      ))}
    </div>
  )
}
```

**説明**:
- `memo`を使用して不要な再レンダリングを防止
- パフォーマンスが向上

#### コード品質の修正例

**問題**: エラーハンドリングの不足

**修正前**:
```typescript
async function fetchUser(id: string) {
  const res = await fetch(`/api/users/${id}`)
  return res.json()
}
```

**修正後**:
```typescript
async function fetchUser(id: string) {
  try {
    const res = await fetch(`/api/users/${id}`)
    
    if (!res.ok) {
      throw new Error(`HTTP error! status: ${res.status}`)
    }
    
    return await res.json()
  } catch (error) {
    console.error('Failed to fetch user:', error)
    throw error
  }
}
```

**説明**:
- HTTPエラーを適切にハンドリング
- エラーログを出力
- エラーを再スロー（上位で処理可能）

#### アクセシビリティの修正例

**問題**: `alt`属性の不足

**修正前**:
```typescript
<img src="/profile.jpg" />
```

**修正後**:
```typescript
<img src="/profile.jpg" alt="ユーザーのプロフィール画像" />
```

**説明**:
- スクリーンリーダーで画像の内容を読み上げ可能
- WCAG 2.1 Level A準拠

### Step 4: 修正内容のレポート作成

修正内容を`.claude/auto-fix-report.md`に保存します。

#### レポート例

```markdown
# 自動修正レポート

**実行日時**: 2025-12-12 14:30:00
**修正対象**: すべて

---

## 修正サマリー

| カテゴリ | 修正数 | 重要度 |
|---------|-------|--------|
| セキュリティ | 3 | 🔴 高 |
| パフォーマンス | 5 | 🟡 中 |
| 品質 | 8 | 🟢 低 |
| アクセシビリティ | 2 | 🟡 中 |

**合計**: 18件の問題を修正

---

## 詳細

### 1. セキュリティ: XSS脆弱性の修正

**ファイル**: `app/components/UserProfile.tsx`
**行**: 45

**問題**:
ユーザー入力をエスケープせずに表示していたため、XSS攻撃のリスクがありました。

**修正内容**:
`DOMPurify`を使用してユーザー入力をサニタイズするように修正しました。

**影響**:
- セキュリティリスクが解消
- ユーザーデータの安全性が向上

---

### 2. パフォーマンス: 不要な再レンダリングの防止

**ファイル**: `app/components/UserList.tsx`
**行**: 12

**問題**:
親コンポーネントが再レンダリングされるたびに、すべての子コンポーネントも再レンダリングされていました。

**修正内容**:
`React.memo`を使用して、propsが変更されない限り再レンダリングしないように修正しました。

**影響**:
- レンダリング時間が約40%短縮
- ユーザー体験が向上

---

（以下、すべての修正内容を記載）
```

### Step 5: 次のアクションを案内

> ✅ **自動修正が完了しました！**
>
> 📄 **修正レポート**: `.claude/auto-fix-report.md`
>
> **修正サマリー**:
> - セキュリティ: 3件
> - パフォーマンス: 5件
> - 品質: 8件
> - アクセシビリティ: 2件
>
> **次にやること：**
> 1. 修正内容を確認: `cat .claude/auto-fix-report.md`
> 2. 動作確認: `npm run dev`
> 3. テスト実行: `npm test`
> 4. コミット: `git add -A && git commit -m "fix: auto-fix による修正"`
>
> 💡 **クライアント向け**: レポートをそのまま提出資料として使用できます。

---

## dry-runモード

**デフォルトでは、実際には修正せず、修正内容のプレビューのみを表示します。**

実際に修正を適用するには:

```
/auto-fix --apply
```

---

## 注意事項

- **バックアップ**: 修正前にGitコミットを推奨
- **動作確認**: 修正後は必ず動作確認を実施
- **テスト**: 自動テストがある場合は実行
- **レビュー**: 重要な修正は人間がレビュー

**この自動修正機能で、高品質なコードを効率的に維持できます。**
