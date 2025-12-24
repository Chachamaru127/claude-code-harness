# Claude-mem Integration Plan

Claude-mem と Harness の統合により、セッション跨ぎの品質・文脈維持を強化する計画。

**作成日**: 2025-12-25
**ステータス**: 計画策定完了

---

## 概要

### 目的

- Claude-mem のモードシステムをハーネス仕様にカスタマイズ
- セッション跨ぎのガードレール能力、指示追従能力をアップグレード
- プロジェクト全体での学習・品質向上を実現

### 位置づけ

- **オプショナルな推奨プラグイン**として位置づけ
- 必須ではないが「入れたら能力が大幅に向上」
- 既存のリポジトリ構造は変更不要
- Claude-mem がない環境でも従来通り動作

### 役割分担

| システム | 役割 | 特徴 |
|---------|------|------|
| **Claude-mem** | セッション履歴、ガードレール発動履歴、細かい実装判断 | 自動的・詳細 |
| **Harness SSOT** | アーキテクチャ判断、パターン、チーム共有すべき知識 | 意図的・Git管理 |

→ 重複ではなく**補完関係**

---

## 主要コンポーネント

### 1. `/harness-mem` コマンド

Claude-mem をハーネス仕様にカスタマイズするセットアップコマンド。

**機能:**
1. Claude-mem インストール検出（未インストールならインストール提案）
2. 日本語化オプション確認
3. `harness.json` モードファイル生成・配置
4. settings.json に `CLAUDE_MEM_MODE=harness` (または `harness--ja`) 設定
5. スキル統合設定（memory-integration.md 追加）
6. 動作確認

**ファイル:** `commands/optional/harness-mem.md`

### 2. `harness.json` モードファイル

ハーネス特化の observation_types と concepts を定義。

**observation_types:**
- `plan`: Plans.md へのタスク追加・更新
- `implementation`: ハーネスルールに従った実装
- `guard`: ガードレール発動（test-quality, implementation-quality）
- `review`: レビュー実施
- `ssot`: decisions.md/patterns.md 更新
- `handoff`: PM ↔ Impl 移行
- `workflow`: ワークフロー改善

**observation_concepts:**
- `test-quality`: テスト品質ガードレール
- `implementation-quality`: 実装品質ガードレール
- `harness-pattern`: ハーネス特有のパターン
- `2-agent`: PM/Impl 協働
- `quality-gate`: 品質ゲート発動点
- `ssot-decision`: SSOT への決定記録

**ファイル:** `~/.claude/plugins/marketplaces/thedotmack/plugin/modes/harness.json`

### 3. `sync-ssot-from-memory` スキル

既存の `sync-ssot-from-serena` を拡張し、Serena と Claude-mem 両方をサポート。

**機能:**
1. メモリシステム検出（Claude-mem / Serena）
2. 重要な観測値の抽出（decision, discovery+pattern, bugfix+gotcha）
3. decisions.md / patterns.md への昇格提案
4. ユーザー確認後に SSOT 更新

**ファイル:** `skills/optional/sync-ssot-from-memory/doc.md`

### 4. Memory Integration Rules

skills-gate.md と連携し、主要スキルに mem-search を自動統合。

**統合されるスキル:**
| スキル | mem-search 活用内容 |
|-------|-------------------|
| session-init | 過去のガードレール発動履歴、直近の作業内容を表示 |
| review | 過去の類似コードレビュー指摘を参照 |
| verify | 過去のビルド/テストエラーパターンを参照 |
| impl | 過去の実装パターン、gotcha を参照 |
| troubleshoot | 過去の類似問題と解決策を参照 |
| workflow | 過去のハンドオフパターン、改善履歴を参照 |

**ファイル:** `.claude/rules/memory-integration.md`

---

## ユースケース

### 1. セッション跨ぎガードレール強化

**Before:** 毎回同じミス（it.skip() 等）を繰り返す
**After:** 過去のガードレール発動履歴から学習、同じミスを防止

**効果:** 品質の累積的向上

### 2. 長期タスクの文脈維持

**Before:** 毎回コールドスタート、立ち上がりに時間がかかる
**After:** 前回の作業内容を自動表示、即座に続きから開始

**効果:** セッション間のロスタイム削減

### 3. デバッグパターン学習

**Before:** 過去の解決策を忘れる、車輪の再発明
**After:** 過去の同様エラーと解決策を自動検索

**効果:** 問題解決速度の向上

