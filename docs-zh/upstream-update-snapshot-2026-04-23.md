# Claude Code / Codex upstream snapshot - 2026-04-23

本 snapshot 为 2026-04-23 时点的官方 upstream 确认记录，分解为应直接纳入 Claude Code Harness 的项目、以及仅自动继承 / 留作将来任务的项目。

确认日：

- 2026-04-23 (Asia/Tokyo)

一次信息：

- Claude Code docs changelog: <https://code.claude.com/docs/en/changelog>
- Claude Code GitHub changelog: <https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md>
- OpenAI Codex releases: <https://github.com/openai/codex/releases>
- OpenAI Codex `rust-v0.123.0` release tag: <https://github.com/openai/codex/releases/tag/rust-v0.123.0>

确认对象：

- Claude Code `2.1.117`
- Claude Code `2.1.118`
- Codex `0.123.0`

分类：

- `A: 実装`: 落地到 Harness 侧的 hooks / release / setup / skills / tests / docs。53.1.1 中将实现任务 ID 固定，实现主体由后续 task 执行。
- `C: 自動継承`: Claude Code / Codex 本体的改进直接继承。若叠加 Harness wrapper 会造成双重责任。
- `P: 将来タスク`: 本次不立即实现，但作为后续候选项留在 Plans 中。不做推测实现。

## Version-by-version breakdown

