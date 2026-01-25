---
description: "[オプション] 作業後にPlans.md等が更新されているか不明な時、念のため実行"
description-en: "[Optional] Sync project specs when unsure if updated"
---

# /sync-project-specs - 作業後の念のため同期

**作業完了後に「Plans.md ちゃんと更新されてるかな？」と不安な時に実行するコマンドです。**

## いつ使う？

| 状況 | 使うべきコマンド |
|------|-----------------|
| 「今どこまで進んだ？次は？」 | `/sync-status`（まずこちら） |
| 「作業したけど Plans.md 更新したか覚えてない」 | **このコマンド** |
| 「古いテンプレから始めたので形式が古いかも」 | **このコマンド** |

> 💡 **ヒント**: 通常は `/sync-status` で十分です。このコマンドは「念のため」や「形式の移行」が必要な時に使います。

---

このコマンドは、プロジェクト内の **仕様書/運用ドキュメント**（例: `Plans.md`, `AGENTS.md`, `.claude/rules/*`）を、
claude-code-harness の最新運用（**PM ↔ Impl**, `pm:*` マーカー、ハンドオフ2コマンド）に揃えます。

「忙しくて更新を忘れた」「途中で運用が変わった」「古いテンプレから始めた」時のリカバリ用です。

## バイブコーダー向け（こう言えばOK）

- 「**作業終わったけど Plans.md 更新したか不安**」→ このコマンド
- 「**古い形式のファイルを最新に揃えたい**」→ マーカーと説明を統一します
- 「**手動変更は残して、必要な部分だけ直して**」→ 既存の文章は極力維持して差分だけ当てます

## できること（成果物）

- `Plans.md` の **マーカー凡例/状態遷移/運用説明** を PM↔Impl 前提に更新
- `AGENTS.md` の **役割分担** を PM（Cursor/PM Claude）↔ Impl（Claude Code）に更新
- `.claude/rules/workflow.md` / `.claude/rules/plans-management.md` の **運用ルール** を更新
- `cursor:*` マーカーは **互換として同義扱い**の説明を残す

## 同期対象（存在するものだけ）

- `Plans.md`
- `AGENTS.md`
- `CLAUDE.md`（運用説明がある場合のみ）
- `.claude/rules/workflow.md`
- `.claude/rules/plans-management.md`

## 同期内容（最小差分ポリシー）

1. **マーカーの正規化**
   - 正規: `pm:依頼中`, `pm:確認済`
   - 互換: `cursor:依頼中`, `cursor:確認済`（同義として扱う）
2. **状態遷移の明文化**
   - `pm:依頼中 → cc:WIP → cc:完了 → pm:確認済`
3. **ハンドオフ導線の追記**
   - PM→Impl: `/handoff-to-impl-claude`（PM Claude向け）
   - Impl→PM: `/handoff-to-pm-claude`
   - Cursor運用の場合は従来通り（`/handoff-to-claude`, `/handoff-to-cursor`）
4. **通知ファイルの説明**
   - `.claude/state/pm-notification.md`（互換: `.claude/state/cursor-notification.md`）

## 実行手順

### Step 1: 現状を収集（必須）

- 対象ファイルの存在確認と、該当セクションの抜粋を取得
- `Plans.md` のマーカー出現状況（pm/cursor/cc）を集計

### Step 2: 変更方針の宣言（必須）

ユーザーに以下を先に宣言：

- 既存の文章は原則残す（破壊的リライトはしない）
- 追加/置換は「運用に必要な最低限」に絞る
- 変更は差分で提示し、必要なら調整する

### Step 3: 同期（差分適用）

- `Plans.md`
  - マーカー凡例に `pm:*` を追加し、`cursor:*` を互換として明記
  - 状態遷移表記を PM↔Impl へ
- `AGENTS.md`
  - 役割分担を PM/Impl へ
  - Plans のマーカー表と遷移を PM↔Impl へ（互換注記あり）
- `.claude/rules/workflow.md` / `.claude/rules/plans-management.md`
  - `cursor:*` 表記を `pm:*` 正規＋互換注記へ
- `CLAUDE.md`
  - もし運用説明セクションがあるなら、PM↔Impl の導線を追記（既存を壊さない）

### Step 4: 仕上げ（必須）

- `/sync-status` で集計して、マーカーが意図通りか確認
- 必要なら `/remember` で「このプロジェクト固有の運用」を固定

---

## ⚡ 並列実行の判断ポイント

このコマンドでは複数ファイルの確認・更新を行うため、**ファイル読み込みフェーズ**で並列実行が有効です。

### 並列実行すべき場合 ✅

| 処理 | 並列化 |
|------|--------|
| Plans.md の読み込み | ✅ 独立 |
| AGENTS.md の読み込み | ✅ 独立 |
| CLAUDE.md の読み込み | ✅ 独立 |
| .claude/rules/*.md の読み込み | ✅ 独立 |

**対象ファイルが 3 つ以上ある場合**:
```
🚀 ファイル収集開始...
├── [Plans.md] 読み込み中... ⏳
├── [AGENTS.md] 読み込み中... ⏳
├── [CLAUDE.md] 読み込み中... ⏳
└── [rules/*.md] 読み込み中... ⏳

→ 同時に読み込んで時間短縮
```

### 直列実行される処理

更新は**ファイル間の整合性**を保つため直列実行：

```
ファイル読み込み（並列）→ 差分分析（直列）→ 更新適用（直列）→ 検証（直列）
```

### 自動判断ロジック

```
同期対象ファイル >= 3 → ファイル読み込みを並列実行
同期対象ファイル < 3  → 直列実行（オーバーヘッド回避）
```


