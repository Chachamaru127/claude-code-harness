# Sandbox Allowlist Recipe (Firecrawl / Web Scraping 用)

claude-code-harness を install した他プロジェクトで Firecrawl・テックブログ取得・外部 API 呼び出しが `HTTP/2 403 / x-deny-reason: host_not_allowed` で塞がれる時の解決レシピ。

> **TL;DR**: CC sandbox は default で **allowlist 空 = 全 deny**。ユーザー global の `~/.claude/settings.json` に `sandbox.network.allowedDomains` を追加するのが正規ルート。AI 経由で書き換えは self-audit guard で deny されるため、**ユーザー手動編集**。

## 症状

外部プロジェクトで Firecrawl CLI / WebFetch / curl が 403 / connection refused になる。Bash subprocess のログに以下が出る:

```
HTTP/2 403
x-deny-reason: host_not_allowed
```

または

```
curl: (6) Could not resolve host: api.firecrawl.dev
```

## 原因

Claude Code sandbox（macOS Seatbelt / Linux bubblewrap）は **allowlist default**。`~/.claude/settings.json` に `sandbox.network.allowedDomains` が無い = どのホストへも外向き通信できない。

Firecrawl plugin の `SKILL.md` を確認すると `allowed-tools: Bash(firecrawl *)`。つまり Firecrawl CLI は Bash subprocess として走り、sandbox の影響を直接受ける（MCP server ではない）。

## 解決: `~/.claude/settings.json` に sandbox 設定を merge

**重要**: `~/.claude/settings.json` に **既存の `sandbox` キーがあるかどうか** で 2 ケース分岐する。誤って既存 sandbox を上書きすると、`failIfUnavailable` / `filesystem.denyRead` / `network.deniedDomains` などの既存 guardrail が消える。

### Step 0: 既存 sandbox の有無を確認

```bash
jq 'has("sandbox")' ~/.claude/settings.json
# false → Case A (新規追加)
# true  → Case B (内側 merge)
```

### Case A: 既存に `sandbox` キーが無い場合 (新規追加)

既存の `permissions` / `hooks` / `enabledPlugins` / `mcpServers` 等と **同じ階層 (top-level)** に `sandbox` キーを 1 つ追加する。既存キーは touch しない:

```json
{
  "permissions": { /* 既存維持 */ },
  "hooks": { /* 既存維持 */ },
  "enabledPlugins": { /* 既存維持 */ },
  "mcpServers": { /* 既存維持 */ },
  /* ... 他の既存 top-level keys も全て維持 ... */

  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "excludedCommands": [
      "docker", "docker-compose", "watchman",
      "systemctl", "launchctl", "brew services"
    ],
    "network": {
      "allowedDomains": [
        "github.com", "api.github.com", "raw.githubusercontent.com",
        "codeload.github.com", "objects.githubusercontent.com",
        "registry.npmjs.org", "api.anthropic.com",
        "pypi.org", "files.pythonhosted.org",
        "proxy.golang.org", "sum.golang.org",
        "crates.io", "static.crates.io", "rubygems.org",
        "api.firecrawl.dev", "firecrawl.dev",
        "techblog.zozo.com", "note.com", "assets.st-note.com",
        "zenn.dev", "qiita.com", "dev.to", "medium.com",
        "cdn-ak.f.st-hatena.com",
        "engineering.dena.com", "developers.cyberagent.co.jp",
        "tech.uzabase.com", "engineer.crowdworks.jp", "tech.smarthr.jp"
      ],
      "deniedDomains": [
        "169.254.169.254", "metadata.google.internal", "metadata.azure.com",
        "pastebin.com", "transfer.sh", "0x0.st",
        "paste.ee", "termbin.com", "ix.io"
      ]
    }
  }
}
```

### Case B: 既存に `sandbox` キーがある場合 (内側 merge)

既存の `sandbox.failIfUnavailable` / `sandbox.filesystem` / `sandbox.network.deniedDomains` などを **保持したまま**、内側にフィールドを追加 / 統合する。**`sandbox` ブロック全体の置換は禁止** (既存 guardrail を破壊する)。

