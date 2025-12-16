# 典型的なワークフロー例

2エージェントワークフローの実際の流れ。

---

## 例1: 新機能開発

### Phase 1: PM（Cursor）がタスクを作成

```markdown
# Plans.md

## 🟡 未着手のタスク

- [ ] ユーザープロフィール編集機能 `pm:依頼中`
  - 名前、メール、アバター画像の編集
  - バリデーション付き
  - 変更履歴の保存
```

**PM の発言**: 「Claude Code にプロフィール編集機能をお願いします」

---

### Phase 2: Claude Code が作業開始

```bash
# Claude Code で実行
/work
```

**Claude Code の作業**:
1. Plans.md を読み込み
2. `pm:依頼中` タスクを検出
3. マーカーを `cc:WIP` に更新
4. 実装開始

```markdown
# Plans.md（更新後）

## 🔴 進行中のタスク

- [ ] ユーザープロフィール編集機能 `cc:WIP`
  - 名前、メール、アバター画像の編集
  - バリデーション付き
  - 変更履歴の保存
  - 関連ファイル:
    - `src/components/ProfileForm.tsx`
    - `src/lib/api/profile.ts`
```

---

### Phase 3: Claude Code が完了報告

```bash
# Claude Code で実行
/handoff-to-cursor
```

**生成されるレポート**:

```markdown
## 📋 完了報告: ユーザープロフィール編集機能

### 実装内容
- ProfileForm コンポーネント作成
- プロフィール API エンドポイント
- Zod によるバリデーション
- 変更履歴テーブル追加

### 変更ファイル
- src/components/ProfileForm.tsx (+150 lines)
- src/lib/api/profile.ts (+80 lines)
- src/lib/validations/profile.ts (+25 lines)
- prisma/schema.prisma (+10 lines)

### テスト結果
✅ 全テスト合格 (12/12)

### 次のアクション
- [ ] staging 環境で動作確認
- [ ] デザインレビュー
```

---

### Phase 4: PM が確認

```markdown
# Plans.md（PM 更新後）

## 🟢 完了タスク

- [x] ユーザープロフィール編集機能 `pm:確認済` (2024-01-15)
```

---

## 例2: バグ修正の緊急対応

### PM からの緊急依頼

```markdown
## 🟡 未着手のタスク

- [ ] 🔥 【緊急】ログインエラー修正 `pm:依頼中`
  - 症状: 特定ユーザーがログインできない
  - エラー: "Invalid token format"
  - 優先度: 最優先
```

### Claude Code の対応

1. `/work` で着手
2. エラーログ調査
3. 原因特定・修正
4. テスト追加
5. `/handoff-to-cursor` で完了報告

---

## 例3: CI 失敗時の自動修正

### CI が失敗

```
GitHub Actions: ❌ Build failed
- TypeScript error in src/utils/date.ts:45
```

### Claude Code の自動対応

1. エラー検出
2. 型エラー修正
3. 再コミット・プッシュ

**3回失敗した場合**:

```markdown
## ⚠️ CI エスカレーション

3回修正を試みましたが解決できませんでした。

### 試した修正
1. 型アノテーション追加 → 失敗
2. 型定義ファイル更新 → 失敗
3. tsconfig 調整 → 失敗

### 推定原因
外部ライブラリの型定義が古い可能性

### 推奨アクション
- [ ] @types/xxx を最新版に更新
- [ ] ライブラリ自体のバージョン確認
```

---

## 例4: 並列タスク実行

### 複数タスクがある場合

```markdown
## 🟡 未着手のタスク

- [ ] ヘッダーコンポーネントのリファクタリング `cc:TODO`
- [ ] フッターコンポーネントのリファクタリング `cc:TODO`
- [ ] テスト追加: ユーティリティ関数 `cc:TODO`
```

### /work 実行時

Claude Code が並列実行可能か判断:
- 独立したタスク → 並列実行
- 依存関係あり → 直列実行

```
🚀 並列実行開始
├─ Agent 1: ヘッダーリファクタリング
├─ Agent 2: フッターリファクタリング
└─ Agent 3: テスト追加
```