| Version | Upstream item | 这样会更好 | Category | Harness surface | Harness action |
|---------|---------------|------------|----------|-----------------|----------------|
| Claude Code 2.1.118 | Vim visual mode / visual-line mode | 仅用键盘即可更方便地选择和编辑 | C | TUI usage | Harness 侧 wrapper 不需要。作为 Claude Code 本体 editor UX 自动继承 |
| Claude Code 2.1.118 | `/cost` 和 `/stats` 整合为 `/usage`，旧命令成为 relevant tab 打开的 typing shortcut | 利用量确认的入口统一为一个，减少迷惑 | C | docs / session guidance | 53.1.6 中若存在以 `/cost` / `/stats` 为中心的老说明，则向 `/usage` 为主靠拢。行为由本体自动继承 |
| Claude Code 2.1.118 | `/theme` 可创建 / 切换 named custom themes，支持 JSON 手写和 plugin `themes/` directory | plugin 有了提供外观初始值的余地 | P | plugin setup / design policy | 53.1.5 中在 setup docs 记录用途。本次不决定 Harness plugin 是否附赠 theme，不做推测实现 |
| Claude Code 2.1.118 | Hooks can invoke MCP tools directly via `type: "mcp_tool"` | 有可能实现不借助 shell script 的读取诊断 hook | A | hooks / MCP diagnostics / tests | 53.1.2 中以读取专用 MCP health/resource 诊断为限进行验证。本次分发 hooks manifest 为 no-op，在 test 中固定"不从 hook 调用写入系 MCP tool" |
| Claude Code 2.1.118 | `DISABLE_UPDATES` blocks all update paths, including manual `claude update` | 企业管理环境可以连手动更新也停止 | A | setup docs / plugin policy | 53.1.5 中说明与 `DISABLE_AUTOUPDATER` 的差异。不追加 Harness 独自 updater block |
| Claude Code 2.1.118 | WSL can inherit Windows-side managed settings via `wslInheritsWindowsSettings` | Windows / WSL 混在环境的管理设置更容易统一 | P | enterprise setup docs | 纳入 53.1.5 的 managed settings 整理。不对 Harness default 过度适用 |
| Claude Code 2.1.118 | Auto Mode `autoMode.allow` / `soft_deny` / `environment` can include `"$defaults"` to extend built-ins | 可以在不删除既定安全规则的情况下追加自定义规则 | A | permissions / sandbox docs / settings template | 53.1.4 中固定为"追加到 `"$defaults"` 而非"替换""，并固定 guidance 和 test |
| Claude Code 2.1.118 | Auto mode opt-in prompt adds "Don't ask again" | 减少重复确认的噪音 | C | Auto Mode UX | 作为 Claude Code 本体对话 UX 自动继承。不在 Harness 侧叠加 prompt suppression |
| Claude Code 2.1.118 | `claude plugin tag` creates release git tags with plugin version validation | plugin release 时更难在 version 不一致的情况下打 tag | A | harness-release / release tests | 53.1.3 中在 release flow 追加 preflight / dry-run guidance 和 validation 位置 |
| Claude Code 2.1.118 | `--continue` / `--resume` find sessions that added the current directory via `/add-dir` | 减少 multi-directory session 恢复遗漏 | C | session-control docs | 53.1.6 中若有旧 resume 前提则更新。实现由本体自动继承 |
| Claude Code 2.1.118 | `/color` syncs session accent color to claude.ai/code when Remote Control is connected | remote UI 的外观统一 | C | Remote Control UX | Harness surface 无。自动继承 |
| Claude Code 2.1.118 | `/model` picker honors `ANTHROPIC_DEFAULT_*_MODEL_NAME` / `_DESCRIPTION` overrides with custom gateways | gateway 环境下 model 显示更接近实际 | C | model guidance | 因 Harness 不包装 model picker 而自动继承。必要的话在 provider docs 后续中提及 |
| Claude Code 2.1.118 | Plugin auto-update skips caused by another plugin's version constraint appear in `/doctor` and `/plugin` Errors | plugin dependency 失败原因更容易查找 | A | setup / plugin policy docs | 53.1.5 中与 dependency auto-resolve / missing dependency hints 一起说明 |
| Claude Code 2.1.118 | MCP OAuth / custom header authentication fixes | 减少 MCP 连接重认证循环和临时 401 后的卡顿 | C | MCP runtime | 继承本体修正。Harness 的 MCP health watch 放后续，不追加 OAuth workaround |
| Claude Code 2.1.118 | Credential save crash on Linux / Windows no longer corrupts `~/.claude/.credentials.json` | 认证信息损坏风险降低 | C | auth runtime | 继承本体修正。Harness 不直接改写 credentials |
| Claude Code 2.1.118 | `/login` clears `CLAUDE_CODE_OAUTH_TOKEN` session token so disk credentials can take effect | env token 启动后的 login 更容易生效 | C | auth runtime | 继承本体修正 |
| Claude Code 2.1.118 | New message scroll pill and `/plugin` badges readability fixes | TUI 显示更易读 | C | TUI | 自动继承 |
| Claude Code 2.1.118 | Plan acceptance dialog no longer offers auto mode when running with `--dangerously-skip-permissions` | 减少 permission mode 显示的混淆 | C | permission UX | 自动继承。Harness permission guidance 在 53.1.4 中聚焦 `"$defaults"` 更新 |
| Claude Code 2.1.118 | Agent-type hooks no longer fail with "Messages are required for agent hooks" on non-Stop events | agent hook 的适用范围更容易处理 | C | agent hooks | 继承本体修正。与 53.1.2 的 `mcp_tool` hook 区别对待 |
| Claude Code 2.1.118 | `prompt` hooks no longer re-fire on tool calls made by an agent-hook verifier subagent | 减少 verifier subagent 引起的 hook 重入噪音 | C | hook runtime | 自动继承。不追加 Harness 侧防重入 hook |
| Claude Code 2.1.118 | `/fork` stores a parent pointer instead of writing the full parent conversation per fork | fork 变轻，disk 使用量减少 | C | session/fork | 自动继承。Harness session-state 可以以 pointer hydration 为前提 |
| Claude Code 2.1.118 | Alt+K / Alt+X / Alt+^ / Alt+_ keyboard freeze fixes | 键盘输入不容易卡住 | C | TUI input | 自动继承 |
| Claude Code 2.1.118 | Remote session connect no longer overwrites local `model` setting | remote session 使用时 local 设置被破坏减少 | C | remote session | 自动继承 |
| Claude Code 2.1.118 | Typeahead no longer errors when pasted file paths start with `/` | 绝对路径粘贴可以正常使用 | C | prompt input | 自动继承 |
| Claude Code 2.1.118 | `plugin install` on already-installed plugin re-resolves wrong-version dependencies | 依赖关系修复更容易 | A | plugin setup docs | 53.1.5 中记录"不叠加 Harness 独自 resolver，委托本体"方针 |
| Claude Code 2.1.118 | File watcher invalid path / fd exhaustion errors are handled | 长时间运行时不容易因 watcher 错误崩溃 | C | long-running sessions | 自动继承 |
| Claude Code 2.1.118 | Remote Control sessions are not archived on transient CCR initialization blips | 临时 remote 初始化失败时 session 不容易消失 | C | remote session | 自动继承 |
| Claude Code 2.1.118 | Subagents resumed via `SendMessage` restore the explicit `cwd` they were spawned with | subagent resume 后工作目录不容易偏离 | C | subagent orchestration | 作为与 Codex native `send_input` 不同的 Claude Code 本体修正自动继承 |
| Claude Code 2.1.117 | Forked subagents can be enabled on external builds with `CLAUDE_CODE_FORK_SUBAGENT=1` | external build 中也可以尝试 forked subagent | P | agents / skills docs | 53.1.6 中作为将来候选整理。不在 Harness default 中强制环境变量 |
| Claude Code 2.1.117 | Agent frontmatter `mcpServers` load for main-thread agent sessions via `--agent` | main-thread agent 中 MCP 前提的 agent 设置更容易生效 | P | agents audit / MCP setup | 53.1.6 中作为 agents audit 的后续候选记录 |
| Claude Code 2.1.117 | `/model` selections persist across restarts and startup header shows project / managed-settings pins | model 设置的来源更容易理解 | C | model guidance | 自动继承。Harness 不覆盖 model pin |
| Claude Code 2.1.117 | `/resume` offers to summarize stale large sessions before re-reading | 大型旧 session 恢复更轻量 | C | session-memory / resume docs | 53.1.6 中记录不追加 wrapper 的理由。优先 Claude Code 本体的 summary |
| Claude Code 2.1.117 | Faster MCP startup when local and claude.ai MCP servers are both configured | 启动等待时间缩短 | C | MCP startup | 自动继承。MCP health watch 限定在 53.1.2 的读取诊断候选 |
| Claude Code 2.1.117 | Already-installed plugin install now installs missing dependencies | dependency 缺失的自我修复更容易 | A | plugin setup docs | 53.1.5 中记录"不叠加 Harness resolver 到 auto-resolve"的方针 |
| Claude Code 2.1.117 | Plugin dependency errors include install hints and `claude plugin marketplace add` auto-resolves missing dependencies | marketplace 衍生的依赖解决更容易理解 | A | plugin setup / marketplace policy | 53.1.5 中作为企业利用·安全 marketplace 运用整理 |
| Claude Code 2.1.117 | Managed settings `blockedMarketplaces` / `strictKnownMarketplaces` are enforced across plugin install/update/refresh/autoupdate | 管理对象 marketplace policy 不容易有漏洞 | A | managed settings docs | 53.1.5 中以不对普通用户 default 过度适用的形式说明 |
| Claude Code 2.1.117 | Advisor Tool experimental label / link / startup notification, plus stuck-result fixes | experimental Advisor 的定位更清晰，卡顿减少 | C | advisor strategy | Harness Advisor Strategy 维持现状。最终品质判定留在 Reviewer |
| Claude Code 2.1.117 | `cleanupPeriodDays` retention sweep covers tasks, shell snapshots, backups | 旧的辅助数据不容易堆积 | C | maintenance / session storage | 继承本体 cleanup 自动继承。Harness maintenance 中不重复删除 |
| Claude Code 2.1.117 | OpenTelemetry command / usage / effort attributes | 观测数据更详细 | C | telemetry | 因 Harness 不直接处理 OTEL schema 而自动继承 |
| Claude Code 2.1.117 | Native macOS/Linux builds replace Glob/Grep tools with embedded `bfs` and `ugrep` through Bash | 搜索变快，tool round-trip 减少 | C | search guidance | 53.1.6 中作为不追加 wrapper 的项目整理 |
| Claude Code 2.1.117 | Windows caches `where.exe` executable lookups per process | Windows subprocess 启动变快 | C | Windows runtime | 自动继承 |
| Claude Code 2.1.117 | Default effort for Pro/Max subscribers on Opus 4.6 / Sonnet 4.6 is `high` | 复杂工作的初始质量更容易提升 | C | effort guidance | 53.1.6 中若有旧 medium 前提则更新。Harness 不强行覆盖 |
| Claude Code 2.1.117 | OAuth / WebFetch / proxy / keyboard / SDK reload / Bedrock / MCP elicitation / subagent model / idle memory / VS Code plugin panel / Opus context fixes | 认证、fetch、proxy、输入、MCP、subagent、memory、context 显示的问题减少 | C | runtime stability | 继承本体修正。不追加 Harness workaround |
| Codex 0.123.0 | Built-in `amazon-bedrock` model provider with configurable AWS profile support | Codex 侧也更容易以标准方式处理 Bedrock provider | A | Codex setup docs / provider policy | 53.2.1 中更新 provider guidance，不与 Claude 侧 Bedrock guidance 混淆 |
| Codex 0.123.0 | `/mcp verbose` shows diagnostics, resources, and resource templates while plain `/mcp` stays fast | 只在需要时能看到详细的 MCP 诊断 | A | troubleshoot / setup skill | 53.2.2 中记录通常 `/mcp` 与 verbose 诊断的区分使用 |
| Codex 0.123.0 | Plugin MCP loading accepts both `mcpServers` and top-level server maps in `.mcp.json` | 更广泛地读取现有 plugin MCP 设置形式 | A | Codex setup / plugin MCP docs | 53.2.2 中说明两种形式，不与 Claude Code 侧术语混淆 |
| Codex 0.123.0 | Realtime handoffs let background agents receive transcript deltas and explicitly stay silent | 长时间工作中 background agent 只在需要时才更容易回复 | A | harness-loop / breezing guidance | 53.2.3 中整理 silence policy。不与 advisor/reviewer drift 检测矛盾 |
| Codex 0.123.0 | Host-specific `remote_sandbox_config` requirements for remote environments | 可以区分 remote 环境各自的 sandbox 要求 | A | sandbox / execution policy | 53.2.4 中比较表化，确认与现有 `--approval-policy` / `--sandbox` guidance 的重复 |
| Codex 0.123.0 | Bundled model metadata refreshed, including current `gpt-5.4` default | 更易于跟随当前默认 model 信息 | A | Codex setup docs | 53.2.1 中记录 Harness 侧不过度固定的方针 |
| Codex 0.123.0 | `/copy` after rollback copies the latest visible assistant response | rollback 后复制内容符合直觉 | C | TUI UX | 53.2.5 中记录为自动继承 bug fix。不追加 workaround |
| Codex 0.123.0 | Follow-up text submitted during manual shell commands is queued | manual shell 中输入下一条时不容易发生 `Working` 卡住 | C | long-running UX | 53.2.5 中记录为对长时间工作 UX 有效的自动继承 |
| Codex 0.123.0 | Unicode / dead-key input fixed in VS Code WSL terminals | WSL terminal 中日文·符号输入不容易损坏 | C | terminal input | 53.2.5 中记录为自动继承 |
| Codex 0.123.0 | Stale proxy env vars are not restored from shell snapshots | 不容易因旧 proxy 设置导致通信损坏 | C | session shell snapshots | 53.2.5 中记录为自动继承 |
| Codex 0.123.0 | `codex exec` inherits root-level shared flags such as sandbox and model options | wrapper 侧可能不需要重复相同的 flag | A | codex exec wrapper / sandbox docs | 53.2.4 中确认重复 flag 削减可行性 |
| Codex 0.123.0 | Review prompts no longer leak into TUI transcripts | review 的内部 prompt 不容易泄露 | C | review privacy | 继承 Codex 本体修正 |
| Codex 0.123.0 | Code Review skill instructions tightened | Codex-driven review 的指示更严格 | C | review skill | Harness reviewer 是独立 surface。必要的话在 Phase 53.3.1 中整理重复 |
| Codex 0.123.0 | App-server protocol docs updated for threadless MCP resource reads and namespaced dynamic tools | MCP resource read / dynamic tool 的说明增加 | P | future MCP / app-server docs | 超出 53.2.2 scope 时有需要再处理。不做超出 release body 的推测实现 |
| Codex 0.123.0 | Dependency alerts fixed, Rust dev debug-info reduced, Python app-server SDK types refreshed | 配布物和开发体验更稳定 | C | dependency / build runtime | Harness 侧无直接变更 |