### 4. プロジェクト引き継ぎ支援

**Before:** 暗黙知が失われる、Why/How が不明
**After:** 全セッションの観測値から文脈を即座に把握

**効果:** オンボーディング時間短縮

### 5. SSOT 自動更新提案

**Before:** SSOT 更新が属人的、漏れが発生
**After:** 重要な観測値を自動検出、SSOT 昇格を提案

**効果:** 知識の散逸防止

### 6. ワークフロー改善の自動発見

**Before:** パターン化できるのに気づかない
**After:** 繰り返しパターンを検出、自動化を提案

**効果:** 継続的な効率改善

### 7. 2-Agent 運用の最適化

**Before:** PM/Impl 間の暗黙知が共有されない
**After:** ハンドオフ時に学びを自動共有

**効果:** PM/Impl 連携強化

---

## 実装フェーズ

### Phase 1: 基本セットアップ（即座に実装可能）

1. `/harness-mem` コマンド作成
   - Claude-mem インストール検出・サポート
   - 日本語化オプション確認
2. `harness.json` モードファイル作成
3. `harness--ja.json` 作成（日本語版）

### Phase 2: スキル統合（1-2日）

4. `memory-integration.md` ルール追加
5. `session-init` への mem-search 追加
6. `skills-gate.md` 更新

### Phase 3: SSOT 同期（2-3日）

7. `sync-ssot-from-serena` → `sync-ssot-from-memory` リネーム
8. Claude-mem サポート追加
9. 自動同期提案ロジック

### Phase 4: 高度な統合（1週間）

10. `review`, `verify`, `impl` への mem-search 追加
11. ガードレール強化（過去履歴表示）
12. トークンコスト測定・最適化

---

## 技術仕様

### harness.json モードファイル構造

```json
{
  "name": "Claude Code Harness Development",
  "description": "Plugin development with quality guardrails and SSOT management",
  "version": "1.0.0",
  "observation_types": [
    {
      "id": "plan",
      "label": "Plan",
      "description": "Task added to or updated in Plans.md",
      "emoji": "📋",
      "work_emoji": "📝"
    },
    {
      "id": "implementation",
      "label": "Implementation",
      "description": "Code written following harness rules",
      "emoji": "🛠️",
      "work_emoji": "💻"
    },
    {
      "id": "guard",
      "label": "Guard",
      "description": "Guardrail triggered (test-quality, implementation-quality)",
      "emoji": "🛡️",
      "work_emoji": "⚠️"
    },
    {
      "id": "review",
      "label": "Review",
      "description": "Code review performed",
      "emoji": "🔍",
      "work_emoji": "👀"
    },
    {
      "id": "ssot",
      "label": "SSOT Update",
      "description": "decisions.md or patterns.md updated",
      "emoji": "📚",
      "work_emoji": "✍️"
    },
    {
      "id": "handoff",
      "label": "Handoff",
      "description": "PM ↔ Impl role transition",
      "emoji": "🤝",
      "work_emoji": "🔄"
    },
    {
      "id": "workflow",
      "label": "Workflow",
      "description": "Workflow improvement or automation",
      "emoji": "⚙️",
      "work_emoji": "🔧"
    }
  ],
  "observation_concepts": [
    {
      "id": "test-quality",
      "label": "Test Quality",
      "description": "Test tampering prevention and quality enforcement"
    },
    {
      "id": "implementation-quality",
      "label": "Implementation Quality",
      "description": "No stub/mock/hardcode enforcement"
    },
    {
      "id": "harness-pattern",
      "label": "Harness Pattern",
      "description": "Reusable harness workflow pattern"
    },
    {
      "id": "2-agent",
      "label": "2-Agent",
      "description": "PM ↔ Impl collaboration pattern"
    },
    {
      "id": "quality-gate",
      "label": "Quality Gate",
      "description": "Guardrail enforcement point"
    },
    {
      "id": "ssot-decision",
      "label": "SSOT Decision",
      "description": "Architectural decision for SSOT"
    }
  ],
  "prompts": {
    "observer_role": "You are observing a Claude Code session using the Claude Code Harness plugin. This plugin enforces quality guardrails, SSOT management (decisions.md/patterns.md), and 2-Agent workflows (PM ↔ Impl).",
    "recording_focus": "WHAT TO RECORD (Harness-Specific)\n--------------------------------\nFocus on harness-specific activities:\n- When Plans.md tasks are added, updated, or completed\n- When guardrails are triggered (test-quality, implementation-quality)\n- When SSOT files (decisions.md, patterns.md) are updated\n- When handoffs occur between PM and Impl roles\n- When workflow improvements are made\n- When quality gates prevent problematic code\n\nUse verbs like: planned, guarded, reviewed, handed-off, enforced, recorded-to-ssot\n\n✅ GOOD EXAMPLES:\n- \"Plans.md updated with 3 new implementation tasks\"\n- \"Test tampering prevented: attempted to add it.skip() to authentication tests\"\n- \"decisions.md updated: D12 - Why we use PM/Impl role separation\"\n- \"Handoff to Impl: Feature X planning completed, ready for implementation\"\n\n❌ BAD EXAMPLES:\n- \"Read some files\"\n- \"Analyzed code structure\"\n- \"Discussed with user\"",
    "type_guidance": "**type**: MUST be EXACTLY one of these 7 options:\n      - plan: task added to or updated in Plans.md\n      - implementation: code written following harness rules\n      - guard: guardrail triggered (test-quality, implementation-quality)\n      - review: code review performed\n      - ssot: decisions.md or patterns.md updated\n      - handoff: PM ↔ Impl role transition\n      - workflow: workflow improvement or automation",
    "concept_guidance": "**concepts**: 2-5 harness-specific categories. MUST use ONLY these exact keywords:\n      - test-quality: test tampering prevention and quality enforcement\n      - implementation-quality: no stub/mock/hardcode enforcement\n      - harness-pattern: reusable harness workflow pattern\n      - 2-agent: PM ↔ Impl collaboration pattern\n      - quality-gate: guardrail enforcement point\n      - ssot-decision: architectural decision for SSOT"
  }
}
```

