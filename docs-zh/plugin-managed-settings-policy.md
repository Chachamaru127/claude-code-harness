# Plugin and Managed Settings Policy

最终更新: 2026-05-03

本文档旨在把 Claude Code `2.1.117-2.1.126` 中新增的 plugin / managed settings / managed sandbox 周边的运用判断，固定为 Harness 的 setup guidance。

## 一句话总结

Harness 通过说明来支援 plugin marketplace 的安全运营，但不会取代 Claude Code 本体的 resolver 或 managed settings enforcement。

## 打个比方

这就像公司的入馆管理，Harness 是写着「把员工引导到哪个入口」的
指示牌。 实际检查入馆证的是闸机，而闸机就是 Claude Code
本体。 如果指示牌自己造一个闸机，规则就会重复，最后分不清哪个才对。

## 公式参照

- Claude Code changelog: <https://code.claude.com/docs/en/changelog>
- Claude Code settings: <https://code.claude.com/docs/en/settings>
- Claude Code plugin dependency versions: <https://code.claude.com/docs/en/plugin-dependencies>
- Claude Code plugin install guide: <https://code.claude.com/docs/en/discover-plugins>

## 对象与判断

| 項目 | 用途 | Harness 判断 |
|------|------|--------------|
| plugin `themes/` directory | 让 plugin 随附外观主题 | plugin `themes/` directory 这次是 P。Harness 是运用支援 plugin，因此现阶段不随附 theme |
| `DISABLE_AUTOUPDATER` | 停止自动更新 | 用于调整个人／团队的更新时机。不会阻止到 manual update 为止 |
| `DISABLE_UPDATES` | 停止所有更新路径 | 仅在管理环境使用。DISABLE_UPDATES 连手动的 `claude update` 也会阻止 |
| `blockedMarketplaces` | 屏蔽特定 marketplace source | managed settings 专用。不放入面向普通用户的 default |
| `strictKnownMarketplaces` | 只允许添加被许可的 marketplace source | managed settings 专用。不放入面向普通用户的 default |
| `extraKnownMarketplaces` | 引导・登记团队使用的 marketplace | 一般的 team onboarding 优先使用这一项 |
| plugin dependency auto-resolve / missing dependency hints | 依赖 plugin 的自动解析与错误提示 | 不添加 Harness 独自的 dependency resolver。交给 Claude Code 本体处理 |
| `wslInheritsWindowsSettings` | 将 Windows 侧的 managed settings 继承到 WSL | 面向 Windows / WSL 混合的企业环境候选。不放入 Harness default |
| `allowManagedDomainsOnly` / `allowManagedReadPathsOnly` | 把 managed sandbox 的允许边界收敛到管理员设置 | managed settings only。不放入 Harness 的通常 template / plugin default / harness.toml，也不覆盖 Claude Code 本体的 precedence |

## Update controls

`DISABLE_AUTOUPDATER` 是用于停止自动更新的环境变量。
在希望停止 Claude Code 本体和 plugin 自动更新时使用。

`DISABLE_UPDATES` 是更强力的管理用环境
变量。 它不仅停止自动更新，也停止手动的 `claude update`。
 这面向的是企业只分发已验证版本的环境。

| 目的 | 使用的东西 | 注意点 |
|------|----------|--------|
| 想避免个人被擅自更新 | `DISABLE_AUTOUPDATER=1` | 手动更新仍然保留 |
| IT 管理者想完全关闭更新路径 | `DISABLE_UPDATES=1` | 连手动 `claude update` 也会阻止，因此需另行准备分发・更新流程 |
| 想只停止 Claude Code 本体更新、保留 plugin 自动更新 | `DISABLE_AUTOUPDATER=1` + `FORCE_AUTOUPDATE_PLUGINS=1` | 请先确认 plugin 侧的依赖 constraint 和 marketplace policy |

Harness 的方针：

