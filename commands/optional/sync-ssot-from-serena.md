---
description: "[オプション] Serenaメモリを読み込み、decisions/patterns（SSOT）へ反映"
---

# /sync-ssot-from-serena - Serenaメモリ→SSOT反映

Serena（または同等の永続メモリ機構）に残っている情報を読み込み、プロジェクトのSSOTである
`.claude/memory/decisions.md` と `.claude/memory/patterns.md` に反映します。

## バイブコーダー向け（こう言えばOK）

- 「**今回分かったことを次回も使えるように残して**」→ このコマンド
- 「**決定事項（なぜ）と、やり方（どうやる）を分けて整理して**」→ decisions/patternsに分離して反映します
- 「**どれを残すべきか分からない**」→ 重要度で選別し、SSOTに入れる候補だけ提案します

## できること

- Serenaメモリから **確定情報だけ**を抽出し、SSOT（decisions/patterns）へ追記/更新する
- 途中メモや個人情報など、SSOTに入れるべきでない内容を除外する

> 注意: Serenaメモリは**開発者ローカルのメモ**として使われることも多いので、SSOTへ反映するのは「確定した情報」だけに絞ります。

参照: `docs/MEMORY_POLICY.md`

---

## 手順

### Step 1: 対象メモリの選定

- Serenaのメモリ一覧を取得し、今回反映すべきメモリを選ぶ  
  - 例: `*_progress_*` / `*_decisions_*` / `*_investigation_*`

### Step 2: メモリ内容の抽出（SSOT候補のみ）

以下の観点で抽出：

- **Decisions候補（Why）**:
  - 技術選定、制約、禁止事項、互換性方針、採用/不採用の理由
- **Patterns候補（How）**:
  - 繰り返し使える解法、運用ルール、トラブル対応の型

除外：

- 途中経過の雑メモ（確度が低い）
- 個人情報/機密

### Step 3: SSOTへ反映（重複排除）

- `.claude/memory/decisions.md`
  - ADR寄りフォーマット（結論/背景/選択肢/採用理由/影響/見直し条件）
  - タイトル行にタグ（例: `#decision #ci`）
  - 先頭Indexにも追記
- `.claude/memory/patterns.md`
  - 問題/解法/適用条件/非適用条件/例/注意点
  - タイトル行にタグ（例: `#pattern #hooks`）
  - 先頭Indexにも追記

### Step 4: 変更サマリー

- 追加/更新したエントリ一覧
- “保留”（まだSSOTに入れるべきでない）項目一覧

---

## 失敗時のフォールバック

Serenaのメモリ読み取りができない場合は、ユーザーに「該当メモリの本文」を貼ってもらい、同じ手順でSSOTへ反映します。


