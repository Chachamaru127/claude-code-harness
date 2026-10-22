# CCH 的 prompt 与对负责人的交接

CCH 向负责人传递目的、变更范围、完成条件、已确认的依据。负责人在这些条件之内自行选择方法。选择模型名和推理量的处理，与决定委托什么的处理，是分开管理的。

prompt 指发给模型的委托文。subagent 是在与主负责人不同会话中工作的负责人。主负责人不一定能读到 subagent 的会话，因此仅凭任务编号无法传达必要信息。

## 委托中应包含的信息

| 信息 | 内容 | 缺失时会发生什么 |
| --- | --- | --- |
| 目的与理由 | 使用者将能做什么、这项工作为什么必要 | 只修眼前的函数，业务问题仍然留存 |
| 负责范围 | 作业位置、可修改的文件、与其他负责人的边界 | 竞争性地编辑同一文件 |
| 完成条件 | 规格、DoD（判定完成的条件）、必要的确认方法 | 仅凭本人宣告成功就结束 |
| 观察到的依据 | 复现步骤、日志、当前差异、已经通过的验证 | 重复同样的调查、搞错失败原因 |
| 决定与审批的参照 | 原始委托、已确定的约束、仍需人判断的点 | 把摘要中写着的推测当作执行许可 |
| 再修正与恢复的信息 | 修正对象的指摘、尝试过的方法、未完成项、下一个判断 | 再 review 的指摘无法传达给实现 |

如果没有审批的参照，则视为未提供。从计划中提取的 `declared_scope` 是变更范围的推测，而不是使用者许可过的证据。

例如对于「修复订单重复登记」的任务，要向负责人传递目标保存处理、发生重复的操作、同一订单只保存 1 条的完成条件、既有测试、以及要避免改动的支付处理。无需由主负责人固定实现的细节顺序。但在 TDD（先确认会失败的测试的开发步骤）为必需的任务中，要遵守该顺序和证据。

## 各负责人的动作

| 负责人 | 委托事项 | 交付物 |
| --- | --- | --- |
| Planner | 从委托和规格出发，制作可独立验证的工作单元 | 包含负责范围、依赖关系、完成条件的计划 |
| Worker | 在已审批的负责范围内完成实现，结束必要的修正与验证 | 差异、执行过的确认、结果、遗留问题 |
| Advisor | 阅读目的与失败的依据，指出接下来要改变的判断 | `PLAN`、`CORRECTION`、`STOP` 之一以及简短指示 |
| Reviewer | 独立于实现负责人，比较规格与当前实物 | 既有形式的判定，以及能定位的指摘 |
| Coordinator | 调整归属范围和依赖关系，统合成果 | 基于验证结果的当前进度与接下来需要的判断 |

信息不足时，先阅读所收到的契约和相关代码来补齐。可逆的实现手段的选择，在记录假设的前提下推进。若允许的范围或重大的规格判断尚未确定，则停止该处理。不要把仅需调查的委托擅自变成实现的委托。

独立的工作在遵守同时执行上限和文件归属范围的前提下进行委派。主负责人也继续推进其他有用工作，在需要结果时再等待。相关的追加工作可以复用同一负责人。最终 review 在新的会话中进行。

必要的验证不得省略。通过之后增加验证，仅限于出现新的变更、失败或未解决的疑虑。不要只把实现抄写一遍的测试，或添加委托范围之外的功能来扩大作业范围。报告中要区分「计划执行」「已执行」「已验证」。

## 指令的正本与送达对象

| 正本 | 送达对象 | 处理 |
| --- | --- | --- |
| `skills/` 的 23 个入口和 54 个 reference | Claude、Codex、OpenCode 的 skill | 全面 audit，调整必要角色特有的文面 |
| `skills-codex/` 的 3 个差异和 4 个 reference | Codex 的同名 skill | 与 shared 版分开 audit。生成时优先使用这一份 |
| `agents/worker.md`、`reviewer.md`、`advisor.md` | Claude 的 native 负责人 | 在各负责人处记载输入回收、证据、角色边界 |
| `hosts.toml` | Codex 的 worker / reviewer profile | 生成即使单独分发也能成立的指令 |
| Go 的 `promptpack/prompts/` 4 份 | `harness plan/work/review/release` | 嵌入可执行文件。不依赖外部文件的存在 |
| loop、advisor、Go team、browser artifact 的生成处理 | 实际被调用的负责人 | 除文面之外，还要验证具体任务信息的交接 |
| `codex/AGENTS.md`、setup 的 EN/JA 模板 | 新导入地的常驻指令 | 不自动覆盖用户已设置的文件，而是更新分发源 |
| `output-styles/harness-ops.md` | Claude 的报告显示 | 区分完成与未确认，指出判断所需的实物 |
| `livemsg-gate`、`test-wiring-auditor`、hook 的 3 个 prompt | 事实确认与既有保护处理 | 不混入一般实现负责人的自主指令，保持固定的判定契约 |

