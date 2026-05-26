# Security Reviewer Profile

`harness-review --security` で起動するセキュリティ専用レビュープロファイル。
OWASP Top 10 をベースに、認証・認可・秘密情報・依存パッケージの脆弱性を網羅的にチェックする。

> **Read-only 制約**: このプロファイルで動作する reviewer は
> Read / Grep / Glob / Bash（読み取り専用コマンドのみ）を使用する。
> Write / Edit / 書き込み系 Bash は一切実行しない。

---

## Security Review フロー

### Step 1: 対象範囲を特定

```bash
# 変更ファイルを収集（BASE_REF は呼び出し元から引き継ぐ）
CHANGED_FILES="$(git diff --name-only --diff-filter=ACMR "${BASE_REF:-HEAD~1}")"
git diff "${BASE_REF:-HEAD~1}" -- ${CHANGED_FILES}
```

### Step 2: OWASP Top 10 チェック

以下の各項目を **変更差分** と **関連ファイル** に対して確認する。

#### A01: アクセス制御の不備 (Broken Access Control)

| チェック項目 | 確認方法 |
|------------|---------|
| 認可チェックの抜け | ルート/エンドポイント定義に認証ミドルウェアが適用されているか |
| 水平越権アクセス | ユーザー所有リソース取得時に `userId` 等でフィルタリングしているか |
| 垂直越権アクセス | ロールチェック（admin/user/guest 等）が適切に実装されているか |
| IDOR | URL パラメータやリクエストボディの ID が認可なしに受け入れられていないか |
| ディレクトリトラバーサル | `../` を含むパス操作がサニタイズされているか |

**検出パターン（Grep で確認）**:
```bash
# 認証なしルート候補
grep -rn "app\.\(get\|post\|put\|delete\|patch\)" --include="*.ts" --include="*.js"
# userId なしでのDB取得
grep -rn "findById\|findOne\|select.*where" --include="*.ts"
```

#### A02: 暗号化の失敗 (Cryptographic Failures)

| チェック項目 | 確認方法 |
|------------|---------|
| 平文での機密情報保存 | パスワード、トークン、PII が平文で DB/ログに保存されていないか |
| 弱いハッシュアルゴリズム | MD5 / SHA1 をパスワードハッシュに使用していないか |
| 安全でない乱数 | `Math.random()` を認証トークン生成に使用していないか |
| TLS 強度 | HTTP（非HTTPS）での機密データ送受信がないか |
| 鍵のハードコード | 暗号鍵・IV が定数として埋め込まれていないか |

**検出パターン**:
```bash
grep -rn "md5\|sha1\|Math\.random\(\)" --include="*.ts" --include="*.js"
grep -rn "createHash.*md5\|createHash.*sha1" --include="*.ts"
grep -rn "http://" --include="*.ts" --include="*.js" --include="*.env*"
```

#### A03: インジェクション (Injection)

| チェック項目 | 確認方法 |
|------------|---------|
| SQL インジェクション | ユーザー入力を文字列連結で SQL に組み込んでいないか |
| NoSQL インジェクション | MongoDB 等で `$where` や入力値を演算子として使用していないか |
| コマンドインジェクション | `exec()` / `spawn()` にユーザー入力を渡していないか |
| LDAP インジェクション | LDAP クエリにサニタイズなしの入力を使用していないか |
| テンプレートインジェクション | テンプレートエンジンにユーザー入力を直接渡していないか |

**検出パターン**:
```bash
grep -rn "exec\|execSync\|spawn" --include="*.ts" --include="*.js"
grep -rn "\`SELECT\|\"SELECT\|'SELECT" --include="*.ts" --include="*.js"
grep -rn "\$where\|\$\[" --include="*.ts" --include="*.js"
```

#### A04: 安全でない設計 (Insecure Design)

| チェック項目 | 確認方法 |
|------------|---------|
| レート制限の欠如 | 認証エンドポイントにレート制限が実装されているか |
| TOCTOU 競合状態 | チェック後・使用前の状態変更を悪用できないか |
| ビジネスロジックの欠陥 | 状態遷移が不正な順序で実行できないか |

#### A05: セキュリティの設定ミス (Security Misconfiguration)

| チェック項目 | 確認方法 |
|------------|---------|
| デフォルト認証情報 | デフォルトパスワード/ユーザー名がそのまま使用されていないか |
| 詳細なエラーメッセージ | スタックトレースや内部情報が本番でクライアントに返されないか |
| 不要な機能の有効化 | デバッグエンドポイント・管理画面が本番で有効でないか |
| HTTP セキュリティヘッダー | HSTS, CSP, X-Frame-Options 等が設定されているか |
| CORS 設定 | `Access-Control-Allow-Origin: *` が本番で設定されていないか |

