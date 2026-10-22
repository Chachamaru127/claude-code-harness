# Grok Adapter 证据边界

> **晋升说明 (2026-07-19):** Grok 于 2026-07-19 晋升为 `supported`
> (2026-07-17 实时 H4 工作流冒烟测试 + H7 release-preflight fail-closed 门)。
> 下面的层级表述为历史证据；公开表面现固定为 `supported`，并附有 Claude-envelope PreToolUse floor 注意事项。

状态：internal-compatible 证据边界
检查时间：2026-07-09 JST
Phase: Grok host completion (目标计划)

## 结论

Grok 是**internal-compatible** Harness host。

Harness 有 Grok adapter 表面 (`.grok-plugin/`、`.grok/AGENTS.md`、
`scripts/setup-grok.sh`、host 分发构建、模型路由、静态冒烟测试)。
通过 `grok plugin install` + `grok inspect` 的包安装和 skill 发现已被观测到。
它**不**有 CI 门控的 Plan → Work → Review 工作流冒烟测试
或 Claude SessionStart / PreToolUse hook parity。不要声明公共 `supported`。

## 证据边界

`not_observed != absent`：缺少 Grok 工作流冒烟测试并不能证明 Grok
无法支持 Harness。这只能证明 Harness 不能过度声明支持。

在以下条件满足前，不要将 Grok 晋升为公共 `supported`：

- 主机特定 bootstrap 冒烟在 release preflight 中保持绿色，
- CI 门控工作流冒烟证明仅从 Grok 即可完成 Plan/Work/Review（或
  等效的 operator 接受的 bar），
- README/onboarding 措辞仍将安装发现与 Claude 层级的
  支持分开。

## 观测到的运行时证据 (2026-07-09)

Operator 本地 / CLI 观测 (Grok CLI `0.2.93`)：

| 观测项 | 证据 | 限制 |
|---|---|---|
| 插件 manifest 验证 | `grok plugin validate` 接受 `.grok-plugin/plugin.json` 包与 `skills: "./skills/"` | 仅形态 |
| 隔离 HOME 安装 | `HOME=<tmp> grok plugin install <dist> --trust` 写入 `~/.grok/installed-plugins/` + registry | 取决于 CLI |
| 其他项目中的 Skill 发现 | 从临时 cwd 的 `HOME=<tmp> grok inspect --json` 列出 `harness-plan`、`harness-work`、`harness-review`、`breezing`，`source.type=plugin` | 单环境证明 |
| 模型 ID | 实际安装在 `grok 0.2.118` 上的账户目录 (2026-08-13 实测)：**仅 `grok-4.6`（默认）和 `grok-4.5` 两个** | 务必阅读下面的"目录更正" |

> **更正 (2026-08-12):** 此前此表中列出的两个模型 ID 实际上不存在于真实目录中
> (其中一个似乎是 cursor 侧 composer 的混淆)。将不存在的 ID 保留在表中会导致
> `tests/test-model-routing.sh` 的 docs↔SSOT 门控失败，缘由见本注记。

## Harness 证据（本仓库）

| 产物 | 证明内容 | 未证明内容 |
|---|---|---|
| `.grok-plugin/plugin.json` | 插件 manifest 指向核心 `skills/` | Marketplace 发布或每个账户安装 |
| `.grok/AGENTS.md` | Plan/work/review 的 bootstrap 路由指导 | 自动运行时路由 |
| `scripts/setup-grok.sh` | 隔离构建/检查 + 安装入口点 | 作为 CI 证明的实时 operator HOME 安装 |
| `scripts/build-host-plugin-dist.sh --host grok` | 包本地 `./skills/` 路径（无 `..`） | 主机运行时超出包形态 |
| `scripts/model-routing.sh --host grok` | 角色层级 → Grok 模型映射契约 | 账户特定模型可用性 |
| `tests/test-grok-adapter-candidate.sh` | 静态 adapter 契约 + 隔离 setup 冒烟 | 完整 Breezing 多任务证明 |

## 官方 Grok 表面（2026-07-09 观测）

已检查来源（本地用户指南 + CLI 帮助）：

- `~/.grok/docs/user-guide/08-skills.md` — skill 发现根目录
- `~/.grok/docs/user-guide/09-plugins.md` — 插件安装 / validate / inspect
- `~/.grok/docs/user-guide/12-project-rules.md` — AGENTS.md 项目规则
- `grok plugin validate|install|list|details`、`grok inspect --json`

观测到的 adapter 相关机制：

| 表面 | Harness 映射 | 备注 |
|---|---|---|
| 项目规则 / `AGENTS.md` | Bootstrap 通知 + prompt 路由 | 与 Codex/Cursor AGENTS 概念相同 |
| Skills | 通过插件 `skills/` 的核心工作流 skills | 当 `user-invocable: true` 时的 slash commands |
| Plugins | `.grok-plugin/plugin.json` + `skills/` | 用户安装在 `~/.grok/installed-plugins/` 下 |
| CLI `--model` | 显式覆盖表面 | 调用方设置时优先于路由默认值 |
| Hooks | 可选未来映射 | 未声称与 Claude PreToolUse parity |