merge ルール:

| フィールド | 操作 | 注意 |
|------|------|------|
| `sandbox.enabled` | `true` に設定 | 既に `true` なら維持 |
| `sandbox.autoAllowBashIfSandboxed` | `true` に設定 | 新規追加 |
| `sandbox.failIfUnavailable` | **既存維持** | 触らない |
| `sandbox.excludedCommands` | 配列なら **union (重複排除して結合)**、無ければ新規追加 | 既存項目を消さない |
| `sandbox.network.allowedDomains` | **既存配列 + 本 recipe の 29 個を union** | 既存ホストを消さない |
| `sandbox.network.deniedDomains` | **既存配列 + 本 recipe の 9 個を union** | 既存遮断ホストを残す |
| `sandbox.filesystem` | **既存維持** | touch 禁止 (denyRead/allowRead 等が消える) |

### 自動 merge する jq one-liner (Case A / B 両対応)

エディタでの手動 merge は重複と guardrail 消去のリスクが高い。以下の jq one-liner は両 case 安全:

```bash
SETTINGS=~/.claude/settings.json

# 1. 元のファイル mode を保存 (token を含むため 600 等で保護されているケースに対応)
#    cross-platform stat: Linux GNU stat -c を先に試し、macOS BSD stat -f に fallback
#    (順序重要: BSD stat -f は Linux では filesystem-status flag として誤動作する)
MODE=$(stat -c '%a' "$SETTINGS" 2>/dev/null || stat -f '%Lp' "$SETTINGS")

# 2. backup (cp -p で mode/ownership を保持)
cp -p "$SETTINGS" "${SETTINGS}.bak.$(date +%Y%m%d-%H%M%S)"

# 3. merge (既存 sandbox.filesystem / failIfUnavailable は保持、配列は union)
jq '
  .sandbox.enabled = true |
  .sandbox.autoAllowBashIfSandboxed = true |
  .sandbox.excludedCommands = (((.sandbox.excludedCommands // []) + [
    "docker", "docker-compose", "watchman",
    "systemctl", "launchctl", "brew services"
  ]) | unique) |
  .sandbox.network.allowedDomains = (((.sandbox.network.allowedDomains // []) + [
    "github.com", "api.github.com", "raw.githubusercontent.com",
    "codeload.github.com", "objects.githubusercontent.com",
    "registry.npmjs.org", "api.anthropic.com",
    "pypi.org", "files.pythonhosted.org",
    "proxy.golang.org", "sum.golang.org",
    "crates.io", "static.crates.io", "rubygems.org",
    "api.firecrawl.dev", "firecrawl.dev",
    "techblog.zozo.com", "note.com", "assets.st-note.com",
    "zenn.dev", "qiita.com", "dev.to", "medium.com",
    "cdn-ak.f.st-hatena.com",
    "engineering.dena.com", "developers.cyberagent.co.jp",
    "tech.uzabase.com", "engineer.crowdworks.jp", "tech.smarthr.jp"
  ]) | unique) |
  .sandbox.network.deniedDomains = (((.sandbox.network.deniedDomains // []) + [
    "169.254.169.254", "metadata.google.internal", "metadata.azure.com",
    "pastebin.com", "transfer.sh", "0x0.st",
    "paste.ee", "termbin.com", "ix.io"
  ]) | unique)
' "$SETTINGS" > "${SETTINGS}.tmp" \
  && chmod "$MODE" "${SETTINGS}.tmp" \
  && mv "${SETTINGS}.tmp" "$SETTINGS"

# 4. mode が保持されたか念のため確認 (元の mode と一致するはず)
#    順序は MODE 取得と同じ: Linux GNU stat -c → macOS BSD stat -f fallback
stat -c '%a' "$SETTINGS" 2>/dev/null || stat -f '%Lp' "$SETTINGS"
```

> **なぜ `chmod "$MODE"` が必要か**: `>` redirect + `mv` パターンは tmp ファイルを umask (一般に `022` → 644) で作成するため、元の `~/.claude/settings.json` が `600` (token / secret を含むため強い permission で保護) だった場合、merge 後に **read access が広がる** security regression が起きる。`chmod "$MODE"` で元の mode を明示復元すれば、token を含むファイルでも安全。

