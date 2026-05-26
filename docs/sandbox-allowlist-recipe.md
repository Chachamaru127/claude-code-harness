# Sandbox Allowlist Recipe (for Firecrawl / Web Scraping)

A recipe for resolving `HTTP/2 403 / x-deny-reason: host_not_allowed` errors when Firecrawl, tech-blog fetching, or external API calls are blocked in other projects that have claude-code-harness installed.

> **TL;DR**: The CC sandbox defaults to **empty allowlist = deny all**. The canonical fix is to add `sandbox.network.allowedDomains` to the user-global `~/.claude/settings.json`. Because the AI cannot make this change itself (the self-audit guard denies it), **the user must edit the file manually**.

## Symptoms

Firecrawl CLI / WebFetch / curl returns 403 / connection refused in an external project. The Bash subprocess log shows:

```
HTTP/2 403
x-deny-reason: host_not_allowed
```

or

```
curl: (6) Could not resolve host: api.firecrawl.dev
```

## Cause

The Claude Code sandbox (macOS Seatbelt / Linux bubblewrap) uses an **allowlist default**. If `~/.claude/settings.json` has no `sandbox.network.allowedDomains`, no outbound communication is permitted to any host.

Checking the Firecrawl plugin's `SKILL.md` shows `allowed-tools: Bash(firecrawl *)`. This means the Firecrawl CLI runs as a Bash subprocess and is directly affected by the sandbox (it is not an MCP server).

## Fix: merge sandbox settings into `~/.claude/settings.json`

**Important**: There are 2 cases depending on whether a `sandbox` key **already exists** in `~/.claude/settings.json`. Accidentally overwriting an existing sandbox block will erase existing guardrails such as `failIfUnavailable` / `filesystem.denyRead` / `network.deniedDomains`.

### Step 0: Check whether a sandbox key already exists

```bash
jq 'has("sandbox")' ~/.claude/settings.json
# false → Case A (add new)
# true  → Case B (inner merge)
```

### Case A: No existing `sandbox` key (add new)

Add a single `sandbox` key at the **same level (top-level)** as the existing `permissions` / `hooks` / `enabledPlugins` / `mcpServers` keys. Do not touch any existing keys:

```json
{
  "permissions": { /* keep as-is */ },
  "hooks": { /* keep as-is */ },
  "enabledPlugins": { /* keep as-is */ },
  "mcpServers": { /* keep as-is */ },
  /* ... all other existing top-level keys unchanged ... */

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

### Case B: An existing `sandbox` key is present (inner merge)

**Retain** the existing `sandbox.failIfUnavailable` / `sandbox.filesystem` / `sandbox.network.deniedDomains` and only add / merge fields inside the existing block. **Replacing the entire `sandbox` block is prohibited** (it destroys existing guardrails).

Merge rules:

| Field | Operation | Notes |
|-------|-----------|-------|
| `sandbox.enabled` | Set to `true` | Keep as-is if already `true` |
| `sandbox.autoAllowBashIfSandboxed` | Set to `true` | Add as new field |
| `sandbox.failIfUnavailable` | **Keep existing** | Do not touch |
| `sandbox.excludedCommands` | If array, **union (merge without duplicates)**; otherwise add new | Do not remove existing entries |
| `sandbox.network.allowedDomains` | **Existing array + 29 entries from this recipe as union** | Do not remove existing hosts |
| `sandbox.network.deniedDomains` | **Existing array + 9 entries from this recipe as union** | Keep existing denied hosts |
| `sandbox.filesystem` | **Keep existing** | Do not touch (denyRead/allowRead etc. would be lost) |

### Automatic merge jq one-liner (handles both Case A and B)

Manual merging in an editor carries a high risk of duplicates and accidental guardrail deletion. The following jq one-liner is safe for both cases:

```bash
SETTINGS=~/.claude/settings.json