- 不把 `DISABLE_UPDATES` 作为默认值放入 `.claude-plugin/settings.json` 或 project template。
- 在企业分发中，作为 managed settings 或终端管理的环境变量来设置。
- 即使停止 update，也维持 `harness-release` 的 version sync / semver tag / validate flow。

## Marketplace policy

`blockedMarketplaces` 和 `strictKnownMarketplaces` 是供管理员控制 marketplace
source 的 managed settings。 不应放入普通用户或 open-source project 的 default。

| 设置 | 做什么 | 适用场景 |
|------|------------|----------------|
| `blockedMarketplaces` | 屏蔽指定的 marketplace source | 想明确阻止危险・不推荐的 marketplace |
| `strictKnownMarketplaces` | 只允许添加许可列表中的 marketplace source | 想让企业只使用经过 vetted 的 marketplace |
| `extraKnownMarketplaces` | 引导・登记 marketplace | 想为团队分发推荐的 marketplace |

`strictKnownMarketplaces` 是 policy gate。 它只决定是否允许，不会自
动登记 marketplace。 如果还想让所有人都登记，可在 managed settings 中组合
`strictKnownMarketplaces` 和 `extraKnownMarketplaces`。

示例：

```json
{
  "strictKnownMarketplaces": [
    { "source": "github", "repo": "acme-corp/approved-plugins" }
  ],
  "extraKnownMarketplaces": {
    "acme-tools": {
      "source": {
        "source": "github",
        "repo": "acme-corp/approved-plugins"
      }
    }
  }
}
```

Harness 的方针：

- 不把 `blockedMarketplaces` / `strictKnownMarketplaces` 放入面向普通用户的 default。
- Harness 的 setup 在团队 onboarding 中引导使用 `extraKnownMarketplaces`。
- 在企业管理环境中，交给 managed settings 的最高 precedence。
- 不实现 Harness 独自的 marketplace allowlist / blocklist evaluator。

## Dependency resolution

Claude Code 会读取 plugin 的 `dependencies`，并在安装时自动解析依赖 plugin。 若依赖在事后缺失，也可通过 `/reload-plugins`、后台 plugin
auto-update、重新执行 `claude plugin install`，或 `claude plugin marketplace add` 从已登记的 marketplace 中解析。

如果依赖关系无法解析，正确的入口是查看 Claude Code 侧的 plugin UI、`/doctor`、
`claude plugin list --json` 的 `errors`。 不添加 Harness 独自的 dependency resolver。

Harness 所做的事：

- 在 setup docs 中引导：missing dependency 请遵循 Claude Code 的 hint。
- 在 release docs 中使用 `claude plugin tag` 和 version constraint，做便于依赖解析的 tag。
- 若 marketplace 尚未登记，引导先使用 `/plugin marketplace add` 或 `claude plugin marketplace add`。

Harness 不做的事：

- 不擅自到其他 marketplace 去找 plugin 并 install。
- 不独自解释 `dependencies` 而直接改写 cache。
- 不制作绕过 `blockedMarketplaces` / `strictKnownMarketplaces` 的 resolver。

## Plugin prune

`claude plugin prune` 是删除不再需要的自动安装 dependency plugin 的 cleanup command。 其对象是
Claude Code 为满足其他 plugin 的 `dependencies` 而安装的 plugin，不是用来擅自删除用户直接安装的 plugin。

Harness 的方针：

- 作为 plugin uninstall 之后的 cleanup 引导使用。
- 首先引导 `claude plugin prune --dry-run`。
- 仅在非交互式 CI 中执行时才使用 `-y`。
- 不在 release / setup 中无条件执行。
- 若有应保留在 `${CLAUDE_PLUGIN_DATA}` 的 state，请考虑 uninstall 侧的 `--keep-data`。

推荐示例：

```bash
claude plugin prune --dry-run
claude plugin prune -y
```

## Project purge

