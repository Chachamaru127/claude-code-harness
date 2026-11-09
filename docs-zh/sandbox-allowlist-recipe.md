# Sandbox Allowlist Recipe (Firecrawl / Web Scraping 用)

在其他项目安装 claude-code-harness 后 Firecrawl・技术博客获取・外部 API 调用被
`HTTP/2 403 / x-deny-reason: host_not_allowed` 阻止时的解决 recipe。

> **TL;DR**: CC sandbox 默认是 **allowlist 空 = 全 deny**。向用户 global 的
> `~/.claude/settings.json` 添加 `sandbox.network.allowedDomains` 是正规路径。
> AI 途经写入被 self-audit guard 拒绝，因此**用户手动编辑**。

## 症状

在外部项目中 Firecrawl CLI / WebFetch / curl 变成 403 / connection refused。
Bash subprocess 日志输出：

```
HTTP/2 403
x-deny-reason: host_not_allowed
```

或者：

```
curl: (6) Could not resolve host: api.firecrawl.dev
```

## 原因

Claude Code sandbox（macOS Seatbelt / Linux bubblewrap）是 **allowlist default**。
`~/.claude/settings.json` 中没有 `sandbox.network.allowedDomains` = 无法向任何主机发出外部通信。

看 Firecrawl plugin 的 `SKILL.md`，`allowed-tools: Bash(firecrawl *)`。
即 Firecrawl CLI 作为 Bash subprocess 运行，直接受 sandbox 影响（MCP server 不是）。

## Migration: runtime floor secret allow 是 plan-time 事前确认

`HARNESS_RUNTIME_FLOOR_SECRET_ALLOW` 这样的广域・常设 secret-read allow 声明在新运营中避免。
取而代之，在 `/harness-plan create` 的计划确定时提出**事前确认部分**，
按 task scope 一并承认需要的 secret-read path / 外部发送 / 破坏操作。

承认结果保存在 `.claude/state/plan-preapprovals.json`（`plan-preapproval.v2`）。
v2 拥有 phase/task scope、`expires_at`、`max_uses`、`uses`。
v1 仅保持对现有记录的读取兼容。
`/harness-work` / `/breezing` 在 task 开始时写入 `.claude/state/active-task.json`。
`scripts/plan-preapproval.sh apply-secret-allow "$PROJECT_ROOT"` 将当前 phase/task 一致的
已承认 `secret-read` path 仅反映到 project config 的 `runtimefloor.secretAllow`。
未计划的 secret-read / 外部发送由于没有记录，传统上 runtime floor / ask 停止，因此安全网不缩小。

## 解决：将 sandbox 设置 merge 到 `~/.claude/settings.json`

**重要**：`~/.claude/settings.json` 中**是否存在现有 `sandbox` 键**分为 2 种情况。
误将现有 sandbox 覆盖的话，`failIfUnavailable` / `filesystem.denyRead` / `network.deniedDomains` 等
现有 guardrail 会消失。

### Step 0: 确认现有 sandbox 有无

```bash
jq 'has("sandbox")' ~/.claude/settings.json
# false → Case A (新規追加)
# true  → Case B (内側 merge)
```

### Case A: 现有无 `sandbox` 键时（新增）

与现有的 `permissions` / `hooks` / `enabledPlugins` / `mcpServers` 等**同一层级 (top-level)**
仅添加 1 个 `sandbox` 键。不 touch 现有键：

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

### Case B: 现有有 `sandbox` 键时（内侧 merge）

**保持**现有的 `sandbox.failIfUnavailable` / `sandbox.filesystem` / `sandbox.network.deniedDomains` 等，
在内侧添加/合并字段。**禁止整体替换 `sandbox` 块**（破坏现有 guardrail）。

merge 规则：

| 字段 | 操作 | 注意 |
|------|------|------|
| `sandbox.enabled` | 设为 `true` | 已经是 `true` 就维持 |
| `sandbox.autoAllowBashIfSandboxed` | 设为 `true` | 新增 |
| `sandbox.failIfUnavailable` | **现有维持** | 不碰 |
| `sandbox.excludedCommands` | 数组的话 **union（去重合并）**，无则新增 | 不删除现有项目 |
| `sandbox.network.allowedDomains` | **现有数组 + 本 recipe 的 29 个 union** | 不删除现有主机 |
| `sandbox.network.deniedDomains` | **现有数组 + 本 recipe 的 9 个 union** | 保留现有拒绝主机 |
| `sandbox.filesystem` | **现有维持** | 禁止 touch（denyRead/allowRead 等会消失） |

### 自动 merge 的 jq one-liner（Case A / B 两用）

手动 merge 在编辑器中有重复和 guardrail 消除的风险。以下的 jq one-liner 两 case 都安全：

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

