# Harness改善計画: Rules活用によるアーキテクチャ改善

> **ステータス**: ドラフト（確定後 Plans.md へ移植）
> **作成日**: 2025-12-23
> **対象**: claude-code-harness プラグイン

---

## 1. 背景と課題

### 1.1 メモリから抽出した課題

| ID | 課題 | 影響 |
|----|------|------|
| #6860 | Skills Gate が Edit/Write を頻繁にブロック | 開発効率低下 |
| #7124 | 毎セッションのスキル確認が冗長 | オーバーヘッド |
| #7464 | 6種のフック × 複数シェルスクリプト | 保守性低下 |

### 1.2 マルチプロジェクト運用の要件

- ユーザーは**複数のプロジェクト**でハーネスを使用
- **プラグイン更新**時にユーザーカスタマイズを破壊してはならない
- **Rules追加・更新**のライフサイクル管理が必要

---

## 2. 既存システムの強み（活用すべき資産）

### 2.1 Template Tracker（既存）

```
template-registry.json → 追跡対象テンプレート定義
template-tracker.sh → ハッシュベースのローカライズ検出
generated-files.json → プロジェクトごとの状態記録
```

**判定ロジック**:
- `fileHash` 変更なし → 🔄 上書き可
- `fileHash` 変更あり → 🔧 マージ要（ユーザーカスタマイズ保持）

### 2.2 登録済みRulesテンプレート

```json
// template-registry.json より
"rules/workflow.md.template": { "tracked": true },
"rules/coding-standards.md.template": { "tracked": true },
"rules/testing.md.template": { "tracked": true },
"rules/plans-management.md.template": { "tracked": true },
"rules/ui-debugging-dev-browser.md.template": { "tracked": true }
```

### 2.3 /localize-rules コマンド（既存）

プロジェクト構造を検出し、`paths:` を自動調整:
- TypeScript/React → `src/**/*.{ts,tsx}`
- Python → `**/*.py`
- など

---

## 3. 改善提案

### 3.1 Phase 1: テンプレートファイル作成（基盤整備）

**問題**: template-registry.json に登録済みだが、実ファイルが未作成

**対応**:
```
templates/
├── rules/
│   ├── workflow.md.template
│   ├── coding-standards.md.template
│   ├── testing.md.template
│   ├── plans-management.md.template
│   └── ui-debugging-dev-browser.md.template
└── rules-by-stack/           ← 新規追加
    ├── typescript-react.md.template
    ├── python-fastapi.md.template
    ├── nextjs.md.template
    └── golang.md.template
```

**各テンプレートの構造**:
```markdown
---
paths: "{{PLACEHOLDER_PATHS}}"
---

# {{RULE_NAME}}

## 概要
{{DESCRIPTION}}

## ルール
- ルール1
- ルール2

<!-- harness:localize-marker -->
<!-- このマーカー以下はローカライズ対象 -->
```

### 3.2 Phase 2: Rules ライフサイクル管理

#### 3.2.1 追加フロー

```
ユーザー: 「APIルールを追加して」
    ↓
/add-rule api  ← 新規コマンド
    ↓
1. templates/rules/api.md.template からコピー
2. /localize-rules で paths: を自動調整
3. generated-files.json に記録（hash保存）
4. ユーザーにカスタマイズ箇所を案内
```

#### 3.2.2 更新フロー（harness-update 拡張）

```
プラグイン更新時:
    ↓
template-tracker.sh check
    ↓
各 Rules ファイルについて:
  - ローカライズなし → 上書き
  - ローカライズあり → マージ支援（diff表示 + 提案）
    ↓
generated-files.json 更新
```

#### 3.2.3 削除フロー

```
/remove-rule api  ← 新規コマンド
    ↓
1. .claude/rules/api.md 削除
2. generated-files.json から除去
3. 確認メッセージ
```

### 3.3 Phase 3: Skills Gate → Rules 移行

#### 現状（Skills Gate）
```bash
# pretooluse-guard.sh
if ! check_skills_decision; then
  echo "❌ Skills not declared in skills-decision.json"
  exit 1
fi
```

#### 提案（Rules ベース）
```markdown
# .claude/rules/impl-guard.md
---
paths: src/**/*.{ts,tsx,js,jsx}
---

# 実装ガードルール

この領域のファイルを編集する際:
1. まず LSP ツールで型定義を確認
2. 既存パターンを踏襲
3. テストを先に書く（TDD推奨）
```

