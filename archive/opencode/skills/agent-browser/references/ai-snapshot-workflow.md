# AI Snapshot Workflow

agent-browser の `snapshot` コマンドを活用した AI エージェント向けワークフロー。

---

## 概要

`snapshot` コマンドは、ページのアクセシビリティツリーを取得し、各要素に参照 ID（`@e1`, `@e2` など）を付与します。これにより：

1. **CSS セレクタ不要**: 動的な ID やクラス名に依存しない
2. **コンテキスト把握**: 要素の役割（button, input, link）が明確
3. **決定的操作**: `@e1` などの参照で確実に操作可能

---

## 基本ワークフロー

### Step 1: ページを開く

```bash
agent-browser open https://example.com
```

### Step 2: スナップショット取得

```bash
agent-browser snapshot -i -c
```

**オプション説明**:
- `-i, --interactive`: インタラクティブな要素（ボタン、リンク、入力フィールド等）のみ表示
- `-c, --compact`: 空の構造要素を除去してコンパクトに

**出力例**:
```
✓ Example Domain
  https://example.com/

- link "Home" [ref=e1]
- link "About" [ref=e2]
- button "Login" [ref=e3]
- input "Search" [ref=e4]
- button "Search" [ref=e5]
```

### Step 3: 要素参照で操作

```bash
# リンクをクリック
agent-browser click @e1

# 検索フォームに入力
agent-browser fill @e4 "search query"

# 検索ボタンをクリック
agent-browser click @e5
```

### Step 4: 結果を確認

```bash
# 新しい状態をスナップショット
agent-browser snapshot -i -c
```

---

## Snapshot オプション詳細

### `-i, --interactive`

インタラクティブな要素のみを表示。操作対象を絞り込む際に有効。

```bash
# インタラクティブ要素のみ
agent-browser snapshot -i

# 全要素（テキストノード含む）
agent-browser snapshot
```

### `-c, --compact`

空の構造要素（div, span など内容のないもの）を除去。

```bash
# コンパクト出力
agent-browser snapshot -c

# 構造も含めて表示
agent-browser snapshot
```

### `-d, --depth <n>`

ツリーの深さを制限。大きなページで概要を把握する際に有効。

```bash
# 深さ3まで
agent-browser snapshot -d 3
```

### `-s, --selector <sel>`

特定のセレクタにスコープを絞る。

```bash
# フォーム内のみ
agent-browser snapshot -s "form.login"

# ナビゲーション内のみ
agent-browser snapshot -s "nav"
```

### 組み合わせ

```bash
# 推奨: インタラクティブ + コンパクト
agent-browser snapshot -i -c

# フォーム内のインタラクティブ要素のみ
agent-browser snapshot -i -c -s "form"

# 浅いツリーで概要把握
agent-browser snapshot -i -d 2
```

---

## ユースケース別ワークフロー

### ログインフロー

```bash
# 1. ログインページを開く
agent-browser open https://example.com/login

# 2. スナップショット取得
agent-browser snapshot -i -c
# 出力:
# - input "Email" [ref=e1]
# - input "Password" [ref=e2]
# - button "Login" [ref=e3]
# - link "Forgot password?" [ref=e4]

# 3. ログイン情報を入力
agent-browser fill @e1 "user@example.com"
agent-browser fill @e2 "password123"

# 4. ログインボタンをクリック
agent-browser click @e3

# 5. 結果を確認
agent-browser snapshot -i -c
agent-browser get url
```

### フォーム送信

```bash
# 1. フォームページを開く
agent-browser open https://example.com/contact

# 2. フォーム内のスナップショット
agent-browser snapshot -i -c -s "form"
# 出力:
# - input "Name" [ref=e1]
# - input "Email" [ref=e2]
# - textarea "Message" [ref=e3]
# - button "Send" [ref=e4]

# 3. フォームに入力
agent-browser fill @e1 "John Doe"
agent-browser fill @e2 "john@example.com"
agent-browser fill @e3 "Hello, this is a test message."

# 4. 送信
agent-browser click @e4

# 5. 確認
agent-browser snapshot -i -c
```

### ナビゲーション探索

```bash
# 1. トップページを開く
agent-browser open https://example.com

# 2. ナビゲーションを確認
agent-browser snapshot -i -c -s "nav"
# 出力:
# - link "Home" [ref=e1]
# - link "Products" [ref=e2]
# - link "About" [ref=e3]
# - link "Contact" [ref=e4]

# 3. Products ページへ
agent-browser click @e2

# 4. 新しいページの構造を確認
agent-browser snapshot -i -c
```

### 動的コンテンツの操作

```bash
# 1. ページを開く
agent-browser open https://example.com/dashboard

# 2. 初期スナップショット
agent-browser snapshot -i -c

# 3. ドロップダウンを開く
agent-browser click @e5

# 4. 待機（動的コンテンツのロード）
agent-browser wait 500

# 5. 新しいスナップショット（ドロップダウンメニューが表示される）
agent-browser snapshot -i -c
# 新しい要素が出現:
# - menuitem "Option 1" [ref=e10]
# - menuitem "Option 2" [ref=e11]
# - menuitem "Option 3" [ref=e12]

# 6. オプションを選択
agent-browser click @e11
```

---

## トラブルシューティング

### 要素が見つからない

```bash
# フルスナップショット（すべての要素）
agent-browser snapshot

# 特定セレクタで絞り込み
agent-browser snapshot -s "#target-element"

# 待機してから再試行
agent-browser wait 2000
agent-browser snapshot -i -c
```

### 動的ページ

```bash
# JavaScript 実行後にスナップショット
agent-browser eval "document.querySelector('#load-more').click()"
agent-browser wait 1000
agent-browser snapshot -i -c
```

### iframe 内の要素

```bash
# メインフレームのスナップショット
agent-browser snapshot -i -c

# iframe 内は直接アクセスできないため、
# eval で iframe 内の操作を行う
agent-browser eval "document.querySelector('iframe').contentDocument.querySelector('button').click()"
```

---

## ベストプラクティス

### 1. 常にスナップショットから開始

操作前に必ずスナップショットを取得し、現在の状態を把握する。

### 2. インタラクティブ + コンパクトをデフォルトに

```bash
agent-browser snapshot -i -c
```

### 3. 操作後は状態を確認

```bash
agent-browser click @e1
agent-browser snapshot -i -c  # 結果を確認
```

### 4. 適切な待機を入れる

動的コンテンツがある場合は待機を入れる：

```bash
agent-browser click @e1
agent-browser wait 500
agent-browser snapshot -i -c
```

### 5. セッションを活用

認証状態を維持するためにセッションを使用：

```bash
agent-browser --session myapp open https://example.com/login
# ... ログイン操作 ...
# 以降、同じセッションで操作を継続
agent-browser --session myapp open https://example.com/dashboard
```