> **为什么需要 `chmod "$MODE"`**：>` 重定向 + `mv` 模式用 umask（一般为 `022` → 644）创建 tmp 文件，
> 因此如果原 `~/.claude/settings.json` 是 `600`（因包含 token / secret 用强 permission 保护），
> merge 后 **read access 扩大** security regression 会发生。
> `chmod "$MODE"` 明确恢复原 mode，即使包含 token 的文件也安全。

> **AI 无法自动执行此 jq 的理由**：`~/.claude/settings.json` 是 AI 防止自我篡改的对象
> (`Edit/Write(.claude/settings*)` deny + auto mode classifier 通过 Bash 迂回也被 block)。
> **用户自己在终端执行**的 recipe 前提。

### 验证

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

### CC 重启

sandbox 设置**仅在 session start 时读取**。merge 后完全重启 CC (cmd+Q → 重启) 才能 initialize。

## 构成的意图

用 3 层先发许可的设计：

| 层 | 域名 | 用途 |
|------|---------|------|
| **开发核心** (14) | `github.com` / `api.github.com` / `raw.githubusercontent.com` / `codeload.github.com` / `objects.githubusercontent.com` / `registry.npmjs.org` / `api.anthropic.com` / `pypi.org` / `files.pythonhosted.org` / `proxy.golang.org` / `sum.golang.org` / `crates.io` / `static.crates.io` / `rubygems.org` | npm install / pip install / go mod / cargo / git clone |
| **Firecrawl** (2) | `api.firecrawl.dev` / `firecrawl.dev` | Firecrawl API endpoint |
| **爬取目标** (13) | `techblog.zozo.com` / `note.com` / `assets.st-note.com` / `zenn.dev` / `qiita.com` / `dev.to` / `medium.com` / `cdn-ak.f.st-hatena.com` / `engineering.dena.com` / `developers.cyberagent.co.jp` / `tech.uzabase.com` / `engineer.crowdworks.jp` / `tech.smarthr.jp` | 日本/英语技术博客・文章爬取 |

`deniedDomains` 9 个（云 metadata endpoint 和 pastebin 系）是**SSRF + 信息泄露路径的遮断**维持。
即使在 allowedDomains 中允许也会被这个优先 deny。

## 各 sandbox 选项的含义

| 键 | 值 | 含义 |
|------|-----|------|
| `enabled` | `true` | CC 启动时 ON sandbox。不需要手动用 `/sandbox` 命令启动 |
| `autoAllowBashIfSandboxed` | `true` | 被 sandbox 封闭的 Bash subprocess 无 permission 对话框自动许可。autonomous 会话不停止 |
| `excludedCommands` | `docker / docker-compose / watchman / systemctl / launchctl / brew services` | 在 sandbox 内无法运行的 OS 系命令在 sandbox 外执行 |
| `network.allowedDomains` | 29 个 | 允许外向通信的主机 |
| `network.deniedDomains` | 9 个 | 即使在允许列表中也拒绝（优先） |

## 外向通信冒烟测试（需要 `FIRECRAWL_API_KEY`）

确认实际上 sandbox 能否通过：

```bash
firecrawl scrape "https://techblog.zozo.com/" -o /tmp/test.md
# → 成功すれば /tmp/test.md に markdown が書き出される
# → 失敗時 (HTTP/2 403 / x-deny-reason: host_not_allowed) は
#   sandbox 設定が effective になっていない (CC 再起動を忘れた可能性)
```

## 为什么 AI 不自动编辑

`~/.claude/settings.json` 是约束 CC 自身的安全边界。AI 擅自缓和自己的约束（self-tampering），
CC 的 auto mode classifier 和 `Edit(.claude/settings*)` / `Write(.claude/settings*)` deny 规则
**双重** block。Bash 迂回也被 classifier 作为"User Deny Rules circumvention" deny 的设计。

因此：
- AI 侧：仅**提示** patch JSON
- 用户侧：手动应用 + 验证

这是 harness 的**责任边界**。不让 AI 有 security 设置变更的自律权限。

## 故障排除

### 编辑后还出 403

1. JSON 语法错误可能性。`jq -e '.' ~/.claude/settings.json` 确认
2. **完全重启** CC (cmd+Q → 重启)。sandbox 设置 session start 时读取
3. `FIRECRAWL_API_KEY` 环境变量未设置可能性。确认 `.zshrc`

### 添加了 filesystem 写许可却出 `EPERM`

⚠️ **键名是 `allowWrite`**（官方：code.claude.com/docs/en/sandboxing）。
用 `write` 这个名会被作为未知键忽略，设置不生效。
`~/` 在 sandbox 侧展开，所以用 tilde 形式（官方例 `["~/.kube"]`）。

修正：

```jsonc
// ❌ 効かない（キー名が違う = 無視される）
"filesystem": { "write": ["~/.cursor"] }