## 53.1.2 MCP tool hook decision

对象 hook 的用途：

- 限定于将来读取专用的 MCP health / resource list 诊断。
- 例如，不增加 shell script 即可直接从 hook 确认 MCP server 的连通状态、公开 resources 列表、resource template 有无等。
- 不在范围内：改写外部状态的 audit log、checkpoint 记录、issue 创建、database 更新、文件写入。

本次判断：

- `hooks/hooks.json` / `.claude-plugin/hooks.json` 本次为 no-op 不变更。
- 理由：2026-04-23 时点官方 changelog 告知了 `type: "mcp_tool"`，但 Hooks reference 的 hook handler field 表仍以 `command` / `http` / `prompt` / `agent` 为主，`mcp_tool` 的必需 field 名和输入展开约定无法作为稳定规格读取。
- 另一理由：分发 plugin 的 hooks 在所有已启用环境中被读取，由于尚不能前提"总是存在读取专用 MCP diagnostic tool"，在 manifest 中直接放入环境依赖的 MCP tool 可能增加未设置环境中的 hook error。

安全条件：

- 不从 hook 调用写入系 MCP tool。
- 即使将来在 manifest 中加入 `type: "mcp_tool"`，tool 名也限定为 `health` / `list` / `read` / `get` / `status` / `diagnostic` / `resource` 等可识别为读取诊断的内容。
- 包含 `write` / `create` / `update` / `delete` / `remove` / `record` / `mutate` / `set` / `insert` / `upsert` / `patch` 的 tool 名不从 hook 调用。
- 本方针在 `tests/test-claude-upstream-integration.sh` 中固定。现时点检测 no-op，将来若追加 `mcp_tool` hook 则 jq check 其为读取专用名称。

