---
description: "[オプション] メモリシステム（Claude-mem/Serena）からSSOT（decisions/patterns）へ重要な観測を昇格"
description-en: "[Optional] Promote important observations from memory systems (Claude-mem/Serena) to SSOT"
---

# /sync-ssot-from-memory - メモリ→SSOT昇格

メモリシステム（Claude-mem または Serena）に記録された重要な観測を、プロジェクトの SSOT である
`.claude/memory/decisions.md` と `.claude/memory/patterns.md` に昇格させます。

---

## こう言えばOK

- 「**今回分かったことを次回も使えるように残して**」→ このコマンド
- 「**重要な決定を SSOT に昇格して**」→ このコマンド
- 「**決定事項（なぜ）と、やり方（どうやる）を分けて整理して**」→ decisions/patterns に分離して反映
- 「**どれを残すべきか分からない**」→ 重要度で選別し、SSOT に入れる候補だけ提案

---

## 対応メモリシステム

| システム | 検出方法 | 観測の取得方法 |
|---------|---------|---------------|
| **Claude-mem** | `~/.claude-mem/settings.json` の存在 | `mem-search` スキル |
| **Serena** | `.serena/memories/` の存在 | `mcp__serena__read_memory` |

コマンド実行時に自動検出し、利用可能なシステムを使用します。

---

## 手順

### Step 0: メモリシステム検出

```bash
# Claude-mem チェック
if [ -f "$HOME/.claude-mem/settings.json" ]; then
  echo "📚 Claude-mem を検出"
  MEMORY_SYSTEM="claude-mem"
fi

# Serena チェック
if [ -d ".serena/memories" ]; then
  echo "📚 Serena を検出"
  MEMORY_SYSTEM="serena"
fi

# 両方ある場合は Claude-mem を優先
```

**どちらもない場合**:
- 手動入力モードに切り替え
- ユーザーに観測内容を貼り付けてもらう

---

### Step 1: SSOT 昇格候補の抽出

**Claude-mem の場合**:

```
# mem-search で重要な観測を検索
mem-search: type:decision
mem-search: type:discovery concepts:pattern
mem-search: type:bugfix concepts:gotcha
```

**Serena の場合**:

```
# Serena メモリ一覧を取得
mcp__serena__list_memories

# 対象メモリを読み込み
# 例: *_decisions_*, *_investigation_*
```

---

### Step 2: 昇格基準による選別

#### Decisions候補（Why）→ `decisions.md`

| 観測タイプ | コンセプト | 昇格基準 |
|-----------|-----------|---------|
| `decision` | `why-it-exists`, `trade-off` | 技術選定、採用/不採用の理由 |
| `guard` | `test-quality`, `implementation-quality` | ガードレール発動理由 |
| `discovery` | `user-intent` | ユーザー要件・制約 |

#### Patterns候補（How）→ `patterns.md`

| 観測タイプ | コンセプト | 昇格基準 |
|-----------|-----------|---------|
| `bugfix` | `problem-solution` | 再発防止パターン |
| `discovery` | `pattern`, `how-it-works` | 再利用可能な解法 |
| `feature`, `refactor` | `pattern` | 実装パターン |

#### 除外対象

- 途中経過の雑メモ（確度が低い）
- 個人情報/機密
- 一度きりの作業（再利用性なし）

---

### Step 3: SSOT への反映（重複排除）

#### decisions.md フォーマット

```markdown
## D{N}: {タイトル}

**日付**: YYYY-MM-DD
**タグ**: #decision #{関連キーワード}
**観測ID**: #{元の観測ID}（重複防止用）

### 結論

{採用した結論}

### 背景

{この決定が必要になった背景}

### 選択肢

1. {選択肢A}: {pros/cons}
2. {選択肢B}: {pros/cons}

### 採用理由

{なぜこの選択肢を選んだか}

### 影響

{この決定の影響範囲}

### 見直し条件

{この決定を見直すべき状況}
```

#### patterns.md フォーマット

```markdown
## P{N}: {タイトル}

**日付**: YYYY-MM-DD
**タグ**: #pattern #{関連キーワード}
**観測ID**: #{元の観測ID}（重複防止用）

### 問題

{どんな問題を解決するか}

### 解法

{どうやって解決するか}

### 適用条件

{このパターンを使うべき状況}

### 非適用条件

{このパターンを使うべきでない状況}

### 例

{コード例や具体的な手順}

### 注意点

{落とし穴や注意すべきこと}
```

---

### Step 4: 変更サマリー

```markdown
## 📚 SSOT 昇格結果

### 追加/更新

| ファイル | 項目 | 元の観測ID |
|---------|------|-----------|
| decisions.md | D12: RBAC採用 | #9602 |
| patterns.md | P8: CORS対応 | #9584 |

### 保留（要検討）

| 観測ID | タイトル | 保留理由 |
|-------|---------|---------|
| #9590 | API設計案 | まだ確定していない |

### 除外

- 途中経過のメモ: 5件
- 重複: 2件
```

---

## 重複防止

観測ID を SSOT エントリに記録することで、同じ観測が複数回昇格されることを防ぎます。

```markdown
## D12: RBAC採用

**観測ID**: #9602  ← これで重複を検出
```

---

## 失敗時のフォールバック

メモリシステムにアクセスできない場合：

1. ユーザーに観測内容を貼り付けてもらう
2. 同じ手順で SSOT へ反映

```
> メモリシステムにアクセスできません。
> 昇格したい情報を貼り付けてください。
```

---

## 関連

- `/harness-mem` - Claude-mem 統合セットアップ
- `mem-search` スキル - 過去の記憶検索
- `.claude/memory/decisions.md` - 決定事項（SSOT）
- `.claude/memory/patterns.md` - 再利用パターン（SSOT）
