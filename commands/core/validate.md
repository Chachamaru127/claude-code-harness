---
description: "[オプション] プロジェクト検証（env/依存/ビルド/テスト/デプロイ準備）"
description-en: "[Optional] Project validation (env/deps/build/test/deploy)"
---

# /validate - プロジェクトの検証

プロジェクトが正しく設定され、動作することを検証します。

**機能**:
- ✅ 環境変数の確認
- ✅ 依存関係の確認
- ✅ ビルドの確認
- ✅ テストの実行
- ✅ デプロイ準備の確認

---

## 使用するスキル

このコマンドは以下のスキルを活用します：

- `review-security` - セキュリティ検証
- `review-performance` - パフォーマンス検証
- `review-quality` - 品質検証
- `verify-build` - ビルド検証

---

## 🔧 LSP 機能の活用

検証では LSP（Language Server Protocol）を活用して、ビルド前に問題を検出します。

### LSP Diagnostics による事前検証

型チェック（`npm run typecheck`）に加えて、LSP Diagnostics を実行：

```
📊 LSP 診断結果（プロジェクト全体）

ファイル数: 42
エラー: 0件 ✅
警告: 3件 ⚠️
情報: 5件

⚠️ 警告:
├── src/components/Header.tsx:15 - 未使用の変数 'debug'
├── src/utils/helpers.ts:23 - 非推奨の API 使用
└── src/pages/Settings.tsx:45 - any 型の使用

→ ビルドは通るが、品質改善の余地あり
```

### 検証フローへの統合

```
/validate full 実行時の流れ:

1. 環境変数チェック
2. 依存関係チェック
3. LSP Diagnostics ← NEW
4. Lint
5. 型チェック
6. ビルド
7. テスト
8. セキュリティ監査
```

### LSP vs 従来ツールの比較

| 検証項目 | 従来 | LSP 追加のメリット |
|---------|------|-------------------|
| 型エラー | `tsc --noEmit` | リアルタイム・詳細な位置情報 |
| 未使用コード | ESLint | IDE と同じ精度の検出 |
| 参照切れ | ビルド時エラー | 事前に検出可能 |

### VibeCoder 向けの言い方

| やりたいこと | 言い方 |
|-------------|--------|
| 全体の問題をチェック | 「LSP診断を含めて検証して」 |
| 警告も見たい | 「警告も含めてチェックして」 |

詳細: [docs/LSP_INTEGRATION.md](../../docs/LSP_INTEGRATION.md)

---

## 💡 バイブコーダー向けの使い方

**このコマンドは、クライアントに納品する前に、すべてが正しく動作することを確認します。**

- ✅ 環境変数が正しく設定されているか
- ✅ すべての依存関係がインストールされているか
- ✅ ビルドが成功するか
- ✅ テストが通るか
- ✅ デプロイ準備ができているか

**受託開発で重要**: 納品前のチェックリストとして使用できます

---

## 使い方

```
/validate
```

→ すべての検証を実行

```
/validate quick
```

→ 基本的な検証のみ（環境変数、依存関係）

```
/validate full
```

→ 完全な検証（ビルド、テスト、デプロイ準備）

---

## 実行フロー

### Step 1: 検証レベルの確認

ユーザーの入力を確認。入力がない場合は質問：

> 🎯 **どのレベルの検証を実行しますか？**
>
> 1. Quick（基本的な検証のみ、約1分）
> 2. Standard（ビルドまで、約3分）
> 3. Full（すべて、約5-10分）
>
> 番号で答えてください（デフォルト: 2）

**回答を待つ**

---

## Quick検証

### Step 2: 環境変数の確認

#### 必須の環境変数

```bash
# .env.localの存在確認
if [ ! -f .env.local ]; then
  echo "❌ .env.local が見つかりません"
  exit 1
fi

# 必須の環境変数をチェック
required_vars=(
  "DATABASE_URL"
  "NEXT_PUBLIC_APP_URL"
)

for var in "${required_vars[@]}"; do
  if ! grep -q "^${var}=" .env.local; then
    echo "❌ ${var} が設定されていません"
    exit 1
  fi
done

echo "✅ 環境変数: OK"
```