## 53.1.3 plugin tag release flow decision

对象：

- Claude Code `2.1.118` 的 `claude plugin tag`
- `harness-release` 的 release flow

本次判断：

- 在 `skills/harness-release/SKILL.md` 中追加 Claude plugin project 用的 tag preflight。
- 有 `.claude-plugin/plugin.json` 的 project 中，version 不一致则不进行 tag。
- Pre-Gate 和 `--dry-run` 中执行 `claude plugin tag .claude-plugin --dry-run`，使即将生成的 plugin tag 名和内部 tag / push 相当命令可见化。
- Post-Gate 中在 release commit 后再次确认 version sync，用 `claude plugin tag .claude-plugin --push --remote origin` 创建 `{plugin-name}--v{version}` tag。
- 现有 GitHub Release automation 以 `vX.Y.Z` tag 为前提的 project 中，与 plugin tag 分开创建 semver tag。plugin 分发 tag 委托 `claude plugin tag`，不单独依赖手动 `git tag`。

安全条件：

- `claude plugin validate .claude-plugin/plugin.json` 失败时不打 tag。
- `VERSION` 和 `.claude-plugin/plugin.json` 不一致时不打 tag。
- `--dry-run` 不打 tag，用于在 release plan 中显示执行命令。
- 本 guidance 在 `tests/test-claude-upstream-integration.sh` 中 grep 固定。

## 53.1.4 Auto Mode "$defaults" permission and sandbox policy

对象：

- Claude Code `2.1.118` 的 Auto Mode `autoMode.allow` / `autoMode.soft_deny` / `autoMode.environment`
- Harness 的 `.claude-plugin/settings.json`
- Project-level template: `templates/claude/settings.security.json.template`

本次判断：

- Auto Mode built-in defaults stay in place through "$defaults"。
- Harness 不替换 Claude Code 内置的 Auto Mode default。
- Project / enterprise 侧仅在追加 `autoMode.allow` / `autoMode.soft_deny` / `autoMode.environment` 时，在各数组中加入 `"$defaults"`，其后追加 project-specific / organization-specific entry。
- 本 task 不向分发的 plugin 的 `.claude-plugin/settings.json` 中追加 `autoMode` object。理由：内置 default 的内容和更新责任应由 Claude Code 本体持有，Harness 若配空替换设置会容易与 upstream default 产生偏差。
- Project-level template 只放追加 `autoMode` 时的注意事项。实际追加 entry 因项目而异，Harness 不推测固定。

追加时的形式：

```json
{
  "autoMode": {
    "allow": ["$defaults", "<project-specific allow entry>"],
    "soft_deny": ["$defaults", "<project-specific soft deny entry>"],
    "environment": ["$defaults", "<project-specific environment entry>"]
  }
}
```

安全条件：

- 不削减 `"$defaults"`。
- 不将 `"$defaults"` 展开为"Harness 认为的 default 列表"重写。
- 维持现有的 `permissions.deny` / `permissions.ask` / `sandbox.failIfUnavailable` / `sandbox.network.deniedDomains` / `sandbox.filesystem`。
- 追加 Auto Mode entry 也不作为缓和高 deny / ask / sandbox 的理由。

R05 guardrail and sandbox.network.deniedDomains are not duplicated by Auto Mode:

- R05 是 Go guardrail 侧的危硂操作检测，检测命令字符串中的 `sudo` wrapper、`find -delete` / `find -exec rm ...`、macOS 危险删除路径等。Auto Mode 是自动批准的分类层，与 R05 这类 Harness 固有的第二层 guard 责任不同。
- `sandbox.network.deniedDomains` 在 sandbox 的 network 边界处阻止到达 metadata endpoint。Auto Mode 的 `environment` guidance 是"在什么环境条件下更容易自动化"的分类，不是 network deny list 的替代品。
- `permissions.deny` / `permissions.ask` 作为明确的拒绝·确认规则保留。通过叠加 Claude Code 侧的 deny precedence 和 Harness 的 guardrail，即使 Auto Mode default 更新也不放松破坏性操作和敏感读取的防御。

验证：

- 在 `tests/test-claude-upstream-integration.sh` 中固定本 section、template note、`.claude-plugin/settings.json` 的现有 deny / ask / deniedDomains 维持。
- 将来在 `.claude-plugin/settings.json` 中追加 `autoMode` 时，同 test 的 jq check 要求 `allow` / `soft_deny` / `environment` 的各 entry 包含 `"$defaults"`。

## 53.1.5 plugin / managed settings policy

对象：