`claude project purge [path]` 是删除 Claude Code 在 project 中持有的 transcripts、tasks、file history、config entry 的强力 cleanup command。

Harness 的方针：

- 仅在有明确理由删除本地 Claude state 时（archive、handoff、path / owner 变更等）才引导。
- 首先使用 `--dry-run` 或 `--interactive`。
- 在需要保留进行中的 task、review evidence、handoff 证据时不要使用。
- 不把它当作 Harness 的 `Plans.md` 或 git 历史的替代 cleanup。

推荐示例：

```bash
claude project purge . --dry-run
claude project purge . --interactive
```

## Plugin-bundled hooks

Plugin 可以随附 hooks，但在 Harness 中要避免「仅仅装入 plugin 就引发强烈副作用」的设计。

Harness 的方针：

- bundled hooks 以 opt-in 为基本。
- 写入、push、deploy、外部发送、tool output 改写默认无效。
- 使用 `PostToolUse.hookSpecificOutput.updatedToolOutput` 时遵循 `docs/output-governance.md`。
- hook 的 stdout 遵守 JSON contract，面向人的日志输出到 stderr。

理由：

plugin 接近信任边界。 如果用户一启用 project
行为就大幅改变，追踪原因和确认安全都会变得困难。

## Themes decision

在 Claude Code `2.1.118` 中，可以用 `/theme` 创建・切换命名自定义主题，plugin 也可以随附 `themes/` directory。

本次的判断：

- Harness 这次不随附 theme。
- 在 Phase 53 中只停留在 `P: 将来タスク`。
- 理由是，Harness 的主价值在于 Plan / Work / Review 的运用安全性，分发 theme 需要另做关于 brand・可访问性・终端适配的 review。

将来若要加入 theme，需满足以下条件后再做。

1. 在 light / dark terminal 下都易于阅读。
2. `/plugin` badges 或 warning text 不会糊掉。
3. 与 Harness 的 docs / screenshot / release copy 保持一致。
4. 即使没有 theme，功能也能完全正常工作。

## Windows / WSL managed settings

`wslInheritsWindowsSettings` 面向希望把 Windows 侧的 managed
settings 继承到 WSL 的企业环境。 在同时使用 Windows 和 WSL 的公司，可以减少设置的重复管理。

Harness 的方针：

- 不放入 Harness default。
- 只有在管理 Windows / WSL 终端的组织才需要考虑。
- 如果 WSL 侧无意中引入了过强的 policy 会影响开发体验，因此请先用 `/status` 确认 active settings source 后再运用。

## Managed sandbox precedence

在 Claude Code `2.1.126` 中，`allowManagedDomainsOnly` 和
`allowManagedReadPathsOnly` 的 precedence hardening 到位了。

这是安全侧的变更，防止管理员决定的「只允许这个范围」的 sandbox 边界被
project-local 的 template 或 plugin default 放松。

Harness 的方针：

- 把 `allowManagedDomainsOnly` / `allowManagedReadPathsOnly` 视为 managed settings only。
- 不作为默认值放入 Harness 通常分发物 `harness.toml`、`.claude-plugin/settings.json`、
   `templates/claude/settings.security.json.template`、
   `templates/sandbox-settings.json.template`。
- 在企业管理环境中使用时，以终端管理或 Claude Code 的
  managed settings 为 source of truth。
- Harness 不独自制作 managed sandbox resolver。
- `scripts/ci/check-consistency.sh` 会对这些
  managed-only key 是否混入通常 template 做回归检查。

## Why this way

Plugin marketplace 和 managed settings 本身就是信任
边界。 信任边界是指「从哪里开始算是安全」的划线。 这条线应由 Claude Code 本
体通过 managed settings 的 precedence 和安装前检查来处理。

Harness 在其之上，追加 Plan / Work / Review 的作业品质和 guardrail。
 因此，与其制作设置检查器本身，不如把正确运用官方机制这件事文档化，并用必要的测试防止说明 drift。