### Step 3: 依存関係の確認

```bash
# package.jsonの存在確認
if [ ! -f package.json ]; then
  echo "❌ package.json が見つかりません"
  exit 1
fi

# node_modulesの存在確認
if [ ! -d node_modules ]; then
  echo "⚠️  node_modules が見つかりません。npm install を実行してください"
  exit 1
fi

# パッケージの整合性チェック
npm ls --depth=0 > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "⚠️  依存関係に問題があります。npm install を実行してください"
  exit 1
fi

echo "✅ 依存関係: OK"
```

---

## Standard検証

### Step 4: Lintの実行

```bash
npm run lint
if [ $? -ne 0 ]; then
  echo "❌ Lint エラーがあります"
  exit 1
fi

echo "✅ Lint: OK"
```

### Step 5: 型チェック

```bash
npx tsc --noEmit
if [ $? -ne 0 ]; then
  echo "❌ 型エラーがあります"
  exit 1
fi

echo "✅ 型チェック: OK"
```

### Step 6: ビルドの確認

```bash
npm run build
if [ $? -ne 0 ]; then
  echo "❌ ビルドに失敗しました"
  exit 1
fi

echo "✅ ビルド: OK"
```

---

## Full検証

### Step 7: テストの実行

```bash
npm test
if [ $? -ne 0 ]; then
  echo "❌ テストに失敗しました"
  exit 1
fi

echo "✅ テスト: OK"
```

### Step 8: E2Eテストの実行

```bash
if [ -f "playwright.config.ts" ]; then
  npx playwright test
  if [ $? -ne 0 ]; then
    echo "❌ E2Eテストに失敗しました"
    exit 1
  fi
  echo "✅ E2Eテスト: OK"
else
  echo "⚠️  E2Eテストが設定されていません（オプション）"
fi
```

### Step 9: セキュリティ監査

```bash
npm audit --audit-level=moderate
if [ $? -ne 0 ]; then
  echo "⚠️  セキュリティ脆弱性が検出されました"
  echo "   npm audit fix を実行してください"
fi

echo "✅ セキュリティ監査: OK"
```

### Step 10: デプロイ準備の確認

#### Vercelの場合

```bash
# vercel.jsonの存在確認
if [ -f "vercel.json" ]; then
  echo "✅ vercel.json: OK"
else
  echo "⚠️  vercel.json が見つかりません（オプション）"
fi

# 環境変数のチェック
echo "📋 Vercelに設定すべき環境変数:"
grep -v "^#" .env.local | grep -v "^$" | cut -d= -f1
```

#### Netlifyの場合

```bash
# netlify.tomlの存在確認
if [ -f "netlify.toml" ]; then
  echo "✅ netlify.toml: OK"
else
  echo "⚠️  netlify.toml が見つかりません（オプション）"
fi
```

---

## 検証レポートの作成

### Step 11: レポート生成

#### `.claude/validation-report.md`

```markdown
# プロジェクト検証レポート

**実行日時**: 2025-12-12 14:30:00
**検証レベル**: Full

---

## 検証結果サマリー

| カテゴリ | ステータス |
|---------|----------|
| 環境変数 | ✅ OK |
| 依存関係 | ✅ OK |
| Lint | ✅ OK |
| 型チェック | ✅ OK |
| ビルド | ✅ OK |
| テスト | ✅ OK (15/15 passed) |
| E2Eテスト | ✅ OK (8/8 passed) |
| セキュリティ監査 | ✅ OK (0 vulnerabilities) |
| デプロイ準備 | ✅ OK |

**総合評価**: ✅ **合格** - デプロイ可能

---

## 詳細

### 環境変数

以下の環境変数が正しく設定されています：

- `DATABASE_URL`
- `NEXT_PUBLIC_APP_URL`
- `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`
- `STRIPE_SECRET_KEY`
- `NEXT_PUBLIC_GA_MEASUREMENT_ID`

### 依存関係

すべての依存関係が正しくインストールされています。

- パッケージ数: 245
- 脆弱性: 0

### ビルド

ビルドが成功しました。

- ビルド時間: 42秒
- 出力サイズ: 1.2 MB

### テスト

すべてのテストが通過しました。

- ユニットテスト: 15/15 passed
- E2Eテスト: 8/8 passed
- カバレッジ: 78%

---

## デプロイチェックリスト

- [x] 環境変数が設定されている
- [x] ビルドが成功する
- [x] テストが通る
- [x] セキュリティ脆弱性がない
- [ ] ドメインが設定されている（本番環境のみ）
- [ ] SSL証明書が有効（本番環境のみ）

---

## 推奨事項

1. **テストカバレッジの向上**: 現在78%、目標80%以上
2. **E2Eテストの追加**: 決済フローのテストを追加
3. **パフォーマンス最適化**: Lighthouseスコアを90以上に

---

**次回検証**: デプロイ前に再度実行してください
```