- Claude Code `2.1.118` 的 plugin `themes/` directory
- `DISABLE_UPDATES` 和现有 `DISABLE_AUTOUPDATER`
- Claude Code `2.1.117` 的 `blockedMarketplaces` / `strictKnownMarketplaces`
- plugin dependency auto-resolve / missing dependency hints
- Windows / WSL managed settings 继承 (`wslInheritsWindowsSettings`)

本次判断：

- 新建 `docs/plugin-managed-settings-policy.md` 作为 setup / plugin policy docs 的正本。
- 从 `skills/harness-setup/SKILL.md` 追加到同 docs 的 pointer，使 setup 时 marketplace policy 和 dependency policy 不容易混淆。
- 区分 `DISABLE_AUTOUPDATER` 停止自动更新、`DISABLE_UPDATES` 是连手动 `claude update` 也停止的企业管理用强停止。
- `blockedMarketplaces` / `strictKnownMarketplaces` 作为 managed settings 专用管理环境 policy 对待，不对普通用户 default 过度适用。
- 通常 team onboarding 优先 `extraKnownMarketplaces`，只有需要严格 allowlist 的企业才在 managed settings 中使用 `strictKnownMarketplaces`。
- plugin dependency auto-resolve 和 missing dependency hints 委托 Claude Code 本体。不追加 Harness 独自 dependency resolver、cache 直接编辑、marketplace policy 绕过。
- plugin `themes/` directory 本次留为 `P`。Harness 是运维安全性的 plugin，theme 同配需要 brand / accessibility / terminal compatibility 的另外审查，不做推测实现。
- `wslInheritsWindowsSettings` 作为 Windows / WSL 混在企业环境的管理 settings 候选记录，不放入 Harness default。

安全条件：

- 不在 `.claude-plugin/settings.json` 中追加 `DISABLE_UPDATES`、`blockedMarketplaces`、`strictKnownMarketplaces` 为 default。
- 信任 managed settings 的最上位 precedence 和 Claude Code 本体的 install / update / refresh / auto-update enforcement。
- Harness 只停留在说明·release guidance·验证 grep，不重新实现信任边界本身。
- 本 guidance 在 `tests/test-claude-upstream-integration.sh` 中固定 policy docs 的存在、`DISABLE_UPDATES` / marketplace policy / dependency resolver / themes decision 的记述、Feature Table 的完成标记。

## 53.1.6 Claude Code UX automatic inheritance policy

对象：

- Claude Code `2.1.118` 的 `/cost` / `/stats` 到 `/usage` 的整合
- Claude Code `2.1.118` 的 `/continue` / `/resume` 发现通过 `/add-dir` 添加的 current directory 的 session 的改进
- Claude Code `2.1.117` 的 main-thread `--agent` + agent frontmatter `mcpServers` 读取
- Claude Code `2.1.117` 的 `CLAUDE_CODE_FORK_SUBAGENT=1` external build flag
- Claude Code `2.1.117` 的 stale large session summary、native `bfs` / `ugrep` search、高 effort default

本次判断：

- 将 `/usage` 作为利用量·成本·统计的 primary entrypoint。
- 将 `/cost` / `/stats` 作为 legacy typing shortcut 对待。在旧 docs 中说明成本确认和统计确认入口时，先引导到 `/usage`，将 `/cost` / `/stats` 作为打开所需 tab 的 shortcut 补充。
- `/resume` 发现 `/add-dir` session 的改进和 stale large session summary 继承 Claude Code 本体的 session discovery / summary logic。Harness 不追加 duplicate resume index、独自 stale-session summarizer、transcript 重读 wrapper。
- `--agent` + `mcpServers` 留作 agents audit 的后续候选。由于 main-thread agent 中 MCP 前提的 agent frontmatter 如何被读取需要盘点现有 agent definitions 和 MCP setup guidance，本次作为 `P` 记录。
- 不在 Harness default 中强制 `CLAUDE_CODE_FORK_SUBAGENT=1`。作为 upstream flag 用于在 external build 中验证 forked subagent，不放入分发 plugin 的 settings / skill default / environment template。
- 不追加 native `bfs` / `ugrep` search 的 wrapper。搜索的高速化是 Claude Code native macOS / Linux build 通过 Bash 提供的领域，Harness 若叠加别样 search shim 会增加 path 解决、glob 差异、fallback 差异。
- 高 effort default 作为 Claude Code 本体的 model/account policy 自动继承。Harness 的 `harness-work` effort scoring 作为对复杂 task 追加 `ultrathink` 或 `high` 的局部 policy，不以固定值覆盖 Pro / Max subscriber 的内置 default。

不追加 Harness wrapper 的理由：

- 这些是 UI command routing、session discovery、agent frontmatter loading、native search、model/account default 等 Claude Code 本体在 runtime 中判断的领域。
- Harness 若将相同判断作为 wrapper 重新实现，会在 upstream 侧修正后仍然保持旧行为，或与用户的 managed settings / account policy / platform-specific build 冲突。
- Harness 的责任是：将旧说明更新为以 `/usage` 为中心，将 `C` 记录为自动继承，将需要 agent audit 的 `--agent` + `mcpServers` 和 external build flag 作为 `P` 留作后续候选。

验证：

- 在 `tests/test-claude-upstream-integration.sh` 中固定本 section、`/usage` primary entrypoint、legacy shortcut 的处理、`--agent` + `mcpServers` follow-up、external build flag 不作为 default 的方针、native search / high effort default 的自动继承、Feature Table 的 `C/P` 标记。

## 53.2.1 Codex provider and model metadata setup policy

对象：

- Codex `0.123.0` 的内置 `amazon-bedrock` model provider
- `model_providers.amazon-bedrock.aws.profile`
- Codex `0.123.0` 的 bundled model metadata refresh 和 current `gpt-5.4` default
- 旧的固定 model slug 的 setup guidance 残留
- 与 Claude Code 侧 Bedrock guidance 的区分

本次判断：

