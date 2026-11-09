# Codex Plugin Workflows Policy

最终更新: 2026-05-15

Codex plugin / workflow 联动和用 Harness 处理 Claude Code native `/goal` (2.1.139+) 时的运营方针。

## 一句话总结

Harness 的 SSOT 是 `Plans.md`。
Codex 端的 `/goal` 和 Claude Code native 的 `/goal` 都作为辅助输入处理，workflow state 不进行双重管理。

## 打个比方

`Plans.md` 是团队的白色写字板。
`/goal` 是当时的备忘录。
备忘录虽然方便，但如果与写字板不一致，就不知道该看哪个了。

## `/goal` 与 `Plans.md` (Codex `/goal` + CC native `/goal` 通用)

CC 2.1.139 添加了 Claude Code native `/goal`。Codex `/goal` 和 CC native `/goal` 都作为 **session continuation memo** 处理。Plans.md 保持作为唯一的 task SSOT。

| 项目 | 方针 |
|------|------|
| 长期任务管理 | 以 `Plans.md` 为正本 |
| Codex `/goal` | 作为当前 turn / current run 的辅助备忘录处理 |
| CC native `/goal` (2.1.139+) | 同上作为当前 turn / current run 的辅助备忘录处理 |
| task status | 优先使用 `Plans.md` 的 `cc:TODO` / `cc:WIP` / `cc:完了` |
| conflict | 读取 `Plans.md`，必要时更新 `/goal` 侧 |

禁止:

- 只在 `/goal` (Codex or CC) 中放置 acceptance criteria
- 在 `Plans.md` 和 `/goal` 中分别持有不同的 task list
- worker 不读 `Plans.md` 只靠 `/goal` 判断完成
- 将 CC native `/goal` 完成条件替换 Plans.md DoD

### CC native `/goal` 允许使用的情况

- 临时显示 "仅下一个 1 turn 集中关注的 sub-goal"
- 用 `--print` / `-p` 模式仅在 1 turn 内声明完成条件
- 通过 Remote Control 留下 operator 的 hand-off 备忘录

### CC native `/goal` 禁止的情况

- 在 `/goal` 侧将 Plans.md `cc:WIP` 的 task 改为 "完成"
- 在 `/goal` 中留下与 Plans.md 独立的 DoD
- 在 `/goal` 的 completion condition 与 Plans.md acceptance criteria 矛盾的状态下继续 turn

## Codex `0.130.0` stable workflow updates

Codex `0.130.0` stable (`rust-v0.130.0`, published `2026-05-08T23:09:55Z`) 增加的 workflow surface，在 Harness 中作为 "更便捷的观测/连接手段" 处理。
`Plans.md` 正本、primary environment write guard、hook opt-in 的边界不变动。

| 项目 | Codex `0.130.0` 的变更 | Harness 判断 |
|------|-------------------------|--------------|
| `codex remote-control` | headless remotely controllable app-server 的更简单的 top-level entrypoint | 作为明示启动的诊断/操作 surface 引导。分发 config 中 remote-control default 不设置 |
| App-server thread pagination | app-server clients can page large threads | 较长的 Breezing / loop transcript 分页阅读。不要假设 1 次就能读取全部 transcript |
| `view_image` selected environment resolution | multi-environment session 中可以通过 selected environment 解析 file | screenshot / artifact evidence 要附带 environment 和 workdir。不要将 non-primary environment 的 artifact 与 primary repo 的证据混淆 |
| Live app-server config refresh | live app-server threads 可以在不重启的情况下获取 config changes | 用于设置反映确认，但 Harness setup 不以 "无需重启" 作为秘密值更新或权限变更的轻率运营理由 |
| Turn diff accuracy | turn diffs 变得更加准确，包括 `apply_patch` partial failure | turn diff 作为 review 辅助使用。但最终判定用 `git diff`、tests、package checks 进行 |
| Plugin details bundled hooks | plugin details now show bundled hooks | 在 plugin install / share 前确认 bundled hooks。Harness bundled hooks 保持 opt-in 原则 |
| Plugin sharing metadata | plugin sharing exposes link metadata and discoverability controls | 将 link metadata 和 discoverability controls 作为公开范围的一部分。不要默认过于 discoverable |
| Configurable OTel trace metadata | configurable OpenTelemetry trace metadata | trace metadata 作为 debugging / triage 的辅助。不要放入 customer data 或 secret |
| Built-in MCPs as runtime servers | built-in MCPs first-class runtime servers | 不要混淆 built-in MCP 和 plugin-provided MCP。在 report 中保留所有者和设置源 |
| `CODEX_HOME` environments TOML provider | 可以使用 `CODEX_HOME` 下的 environment provider | 明示 user-level environment 和 repo-local config 的优先顺序，write 固定为 primary environment |
| Skill root cleanup | remove skills list extra roots | 不要增加依赖多余 skills root 的 fallback。Harness 保持明示 mirror / path-based loading |

## Remote-control / app-server operations

`codex remote-control` 是使 headless app-server 更容易远程操作的入口。
Harness 中固定为以下处理方式。

- 启动由 user / operator 明示。在 `codex/.codex/config.toml` 中不设置 remote-control defaults。
- 确认 port、pid、auth boundary、selected environment、workdir 后再操作。
- app-server clients 处理 large threads 时使用 pagination，在 report 中保留需要的 page 和 timestamp。
- 即使 live app-server threads 可以拾取 config changes，secret、network、provider、hook policy 的变更也要作为 repo / user config 的 diff 保留。
- 即使发现 stale artifact，如果不是负责范围的 environment 不要擅自删除。