## 验证命令

```bash
bash tests/test-grok-adapter-candidate.sh
bash scripts/setup-grok.sh --check
bash scripts/build-host-plugin-dist.sh --host grok --out /tmp/cch-grok-dist
bash scripts/model-routing.sh --host grok --role worker --format json
# Optional when CLI available:
grok plugin validate /tmp/cch-grok-dist
```

## Hooks 更正 (2026-08-13, Phase 133.2)

`hosts.toml` 的 `[grok]` 描述符此前引用"grok-cli v1.1.7
src/hooks/{types,config,executor}.ts" 作为项目级 hooks 被拒绝的证据。
那是另一个无关的 TypeScript 项目 — 而非本仓库集成的 CLI。
直接针对已安装 CLI (`grok 0.2.118`, "Grok Build TUI", Rust) 重新测量：

- `~/.grok/docs/user-guide/10-hooks.md`（捆绑 CLI 文档）将项目
  hooks 记录为支持：`<project>/.grok/hooks/*.json`、
  `<project>/.claude/settings.json` (Claude 兼容)，以及捆绑在已安装
  插件内的 hooks 全部合并，由一次性文件夹信任授予门控。这与"故意拒绝"相反。
- 对本仓库的 `grok inspect --json` 显示 `externalCompat.cells` 具有
  `{vendor:"claude", surface:"hooks", enabled:true, source:"default"}`，
  其 `hooks[]` 数组显示 claude-compat 加载器为其他四个真实 Claude Code 插件
  (codex, security-guidance, vercel, agentforce-adlc) 积极触发，
  这些插件仅安装在 `~/.claude/plugins/` 下。
- `bin/harness hook pre-tool --host grok`，用 Claude 形态 payload 直接探测，
  以与 `--host claude` 产生的字节相同的信封拒绝 `git push --force`（退出码 2）。
  策略引擎侧对 grok 已经正确。
- 差距在打包，而非 CLI 策略：本仓库构建的 grok 分发
  (`scripts/build-host-plugin-dist.sh` `build_grok()`) 从未将 `hooks/` 目录复制到
  包中，因此 `grok inspect` 正确报告已安装的 `claude-code-harness` 插件的
  `hooks: false`。因此原生 hook parity 是一个有范围的后续事项
  (在 grok 分发中发运 `hooks/hooks.json` + `go/internal/hostgen/hostgen.go` 中的
  `grokDoc()` case + 翻转 `hook_generation`)，而非被阻止的路径。

完整证据和引用：`hosts.toml` `[grok]` 注释块。

## 禁止措辞

| 允许 | 禁止 |
|---|---|
| internal-compatible Grok adapter | 此 host 的公共顶级产品声明 |
| setup-grok install / package 冒烟 | Claude SessionStart parity |
| 通过 inspect 发现 skill | PreToolUse deny parity |
| 模型路由 host `grok` | Breezing 多任务公共支持声明 |

## 目录更正 (2026-08-13)

本文档在 2026-08-12 之前从 `/Users/tachibanashuuta/LocalWork/Code/grok-cli`
的 `src/grok/models.ts` 读取并记录了 `grok` 的模型目录。**那是同名但不同的产品。**

- 记录的内容 (TypeScript 版 `grok-cli` v1.1.7)：flagship 1 种 + 2M ctx 系列 3 种 + budget 1 种
- 实际运行的 CLI (`grok 0.2.118`, "Grok Build TUI", Rust)：**仅 2 种**。`grok-4.6` (默认 / 500k ctx / effort 为 xhigh・high・medium・low) 和 `grok-4.5` (500k ctx / effort 为 high・medium・low)

也就是说 `scripts/model-routing.sh` 中的 5 个 pin **没有一个存在**，在开始向 grok 委托的瞬间所有层级都会失败。更早一代的 pin (`grok-composer-2.5-fast`) 同样是不存在的 ID，这似乎是 cursor 的 `composer-2.5-fast` 的混淆。

讽刺的是，2 代前的 `grok-4.5` **确实存在过**。当时的注释是 `observed 2026-07-09 on CLI 0.2.93` — 也就是在真实二进制上的观测。通过阅读 source tree 进行"更正"，实际上是把正确的值替换成了错误的值。

本文档的 Model IDs 行一开始就注明了 `Account catalog may differ`。完全准确。

**教训**：capability 和目录都要用**实际运行的 binary** 来确认 (CLAUDE.md FACT-4)。同名的 source tree 不能作为依据。同样的混淆也波及到了 hook capability 的描述 (Phase 133.2)。