# 1. Save the original file mode (handles files protected with 600 etc. that contain tokens)
#    Cross-platform stat: try Linux GNU stat -c first, fall back to macOS BSD stat -f
#    (Order matters: BSD stat -f is misinterpreted as a filesystem-status flag on Linux)
MODE=$(stat -c '%a' "$SETTINGS" 2>/dev/null || stat -f '%Lp' "$SETTINGS")

# 2. Backup (use cp -p to preserve mode/ownership)
cp -p "$SETTINGS" "${SETTINGS}.bak.$(date +%Y%m%d-%H%M%S)"

# 3. Merge (preserve existing sandbox.filesystem / failIfUnavailable; union arrays)
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

# 4. Verify that the mode was preserved (should match the original MODE)
#    Same order as MODE capture: Linux GNU stat -c → macOS BSD stat -f fallback
stat -c '%a' "$SETTINGS" 2>/dev/null || stat -f '%Lp' "$SETTINGS"
```

> **Why `chmod "$MODE"` is necessary**: The `>` redirect + `mv` pattern creates a tmp file with umask permissions (typically `022` → 644). If the original `~/.claude/settings.json` was `600` (protected with strong permissions because it contains tokens / secrets), the merge would widen read access, creating a security regression. Explicitly restoring the mode with `chmod "$MODE"` keeps the file safe even when it contains tokens.

> **Why the AI cannot run this jq command**: `~/.claude/settings.json` is protected against AI self-tampering (`Edit/Write(.claude/settings*)` deny + the auto mode classifier also blocks Bash-based workarounds). **The user must run this command in their own terminal**.

### Verification

```bash
# JSON syntax
jq -e '.' ~/.claude/settings.json > /dev/null && echo "VALID JSON"

# Number of allowedDomains entries
# Case A (no existing sandbox): exactly 29
# Case B (existing sandbox present): 29 or more (union with existing entries)
jq '.sandbox.network.allowedDomains | length' ~/.claude/settings.json

# Number of deniedDomains entries
# Case A: exactly 9 / Case B: 9 or more
jq '.sandbox.network.deniedDomains | length' ~/.claude/settings.json

# Check that required hosts are present (minimum condition for both Case A and B)
# Note: jq array `contains` does substring matching, so "www.firecrawl.dev" would
# incorrectly match "firecrawl.dev". Use any(. == "...") for exact matching
# (any() does not include !, avoiding zsh history expansion issues)
jq -e '
  (.sandbox.network.allowedDomains | any(. == "api.firecrawl.dev")) and
  (.sandbox.network.allowedDomains | any(. == "firecrawl.dev")) and
  (.sandbox.network.deniedDomains | any(. == "169.254.169.254")) and
  (.sandbox.network.deniedDomains | any(. == "pastebin.com"))
' ~/.claude/settings.json && echo "REQUIRED HOSTS PRESENT"

# Case B only: verify the existing filesystem section was not destroyed
jq '.sandbox.filesystem // "no filesystem section (Case A)"' ~/.claude/settings.json