**移行メリット**:
- 明示的宣言不要（パスマッチで自動）
- シェルスクリプト削減
- Claude Code ネイティブ機能を活用

### 3.4 Phase 4: User-level vs Project-level 分離

```
~/.claude/rules/           ← ユーザーレベル（全プロジェクト共通）
├── preferences.md         ← 個人設定（更新対象外）
└── shared/                ← 共有ルール（シンボリンク可）

.claude/rules/             ← プロジェクトレベル（ハーネス管理）
├── workflow.md            ← テンプレート由来
├── coding-standards.md    ← テンプレート由来
└── project-specific.md    ← プロジェクト固有（tracked: false）
```

**設計原則**:
- `~/.claude/rules/` は**絶対に更新しない**
- `.claude/rules/` のみハーネスが管理
- `tracked: false` のファイルは更新対象外

---

## 4. 実装タスク

### 4.1 即時対応（Phase 1）

- [ ] `templates/rules/` に5つのテンプレートファイル作成
- [ ] `templates/rules-by-stack/` にスタック別テンプレート追加
- [ ] `/localize-rules` のテスト・動作確認

### 4.2 短期対応（Phase 2）

- [ ] `/add-rule` コマンド実装
- [ ] `/remove-rule` コマンド実装
- [ ] `harness-update` のRulesマージ処理テスト

### 4.3 中期対応（Phase 3）

- [ ] Skills Gate の段階的廃止計画策定
- [ ] `pretooluse-guard.sh` からSkills Gate ロジック削除
- [ ] Rules ベースのガード機構への移行

### 4.4 長期対応（Phase 4）

- [ ] ドキュメント整備（User-level vs Project-level の説明）
- [ ] シンボリンク共有ルールのガイド作成

---

## 5. マルチプロジェクト対応チェックリスト

### 5.1 ユーザーカスタマイズ保持

| シナリオ | 対応 | 確認 |
|---------|------|------|
| ユーザーが `paths:` を変更 | ハッシュ比較で検出 → マージ | ✅ |
| ユーザーがルール内容を追記 | ハッシュ比較で検出 → マージ | ✅ |
| ユーザーが新規ルールを追加 | `tracked: false` なら無視 | ✅ |
| プラグイン更新で新ルール追加 | 新規ファイルとして配置 | ✅ |

### 5.2 プラグイン更新時の安全性

| 操作 | 安全性担保 |
|------|-----------|
| 上書き | ローカライズなし確認後のみ |
| マージ | diff表示 + ユーザー確認 |
| 削除 | 自動削除なし（手動 /remove-rule） |
| バックアップ | `.claude-code-harness/backups/` に保存 |

### 5.3 新規プロジェクトへの展開

```
/harness-init
    ↓
1. プロジェクト構造検出
2. 適切なスタック用テンプレート選択
3. templates/rules/ からコピー
4. /localize-rules で自動調整
5. generated-files.json 初期化
```

---

## 6. リスクと軽減策

| リスク | 軽減策 |
|--------|--------|
| テンプレート構造変更でマージ困難 | マーカーコメントで境界を明示 |
| Rules 肥大化 | paths: 必須化でコンテキスト効率維持 |
| 既存 Skills Gate 利用者への影響 | 移行期間中は両方サポート |
| シェルスクリプト依存の残存 | 段階的移行、完全廃止は急がない |

---

## 7. 成功指標

| 指標 | 現状 | 目標 |
|------|------|------|
| Skills Gate ブロック頻度 | 高 | ゼロ（Rules自動適用） |
| harness-update 成功率 | 不明 | 95%以上（マージ失敗なし） |
| フック数 | 6種 | 3種以下 |
| 新規プロジェクトセットアップ時間 | - | 1分以内 |

---

## 8. 追加提案: template-tracker → フロントマター統合

### 8.1 現状の課題

```
template-registry.json    ← テンプレート定義（プラグイン内）
       ↓
template-tracker.sh       ← シェルスクリプトで追跡
       ↓
generated-files.json      ← プロジェクトごとの状態（別ファイル管理）
```

**問題点**:
- 追跡情報が生成ファイルと分離している
- シェルスクリプト依存（jq必須）
- 複数ファイルの同期管理が必要

### 8.2 提案: フロントマターベース追跡

**生成ファイル自体にバージョン情報を埋め込む**:

