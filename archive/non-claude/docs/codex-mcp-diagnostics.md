# Codex MCP Diagnostics And Plugin Loading

この文書は Codex `0.123.0` 以降の MCP 診断と plugin MCP loading の運用メモ。
Claude Code 側の `claude mcp`、`.claude/mcp.json`、hook `type: "mcp_tool"` の話とは混ぜない。

## 目的

Codex の `/mcp` は、普段の軽量確認に使う。
接続済み server の概要だけを素早く見たい時の入口。

Codex の `/mcp verbose` は、困った時だけ使う。
diagnostics、resources、resource templates まで確認する詳細診断の入口。

この分け方にすると、通常の確認は速いまま、MCP server が見えない・resources が出ない・template が読めない時だけ詳しく掘れる。

## 使い分け

| 状況 | 使うもの | 見るポイント |
|------|----------|--------------|
| MCP server が登録されているかだけ見たい | `/mcp` | server 名、接続状態、ざっくりした有効 / 無効 |
| server が表示されない | `/mcp verbose` | diagnostics の起動エラー、認証エラー、設定ファイル読み込み |
| tool は見えるが resource が見えない | `/mcp verbose` | resources の有無、resource templates の有無 |
| plugin の `.mcp.json` が読まれているか怪しい | `/mcp verbose` | plugin MCP loading の対象 server と diagnostics |

## 診断手順

1. まず Codex TUI で `/mcp` を実行する。
2. 期待した server が見えない、または状態が分からない時だけ `/mcp verbose` を実行する。
3. `diagnostics` で起動失敗、認証失敗、設定ファイル parse error がないか見る。
4. `resources` で server が公開している resource が見えているか見る。
5. `resource templates` で `repo://{owner}/{name}` のような template が公開されているか見る。
6. plugin 由来の MCP server だけが見えない場合は、plugin の `.mcp.json` の形を確認する。

## `.mcp.json` の対応形式

Codex `0.123.0` 以降の plugin MCP loading は、plugin 内の `.mcp.json` について次の 2 形式を受け取れる。

### `mcpServers` 形式

```json
{
  "mcpServers": {
    "docs": {
      "command": "node",
      "args": ["server.js"]
    }
  }
}
```

### top-level server map 形式

```json
{
  "docs": {
    "command": "node",
    "args": ["server.js"]
  }
}
```

どちらも plugin MCP loading の入力として扱える。
新規で書く場合は、他の AI tool と共有しやすい `mcpServers` 形式を優先する。
既存 plugin が top-level server map 形式なら、無理に書き換えず Codex 側の読み込み改善を利用する。

## Claude Code 側と混ぜないこと

この文書の対象は Codex の plugin MCP loading と Codex TUI の `/mcp` / `/mcp verbose`。

Claude Code 側の設定や診断とは入口が違う。

| 領域 | 入口 | この文書で扱うか |
|------|------|------------------|
| Codex TUI の MCP 診断 | `/mcp`, `/mcp verbose` | 扱う |
| Codex plugin の `.mcp.json` loading | plugin 内 `.mcp.json` | 扱う |
| Claude Code CLI の MCP 管理 | `claude mcp ...` | 扱わない |
| Claude Code project MCP 設定 | `.claude/mcp.json` | 扱わない |
| Claude Code hook の `type: "mcp_tool"` | `hooks.json` | 53.1.2 の別判断として扱う |

## 注意点

- `/mcp verbose` は詳細診断用。毎回の通常確認では `/mcp` を使う。
- `.mcp.json` には secret を直接書かない。必要な値は環境変数や管理された credential store に寄せる。
- `resources` と `resource templates` が空でも、server によっては正常な場合がある。tool だけを提供する MCP server もある。
- plugin `.mcp.json` の読み込み改善は Codex 側の話。Claude Code の `.claude/mcp.json` や managed settings の仕様変更として扱わない。