# Verify existing enabledPlugins were not broken (Case A and B)
jq '.enabledPlugins | length' ~/.claude/settings.json
# → should match the original count
```

### Restart CC

Sandbox settings are **read only at session start**. After merging, fully restart CC (cmd+Q → relaunch) to initialize the new settings.

## Design intent

Three-tier pre-approved allowlist:

| Tier | Domains | Purpose |
|------|---------|---------|
| **Dev core** (14) | `github.com` / `api.github.com` / `raw.githubusercontent.com` / `codeload.github.com` / `objects.githubusercontent.com` / `registry.npmjs.org` / `api.anthropic.com` / `pypi.org` / `files.pythonhosted.org` / `proxy.golang.org` / `sum.golang.org` / `crates.io` / `static.crates.io` / `rubygems.org` | npm install / pip install / go mod / cargo / git clone |
| **Firecrawl** (2) | `api.firecrawl.dev` / `firecrawl.dev` | Firecrawl API endpoint |
| **Scrape targets** (13) | `techblog.zozo.com` / `note.com` / `assets.st-note.com` / `zenn.dev` / `qiita.com` / `dev.to` / `medium.com` / `cdn-ak.f.st-hatena.com` / `engineering.dena.com` / `developers.cyberagent.co.jp` / `tech.uzabase.com` / `engineer.crowdworks.jp` / `tech.smarthr.jp` | Japanese and English tech blog / article scraping |

The 9 `deniedDomains` (cloud metadata endpoints and pastebin-style services) are maintained as **SSRF and data-exfiltration route blockers**. They are denied even if a domain appears in `allowedDomains`.

## Meaning of each sandbox option

| Key | Value | Meaning |
|-----|-------|---------|
| `enabled` | `true` | Enables the sandbox from CC startup. Manual activation via `/sandbox` is not required. |
| `autoAllowBashIfSandboxed` | `true` | Bash subprocesses running inside the sandbox are auto-approved without a permission dialog. Autonomous sessions do not stall. |
| `excludedCommands` | `docker / docker-compose / watchman / systemctl / launchctl / brew services` | OS-level commands that cannot run inside the sandbox are redirected to run outside it. |
| `network.allowedDomains` | 29 entries | Hosts permitted for outbound communication. |
| `network.deniedDomains` | 9 entries | Hosts that are denied even if they appear in the allowlist (takes priority). |

## Outbound connectivity smoke test (requires `FIRECRAWL_API_KEY`)

Verify that traffic passes through the sandbox:

```bash
firecrawl scrape "https://techblog.zozo.com/" -o /tmp/test.md
# → On success: /tmp/test.md contains the scraped markdown
# → On failure (HTTP/2 403 / x-deny-reason: host_not_allowed):
#   the sandbox settings are not yet effective (you may have forgotten to restart CC)
```

## Why the AI does not edit this automatically

`~/.claude/settings.json` is the security boundary that constrains CC itself. To prevent AI self-tampering (the AI relaxing its own constraints), the CC auto mode classifier and the `Edit(.claude/settings*)` / `Write(.claude/settings*)` deny rule provide **dual-layer** blocking. Bash-based workarounds are also denied by the classifier as "User Deny Rules circumvention".

Therefore:
- AI side: **presents** the patch JSON only
- User side: applies and verifies it manually

This is a **responsibility boundary** of the harness. The AI is not granted autonomous authority to change security settings.

## Troubleshooting

### Still getting 403 after editing

1. Possible JSON syntax error. Verify with `jq -e '.' ~/.claude/settings.json`
2. **Fully restart CC** (cmd+Q → relaunch). Sandbox settings are read at session start.
3. `FIRECRAWL_API_KEY` environment variable may not be set. Check `.zshrc`.

### A different domain is needed

Just add it to the `allowedDomains` array. CC 2.1.113+ supports `*.example.com` wildcards, but **explicit enumeration is recommended for visibility**.

### Temporarily disable the sandbox

Set `"enabled": false`, or launch with the `--no-sandbox` flag. This reduces security, so restrict it to temporary use only.

## Related

- `templates/sandbox-settings.json.template` — harness reference config. **This recipe and the template are fully in sync: 29-domain allowlist + 9-domain denylist**. For new projects (no existing `sandbox` = Case A), copying the entire `sandbox` section from the template is the easiest approach. **For projects with an existing sandbox (Case B) use the jq merge** (wholesale copying the template would destroy existing `filesystem` / `failIfUnavailable` settings).
- `CLAUDE.md` Permission Boundaries — the sandbox setting forms a multi-layered defense together with the AI self-tampering prevention layer
- `.claude/rules/cross-repo-handoff.md` — Layer 1 (server-side) / Layer 2/3 (client-side) redaction design
- CC v2.1.108+ sandbox specification: see `sandbox` section in official docs

## History

- 2026-05-21: Initial version. Documented after a Firecrawl 403 error in an external project.