// ✅ 効く（公式キー）
"filesystem": { "allowWrite": ["~/.cursor"] }
```

目录指定可以递归允许下层。

（作为 cursor-agent backend 的 sandbox 要件在 2026-05-29 实测确认。
错误 `write` 键时的错误例：`EPERM: open '/Users/<user>/.cursor/cli-config.json.tmp'`）

### 需要其他域名

仅需在 `allowedDomains` 数组追加。CC 2.1.113+ 可以使用 `*.example.com` 的 wildcard，
但**为可见性建议明确列举**。

### 想临时解除 sandbox

设为 `"enabled": false`。或用 `--no-sandbox` 标志启动。但 security 倒退，仅限临时使用。

## PROPOSAL (未适用・仅提案): credential-masking + strictAllowlist による denyRead 代替 (133.6)

> **这是提案，不是 live 设置的适用。** 本任务中 `~/.claude/settings.json` 完全没有变更。
> 适用判断由用户（owner）进行。

在 `docs/research/133-6-cc-cli-claim-verification.md` 中从一次信息 (raw CHANGELOG.md) 确认的
CC CLI 新功能 3 件，可能能从结构上防止 `.claude/rules/defense-layer-blast-radius.md` 记录的 2 件事故
(用 denyRead 遮断 gh CLI 设置目录导致 credential helper 死亡 / sandbox.enabled 导致 SSH
alias 解析破坏)。

| CC 版本 | 功能 | 现行 `denyRead` 的差异 |
|---|---|---|
| `2.1.219` | `sandbox.network.strictAllowlist` | 未许可主机无 prompt 直接 deny。不涉及文件读取，因此 gh/npm/ssh 的设置文件读取不受影响 |
| `2.1.221` | credential file `mode: "mask"` (Linux/WSL 限定，macOS 是 `deny` fallback) | 不是目录整体 `denyRead`，而是向 sandboxed 进程展示dummy值，egress 时 sandbox proxy 仅替换实值。**CLI 本体能正常读取自己的设置文件**，实际 secret 不会外出 |
| `2.1.224` | `extract` / `onExtractNoMatch` / `decode: "jwt"` + `maskClaims` / `awsPairs` + `sigv4` | 结构化 credential (JWT、AWS SigV4 签名) 按值单位 masking。前提条件是 `network.tlsTerminate` |

**为什么可能防止现有事故**：2 件事故都是"将设置和 secret 混在同一个目录的文件目录整体 `denyRead`"导致的
(`~/.config/gh` 是 gh CLI 本体每次读取的设置和 OAuth token 同居)。
`mode: "mask"` 不是目录单位而是文件内值单位动作，因此从 CLI 本体看"文件可读，仅值是 dummy"状态，
gh CLI 启动时设置读取死亡的结构可能回避。

**未验证・需确认事项** (适用前需验证，本任务仅到此为止)：

1. macOS 上 credential file masking 会 fallback 为 `deny` (2.1.221 changelog 原文)。
   `.claude/rules/defense-layer-blast-radius.md` 的 2 件事故都是 macOS 执行环境，
   因此**在 macOS 上本提案效果有限**（变成与 denyRead 相同的 deny 动作的可能性高）— Linux/WSL 环境限定的改善可能性高
2. `network.tlsTerminate` 前提条件的运营成本未调查
3. `strictAllowlist` 仅是 network 侧，不是 filesystem denyRead 问题本身的解决
   (不同轴的改善)
4. 实际 gh/npm/ssh 设置文件应用 `mode: "mask"` 的具体模式未验证

**现行建议无变更**：基于上述未验证事项（特别 1），不推荐从 `denyRead` 替换。
在 macOS 中心的运营实际状态下，先验证 Linux/WSL 环境采用可行性后，
作为 `.claude/rules/defense-layer-blast-radius.md` 的"追加前检查"候选追加的下一步提案。

## 相关

- `templates/sandbox-settings.json.template` — harness 的 reference 设置。
  **本 recipe 与 29 域名 allowlist + 9 域名 denylist 完全同步**。
  新项目（= 无现有 `sandbox` = Case A）一括流用时，复制 template 的 `sandbox` 部分整体。
  **现有 sandbox 有时 (Case B) 使用 jq merge**（整体复制会破坏现有 `filesystem` / `failIfUnavailable`）
- `CLAUDE.md` Permission Boundaries — sandbox 设置与 AI 自我篡改防止层和多层防御构成
- `.claude/rules/cross-repo-handoff.md` — Layer 1 (server-side) / Layer 2/3 (client-side) 的 redact 设计
- CC v2.1.108+ sandbox 规格：官方 docs 的 `sandbox` 部分

## 历史

- 2026-05-21：初版创建。以外部项目中 Firecrawl 403 事例为契机 docs 化