**検出パターン**:
```bash
grep -rn "cors.*origin.*\*\|allowedOrigins.*\*" --include="*.ts" --include="*.js"
grep -rn "debug.*true\|NODE_ENV.*development" --include="*.ts"
grep -rn "console\.log.*password\|console\.log.*token\|console\.log.*secret" --include="*.ts"
```

#### A06: 脆弱で古いコンポーネント (Vulnerable and Outdated Components)

| チェック項目 | 確認方法 |
|------------|---------|
| 既知の脆弱性を持つパッケージ | `package.json` の依存関係に CVE が報告されているバージョンがないか |
| `npm audit` の結果 | high / critical 脆弱性が放置されていないか |
| ロックファイルとの整合性 | `package-lock.json` / `yarn.lock` が最新か |

**確認コマンド**:
```bash
# package.json の依存関係を確認（読み取りのみ）
cat package.json | grep -E '"dependencies"|"devDependencies"' -A 50 | head -60
# ロックファイルの存在確認
ls -la package-lock.json yarn.lock pnpm-lock.yaml 2>/dev/null
```

#### A07: 識別と認証の失敗 (Identification and Authentication Failures)

| チェック項目 | 確認方法 |
|------------|---------|
| ブルートフォース対策 | ログイン試行回数の制限・アカウントロックが実装されているか |
| 弱いパスワードポリシー | 最小文字数・複雑性の要件が設定されているか |
| セッション固定攻撃 | ログイン後にセッション ID が再生成されているか |
| セッション有効期限 | 長期間有効なセッション/トークンが適切に失効するか |
| JWT 検証 | `alg: none` や弱い鍵での署名を受け入れていないか |

**検出パターン**:
```bash
grep -rn "jwt\.verify\|jwt\.sign" --include="*.ts" --include="*.js"
grep -rn "expiresIn.*\|expire.*" --include="*.ts"
grep -rn "algorithm.*none\|alg.*none" --include="*.ts" --include="*.js"
```

#### A08: ソフトウェアとデータの整合性の失敗 (Software and Data Integrity Failures)

| チェック項目 | 確認方法 |
|------------|---------|
| 信頼できないソースからのコード実行 | 外部 CDN / URL から動的にスクリプトを読み込んでいないか |
| デシリアライゼーション | 信頼できないデータを直接 `eval()` / `Function()` に渡していないか |
| CI/CD パイプラインの保護 | ビルドスクリプトが外部入力を無検証で実行していないか |

**検出パターン**:
```bash
grep -rn "eval(\|new Function(" --include="*.ts" --include="*.js"
grep -rn "require(.*\$\|import(.*\$" --include="*.ts" --include="*.js"
```

#### A09: セキュリティのログと監視の失敗 (Security Logging and Monitoring Failures)

| チェック項目 | 確認方法 |
|------------|---------|
| 認証失敗のログ | ログイン失敗・権限エラーが記録されているか |
| 機密情報のログ出力 | パスワード・トークン・PII がログに含まれていないか |
| ログインジェクション | ユーザー入力がログに直接書き込まれていないか（CRLF インジェクション） |

#### A10: サーバーサイドリクエストフォージェリ (SSRF)

| チェック項目 | 確認方法 |
|------------|---------|
| ユーザー指定 URL へのリクエスト | ユーザー入力の URL に対して内部ネットワークへのアクセスが可能でないか |
| URL バリデーション | 許可ドメインリストや IP フィルタリングが実装されているか |
| リダイレクト追従 | リクエストライブラリが内部アドレスへのリダイレクトを追従しないか |

**検出パターン**:
```bash
grep -rn "fetch(\|axios\.\|got(\|request(" --include="*.ts" --include="*.js"
```

---

## 認証・認可 レビューポイント

### 認証フロー

```
1. 入力バリデーション → 型・長さ・形式チェックがあるか
2. 認証処理 → タイミング攻撃対策（constantTimeCompare 等）があるか
3. トークン発行 → 十分なエントロピー（crypto.randomBytes 等）があるか
4. トークン保存 → httpOnly + Secure + SameSite Cookie か、LocalStorage か
5. トークン検証 → 署名・有効期限・失効チェックが完全か
6. ログアウト → サーバー側でのトークン無効化が実装されているか
```

### 認可フロー

```
1. エンドポイントごとに必要なロールが明示されているか
2. ミドルウェアとルートハンドラの両方でチェックされているか（多層防御）
3. フロントエンドの非表示だけに依存していないか（バックエンド必須）
4. リソースオーナーシップの検証が抜けていないか
```

---

## 秘密情報の取り扱い

### ハードコード検出