`scripts/sync-skill-mirrors.sh` 更新 skill 的副本。`harness gen` 生成 native profile。Go 的内置指令若不重新构建二进制就无法送达使用方。分发确认时，不仅要确认源码的变更，还要比对这 3 条路径。

兼容 helper 与 Cursor 特有的指令也纳入 audit 对象。但是，不要把 provider 特有的执行步骤整体替换为 Fable / astra 用的版本。默认 OFF 的功能，不以调整 prompt 为理由启用。

Go 的 `HARNESS_TEAM_HIERARCHY=sublead` 是尚未支持的路径：内部调用的 `harness plan decompose` 没有返回所需的 JSON 小计划。本次修正了看起来像已工作的文面。维持通常的 flat 方式（主负责人直接管理各 worker）。这个入口的实现仅靠调整 prompt 是无法完成的。

Go 的追加 review `HARNESS_REVIEW_ITERATE=on` 同样缺少实际判定所必需的 `claude-companion.sh`。回答形式和交接通过 fixture（用于验证、替代外部服务的实现）来确认，维持默认 OFF。它与使用普通 skill 和 native reviewer 的 review 是不同的路径。

在这个 Go 追加路径中，即便继承的过去输出里只写有「未执行 `npm publish`」，执行前检查也会检测到公开操作并中止。正文以单个参数传入，并不是把所描述的命令当作 shell 来执行。将来启用时，除了替换检查的配送测试之外，还需要能通过实际检查的统合确认。

## 与设置的关系

模型决定负责人的能力、effort（推理量）决定思考处理的任务分配、prompt 决定负责人的工作。目的传达不到的路径，即使提高 effort 也无法修复。应先验证必要信息的交接。

Fable / astra 的路由与显式值的优先级遵循 [model-routing-policy.md](model-routing-policy.md)。维持轻量 worker、Sonnet 的隔离 reviewer、read-only 权限、review 上限、保护设置。不要因文面而自动改变模型或权限。

在 Codex 0.153.4 中，位于相同设置层级的 `agents.reviewer` 声明优先于单独的 `reviewer.toml`。要使用默认的负责人文件，需用 `config_file` 建立引用连接。除设置文件的存在之外，还要用新启动的 Codex 所显示的负责人模型和推理量来确认。

此版本的 native 子进程会继承父的执行权限。不要认为仅凭负责人文件的 `sandbox_mode=read-only` 就意味着文件修改已被执行应用禁止。CCH 的只读 review 通过明确指定该执行设置的 companion 进行。角色指令和执行应用的权限，要分开确认。[Codex 的实现与验证](https://github.com/openai/codex/blob/rust-v0.153.4/codex-rs/core/src/agent/role_tests.rs)

允许使用者手动更改模型或推理量。默认值不是固定的强制值。当前会话的设置、负责人的设置、单次调用的指定，在各自的执行路径上都会被尊重。在环境更新时，不要把调查开始时的值恢复成当前值，而应保持 CCH 变更对象之外的最新设置。这并不意味着把父的设置变更自动分发给所有子进程。

API（从应用调用模型的连接口）的 `async`、WebSocket、`configuration_update`、`thinking.display` 需要执行应用的对应支持。仅在 prompt 中写入名称并不会增加 CLI 的功能。

## 来源与验证范围

确认了 2026-09-05 指定的 [OpenAI latest-model guide](https://developers.openai.com/api/docs/guides/latest-model) 和 [Claude Fable 5 prompting guide](https://platform.claude.com/docs/ja/build-with-claude/prompt-engineering/prompting-claude-fable-5)。后者作为 Fable 5 的页面返回 HTTP 200，而非转向 5.1。也比对了 [Fable 5.1 的另一份指南](https://platform.claude.com/docs/ja/build-with-claude/prompt-engineering/prompting-claude-fable-5-1)。

这是把官方资料的原则套用到本 repo 的契约和实现上的设计。要求给出判断理由和可验证的依据，不要求逐字披露内部思考过程。输入捕捉测试证明信息能够送达调用方。实务速度或正确率的改善量，必须比较相同条件的代表任务才能测量。
