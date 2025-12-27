---
name: cursor-mem
description: "Cursorでclaude-memのMCPサーバーにアクセスし、過去のセッション記録を検索・新しい観測を記録。トリガー: 'メモリ検索', 'claude-mem', '過去の判断', '記録して', 'memory search', 'past decisions'. Do NOT load for: 通常のコーディング、一時的なメモ、実装作業。"
allowed-tools: ["Bash", "Read", "mcp__claude-mem__*"]
metadata:
  skillport:
    category: integration
    tags: [cursor, memory, mcp, search, cross-tool]
    alwaysApply: false
---

# Cursor-Mem Integration Skill

CursorからClaude-memを活用するスキル。Claude CodeとCursorで同じメモリデータベースを共有し、セッション間の知識を引き継ぎます。

## 🎯 使用場面

### 検索（読み取り）
- **過去の意思決定を確認**: 「なぜこのアーキテクチャを選んだのか？」
- **パターンの参照**: 「以前はどのように実装したか？」
- **バグ修正履歴**: 「同様の問題を過去に解決したか？」
- **技術選定の理由**: 「なぜこのライブラリを使っているのか？」

### 記録（書き込み）
- **PMとしての判断をメモ**: レビュー中の気付きや設計判断
- **パターンの記録**: 再利用可能なソリューション
- **引き継ぎ事項**: 次のセッションやチームメンバーへの情報
- **学習事項**: トラブルシューティングで得た知見

## 📋 利用可能なMCPツール

Cursor上でclaude-memのMCPツールを直接利用できます：

### 検索系
- `mcp__claude-mem__search`: キーワードでメモリを検索
- `mcp__claude-mem__timeline`: 時系列で記録を取得
- `mcp__claude-mem__get_recent_context`: 最近の文脈を取得
- `mcp__claude-mem__get_observation`: 特定の観測を取得

### 書き込み系
- `mcp__claude-mem__create_entities`: 新しいエンティティを作成
- `mcp__claude-mem__create_relations`: エンティティ間の関連を作成
- `mcp__claude-mem__add_observations`: 観測を追加

## 🔧 セットアップ

### 1. MCPラッパースクリプトの配置

```bash
# harness リポジトリ内に claude-mem-mcp がインストールされている前提
# 絶対パスで参照
HARNESS_PATH="/path/to/claude-code-harness"
```

### 2. Cursor MCP設定

プロジェクトルートに `.cursor/mcp.json` を作成：

```json
{
  "mcpServers": {
    "claude-mem": {
      "type": "stdio",
      "command": "/absolute/path/to/claude-code-harness/scripts/claude-mem-mcp"
    }
  }
}
```

**⚠️ 重要**: `command` には絶対パスを指定してください。

### 3. Cursor再起動

設定後、Cursorを再起動してMCPサーバーを認識させます。

## 💡 使い方の例

詳細な使用例は [examples.md](./examples.md) を参照してください。

### 基本的な検索

```
ユーザー: 「認証方式の選定理由を確認したい」

Cursor（Composer）:
mcp__claude-mem__search を使用
→ クエリ: "認証 JWT Supabase 選定理由"
→ 過去の決定記録（decisions）を取得
```

### 気付きの記録

```
ユーザー: 「この実装パターンを記録しておいて」

Cursor（Composer）:
mcp__claude-mem__add_observations を使用
→ タイプ: pattern
→ タグ: source:cursor, review, best-practice
→ 内容: 実装パターンの説明
```

## 🏷️ タグ規約

Claude CodeとCursorで統一されたタグ体系を使用します：

| タグ | 用途 |
|------|------|
| `source:cursor` | Cursorから記録された情報 |
| `source:claude-code` | Claude Codeから記録された情報 |
| `type:decision` | 意思決定の記録 |
| `type:pattern` | 再利用可能なパターン |
| `type:bug` | バグ修正の記録 |
| `type:review` | レビューでの気付き |
| `type:handoff` | 引き継ぎ事項 |

## 🔄 Claude Code との連携

### データ共有

- Claude CodeとCursorは同じSQLiteデータベース（`~/.claude-mem/claude-mem.db`）を使用
- WALモードで並行書き込みに対応
- リアルタイムでデータが共有される

### 推奨ワークフロー

1. **Cursor（PM役）**: 設計判断やレビュー結果を記録
2. **Claude Code（実装役）**: 過去の判断を参照しながら実装
3. **双方向検索**: どちらからでも過去の記録を検索可能

## ⚠️ 注意事項

### パフォーマンス

- 初回検索時はワーカー起動に2-3秒かかる場合があります
- 2回目以降はワーカーが常駐するため高速

### セキュリティ

- メモリデータベースはローカル環境にのみ保存されます
- 機密情報を記録する場合は注意してください

### トラブルシューティング

**問題**: MCPツールが認識されない
**解決策**:
1. `.cursor/mcp.json` のパスが正しいか確認
2. スクリプトが実行可能か確認: `chmod +x scripts/claude-mem-mcp`
3. Cursorを再起動

**問題**: ワーカーが起動しない
**解決策**:
1. ヘルスチェック: `curl http://127.0.0.1:37777/health`
2. 手動起動: `node ~/.claude/plugins/cache/thedotmack/claude-mem/*/scripts/worker-cli.js start`

## 📚 参考資料

- [Claude-mem 公式ドキュメント](https://github.com/thedotmack/claude-mem)
- [Cursor MCP 設定ガイド](https://cursor.com/docs/context/mcp)
- [使用例集](./examples.md)
- [統合ガイド](../../docs/guides/cursor-mem-integration.md)