- 新建 `docs/codex-provider-setup-policy.md` 作为 Codex provider / model metadata setup guidance 的正本。
- 只有使用 Bedrock 的 user / project 才在自己的 Codex config 中追加 `model_provider = "amazon-bedrock"` 和 `[model_providers.amazon-bedrock.aws] profile = "codex-bedrock"`。
- Harness 的分发用 `codex/.codex/config.toml` 中只放 `amazon-bedrock` 的说明 comment。不设置实际的 `model_provider` default。
- Harness 不写入 AWS credential、temporary token、secret key、Bedrock endpoint override。
- `gpt-5.4` 作为 Codex `0.123.0` 的 current bundled model metadata 对待。Harness setup 不将 `model = "gpt-5.4"` 固定为 default。
- 删除 `scripts/check-codex.sh` 中旧的 `gpt-5.2-codex` 推荐 sample，改为说明"通常委托 Codex CLI 的 current default metadata"。
- Claude Code 侧的 Bedrock guidance 保留为 `CLAUDE_CODE_USE_BEDROCK`、`ANTHROPIC_DEFAULT_*`、`modelOverrides` 的领域。不与 Codex 的 `model_provider = "amazon-bedrock"` 混淆。

Bedrock config example:

```toml
model_provider = "amazon-bedrock"

[model_providers.amazon-bedrock.aws]
profile = "codex-bedrock"
```

旧固定 model slug 的检查：

```bash
rg -n "gpt-5\.2-codex|gpt-5-codex|gpt-5\.1|codex-mini|gpt-5\.3-codex|gpt-5\.4" \
  docs skills codex skills-codex scripts tests templates .claude-plugin opencode .agents -u
```

结果的处理：

- `scripts/check-codex.sh` 的 `gpt-5.2-codex` sample 因是旧 setup guidance 而删除。
- `scripts/codex-loop.sh`、`scripts/config-utils.sh`、advisor contract tests 的 `gpt-5.4` 是 Advisor Strategy 的 model policy / fixture，不是 Codex setup default，本次维持。
- `docs/CLAUDE-feature-table.md` 的过去 version 说明中的 Bedrock / model 名作为历史说明保留。
- 新规 setup docs / skill / Codex README 中不作为推荐值追加旧的 model slug。

验证：

- 在 `tests/test-claude-upstream-integration.sh` 中 grep 固定 provider policy docs、`harness-setup` pointer、Codex README / config note、旧 `gpt-5.2-codex` sample 删除、Feature Table 的 53.2.1 完成标记。

## 53.2.2 Codex MCP diagnostics and plugin loading policy

对象：

- Codex `0.123.0` 的 `/mcp verbose`
- Codex `0.123.0` 的 plugin `.mcp.json` loading
- plugin `.mcp.json` 的 `mcpServers` 形式
- plugin `.mcp.json` 的 top-level server map 形式

本次判断：

- 新建 `docs/codex-mcp-diagnostics.md` 作为 Codex MCP diagnostics / plugin MCP loading guidance 的正本。
- 通常的 Codex TUI 中将 `/mcp` 作为轻量级 server 状态确认使用。
- 只在 MCP server 不可见、启动错误不明、想确认 resources / resource templates 有无时使用 `/mcp verbose`。
- 将 `/mcp verbose` 作为查看 diagnostics、resources、resource templates 的 troubleshoot 入口引导。
- plugin 内 `.mcp.json` 更新为可以接收 `mcpServers` 形式和 top-level server map 形式两者。
- 新规 plugin 中优先使用与其他 tool 共享更容易的 `mcpServers` 形式。
- 现有 plugin 若使用 top-level server map 形式，则利用 Codex 侧的 loading 改进，不要求不必要的迁移。

`.mcp.json` examples:

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

```json
{
  "docs": {
    "command": "node",
    "args": ["server.js"]
  }
}
```

不与 Claude Code 侧 MCP guidance 混淆的理由：

- Codex TUI 的 `/mcp` / `/mcp verbose` 是 Codex runtime 的诊断入口。
- Codex plugin `.mcp.json` loading 是 Codex plugin 侧的读取改进。
- Claude Code 侧的 `claude mcp ...`、`.claude/mcp.json`、hook `type: "mcp_tool"` 是不同 surface。
- 53.1.2 的 `type: "mcp_tool"` hook safety decision 是 Claude Code hooks 的话，与 53.2.2 的 Codex `/mcp verbose` guidance 分担责任。

验证：

- 在 `tests/test-claude-upstream-integration.sh` 中 grep 固定 `docs/codex-mcp-diagnostics.md`、`harness-setup` pointer、Codex README guidance、`/mcp verbose`、diagnostics / resources / resource templates、`mcpServers` 形式、top-level server map 形式、不与 Claude Code 侧 MCP guidance 混淆的方针、Feature Table 的 53.2.2 完成标记。
- 在 `tests/test-codex-package.sh` 中检测 Codex README 的 `/mcp verbose` 和 `.mcp.json` loading guidance。

## 53.2.3 Codex realtime handoff silence policy

对象：

- Codex `0.123.0` 的 realtime handoff
- background agents 收到的 transcript delta
- `harness-loop` 的 background runner
- `breezing` 的 Worker / Advisor / Reviewer
- advisor / reviewer drift 检测

本次判断：

- 将 Codex `0.123.0` 的 realtime handoff 改进作为 `A: docs / guidance 化済み` 纳入。
- background agent 可以接收 transcript delta 这件事，不作为增加途中通知的理由，而是作为"只在需要时更新判断"的前提对待。
- 在 `skills-codex/harness-loop/SKILL.md` 和 Codex mirror `codex/.codex/skills/harness-loop/SKILL.md` 中追加 `Realtime Handoff / Silence Policy`。
- 在 `skills-codex/breezing/SKILL.md` 和 Codex mirror `codex/.codex/skills/breezing/SKILL.md` 中追加 Worker / Advisor / Reviewer 的 silence policy。
- 在共享的 `skills/breezing/SKILL.md` 和 `skills/harness-loop/SKILL.md` 中，作为长时间执行的通知整理反映同样的想法。
- 在 `scripts/codex-loop.sh` 生成的 1-cycle prompt 中追加"不因 transcript delta 多余地输出中间报告"的指示。