## Telemetry / MCP / environment setup surfaces

Codex `0.130.0` 还包括 configurable OpenTelemetry trace metadata、built-in MCPs first-class runtime servers、`CODEX_HOME` environments TOML provider。
Harness 将它们作为便捷的 setup surface 处理，但不模糊所有者边界。

- OpenTelemetry trace metadata 中不要放入 user / customer data、API key、provider credential、private URL。仅使用 debugging / triage 所需的 low-cardinality metadata。
- built-in MCPs 是 Codex runtime 的 owned surface。不要与 plugin-provided MCP 同名同责。
- `CODEX_HOME` environments TOML provider 作为 user-level environment source 处理。与 repo-local `.codex/config.toml` 或 managed requirements 冲突时，report 实际选择的 environment。
- remove skills list extra roots 使依赖隐式 extra root fallback 的运营变弱。Harness 明示使用 `scripts/setup-codex.sh` 的 user install 或 `[[skills.config]]` path-based loading 之一。
- write turn 继续为 one primary environment。即使 environment provider 增加，也不同时向多个 environment 写入。

## Plugin-bundled hooks

Codex `0.128.0` 的 plugin-bundled hooks 作为 opt-in 的 workflow extension 处理。
Codex `0.130.0` 中 plugin details 会显示 bundled hooks，因此作为 install / share 前确认项目的查看对象。

plugin 包含 hooks 时，默认不强烈改变 project 的行为。

CCH 的 Codex manifest 明示 inline 的空 hook object。这是为了防止 Codex fallback 到 plugin root 的 Claude 向け `hooks/hooks.json`，并警告未対応の agent / async handler。Codex 的 project hook 由 `harness gen hooks` 另行生成到 `.codex/hooks.json`，审计 metadata 不嵌入 vendor schema。

方针:

- hook 设为 opt-in
- 破坏性操作、push、deploy、外部发送默认禁用
- 用 `PostToolUse` 改写 output 时遵循 `docs/output-governance.md`
- hook 的 stdout 遵守 JSON contract
- 不要在 plugin details 显示的 bundled hooks 和实际分发的 hooks 之间留下差异

原因:

因为如果 plugin 装入后 hook 就擅自强力动作，user / project 的权限边界会变得模糊。

## Plugin sharing metadata and discoverability

Codex `0.130.0` 中 plugin sharing 会出现 link metadata 和 discoverability controls。
Harness 的 plugin 分发中，不仅共享 URL 本身，还要将 "被谁发现"、"以什么说明显示" 作为 release surface 处理。

方针:

- link metadata 格式要能了解 plugin 名、用途、危险的 hook / external-send 的有无。
- 明示选择 discoverability controls。不要将内部验证中的 plugin 设为公开 discoverable。
- 贴 shared link 时并列标注目标 version 和 install 后的 verification command。
- share 前在 plugin details 中确认 bundled hooks。

## External agent import ownership

import 外部 agent 时要明确所有者。

| 情况 | 所有者 | 方针 |
|--------|--------|------|
| Harness 分发的 agent | Harness | 在 repo 内接受 review / test / sync |
| user local agent | User | Harness 不覆盖 |
| third-party plugin agent | Third-party plugin | Harness 作为依赖对待，不 fork 内容 |
| copied external agent | Harness fork | 在 docs 中保留 fork 元、更改理由、更新责任 |

禁止:

- 默许将外部 agent 混入 Harness 分发物
- 在 setup 中覆盖 user local agent
- 不记录 fork 元的 policy / license / update path 就改写

## MultiAgentV2 and `agents.max_threads = 8`

`agents.max_threads = 8` 作为强并行执行的上限处理。
不意味着始终以 8 并行运行。

方针:

- default 根据 task size 和 risk 从较少量开始
- IO 型的调查可以增加并行度
- 操作相同文件的 worker 不要并行化
- write-heavy work 先固定 ownership file list
- 8 是上限。review / integration / final verification 回到串行

例:

| 工作 | 推荐 |
|------|------|
| docs grep / evidence collection | 4-8 threads |
| 独立的 docs 章节创建 | 2-4 threads |
| 修改相同的 TypeScript module | 1-2 threads |
| release / version sync | 1 thread |

## Sticky environments

Sticky environment 作为复用相同工作环境以降低 setup cost 的机制处理。
但存在残留旧 server / cache / artifact 的风险。

safe default:

- 维持 one primary environment per write turn
- remote / sticky environment 以 read-only first 确认，写入前明示 primary environment
- task 开始时确认 `git status --short`
- 确认 app server 的 port / pid / health
- 不将 env var 和 secret 输出到日志
- 即使发现 stale artifact，如果不是负责范围不要擅自删除

## App-server artifacts

app server 生成的 artifact 有助于 review / reproduction，但老化后会成为误判的原因。

方针:

- screenshot、trace、coverage、test output 要 report path 和生成时间。
- 以 artifact 为依据时也要保留再生成命令。
- cleanup stale artifact 时要明示目标 path。
- 不要在 artifact 中包含 production credential 或 customer data。

## Codex cloud / local boundary

Codex cloud task 在 sandboxed environment 中运行。
不要假设 Harness repo 内的 local `Plans.md` 和 cloud 侧的 task state 会自动同步。

因此:

- cloud task 的成果作为 PR / diff / report 接收
- Harness 的完成判定在 local repo 中通过 `git diff`、tests、`Plans.md` 确认
- 不要将 cloud artifact 直接作为 source of truth

## Sources

- OpenAI Codex docs: https://platform.openai.com/docs/codex