```markdown
# CLAUDE.md（生成されたファイル）
---
_harness_template: "CLAUDE.md.template"
_harness_version: "2.5.23"
_harness_generated_at: "2025-12-23"
---

# プロジェクト指針
...
```

```markdown
# .claude/rules/workflow.md（Rulesファイル）
---
paths: "**/*"
_harness_template: "rules/workflow.md.template"
_harness_version: "2.5.23"
---

# ワークフロールール
...
```

### 8.3 メリット

| 観点 | 現状 | 提案 |
|------|------|------|
| **追跡ファイル** | `generated-files.json`（別ファイル） | なし（自己完結） |
| **シェルスクリプト** | `template-tracker.sh` 必須 | 不要（Claude Code ネイティブ） |
| **バージョン確認** | jq/bash で JSON パース | フロントマター読み取り |
| **ローカライズ検出** | ハッシュ比較 | コンテンツ差分で判定 |
| **他ツール連携** | harness専用 | 標準マークダウン互換 |

### 8.4 統合対象の分散管理ファイル

| 現状の分散管理 | フロントマター統合後 |
|---------------|---------------------|
| `VERSION` | `_harness_version` in 各ファイル |
| `.claude-code-harness-version` | 廃止可能 |
| `generated-files.json` | 廃止（フロントマターに移行） |
| `template-tracker.sh` | 廃止（Claude Code ネイティブ） |

### 8.5 安全な移行戦略（破壊的変更回避）

```
Phase A: テンプレートにフロントマター追加（非破壊）
    ↓ 新規生成ファイルのみ影響、既存は旧方式継続

Phase B: harness-update をフロントマター優先に（並行サポート）
    ↓ フロントマターあり → 新方式
    ↓ フロントマターなし → 旧方式（generated-files.json）

Phase C: session-init.sh を更新（並行サポート）
    ↓ 同上の並行サポート

Phase D: 旧方式の非推奨化（十分な移行期間後）
    ↓ template-tracker.sh, generated-files.json を deprecated に
```

### 8.6 影響分析

| 変更 | リスク | 軽減策 |
|------|--------|--------|
| フロントマター追加 | **低** | 既存ファイルに影響なし |
| generated-files.json廃止 | **高** | 並行サポート期間を設ける |
| template-tracker.sh廃止 | **高** | 段階的移行（フォールバック） |
| session-init.sh変更 | **中** | 新旧両方式をサポート |

### 8.7 依存関係（現行）

```
template-tracker.sh
  ← session-init.sh (Step 4: 更新チェック)
  ← harness-update.md (check/status/record)

generated-files.json
  ← template-tracker.sh (状態保存)
  ← session-init.sh (存在チェック)
```

---

## 9. 統合実装タスク

### 9.1 Phase A: フロントマター追加（即時・非破壊） ✅ 完了

- [x] 全テンプレートファイル（15個）に `_harness_*` フロントマター追加
- [x] `frontmatter-utils.sh` を作成（5関数、MD/JSON/YAML対応）
- [x] 既存プロジェクトは影響なし（旧方式継続）

### 9.2 Phase B: 並行サポート（短期） ✅ 完了

- [x] `template-tracker.sh` をフロントマター優先に修正
- [x] フォールバック: フロントマターなし → `generated-files.json`
- [x] [FM]/[GF] ソース表示を追加

### 9.3 Phase C: session-init更新（中期） ✅ 完了

- [x] `session-init.sh` は `template-tracker.sh` 経由で既にフロントマター対応
- [x] 追加の変更不要（template-tracker.sh がフロントマター優先で動作）

### 9.4 Phase D: 旧方式非推奨（長期） ✅ 完了

- [x] `template-tracker.sh` に deprecation 注記追加（v2.5.30+）
- [ ] ドキュメントに移行ガイド追加（オプション）
- [ ] 次メジャーバージョンで完全削除（v3.0.0 予定）

---

## 10. 次のアクション

1. ~~**確認完了**: 計画承認済み~~
2. ~~**実装開始**: Phase A（フロントマター追加）から着手~~
3. ~~**確定後**: Plans.md に移植~~

**✅ 全フェーズ完了** (v2.5.30)

---

## 付録: 関連ファイル

- `/commands/optional/localize-rules.md`
- `/scripts/template-tracker.sh`（将来的に廃止予定）
- `/templates/template-registry.json`
- `/commands/optional/harness-update.md`
- `/scripts/session-init.sh`