silence policy：

- 报告的是 cycle / task 完成、blocked、validation failure、review `REQUEST_CHANGES`、advisor `STOP`、plateau、contract readiness failure、user 明确要求 status 时。
- `advisor-request.v1` 无响应、`review-result.v1` 未到达、review loop plateau 等 advisor / reviewer drift 不作为 silence 对象。
- 仅因收到 transcript delta 而 task status、review verdict、advisor decision 未变化时明确沉默。
- tool stdout 的细微增量寄予 log / status 侧。
- default 是 `harness-loop` 中"每 cycle 最终报告 1 次"、`breezing` 中"每 task 完成 progress feed 1 次"。

不与 advisor / reviewer drift 矛盾的理由：

- silence policy 是"减少不必要通知"的方针，不削弱品质判定或停止条件。
- Advisor 保持作为 `PLAN` / `CORRECTION` / `STOP` 的咨询角色、Reviewer 保持作为 `APPROVE` / `REQUEST_CHANGES` 的品质判定角色分离。
- drift 作为 `.claude/state/session.events.jsonl` / contract / review artifact 的缺失对待，作为与对话沉默不同的异常检测。

验证：

- 在 `tests/test-claude-upstream-integration.sh` 中 grep 固定 snapshot、Codex harness-loop / breezing、共享 harness-loop / breezing、`scripts/codex-loop.sh` 中的 silence policy 和 drift 例外。
- 在 `tests/test-codex-package.sh` 中检测 Codex README 和 Codex skill mirror 中有 realtime handoff / silence policy。
- 用 `./scripts/sync-skill-mirrors.sh --check` 确认 `skills-codex` 和 Codex mirror 无 drift。

## 53.2.4 Codex sandbox / execution policy

对象：

- Codex `0.123.0` 的 host-specific `remote_sandbox_config`
- `requirements.toml` 的 `allowed_sandbox_modes`
- `codex exec` 的 root-level shared flags 继承
- `scripts/codex-companion.sh`
- `scripts/codex/codex-exec-wrapper.sh`

本次判断：

- 新建 `docs/codex-sandbox-execution-policy.md` 作为 Codex sandbox / execution policy 的正本。
- 将 `remote_sandbox_config` 作为不是 user / project `config.toml` 而是管理员约束的 `requirements.toml` 的 host-specific policy 引导。
- 放置 remote devbox / ephemeral CI runner / shared host / unknown host 的比较表，整理 host class 各自的 `allowed_sandbox_modes`。
- host matching 作为 FQDN 优先、kernel hostname fallback 的 best-effort classification 对待。不是强设备认证，因此 persistent host 不使用 broad wildcard。
- 各 requirements source 在 merge 前应用第一个匹配的 `remote_sandbox_config`，维持 source precedence。不以低优先 source 的 host rule 可以削弱高优先 source 的 `allowed_sandbox_modes` 为前提。
- Codex `0.123.0` 以后因 `codex exec` 继承 root-level shared flags，Harness wrapper 侧不重复传输相同的 sandbox / model / approval policy。
- 53.2.4 中不改变 runtime wrapper behavior。

wrapper flag 削减可行性：

| Wrapper | 确认结果 | 判断 |
|---------|----------|------|
| `scripts/codex-companion.sh` structured task mode | 将 `task --write` 变换为 `--sandbox workspace-write`，在有显式 `--sandbox` / `-s` / `--full-auto` / bypass flag 时保存 caller intent | 维持。这是 root shared flags 的重复传输，不是 Harness workflow intent 的 exec-local 变换 |
| `scripts/codex/codex-exec-wrapper.sh` | 用 `codex exec - --full-auto` 的单一 policy 执行 hardening prompt，没有另行叠加 `--approval-policy` / `--sandbox` pair | 维持。`--full-auto` 的变更会改变 approval / sandbox behavior，因此需要独立 task 和 focused regression test |
| docs / setup guidance | 不需要在旧 docs 中增加 `--approval-policy` / `--sandbox` 双重指定 | docs 中明确"One call, one source of truth" |

automatic inheritance 保留的项目：

- `codex exec` 继承 root-level shared flags 的行为本身作为 Codex 本体的 fix 自动继承。
- Harness 不重新实现该 fix。
- Harness 所做的是不增加重复 flag 的 guidance、使现有 wrapper 的意图明确化、整理 remote sandbox policy 的放置位置。

验证：

- 在 `tests/test-claude-upstream-integration.sh` 中 grep 固定 policy docs、snapshot section、Feature Table 完成标记、CHANGELOG、harness-setup pointer、wrapper comments。
- 在 `tests/test-codex-package.sh` 中检测 Codex README 中有 sandbox / exec policy 和 `remote_sandbox_config` guidance。
- 用 `bash -n scripts/codex-companion.sh scripts/codex/codex-exec-wrapper.sh` 确认 wrapper comment 追加后的 shell 语法。

## 53.2.5 Codex automatic bug fix inheritance policy

对象：

- Codex `0.123.0` 的 `/copy` after rollback
- manual shell follow-up queue
- Unicode / dead-key input
- stale proxy env
- VS Code WSL keyboard
- review prompt leak

本次判断：

