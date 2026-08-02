# Claude Code Setup: MCP, Telemetry, Provider Guidance

最終更新: 2026-05-05

Claude Code 2.1.120 以降で増えた setup / MCP / telemetry / provider 周辺の運用ガイド。

## ひとことで

Harness は Claude Code の新機能を隠さず案内するが、公式設定の意味を置き換えない。
MCP の常時ロード、telemetry、provider、Windows shell、deferred tools は、用途ごとに小さく opt-in する。

## たとえると

Claude Code は工具箱で、Harness は作業手順書。
工具箱の中身を勝手に作り替えるのではなく、「この作業ではこの工具を出しておく」と案内する。

## Setup checklist

| 項目 | Harness guidance |
|------|------------------|
| `${CLAUDE_EFFORT}` | skill 本文で現在の effort を参照する時だけ使う。effort の決定は呼び出し側に残す |
| MCP `alwaysLoad` | 毎ターン必須の少数ツールだけ `true`。大きい server は deferred のまま |
| `claude plugin prune` | plugin uninstall 後の孤立 dependency cleanup。まず `--dry-run` |
| `claude project purge` | project state を消す強い cleanup。まず `--dry-run` または `--interactive` |
| `ANTHROPIC_BEDROCK_SERVICE_TIER` | Bedrock 利用者だけが provider 環境で設定。Harness default には入れない |
| `claude_code.skill_activated.invocation_trigger` | telemetry では skill 起動理由を区別して見る |
| PowerShell primary shell | Windows では PowerShell primary を前提に案内し、Bash 固定の例を避ける |
| forked skills / subagents deferred tools | 初回 turn で deferred tools が必要な workflow では、明示的に tool discovery できる書き方にする |

## Effort guidance

`${CLAUDE_EFFORT}` は、skill 本文から現在の effort level を参照するための変数。
これは「skill が自分で effort を決める」ためではなく、「今どの effort で呼ばれているかを説明や分岐に使う」ためのもの。

使ってよい例:

```md
Current effort: `${CLAUDE_EFFORT}`.
If effort is low, keep the review to confirmed blockers.
If effort is xhigh, include adversarial checks.
```

避ける例:

- skill 本文で「必ず xhigh に変更して」と要求する
- user / parent workflow の effort 指定を無視する
- `${CLAUDE_EFFORT}` が空の時に失敗扱いにする

## MCP `alwaysLoad`

MCP tool search は context 節約のために tool schema を遅延ロードする。
`alwaysLoad: true` は、この遅延から server を除外し、session start で常に tool を見えるようにする設定。

使う場面:

- 毎ターン使う小さな core tool server
- workflow の最初の一手で必ず必要な server
- tool search では発見が遅れて作業品質が落ちる少数 server

避ける場面:

- tool 数が多い server
- たまにしか使わない integration
- 大きな schema を持つ database / observability server

例:

```json
{
  "mcpServers": {
    "core-tools": {
      "type": "http",
      "url": "https://mcp.example.com/mcp",
      "alwaysLoad": true
    }
  }
}
```

## Parallel Search MCP (optional)

現在の Web 検索と URL 本文の取得が必要な場合は、Parallel Search MCP を
remote HTTP server として opt-in できる。既存の `mcpServers` を置き換えず、
次の entry を merge する。

```json
{
  "mcpServers": {
    "parallel-search": {
      "type": "http",
      "url": "https://search.parallel.ai/mcp"
    }
  }
}
```

default endpoint は account、API key、OAuth を必要としない。
`web_search` は現在の Web 検索、`web_fetch` は指定 URL から clean Markdown を
取得する。毎 turn 必須の server ではないため、通常は `alwaysLoad` を付けず
deferred のまま使う。Harness の default server や provider は変更しない。

## Plugin cleanup

`claude plugin prune` は、plugin dependency として自動インストールされたが、今は不要になった plugin を消す cleanup。
直接インストールした plugin を勝手に消す用途ではない。

推奨:

```bash
claude plugin prune --dry-run
claude plugin prune -y
```

Harness setup では、uninstall 後の案内として出す。
初期セットアップや release 手順の中で無条件実行しない。

## Project state cleanup

`claude project purge [path]` は、Claude Code が project に持つ transcripts、tasks、file history、config entry を削除する強い cleanup。

推奨:

```bash
claude project purge . --dry-run
claude project purge . --interactive
```

使う場面:

- project を archive する
- team handoff 前に古い local state を消す
- project path / owner が変わり、古い状態が邪魔になっている

避ける場面:

- 現在進行中の作業が残っている
- transcript や task queue を証跡として残す必要がある
- 「なんとなく軽くしたい」だけで、削除対象を確認していない

## Provider guidance

`ANTHROPIC_BEDROCK_SERVICE_TIER` は Bedrock 利用時の provider 側 tuning に関わる環境変数として扱う。
Harness の plugin default、template、shared project settings には既定値として入れない。

理由:

- Bedrock を使わない利用者には不要
- team / account / region によって正しい値が変わる
- provider 設定は user / organization の責任境界に近い

Bedrock guidance は、Claude Code 側の `CLAUDE_CODE_USE_BEDROCK` / `ANTHROPIC_*` 系と、
Codex 側の provider 設定を混ぜない。

## Telemetry guidance

`claude_code.skill_activated.invocation_trigger` は、skill がどう起動したかを見るための telemetry attribute。

代表値:

| 値 | 意味 |
|----|------|
| `user-slash` | ユーザーが slash command として明示起動 |
| `claude-proactive` | Claude が文脈から proactive に起動 |
| `nested-skill` | 他の skill / workflow から内部起動 |

Harness では、media / announcement 系のような `user-invocable: false` skill が
`claude-proactive` 前提にならないようにする。
期待する起動は `user-slash` または `nested-skill`。

## Windows shell guidance

Windows では、PowerShell tool が有効な場合は PowerShell primary shell として扱う。
Git Bash 固定の案内は避ける。

書き方:

- `pwsh` / PowerShell 前提の例を併記する
- POSIX shell 固有の `export` だけで終わらせない
- path separator や quoting の違いを意識する

## Forked skills / subagents and deferred tools

`context: fork` skill や subagent でも deferred tools が必要になる。
workflow 本文では、初回 turn で使う tool を曖昧にせず、必要なら tool discovery を明示する。

例:

- WebFetch が必要なら、allowed-tools / tools に含める
- MCP tool が必要なら server 名と用途を明記する
- 初回 turn で tool が見えない可能性を前提に、検索・確認の手順を書く

これにより、forked context の最初の判断で「使えるはずの tool がない」と誤判定しにくくなる。

## Sources

- Claude Code changelog: https://code.claude.com/docs/en/changelog
- Claude Code MCP docs: https://code.claude.com/docs/en/mcp
- Claude Code plugins reference: https://code.claude.com/docs/en/plugins-reference