```bash
# API キー・シークレットっぽいパターン
grep -rn "api[_-]key\s*=\s*['\"][^'\"]\|secret\s*=\s*['\"][^'\"]" \
  --include="*.ts" --include="*.js" --include="*.sh"

# AWS / GCP / Azure 認証情報
grep -rn "AKIA\|sk-[a-zA-Z0-9]\{20\}\|AIza" --include="*.ts" --include="*.js"

# JWT 署名鍵のハードコード
grep -rn "jwt.*secret.*=\s*['\"][^'\"]\{8,\}" --include="*.ts" --include="*.js"

# .env ファイルへのコミット
git diff "${BASE_REF:-HEAD~1}" -- .env .env.local .env.production
```

### 環境変数の適切な利用

| 良いパターン | 悪いパターン |
|------------|------------|
| `process.env.DATABASE_URL` | `"postgresql://user:pass@localhost/db"` |
| `process.env.JWT_SECRET` | `const JWT_SECRET = "my-super-secret"` |
| `process.env.API_KEY` | `const API_KEY = "sk-abc123..."` |

### .env ファイルの管理

- `.env.example` にダミー値が記載されているか
- `.env` / `.env.local` が `.gitignore` に含まれているか
- 本番シークレットが `.env.production` にコミットされていないか

```bash
# .gitignore の確認
grep -n "\.env" .gitignore 2>/dev/null
# リポジトリに .env ファイルが含まれていないか
git diff "${BASE_REF:-HEAD~1}" --name-only | grep "\.env"
```

---

## 依存パッケージの既知脆弱性チェック

### package.json の確認手順

1. 変更された `package.json` を読み取る
2. 新規追加・バージョンアップされたパッケージを特定する
3. 既知の CVE データベース（NVD, Snyk, GitHub Advisory）との照合を推奨

```bash
# 変更されたパッケージを確認
git diff "${BASE_REF:-HEAD~1}" -- package.json package-lock.json

# 現在の依存関係バージョンを確認
cat package.json | python3 -c "import json,sys; d=json.load(sys.stdin); [print(k,v) for d2 in [d.get('dependencies',{}),d.get('devDependencies',{})] for k,v in d2.items()]" 2>/dev/null
```

### 高リスクパッケージカテゴリ

| カテゴリ | 注意点 |
|---------|--------|
| 認証ライブラリ | passport, jsonwebtoken, bcrypt — バージョンに依存した脆弱性が多い |
| HTTP クライアント | axios, node-fetch, got — SSRF 対策のデフォルト設定を確認 |
| テンプレートエンジン | handlebars, ejs, pug — RCE 脆弱性の過去事例あり |
| XML パーサー | xml2js, fast-xml-parser — XXE 攻撃に注意 |
| シリアライゼーション | serialize-javascript, node-serialize — RCE リスク |
| 画像処理 | sharp, imagemagick — バッファオーバーフロー系の脆弱性 |

---

## Security Review 出力形式

通常の Code Review と同じ JSON スキーマを使用するが、`reviewer_profile: "security"` を設定する。

```json
{
  "schema_version": "review-result.v1",
  "verdict": "APPROVE | REQUEST_CHANGES",
  "reviewer_profile": "security",
  "critical_issues": [
    {
      "severity": "critical",
      "category": "Security",
      "owasp": "A03:2021 - Injection",
      "location": "src/api/users.ts:42",
      "issue": "ユーザー入力を直接 SQL 文字列に連結している",
      "suggestion": "プリペアドステートメントまたは ORM を使用する",
      "cwe": "CWE-89"
    }
  ],
  "major_issues": [],
  "observations": [],
  "recommendations": []
}
```

### Security 固有フィールド

| フィールド | 説明 |
|----------|------|
| `owasp` | 該当する OWASP Top 10 カテゴリ（例: `A01:2021 - Broken Access Control`） |
| `cwe` | 該当する CWE 番号（例: `CWE-89`） |
| `cvss_estimate` | CVSS スコアの概算（Critical: 9.0+, High: 7.0-8.9, Medium: 4.0-6.9） |

### Verdict 判定基準（Security モード）

Security モードでは通常より厳格な基準を適用する。

| 重要度 | 定義 | verdict |
|--------|------|---------|
| **critical** | RCE, 認証バイパス, 機密情報の直接露出, SQLi/CMDi | 1 件でも REQUEST_CHANGES |
| **major** | 不十分な認可チェック, ハードコードされた秘密情報, 脆弱な暗号化 | 1 件でも REQUEST_CHANGES |
| **minor** | セキュリティヘッダーの欠如, 過剰なエラー情報, 軽微な設定ミス | APPROVE（修正推奨を添える） |
| **recommendation** | セキュリティベストプラクティスの提案 | APPROVE |