- 将 Codex `0.123.0` 的 `/copy` after rollback、manual shell follow-up queue、Unicode / dead-key input、stale proxy env、VS Code WSL keyboard 作为 `C: 自動継承` 对待。
- `/copy` after rollback 是正确复制 TUI 显示中 assistant message 的修正，Harness 不直接管理 clipboard / rollback state。
- manual shell follow-up queue 是修正"在 manual shell 中发送下一输入时的 Codex TUI queueing"，不是 `harness-loop` 或 `codex-loop` 叠加独自 queue 的领域。
- Unicode / dead-key input 和 VS Code WSL keyboard 是 terminal input layer 的修正，Harness skill / wrapper 若转换 key event 则更危险。
- stale proxy env 是修正"不从 shell snapshot 恢复旧 proxy environment"，Harness session docs 只记录"信任本体行为，不追加 proxy scrubber"方针。
- review prompt leak 是 Codex review runtime 的 transcript hygiene 修正，与 Harness reviewer surface 独立接收本体修正。

不直接实现的理由：

- 不直接实现的理由是继承本体修正。
- 这些是 clipboard、TUI queue、terminal input、shell snapshot restore、review transcript 的 runtime bug fix，与 Harness 的 Plan / Work / Review orchestration policy 责任不同。
- 不追加 Harness workaround、copy wrapper、manual shell queue shim、proxy snapshot scrubber。
- 追加勉强的 wrapper 会导致即使 Codex 本体修正后仍然在 Harness 侧保留旧行为和 platform-specific 例外。

Harness docs 反映的范围：

- 在 `skills/harness-loop/SKILL.md` 中只记录 manual shell follow-up queue 和 `/copy` rollback 作为长时间工作 UX 自动继承，loop runner 不拥有追加输入 queue。
- 在 `skills/session/SKILL.md` 中简短记录 stale proxy env、Unicode / dead-key、VS Code WSL keyboard 作为 session shell / terminal input 的自动继承。
- Feature Table 和 CHANGELOG 只作为入口，判断依据集中在本 snapshot section。

验证：

- 在 `tests/test-claude-upstream-integration.sh` 中 grep 固定本 section、`C: 自動継承` 判定、不直接实现的理由、不追加 workaround 的方针、Feature Table / CHANGELOG / long-running / session docs 的反映。

## 53.3.1 Phase 53 closeout / Phase 51.2 dependency note

Phase 53 的 A/C/P 反映在此关闭。

完成确认：

- Feature Table 作为 Phase 53 补充表格，已将 Claude Code `2.1.117-2.1.118` 和 Codex `0.123.0` 的各项目分类为 `A` / `C` / `P`。
- CHANGELOG `[Unreleased]` 已记录 Phase 53 的 user-facing change，从 snapshot、MCP hook safety、plugin tag、Auto Mode、managed settings、Codex provider / MCP / realtime / sandbox / bug-fix inheritance。
- `tests/test-claude-upstream-integration.sh` 已用 grep 固定 Phase 53 snapshot 和主要 guidance。
- `tests/validate-plugin.sh` 在 Phase 53 closeout 时点 PASS。现有 warning 仅 script executable bit 和 `IMPLEMENTATION_GUIDE.md` 推荐缺失。

与 Phase 51.2 的重复整理：

- Phase 53 是纳入 upstream `0.123.0` 具体差异的周期，不是 Codex-native skill audit 的整体清理。
- 53.2.3 的 realtime handoff silence 和 53.2.4 的 sandbox / exec policy 只处理了 `harness-loop` / `breezing` / `harness-setup` 的最小必要 guidance 和 mirror 同步。
- Phase 51.2.1-51.2.4 中残留的 Codex-native tool model、memory/session path drift、review / loop / release mirror path policy、media skill metadata 继续由 Phase 51.2 own。
- 今后若要广泛修复 mirror / path drift，在 Phase 51.2 侧处理，不与 Phase 53 的 upstream snapshot 追加混合。

## Harness judgement

53.1.1 中只停留于制作 snapshot，不预先提取后续 task 的实现。

确定为实现候选的项目：

- `type: "mcp_tool"` hook: 53.1.2 中作为 no-op + safety test 完成。manifest 追加必须在必备 field 规格和常设 read-only diagnostic tool 齐备后进行
- `claude plugin tag`: 53.1.3
- Auto Mode `"$defaults"`: 53.1.4
- plugin themes / managed settings / update controls / dependency auto-resolve docs: 53.1.5
- Claude Code UX 自动继承 / 将来候选整理: 53.1.6
- Codex Bedrock provider / model metadata: 53.2.1
- Codex `/mcp verbose` / `.mcp.json` loading: 53.2.2
- Codex realtime handoff silence policy: 53.2.3
- Codex `remote_sandbox_config` / `codex exec` shared flags: 53.2.4
- Codex automatic bug fix notes: 53.2.5

仅自动继承的理由：

- UI / TUI / keyboard / OAuth / file watcher / Remote Control / runtime stability fix 是 Claude Code 或 Codex 本体修复的领域，Harness 若叠加 wrapper 会容易产生行为差异和双重责任。
- `/resume`、`/fork`、subagent cwd restore、Codex follow-up queue 等对长时间工作有效，但首先接收本体行为更安全。Harness 侧只在后续 task 中更新必要的 docs/guidance。
- Codex `0.123.0` 的 app-server protocol / namespaced dynamic tools 只记录 release body 中有的范围，不做 compare 推测实现。

## Why `B: 書いただけ` is 0

本 snapshot 不使用 `B: 書いただけ` 作为分类。

- `A` 必须连接到 Phase 53 的具体 Plans task。不以写在 Feature Table 上结束。
- `C` 明记自动继承本体修正的理由和不在 Harness 侧追加 wrapper 的理由。
- `P` 明确"本次不实现"，避免推测实现。

因此，`CHANGELOG.md` 和 `docs/CLAUDE-feature-table.md` 是 snapshot 的入口，一次信息和判断依据的正本是本文档。