---

## 次のアクションを案内

> ✅ **検証が完了しました！**
>
> 📄 **検証レポート**: `.claude/validation-report.md`
>
> **検証結果**:
> - 環境変数: ✅ OK
> - 依存関係: ✅ OK
> - Lint: ✅ OK
> - 型チェック: ✅ OK
> - ビルド: ✅ OK
> - テスト: ✅ OK (15/15 passed)
> - E2Eテスト: ✅ OK (8/8 passed)
> - セキュリティ監査: ✅ OK
> - デプロイ準備: ✅ OK
>
> **総合評価**: ✅ **合格** - デプロイ可能
>
> **次にやること：**
> 1. レポートを確認: `cat .claude/validation-report.md`
> 2. デプロイ: `/deploy-setup` を実行
> 3. クライアントにレポートを共有
>
> 💡 **クライアント向け**: このレポートを納品資料として使用できます。

---

## エラーが発生した場合

検証に失敗した場合、詳細なエラーメッセージが表示されます。

### 環境変数エラー

```
❌ DATABASE_URL が設定されていません

解決方法:
1. .env.local を作成
2. DATABASE_URL=postgresql://... を追加
```

### ビルドエラー

```
❌ ビルドに失敗しました

解決方法:
1. エラーメッセージを確認
2. 該当ファイルを修正
3. 再度 /validate を実行
```

### テストエラー

```
❌ テストに失敗しました (12/15 passed)

解決方法:
1. 失敗したテストを確認
2. コードを修正
3. npm test を実行して確認
```

---

## 注意事項

- **定期実行**: デプロイ前、プルリクエスト前に実行
- **CI/CD統合**: GitHub Actionsで自動実行を推奨
- **レポート保存**: 納品時の証跡として保存
- **クライアント共有**: 品質保証の証明として共有

**この検証機能で、高品質な納品が保証されます。**

---

## ⚡ 並列実行の判断ポイント

このコマンドでは複数の検証を実行しますが、**並列実行するかどうか**を以下の基準で判断します。

### 並列実行すべき場合 ✅

| 条件 | 理由 |
|------|------|
| 検証項目が 3 つ以上 | 時間短縮効果が大きい |
| 各検証が独立している | lint/typecheck/test は互いに依存しない |
| 早く結果を知りたい | 全体の待ち時間を短縮 |

**並列実行の例**:
```
🚀 並列検証開始...
├── [Lint] 実行中... ⏳
├── [TypeCheck] 実行中... ⏳
└── [Test] 実行中... ⏳

⏱️ 所要時間: 45秒（直列なら2分、62%短縮）
```

### 直列実行すべき場合 ⚠️

| 条件 | 理由 |
|------|------|
| 検証が 1-2 つだけ | 並列化のオーバーヘッドが大きい |
| エラーを順番に修正したい | 1つずつ確認しながら進めたい |
| リソースが限られている | CI環境で並列数に制限がある |

### 自動判断ロジック

```
検証項目数 >= 3 かつ 独立した検証 → 並列実行
検証項目数 < 3 または 依存関係あり → 直列実行
```

**並列実行を明示的に指定する場合**:
```
/validate full --parallel    # 並列実行を強制
/validate full --sequential  # 直列実行を強制
```