> **AI からこの jq を実行できない理由**: `~/.claude/settings.json` は AI による self-tampering 防止対象 (`Edit/Write(.claude/settings*)` deny + auto mode classifier が Bash 経由の迂回も block)。**ユーザー自身がターミナルで実行する**前提のレシピ。

### 検証

```bash
# JSON 構文
jq -e '.' ~/.claude/settings.json > /dev/null && echo "VALID JSON"

# allowedDomains の件数
# Case A (既存 sandbox 無し): ちょうど 29
# Case B (既存 sandbox あり): 29 以上 (既存と union したので 29 + 既存独自分)
jq '.sandbox.network.allowedDomains | length' ~/.claude/settings.json

# deniedDomains の件数
# Case A: ちょうど 9 / Case B: 9 以上
jq '.sandbox.network.deniedDomains | length' ~/.claude/settings.json

# 必須ホストが含まれているか (Case A / B 共通の最低条件)
# 注意: jq array `contains` は string substring match なので "www.firecrawl.dev" が
# "firecrawl.dev" を含むと誤判定する。exact match のため any(. == "...") を使う
# (any() は ! を含まないため zsh history expansion との衝突も無い)
jq -e '
  (.sandbox.network.allowedDomains | any(. == "api.firecrawl.dev")) and
  (.sandbox.network.allowedDomains | any(. == "firecrawl.dev")) and
  (.sandbox.network.deniedDomains | any(. == "169.254.169.254")) and
  (.sandbox.network.deniedDomains | any(. == "pastebin.com"))
' ~/.claude/settings.json && echo "REQUIRED HOSTS PRESENT"

# Case B 限定: 既存 filesystem セクションが破壊されていないか
jq '.sandbox.filesystem // "no filesystem section (Case A)"' ~/.claude/settings.json

# 既存の enabledPlugins が壊れていないか (Case A / B 共通)
jq '.enabledPlugins | length' ~/.claude/settings.json
# → 既存件数を維持
```

### CC 再起動

sandbox 設定は **session start 時にのみ読まれる**。merge 後は CC を完全再起動 (cmd+Q → 再起動) で initialize される。

## 構成の意図

3 階層で先回り許可する設計:

| 階層 | ドメイン | 用途 |
|------|---------|------|
| **開発コア** (14) | `github.com` / `api.github.com` / `raw.githubusercontent.com` / `codeload.github.com` / `objects.githubusercontent.com` / `registry.npmjs.org` / `api.anthropic.com` / `pypi.org` / `files.pythonhosted.org` / `proxy.golang.org` / `sum.golang.org` / `crates.io` / `static.crates.io` / `rubygems.org` | npm install / pip install / go mod / cargo / git clone |
| **Firecrawl** (2) | `api.firecrawl.dev` / `firecrawl.dev` | Firecrawl API endpoint |
| **スクレイプ対象** (13) | `techblog.zozo.com` / `note.com` / `assets.st-note.com` / `zenn.dev` / `qiita.com` / `dev.to` / `medium.com` / `cdn-ak.f.st-hatena.com` / `engineering.dena.com` / `developers.cyberagent.co.jp` / `tech.uzabase.com` / `engineer.crowdworks.jp` / `tech.smarthr.jp` | 日本/英語のテックブログ・記事スクレイプ |

`deniedDomains` 9 個（クラウド metadata endpoint と pastebin 系）は **SSRF + 情報流出経路の遮断**として維持。`allowedDomains` で許可してもこちらが優先で deny される。

## 各 sandbox オプションの意味

