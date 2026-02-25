# Scope Dialog

`/work` 引数なし時の対話式スコープ確認仕様。

## Dialog Flow

```text
/work
    ↓
引数あり? → YES → 即実行（対話スキップ）
    ↓ NO
AskUserQuestion で対話:

どこまでやりますか?
1) 次のタスク (推奨): Plans.md の次の未完了タスク
2) 全部: 残りのタスクを全て完了
3) 指定: タスク番号や範囲を指定 (例: 3, 3-6)

> [Enter = 1]
```

## 引数パターンと即実行

| 引数 | 解釈 | 対話 |
|------|------|------|
| (なし) | 対話で確認 | あり |
| `3` | タスク3だけ | スキップ |
| `3-6` | タスク3〜6 | スキップ |
| `all` | 全未完了タスク | スキップ |
| `--codex` | Codex エンジン（スコープは対話） | あり |
| `--codex all` | Codex で全タスク | スキップ |
| `--codex 3` | Codex でタスク3 | スキップ |

## 自然言語対応

```bash
/work 認証機能からユーザー管理まで
/work ログイン機能を終わらせて
/work Header, Footer, Sidebar を作って
```

自然言語は Plans.md のタスクタイトルとマッチング:
1. 各タスクのタイトルをトークン化
2. ユーザー入力のキーワードとの一致度を計算
3. マッチしたタスクを表示して確認

## AskUserQuestion の実装

```json
{
  "questions": [{
    "question": "どこまでやりますか?",
    "header": "Scope",
    "options": [
      {
        "label": "次のタスク (推奨)",
        "description": "Plans.md の次の未完了タスク 1 件を実行"
      },
      {
        "label": "全部",
        "description": "残りの未完了タスクを全て完了まで実行"
      },
      {
        "label": "指定",
        "description": "タスク番号や範囲を指定 (例: 3, 3-6)"
      }
    ],
    "multiSelect": false
  }]
}
```

「指定」が選ばれた場合、追加で番号/範囲を聞く:

```json
{
  "questions": [{
    "question": "タスク番号または範囲を指定してください (例: 3, 3-6)",
    "header": "Range",
    "options": [
      {"label": "次の3件", "description": "未完了の先頭3タスク"},
      {"label": "残り全部", "description": "全未完了タスク"}
    ],
    "multiSelect": false
  }]
}
```

## スコープ確認プロンプト（実行前に必ず表示）

```text
📋 実行範囲を確認します

対象タスク:
├── 3. ログイン機能の実装 (cc:TODO)
├── 4. 認証ミドルウェアの作成 (cc:TODO)
└── 5. セッション管理 (cc:TODO)

🔧 戦略: 並列 3 ワーカー (タスク3件)

計 3 タスクを実行します。よろしいですか？
```

## Strategy Recommendation（breezing 提案）

### 発動条件

4+ タスクのスコープが確定し、Strategy Analyzer が `recommended: "breezing"` を返した場合に発動。

詳細: [strategy-analyzer.md](strategy-analyzer.md)

### 提案 UI フロー

```text
/work all
    ↓
Phase 0: スコープ確定 → 5 タスク
    ↓
Phase 0.5: Strategy Analysis
  → recommended: "breezing", confidence: "high"
    ↓
AskUserQuestion（戦略提案）:
  markdown preview で分析結果を表示
  → ユーザーが戦略を選択
    ↓
breezing 選択 → Skill tool で /breezing invoke
parallel 選択 → 従来の /work フローで続行
direct 選択   → 直列実行で続行
```

### AskUserQuestion 仕様

```json
{
  "questions": [{
    "question": "推奨戦略を選択してください",
    "header": "Strategy",
    "options": [
      {
        "label": "breezing で実行 (推奨)",
        "description": "Agent Teams: Implementer 並列 + Reviewer 独立レビュー",
        "markdown": "## 📋 タスク分析結果\n\n| 指標 | 値 |\n|------|----|\n| タスク数 | 5 |\n| 独立タスク率 | 80% |\n| カテゴリ | UI + API + テスト |\n\n## 🏇 breezing を推奨する理由\n\n- 独立タスク率 80% → Implementer 2並列で効率的\n- Reviewer 独立レビューで品質確保\n- 推定コスト: ~440k tokens (5.5x)"
      },
      {
        "label": "parallel で実行",
        "description": "従来の並列ワーカー（サブエージェント）"
      },
      {
        "label": "1つずつ実行",
        "description": "直列で順番に実装"
      }
    ],
    "multiSelect": false
  }]
}
```

> **注**: `markdown` フィールドの内容は Strategy Analyzer の実行結果から動的に生成する。
> 上記は表示イメージのサンプル。

### breezing 選択時の Skill tool invoke

ユーザーが「breezing で実行」を選択した場合:

```text
1. 現在の work 状態を引き継ぎデータとして構築:
   {
     "source": "work",
     "scope": "all" or "3-6",
     "task_list": [...],
     "strategy_analysis": { ... },
     "options": { "codex": false, "parallel": null }
   }

2. Skill tool で /breezing を invoke:
   skill: "breezing"
   args: "--from-work all" (or "--from-work 3-6")

3. /work の Phase は終了（breezing に委譲完了）
```

### `--from-work` 引数

`/breezing` が `/work` から invoke された場合に付与されるマーカー:
- Phase 0 の Planning Discussion: 実行する（スコープは確認済みでも計画議論は価値あり）
- Phase A Step 2 の範囲確認: **スキップ**（/work 側で確認済み）
- strategy_analysis が引き継がれ、breezing-active.json に記録

### `breezing_auto_approve` 設定

`.claude-code-harness.config.yaml`:

```yaml
work:
  breezing_auto_approve: false  # default: false
```

`true` の場合:
- Strategy Analyzer が `recommended: "breezing"` + `confidence: "high"` を返した場合
- AskUserQuestion をスキップし、自動的に breezing を invoke
- `confidence: "medium"` の場合は設定に関わらず AskUserQuestion で確認

### 提案しない条件

| 条件 | 動作 |
|------|------|
| `--no-breezing` 指定 | 戦略分析自体をスキップ |
| タスク数 1-3 | 従来の戦略選択のみ |
| Agent Teams 未有効化 | フォールバック UI を表示（strategy-analyzer.md 参照） |

## /breezing との対話の違い

| 項目 | /work | /breezing |
|------|-------|-----------|
| デフォルト選択 | 次のタスク (1件) | 全部 |
| 理由 | 軽量実行が基本 | チーム並列が前提 |
| 「次のタスク」選択肢 | あり | なし |
| breezing 提案 | あり（4+タスク時） | N/A（breezing 自体） |
