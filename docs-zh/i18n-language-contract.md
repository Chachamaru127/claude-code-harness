# I18n Language Contract

状态: Phase 55 / task 55.0.1

Issues:

- [#105 Can the default language be changed to English?](https://github.com/Chachamaru127/claude-code-harness/issues/105)
- [#147 Status Marker Localization Issue](https://github.com/Chachamaru127/claude-code-harness/issues/147)

确认时间: 2026-04-24
更新时间: 2026-05-24（针对 Issue #147）

## Purpose

Claude Code Harness 必须以 English 作为用户面的默认语言，同时为选择使用日语或输入日语的用户保留现有的日语用户体验。

本契约首先关注状态和兼容性。翻译工作、运行时消息重写、setup 模板重写和 CI gate 必须以本文档为事实来源（source of truth）。

## Decisions

1. 用户面默认 locale 为 `en`。
2. Japanese 继续通过显式 opt-in 和日语输入 UX 支持。
3. Status marker 是协议值，但也是生成 Plans.md 行、摘要和通知中可见的用户面文本。
4. Skill frontmatter 必须保留 `description-en` 和 `description-ja`。
5. 迁移必须是非破坏性的且幂等。

## Locale Resolution

Locale resolution 只有一个事实来源（source of truth）：Phase 55 实现工作中引入的 locale resolver。
一旦该 resolver 存在，脚本和 Go hook handler 不得保留单独的硬编码默认值。

resolver 优先级为：

| Priority | Source | Meaning |
| --- | --- | --- |
| 1 | Explicit user or session setting | 当前会话状态中的直接用户选择、CLI setup 选择或其他持久化的显式偏好。 |
| 2 | `.claude-code-harness.config.yaml` `i18n.language` | 项目级配置。现有值必须被视为有意的。 |
| 3 | `CLAUDE_CODE_HARNESS_LANG` | 本地运行、测试和临时会话的进程级覆盖。 |
| 4 | Default | `en`。 |

只有 `en` 和 `ja` 是有效的 locale 值。未知值必须规范化为当前进程的 `en`，不得重写原始状态。

日语输入检测是 UX 和路由信号，不是持久化的 locale 设置。
当日前显示 locale 为 `en` 时，`実装して`、`レビューして` 或 `計画作って` 等日语 prompt 必须继续路由到相应的 skill。
日语输入不得静默覆盖显式的 `en` 设置。

## State And Migration Contract

实现必须区分以下状态：

| State | Examples | Required behavior |
| --- | --- | --- |
| Unset | No session preference, no `i18n.language`, no environment variable | 使用 `en`。不要隐式创建日语偏好。 |
| Explicit Japanese | `i18n.language: ja`, `CLAUDE_CODE_HARNESS_LANG=ja`, or explicit session/user `ja` | 保留日语行为和消息。升级后首次启动时不要覆盖。 |
| Explicit English | `i18n.language: en`, `CLAUDE_CODE_HARNESS_LANG=en`, or explicit session/user `en` | 保留英语行为和消息。日语输入仍能正确路由。 |
| Legacy saved value | Phase 55 之前的现有配置或状态 | 如果有效则读取。将 `ja` 视为有意的 opt-in。除非用户运行显式 locale 命令，否则不要重写。 |
| Missing or corrupted state | 无效 YAML、无效枚举值、无法读取的状态文件 | 仅在更高优先级有效来源不可用后，才使用安全当前进程回退 `en`。不要自动删除或重写损坏的状态。 |

迁移检查必须可重复。
多次使用相同文件运行启动、setup 或 locale 检测必须产生相同的 locale 决策，不得持续更改文件。

失败处理优先保留现有状态而非强制新默认值。
如果迁移无法安全确定现有状态是否为显式的，实现必须避免覆盖它，并且仅对当前进程回退。

## Status Markers

这些 marker 保持读取兼容的协议值：

| Marker | Meaning |
| --- | --- |
| `pm:依頼中` | PM requested work. |
| `cc:WIP` | Claude Code / Codex is working. |
| `cc:TODO` | Work is queued. |
| `cc:完了` | Work is complete and awaiting PM confirmation. |
| `pm:確認済` | PM confirmed completion. |
| `blocked` | Work is blocked. |

新的和更新的写入路径不得继续生成混合语言 marker 系列（如 `cc:TODO`、`cc:WIP` 和 `cc:完了`）在 Plans.md 行或通知文本中。
该形状是有效的旧版输入，但不是未来写入的规范输出。

新写入或更新行的规范 writer 输出为：

| State | New/update writer output | Read-compatible aliases |
| --- | --- | --- |
| Requested | `pm:requested` | `pm:依頼中`, `cursor:依頼中` |
| Queued | `cc:todo` | `cc:TODO` |
| In progress | `cc:wip` | `cc:WIP` |
| Done | `cc:done` | `cc:完了` |
| Approved | `pm:approved` | `pm:確認済`, `cursor:確認済` |
| Blocked | `blocked` | `cc:blocked` |

日语 opt-in 本地化周围散文、模板和运行时消息，但不影响 status marker writer 输出。
现有 Plans.md 文件不得被隐式批量重写；迁移需要显式命令或用户批准。

marker 解析的状态契约故意较窄：

| Checkpoint | Required invariant |
| --- | --- |
| Input | 现有 `Plans.md` 行和标题风格任务可能包含规范 marker、cursor 别名或上列英语别名。 |
| Storage | `Plans.md` 保持事实来源（source of truth）；解析器检查在验证或 dry-run 路径中不得重写它。 |
| Update trigger | Writer 仅在执行批准的工作流（如工作完成或 PM 确认）时更新任务状态。 |
| Readers | `codex-loop`、sprint-contract 生成、Plans issue bridge 和格式检查必须接受旧版 marker 和英语别名。 |
| Writers | 所有新的/更新的 writer 路径发出英语 marker 系列；locale 仅影响散文。 |
| Rollback | Rollback 必须保留对旧版 Plans.md 文件的解析器兼容性；不要删除旧版 marker 识别。 |

## Skill Metadata Contract

每个发布的 `SKILL.md` 必须包含：

```yaml
description: "..."
description-en: "..."
description-ja: "..."
```

对于分发的英语默认，`description` 必须等于 `description-en`。

对于日语 opt-in，locale 工具可以将 `description-ja` 复制到 `description`，但必须保留两个语言特定字段。

日语触发器可发现性必须保留。至少，日语路由短语实现、审查和计划必须保留在 `description-ja` 或附近 skill 使用文本中：

- `実装して`
- `レビューして`
- `計画作って`

## Skill Body And Completion Report Contract

定义用户面输出的 skill 指令必须应用与运行时脚本相同的 locale resolution 契约。
它们不得依赖周围指令散文的语言或临时转换输出模板。

对于 `harness-work` Solo、强制单任务 Parallel 和 Breezing 完成报告：

1. 通过共享的 `get_harness_locale` 函数解析 locale。显式会话或用户语言作为其可选参数传递；否则 resolver 保持项目配置、环境，然后 `en` 默认优先级的顺序。
2. Unset、无效和解析的 `en` 使用英语模板。
3. 仅解析的 `ja` 使用日语模板。
   仅日语输入不选择日语完成模板。
4. 英语和日语模板必须携带相同的语义字段。Status marker、审查裁定、commit hash、路径和命令保持机器可读值。
5. Claude、Codex 和 OpenCode 副本必须在此输出契约或任一模板更改时重新生成并检查。

## Japanese UX Regression Boundary

英语默认意味着第一个分发的发现 surface 是英语。
这不意味着应该删除仅日语用户的价值。

当某个 surface 主要为日语用户存在时，请保留以下路径之一：

| Surface type | English default boundary | Japanese opt-in boundary |
| --- | --- | --- |
| README and setup templates | English onboarding remains the default path. | `README_ja.md` and `templates/locales/ja/` remain reachable and render Japanese output when `i18n.language: ja` or `CLAUDE_CODE_HARNESS_LANG=ja` is explicit. |
| Skill metadata | `description` equals `description-en` in shipped packages. | `description-ja` remains complete, and `scripts/i18n/set-locale.sh ja` can copy it into `description`. |
| Hook and system messages | English is emitted when no locale is configured. JSON shape and decisions are unchanged. | Existing Japanese messages remain available through explicit `ja`. |
| Memory / output style modes | English mode remains `templates/modes/harness.json`. | `templates/modes/harness--ja.json` remains valid JSON and keeps Japanese language requirements. |
| Creative skills such as `x-announce` and `x-article` | English `description-en` controls default skill discovery and must not promise English creative output unless an English playbook exists. | Japanese article / post structure, Japanese image text defaults, and Japanese publication tone are retained as intentional creative defaults. |

对于日语特定的创意默认值，安全规则是附加的：如果英语用户以后需要完整的英语创意流程，请添加英语 playbook 或 mode。
不要仅仅因为分发默认更改为英语就删除日语默认值。

## Surface Checklist

以下 surface 属于 Phase 55 实现范围，必须在 Issue #105 关闭前检查：

| Surface | Required check |
| --- | --- |
| `README.md` | English default guidance and Japanese opt-in link are clear. |
| `README_ja.md` | Japanese onboarding remains reachable. |
| `CLAUDE.md` | Repository guidance does not imply Japanese-only behavior for distributed users. |
| `AGENTS.md` | OpenCode/Codex-compatible guidance follows the same language contract. |
| `claude-code-harness.config.schema.json` | `i18n.language` default is `en`; enum keeps `ja`. |
| `claude-code-harness.config.example.json` | Example uses `en` by default and documents `ja`. |
| `templates/.claude-code-harness.config.yaml.template` | Generated project config follows English default. |
| `skills/` | Root skills have `description-en` and `description-ja`; distributed `description` is English. |
| `skills-codex/` | Codex source skills follow the same metadata rule. |
| `codex/.codex/skills/` | Codex packaged mirror has no metadata drift. |
| `opencode/skills/` | OpenCode packaged skills follow the same metadata rule. |
| `.agents/skills/` | Local-only mirror is either synchronized or explicitly documented as excluded from distribution. |
| `scripts/i18n/set-locale.sh` | Locale switching supports `ja -> en` and `en -> ja` without losing language fields. |
| `scripts/i18n/check-translations.sh` | Checks all shipped skill surfaces, not only root `skills/`. |
| `scripts/config-utils.sh` | Contains the shell locale resolver. |
| `scripts/pretooluse-guard.sh` | Uses the shared resolver and defaults to English when unset. |
| `scripts/userprompt-inject-policy.sh` and hook shell output | User-facing output follows locale. JSON shape remains unchanged. |
| Go hook handlers under `go/internal/hookhandler/` | System messages are English by default and Japanese with explicit `ja`. |
| `templates/AGENTS.md.template` | Default setup output is English or locale-aware. |
| `templates/CLAUDE.md.template` | Default setup output is English or locale-aware. |
| `templates/Plans.md.template` | Generated plan guidance is English by default while protocol markers remain unchanged. |
| `templates/modes/harness--ja.json` | Japanese mode remains valid and reachable. |
| `scripts/setup-existing-project.sh` | Setup can render English default and Japanese opt-in. |
| `scripts/setup-hook.sh` | Hook setup messaging follows locale rules. |
| `scripts/quick-install.sh` | Installer messaging and generated config follow locale rules. |
| `.claude-plugin/marketplace.json` | Marketplace user-facing text is English default. |
| `.claude-plugin/hooks.json` and `hooks/hooks.json` | Hook metadata stays synchronized and user-facing descriptions follow English default. |
| `docs/constitution.md` | Any language guidance aligns with this contract. |
| `opencode/README.md` and `codex/README.md` | Runtime-specific docs do not contradict the contract. |

55.2.2 setup hardening 后的已知当前 drift：

- `scripts/pretooluse-guard.sh` 在未设置环境变量时默认为日语。
- Runtime shell / Go 消息尚未完全 locale-aware。
- Setup content templates 现在以英语默认分发，日语 opt-in 副本位于 `templates/locales/ja/`。

这些是后续 Phase 55 任务的目标，不是本契约任务的阻碍因素。

## Acceptance Criteria For Later Tasks

Phase 55 实现必须证明以下情况：

1. 新用户首次启动默认使用英语。
2. 有显式 `ja` 的现有日语用户升级后保持日语。
3. 有显式 `en` 的现有英语用户重启后保持英语。
4. 显式 locale 切换在重启或重复调用中保持。
5. 缺失状态回退到英语而不写入意外状态。
6. 损坏状态不会被迁移路径销毁。
7. 在旧状态上重新运行迁移是幂等的。
8. 日语输入仍然发现并路由主要工作流：
   `実装して`、`レビューして` 和 `計画作って`。
9. 内部 Plans.md status marker 保持可解析，除非先测试别名兼容层，否则不变。
10. 所有发布的 skill 保留 `description-en` 和 `description-ja`。

## Non-goals For 55.0.1

本任务不实现 resolver、更新模板、重写运行时消息或关闭 Issue #105。
它修复的是后续更改必须遵循的契约。
