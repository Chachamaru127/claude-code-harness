# E2E Verification Design (Future)

> **Status**: 設計フェーズ（将来実装予定）
>
> CDP (Chrome DevTools Protocol) を活用した E2E 検証機能の設計。

## Overview

`/verify --e2e` コマンドで、実際のブラウザを操作して E2E テストを自動実行する機能。

**目的**: Sloppiness（コード品質低下）問題の解決強化

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Claude Code                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │              /verify --e2e                       │   │
│  └─────────────────┬───────────────────────────────┘   │
│                    │                                    │
│  ┌─────────────────▼───────────────────────────────┐   │
│  │           E2E Verification Skill                 │   │
│  │  - シナリオ生成                                   │   │
│  │  - 実行制御                                       │   │
│  │  - 結果分析                                       │   │
│  └─────────────────┬───────────────────────────────┘   │
└────────────────────┼────────────────────────────────────┘
                     │
     ┌───────────────┴───────────────┐
     │                               │
     ▼                               ▼
┌─────────────┐              ┌─────────────┐
│  Playwright │              │     CDP     │
│   (推奨)    │              │  (軽量版)   │
└──────┬──────┘              └──────┬──────┘
       │                            │
       └────────────┬───────────────┘
                    ▼
              ┌───────────┐
              │  Browser  │
              │ (Chromium)│
              └───────────┘
```

## Proposed Commands

### /verify --e2e

```bash
# 基本実行
/verify --e2e

# 特定のフローのみ
/verify --e2e --flow login,checkout

# スクリーンショット比較あり
/verify --e2e --visual

# CI モード（ヘッドレス）
/verify --e2e --ci
```

### オプション

| オプション | 説明 | デフォルト |
|------------|------|------------|
| `--flow` | 検証するフロー | all |
| `--visual` | スクリーンショット比較 | false |
| `--ci` | CI モード（ヘッドレス） | false |
| `--base-url` | 対象URL | http://localhost:3000 |
| `--timeout` | タイムアウト(ms) | 30000 |

## E2E Flow Detection

プロジェクトを分析して自動的にテストフローを検出：

### 検出対象

1. **認証フロー**
   - `/login`, `/signup`, `/auth/*` ルート
   - form[action*="login"], form[action*="register"]

2. **CRUD フロー**
   - `/api/*` エンドポイント
   - フォーム送信ページ

3. **決済フロー**
   - `/checkout`, `/payment`, `/cart`
   - Stripe/PayPal 連携

4. **ナビゲーション**
   - メインナビゲーション
   - フッターリンク

### 自動生成シナリオ例

```typescript
// auto-generated: login-flow.spec.ts
test('ログインフロー', async ({ page }) => {
  await page.goto('/login');
  await page.fill('[name="email"]', 'test@example.com');
  await page.fill('[name="password"]', 'password');
  await page.click('button[type="submit"]');
  await expect(page).toHaveURL('/dashboard');
});
```

## Visual Regression Testing

### スクリーンショット比較

```
.claude/e2e/
├── baseline/          # 基準スクリーンショット
│   ├── login.png
│   └── dashboard.png
├── current/           # 今回のスクリーンショット
│   ├── login.png
│   └── dashboard.png
└── diff/              # 差分
    └── dashboard-diff.png
```

### 差分検出

```bash
/verify --e2e --visual

# 出力例
📸 Visual Regression Report:
  ✅ login.png - 一致
  ⚠️ dashboard.png - 差分検出 (2.3%)
     → .claude/e2e/diff/dashboard-diff.png を確認

💡 意図した変更の場合: /verify --e2e --update-baseline
```

## Integration with Existing Skills

### verify スキルとの連携

```
/verify
├── build        # ビルド検証（既存）
├── lint         # Lint 検証（既存）
├── test         # ユニットテスト（既存）
└── e2e          # E2E 検証（新規）
```

### harness-review との連携

```bash
/harness-review --include-e2e

# レビュー項目に E2E 結果を含める
```

## Implementation Phases

### Phase 1: 基盤整備

- [ ] Playwright MCP サーバー連携
- [ ] 基本的な E2E 実行機能
- [ ] 結果レポート生成

### Phase 2: 自動化

- [ ] フロー自動検出
- [ ] シナリオ自動生成
- [ ] CI 連携

### Phase 3: Visual Testing

- [ ] スクリーンショット取得
- [ ] 差分比較
- [ ] ベースライン管理

### Phase 4: AI 支援

- [ ] 失敗原因の AI 分析
- [ ] 修正提案の自動生成
- [ ] フレーキーテストの検出

## Technical Considerations

### Playwright vs CDP 直接操作

| 観点 | Playwright | CDP 直接 |
|------|------------|----------|
| 学習コスト | 低（API が整理されている） | 高 |
| 機能 | 豊富（セレクタ、待機など） | 基本のみ |
| 安定性 | 高 | 中 |
| 依存 | playwright パッケージ | なし |
| 推奨 | ✅ | 軽量版用途 |

**結論**: Playwright を推奨、CDP は MCP 経由で既にサポート済み

### MCP 連携

既存の MCP サーバーを活用：

```json
// .claude/settings.json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@anthropic-ai/mcp-playwright"]
    }
  }
}
```

## Example Usage Scenario

### 1. 初回セットアップ

```bash
/verify --e2e --init

# 出力
🎭 E2E 検証をセットアップします

検出されたフロー:
  - 認証: /login, /signup
  - ダッシュボード: /dashboard
  - 設定: /settings

📁 生成ファイル:
  - .claude/e2e/flows.json
  - .claude/e2e/scenarios/auth.spec.ts
  - .claude/e2e/scenarios/dashboard.spec.ts

💡 実行: /verify --e2e
```

### 2. 通常実行

```bash
/verify --e2e

# 出力
🎭 E2E 検証を実行中...

  ✅ auth.spec.ts (3 tests)
     - ログイン成功 (1.2s)
     - ログイン失敗（無効なパスワード） (0.8s)
     - ログアウト (0.5s)

  ❌ dashboard.spec.ts (2 tests)
     - ✅ ダッシュボード表示 (1.5s)
     - ❌ グラフ表示 (timeout)
        Error: Element [data-testid="chart"] not found

📊 結果: 4/5 passed, 1 failed

💡 失敗テストの修正提案:
   [data-testid="chart"] が見つかりません。
   - コンポーネントがレンダリングされているか確認
   - data-testid 属性が正しく設定されているか確認
```

### 3. CI での実行

```yaml
# .github/workflows/e2e.yml
jobs:
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        run: npm ci
      - name: Build
        run: npm run build
      - name: Start server
        run: npm start &
      - name: Run E2E
        run: claude --non-interactive "/verify --e2e --ci"
```

## Related Documents

- [IMPLEMENTATION_GUIDE.md](../IMPLEMENTATION_GUIDE.md) - 実装ガイド
- [docs/CURSOR_INTEGRATION.md](CURSOR_INTEGRATION.md) - Cursor 連携

## Notes

- 実装優先度は低め（Phase 4 として位置付け）
- MCP Playwright サーバーの成熟度に依存
- ユーザーからの需要に応じて優先度を調整