### /harness-mem コマンドフロー（重要）

> **追加要望反映**: インストールサポートと日本語化オプションを必須機能として実装

```
Step 1: Claude-mem インストール検出
├── インストール済み → Step 2 へ
└── 未インストール → インストール確認ダイアログ
    │
    │  「Claude-mem がインストールされていません。
    │   セッション跨ぎの品質・文脈維持機能を利用するには
    │   Claude-mem のインストールが必要です。
    │
    │   インストールしますか？」
    │
    ├── Yes → インストール実行
    │   └── /plugin marketplace add thedotmack/claude-mem
    │   └── /plugin install claude-mem
    │   └── 成功 → Step 2 へ
    │   └── 失敗 → エラー表示、手動インストール案内
    └── No → 終了（Claude-mem なしで継続可能）

Step 2: 日本語化確認ダイアログ
│
│  「Claude-mem の記録を日本語化しますか？
│
│   - 日本語: 観測値、サマリー、検索結果が日本語で記録されます
│   - 英語: デフォルト設定（英語での記録）」
│
├── 日本語化する → harness--ja モード設定
└── 英語のまま → harness モード設定

Step 3: モードファイル生成
├── harness.json 作成（または確認）
└── harness--ja.json 作成（日本語選択時）

Step 4: settings.json 更新
└── CLAUDE_MEM_MODE を設定

Step 5: スキル統合設定
├── memory-integration.md 追加
└── skills-gate.md 更新

Step 6: 検証
├── Claude-mem 再起動
└── mem-search テスト
```

---

## トークンコスト測定計画

### 測定指標

1. セッションあたりの平均トークン増加
2. 有用な観測値の割合（ノイズ vs 有益情報）
3. mem-search による時間短縮効果

### 測定方法

- ベンチマークプロジェクトで1週間運用
- Before/After 比較

### 最適化オプション

- `harness--chill` モード作成（重要イベントのみ記録）
- mem-search の頻度制限
- 観測値の圧縮設定

---

## 注意事項

- **既存構造は変更不要**: Claude-mem 前提の設計にはしない
- **段階的導入**: `/harness-mem` でオプトイン
- **フォールバック**: Claude-mem がない環境でも従来通り動作
- **SSOT の正典性維持**: decisions.md/patterns.md は Git 管理の正典として残す
- **Claude-mem は検索・履歴・文脈提供に徹する**

---

## 関連ファイル

- `/commands/optional/harness-mem.md` - セットアップコマンド
- `/skills/optional/sync-ssot-from-memory/doc.md` - SSOT 同期スキル
- `/.claude/rules/memory-integration.md` - メモリ統合ルール
- `/templates/rules/skills-gate.md.template` - スキルゲート更新
