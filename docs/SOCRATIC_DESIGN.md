# Socratic Design

段階的な質問を通じて設計を明確化する手法。v2.14.0 からデフォルトで有効。

---

## 概要

Socratic Design は、プロジェクト開始時の対話を構造化し、より良い設計決定を導きます。

### 原則

1. **1回1質問**: 複数の質問を同時にしない
2. **選択肢優先**: 自由記述より選択肢形式
3. **段階的検証**: 200-300語ごとに確認
4. **代替案必須**: 決定前に必ず2-3案を比較

---

## 有効化・無効化

### デフォルト（有効）

```yaml
# .claude-code-harness.config.yaml
planning:
  socratic_mode: true           # default: true
  max_questions_per_turn: 1     # default: 1
  require_alternatives: true    # default: true
```

### 無効化する場合

```yaml
planning:
  socratic_mode: false  # 従来の3質問形式に戻す
```

---

## 対話フロー

### Phase 1: Purpose（目的）

```
Q1: 何を作りたいですか？
    ↓
Q2: なぜそれが必要ですか？（真の目的を探る）
    ↓
Q3: 成功したらどうなりますか？（ゴール明確化）
```

### Phase 2: User（ユーザー）

```
Q4: 誰が使いますか？
    a) 自分だけ  b) チーム  c) 一般公開
    ↓
Q5: どこで使いますか？
    a) ブラウザ  b) モバイル  c) CLI
```

### Phase 3: Constraints（制約）

```
Q6: 使える時間は？
    a) 1日  b) 1週間  c) 1ヶ月
    ↓
Q7: 技術的制約は？
    a) 言語/FW指定  b) 既存連携  c) なし
```

### Phase 4: Alternatives（代替案）

```
📊 3つのアプローチを提案します

| 案 | 概要 | 工数 | 拡張性 | 推奨 |
|----|------|------|--------|------|
| A | シンプル | 小 | 低 | |
| B | 標準 | 中 | 中 | ⭐ |
| C | 本格 | 大 | 高 | |

推奨: 案B — 理由: YAGNI原則

どれにしますか？
```

### Phase 5: Validation（最終確認）

```
📝 設計の概要

## プロジェクト: {名前}
### 目的: {1-2文}
### ユーザー: {誰が、どこで}
### 主要機能: {リスト}
### 技術: {言語、FW、DB}
### スコープ: {MVP、将来}

この内容で進みますか？
```

---

## Before → After

### Before（従来）

```
Claude: 📋 Tell me a bit more:
1. Who will use it?
2. Any similar services?
3. How far do you want to build?

User: 自分用、Notionみたいな、MVP程度で

Claude: Plans.md を作成しました
```

問題点:
- 複数質問を一度に
- 深堀りなし
- 代替案の検討なし

### After（Socratic）

```
Claude: 🎯 何を作りたいですか？
User: タスク管理アプリ

Claude: 🤔 なぜそれが必要ですか？
User: メモが散らばって見つからない

Claude: ✅ 成功の定義は？
User: メモを3秒で検索できる

Claude: 👤 使う人は？
a) 自分だけ  b) チーム  c) 一般公開
User: a

Claude: 📊 3つのアプローチ
| 案 | 概要 | 工数 |
|----|------|------|
| A | ローカルMarkdown | 1日 |
| B | SQLite検索 | 3日 | ⭐
| C | Elasticsearch | 1週間 |

推奨: 案B

User: B

Claude: Plans.md を作成しました
```

改善点:
- 1問ずつ深堀り
- 真の目的を発見（検索速度が重要）
- 代替案を比較して選択

---

## コマンド

| コマンド | 説明 |
|---------|------|
| `/brainstorm` | Socratic対話を開始 |
| `/plan-with-agent` | Socratic対話 → Plans.md生成 |

---

## テンプレート

- [templates/socratic/questions.md](../templates/socratic/questions.md) - 質問テンプレート
- [templates/socratic/alternatives.md](../templates/socratic/alternatives.md) - 代替案テンプレート

---

## よくある質問

### Q: 質問が多くて面倒では？

A: 1問あたり数秒で回答できる選択肢形式が中心です。従来の「自由に書いてください」より実は早く、より明確な結果が得られます。

### Q: 急いでいるので省略したい

A: `socratic_mode: false` で従来モードに戻せます。ただし、設計の抜け漏れが発生しやすくなります。

### Q: 代替案の提示が不要

A: `require_alternatives: false` で無効化できます。ただし、後から「別の方法もあったのでは」という後悔が起きやすくなります。

---

## 関連ドキュメント

- [commands/optional/brainstorm.md](../commands/optional/brainstorm.md) - brainstormコマンド
- [commands/core/plan-with-agent.md](../commands/core/plan-with-agent.md) - plan-with-agentコマンド