| キー | 値 | 意味 |
|------|-----|------|
| `enabled` | `true` | CC 起動時から sandbox を ON にする。`/sandbox` コマンドでの手動起動が不要 |
| `autoAllowBashIfSandboxed` | `true` | sandbox に閉じ込められた Bash subprocess は permission ダイアログ無しで自動許可。autonomous セッションが止まらない |
| `excludedCommands` | `docker / docker-compose / watchman / systemctl / launchctl / brew services` | sandbox 内で動かせない OS 系コマンドは sandbox 外で実行に逃がす |
| `network.allowedDomains` | 29 個 | 外向き通信を許可するホスト |
| `network.deniedDomains` | 9 個 | 許可リストにあっても拒否する（優先） |

## 外向き通信のスモークテスト (要 `FIRECRAWL_API_KEY`)

実際に sandbox 越しに通るかを確認:

```bash
firecrawl scrape "https://techblog.zozo.com/" -o /tmp/test.md
# → 成功すれば /tmp/test.md に markdown が書き出される
# → 失敗時 (HTTP/2 403 / x-deny-reason: host_not_allowed) は
#   sandbox 設定が effective になっていない (CC 再起動を忘れた可能性)
```

## なぜ AI が自動で編集しないのか

`~/.claude/settings.json` は CC 自身を制約する security boundary。AI が自分の制約を勝手に緩める（self-tampering）のを防ぐため、CC の auto mode classifier と `Edit(.claude/settings*)` / `Write(.claude/settings*)` deny rule が **二重で**ブロックする。Bash 経由の迂回も classifier が「User Deny Rules circumvention」として deny する設計。

このため:
- AI 側: patch JSON を **提示するだけ**
- ユーザー側: 手動で適用 + 検証

これは harness の **責任境界**。AI に security 設定変更の自律権限は持たせない。

## トラブルシューティング

### 編集後も 403 が出る

1. JSON syntax error の可能性。`jq -e '.' ~/.claude/settings.json` で確認
2. CC を **完全再起動**（cmd+Q → 再起動）。sandbox 設定は session start 時に読まれる
3. `FIRECRAWL_API_KEY` 環境変数が未設定の可能性。`.zshrc` を確認

### `filesystem` の write 許可を追加したのに `EPERM` が出る

⚠️ **キー名は `allowWrite`**（公式: code.claude.com/docs/en/sandboxing）。
`write` という名前にすると未知キーとして無視され、設定が効かない。
`~/` は sandbox 側で展開されるので tilde 形式でよい（公式例 `["~/.kube"]`）。

修正:

```jsonc
// ❌ 効かない（キー名が違う = 無視される）
"filesystem": { "write": ["~/.cursor"] }

// ✅ 効く（公式キー）
"filesystem": { "allowWrite": ["~/.cursor"] }
```

ディレクトリ指定で配下も再帰的に許可される。

（cursor-agent backend の sandbox 要件として 2026-05-29 に実測確認。誤った `write` キーでの
エラー例: `EPERM: open '/Users/<user>/.cursor/cli-config.json.tmp'`）

### 別のドメインが必要になった

`allowedDomains` 配列に追加するだけ。CC 2.1.113+ では `*.example.com` の wildcard も使えるが、**漏れの可視性のため明示列挙を推奨**。

### sandbox を一時的に外したい

`"enabled": false` にする。または `--no-sandbox` flag で起動。ただし security 後退するため一時利用に限る。

## 関連

- `templates/sandbox-settings.json.template` — harness の reference 設定。**本 recipe と 29 ドメイン allowlist + 9 ドメイン denylist が完全同期**。新規プロジェクト (= `sandbox` 既存無し = Case A) で一括流用するなら、template の `sandbox` セクション全体をコピーすると確実。**既存 sandbox がある場合 (Case B) は jq merge を使う**こと (template の丸ごとコピーは既存 `filesystem` / `failIfUnavailable` を破壊する)
- `CLAUDE.md` Permission Boundaries — sandbox 設定が AI による self-tampering 防止層と多層防御を構成
- `.claude/rules/cross-repo-handoff.md` — Layer 1 (server-side) / Layer 2/3 (client-side) の redact 設計
- CC v2.1.108+ sandbox 仕様: 公式 docs の `sandbox` セクション

## 履歴

- 2026-05-21: 初版作成。外部プロジェクトで Firecrawl が 403 になった事例を契機に docs 化
