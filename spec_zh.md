# Claude Code Harness V2 规范

状态：截至 Phase 145/146 前沿模型与 prompt 更新时的 SSOT 最后更新：2026-10-13

本文件是 Claude Code Harness V2 的根产品契约。 Plans.md 是任务账本。`spec.md`是产品契约。 `spec.md` 规定什么必须保持为真。

## 目的

V2 让 Harness 成为更快的操作者工作流，同时不削弱证据。

目标是通过让 Harness 来降低人类的规划与验证负担：

- 在执行前对工作分类，
- 在实现前锁定正确的规格说明，
- 行为变更时要求 TDD 证据，
- 按风险分配评审深度，
- 生成 PR 就绪的证据包，
- 为公开产物保留发布级别的检查，
- 通过用户已经在用的工具来引导用户，同时只声称有 adapter 证据支持的支持，
- 让格式化、lint、发布预检、host runtime smoke 等仓库健康门禁与所声称的支持层级保持一致。

### 北极星（3 层）

志向自最基础的地基层起逐层堆叠；每层都是下一层的地基。

- **L1 专注判断式运营**：AI 准备 plan、实现、比较与验证证据；operator（人类）只做最终判断。（地基，即上文的 Purpose。）
- **L2 工具无关的强制执行**：同一 Harness（R01-R16 守卫 + plan/work/review/release）可从 Claude / Codex / Cursor *任何一方* 生效。单个 policy engine 通过各自的 native hook 裁决全部 3 个 host —— 是路由，不是复制。两个方向同等是一等公民：(#1) harness 驱动（Lead 把另一个工具作为执行引擎 spawn），(#2) host 发起（*从* Codex / Cursor *使用* Harness）。
- **L3 协作（未来的北极星）**：多个工具共同驱动同一项目，而不必让人类充当复制粘贴的快递员。Mode 1 = 完全自主编排（v1 保持 Lead = Claude 固定；Codex / Cursor 尚无对外 spawn API）。Mode 2 = 人类在席的 peer co-drive，通过 live notice messaging 实现。完整的 peer-Lead 协作在后续阶段引入。

## HOTL 治理契约

本契约把北极星 **L3** 落到 **个人
harness**（本仓库）上。组织范围的治理（共享宪法、团队规范）位于
**ContextHarness V2**；CCH 继承那份宪法，只治理单个 operator
的自主循环。目标是 **Human-on-the-Loop**：operator
从循环之外监督，而不是批准每一个门禁（HITL）。

状态：**verification-first**。在 `Plans.md` Phase
101（U0-U7）的前提条件被证据证明之前，不进行任何自主化推广 ——
也不设分阶段采纳阶梯。自主是已被证明的 harness 的*产出*，而不是起点。

不变量（在对应的自主能力启用前，每一条都必须变为机器可检查）：

1. **确定论优先的裁决。** 确定论检查（测试、R01-R14、RTM 覆盖）持有约束性裁决（否决权）。LLM 语义评审仅作建议，永远不能把门禁抬到确定论层之上。跨模型的一致 APPROVE 是佐证性建议，不是证明（裁决者的错误是相关的；即使 temperature 为 0，裁决仍是非确定性的）。
2. **SSOT 与派生物分离。** 人类批准的来源（规则、spec、测试）是唯一的判断依据。派生产物（溯源映射、图、生成的 HTML、摘要）仅用于导航，带有 `derived` 标记，生成物在 gitignore 中，且绝不能回流进执行者的决策。
3. **三轴升级。** 循环在以下情况升级到人类：(a) 最终的 spec/UX 变更，(b) 安全风险，或 (c) 影响半径 / 不可逆性（删除、超过阈值的文件/目录数、跨仓库、不可回退的操作）。轴 (c) 是机器可检测的，是最外层的后备，因为 (a)/(b) 是语义的，agent 自行分类并不可靠。
4. **运行中范围牵引（零人类负担）。** 执行期间每次工具使用都要对照任务声明的范围检查。范围由 plan **自动推断**得出（任务目标文件 + RTM）—— operator 从不手工声明文件白名单。越界写入触发告警/升级；已声明但未触及的范围（被丢下的工作）会被标记。这能捕捉任务漂移和终端评审在结构上看不见的静默失败。
   同一个 Runtime Floor 对本地文件有对称的秘密读取白名单契约，与 `isAllowlistedHost` 强制执行的外连白名单相匹配：除非目标 host 被显式声明，否则拒绝网络外连；除非精确路径被显式声明，否则拒绝秘密读取。
   秘密读取白名单唯一提供的放宽仅针对具名路径；它绝不能意味着宽泛的文件系统访问。空字符串、裸 `*`、`/`、`~`、`~/`，或任何其他全开声明都是无效的，解析结果为 deny。
   环境白名单匹配会在命令 token 和声明两侧都用进程 home 目录展开前导 `~/`；这是拼写规范化，不是更宽的具名路径集合。`$HOME` 和 `~user` 不展开。展开后，若声明本身就是 home 目录，或不严格位于其内部（包括 `~/.`、`~/./`、`~//`、`~/..`），则被丢弃。只写入的 `cat`（`>` / `>>` / heredoc，没有位置输入文件也没有 stdin `<`）不是秘密读取动词；`cat FILE` 与 `cat FILE > out` 仍被拒绝。生效的
   声明是 `HARNESS_RUNTIME_FLOOR_SECRET_ALLOW` 与项目配置 `.claude-code-harness.config.json` 的
   `runtimefloor.secretAllow` 键的并集。如果项目配置不可读、格式错误，或 `runtimefloor.secretAllow` 形状无效，fail-safe 行为是空白名单（拒绝所有秘密读取）。相对和绝对的 `secretAllow` 声明都会先解析为绝对路径，再对照 worktree 边界检查；任何解析后落在 worktree 之外的声明 —— 包括通过 `..` 段逃逸的相对声明 —— 都是无效的并被丢弃，而不是扩大白名单。该边界检查同样跟随符号链接：文本上位于 worktree 内、但经符号链接解析到外部目标的声明，同样被丢弃。符号链接解析仅用于做这个放行/拒绝判定 —— 白名单本身始终存储 operator 声明的路径，绝不存储解析后的 realpath，因此 worktree 内声明的符号链接以其声明名保持可读，而 operator 从未声明过的 realpath 即便恰好被某个已声明的符号链接指向也仍被拒绝。
5. **有界且外部锚定的评审。** OK-until-clean 循环有上限（例如 3 轮），同一原因反复失败时升级到人类。严重度是固定分类：安全 / 数据丢失 / 正确性发现始终阻断，永远不适用「别再挑刺了，继续走」；只有风格/偏好可以被抑制。跨家族评审是必需的（Claude-Lead 由 Codex 评审，反之亦然，加上全新上下文）；当跨家族这一腿不可用时，这是一个具名的降级自主状态，而不是静默的同家族回退。
6. **宪法与自我修改保护。** 规则定义（`rules.go`）、`deny-baseline`、settings 文件和 `self-audit` 策略属于不可触碰类：任何 AI 路径都不得修改它们；仅限人类。自主决策的审计轨迹是从不可变事件日志机械派生的，而不是来自 agent 的自我叙述。急停开关（`~/.harness/HALT`）在任何 LLM 判断之前就拒绝所有工具使用。`.claude-code-harness.config.{json,yaml}` 是与 settings 文件同治理层级的控制面文件 —— 它限定 `runtimefloor.secretAllow`（秘密读取硬下限的白名单）和 `runtimefloor.releaseAuto` —— 因此它与 `.claude/settings*` / `.claude-plugin/settings*` 一起加入同一受保护路径 deny 层，在 `go/internal/policy/helpers.go` 的 `protectedPathRules`（R02/R03，层级 `protectedPathDeny`）中强制执行，并由 `go/internal/policy/selfaudit.go` 的 deny 面基线取指纹（Phase 128.3）。原生 Claude Code deny 列表（`.claude-plugin/settings.json`、`templates/security/deny-baseline.json`）仍是仅限人类编辑的，不在这个 Go 层控制的范围内；AI 撰写的 PR 仅通过守卫引擎执行它。

散文质量的治理是有范围的，不是普适的。写作规范的强制执行（源自 Phase 101
验证过的日语技术写作标准）仅适用于**日语 opt-in
界面**；英语是出厂默认并保持不动。只有确定论的禁用短语子集（空的 LLM
填充串）才有资格成为门禁，并先作为规则↔检查溯源的参考实例被证明（不变量
1）。语义写作规则（因果机制、保留限定语、单一原因归约）保持建议性质，永不否决。正字法偏好（如禁用
em dash）是宽松建议，永不是门禁 —— 一个会对 agent
自身输出触发的散文门禁会让运行中牵引死锁且毫无余量。散文只有一个
SSOT，不是三个重叠的。

复用而非重建：规则↔检查与 功能→需求→证明 的可追溯性是
policy-as-code（OPA/Conftest）与需求可追溯矩阵（DO-178C / ISO
26262）的成熟学科；防篡改证据来自 in-toto / SLSA。CCH
采用它们而非重建。真正新颖的范围是**自指的治理**：一个编辑自己
harness、并且可能给自己评分器做手脚的 agent。

## 用户与工作流

### 用户文档（2026-10-13）

README
主视觉区先用一句大的短陈述呈现用户问题，再用三个可扫读的结果，之后才是解释性文字。细节跟随第一个动作，而不是
precedes 它。主视觉动画是概念性的工作路径，不是实时进度：自包含的
SVG、给纯图像渲染器的 12 秒
GIF、以及给减弱动效偏好的静态海报。本地验收不声称已完成 GitHub
图像代理或跨操作系统字体验证。 英语和日语 README
用平实语言解释结果、安装、第一个请求、人类决策、成本与数据边界、重启与更新。当用户必须对它采取行动时保留技术名称，并在首次出现处解释其含义。类比用于补充具体解释；它从不替代条件，也不证明安全保证。
英语和日语变更日志保留发布版本、日期、比较链接和与升级相关的条件。当条目为读者重写时，历史原文仍然可用。这些都是编辑性改动，不是对
host 支持、权限、运行时行为或模型默认值的改变。

主要用户：

- 偏好让 AI 准备 plan、实现、比较与验证证据，而 operator 只做最终判断的操作者。

核心工作流：

- Plan：把意图转成有范围、可评审的契约。
- Work：只实现已批准的切片，并配以确定论检查。
- Review：按风险分配评审深度并保留证据。
- Sync：让 Plans、git 状态、镜像与分发界面保持一致。
- Release：打包证据，只在发布级门禁通过后才发布。

## SSOT 层级

`spec.md` 是根产品契约，保持稳定核心可读。 详细契约位于 `docs/spec/`下，属于同一产品契约的一部分。`Plans.md`记录排期工作与证据，但它不削弱也不覆盖 spec。

SSOT 优先级：

锚点：spec.md > sub-spec > Plans.md。

1. `spec.md` 核心：北极星、HOTL 治理、全局不变量、SSOT 顺序、非目标与未决事项。
2. `docs/spec/*` sub-spec：从本文件链接的详细契约章节。
3. `Plans.md`：任务账本、实现顺序与验证记录。
4. `CHANGELOG.md` / README / 技能正文：面向分发的摘要。

当某个细节从 `spec.md` 移入 `docs/spec/*` 时，它仍然是 spec 材料。 如果
sub-spec 与本核心冲突，在人类批准的 spec 更新改变顺序之前，以本核心为准。

## 规划界面契约

规划产出共同必需的规划输出：`spec.md` 产品契约与 Plans.md 任务契约。
锚点：spec.md 产品契约与 Plans.md 任务契约。 每个 `create`输出与每个影响产品的 `/harness-plan add` 都必须产出 `Spec delta` 或 `Spec skip
reason`，并且必须先产出 spec 结果、再产出任务行。由 Harness 生成 spec
结果；消费方批准或编辑它。 未知数据遵循 `not_observed !=
absent`；不要从缺失证据推断不存在。

非平凡的规划必须经团队验证。可用时要求 TeamAgent 或 sub-agent
视角，输出必须记录 `team_validation_mode`。非平凡工作必须使用
`native`、`subagent` 或 `manual-pass`；Product / Architecture / Security / QA
/ Skeptic 是视角，不是必需的 runtime `agent_type` 名称。规划必须包含项目范围的
harness-mem / harness-recall / repo-memory
轮盘检查，针对权限、秘密、外部发送、供应链的安全验证，以及可用性验证。安全验证不得要求读取秘密。

相关 sub-spec 锚点：`docs/architecture/hokage-core.md`、`go/SPEC.md`、Host
Adapter Boundary、Support Tiers And Host Claims、Onboarding Contract、New
Session Bootstrap Rule，以及 `future/unsupported` host claim 处理。

## Sub-Spec 索引

- [规划与 host adapter](docs-zh/spec/planning-and-host-adapter.md)：Planning Surface Contract、Hokage Core And Host Adapter Boundary。
- [执行后端与分发](docs/spec/execution-backends-and-distribution.md)：Support Tiers And Host Claims、Execution Backend Contract、Orchestration Visibility Contract、Onboarding Contract、Host Distribution Contract、Clean Mode And Compatibility Mode。
- [工作流、评审与发布](docs/spec/workflow-review-and-release.md)：New Session Bootstrap Rule、Lane Taxonomy、Stage Gate Flow、Unknown Data Contract、Review Contract、PR And Release Boundary、Release Workflow Delegation Contract、README Product Surface Contract、I18n And Status Marker Contract。
- [运维、memory 与协作](docs/spec/operations-memory-and-collaboration.md)：Supply Chain Alert Contract、Memory Contract、Upstream Tracking Contract、Session Coordination Contract、Worktree Root Discipline、Tri-Tool Parallel Collaboration Contract、risk gate distribution、auto-approve scope。
- [Breezing 与 bridge](docs/spec/breezing-and-bridge.md)：Breezing Brief Contract、memory lifecycle events、Bridge Daemon Contract、delivery layer、Channels-Wake、workgraph signal boundary。
- [决策卡界面](docs/spec/decision-card-surface.md)：Decision Card Surface Contract、`judgment-card.v1`、过往决策引用准确性、fail-open memory 行为。

上面这些章节名有意保留旧的 `spec.md` 标题，好让基于 grep
的审计仍能从核心文件找到契约位置。

## Prompt 交付契约

执行请求要携带预期结果、相关约束、归属范围、完成条件与可用证据，交给实际的
worker 或 advisor。任务描述、评审细化、选定的 plan 路径或先前的 advisor
回应，不得在编排与派发之间丢失。
推断出的范围是规划上下文，绝不是用户授权的证明。

在已授权的任务内，agent
自行选择方法，并在合理且已声明的假设下继续可逆工作。它们先从提供的契约与只读项目上下文中取回所需输入。缺失的授权、实质性的规格决策或受保护操作仍会阻断依赖动作；独立的已授权工作可以继续。仅为评估的请求仍然是评估。既有的安全门禁与明确指示优先于通用工作流默认值。

委派使用可独立验证的结果、明确的归属，以及配置的并发上限。协调者继续推进有用的工作，并把相关后续任务复用给同一个
worker；独立评审保持全新上下文及其有界裁决契约。必需的测试与证据仍是强制性的，额外测试需由新变更或未解决的疑虑来正当化。
报告区分「打算做的」「实际做的」「已验证的」，并请求给出带可核查证据的决策理由，而不是私有推理记录。

原生 agent 权限、模型与 effort 路由、受保护 hook prompt、评审 schema
以及仅限人类的 settings，不受 prompt 校准影响。 仅 API
可用的功能不会被呈现为已由 CLI 指示启用。

模型与 effort 的默认值不冻结 operator 的选择。明确的单次运行选择与 operator
所拥有的 profile 设置，对各自的执行路径保持权威。agent
不得从任务措辞推断出有权重新调整它们。有范围的环境更新保留当前未被占有的设置，包括更新期间做出的交互式模型/effort
变更；更新自身键上的冲突仍保持可见。父级设置变更不是重新调整每个子角色或放宽其沙箱的指示。

## 当前前沿模型集成

2026 年 9 月的模型刷新对 Claude 路由器的深度规划与 advisor 默认值使用 Claude
Fable 5.1，对 Codex 前沿路由使用 GPT-6 astra。轻量 worker
仍单独路由。`docs/model-routing-policy.md` 规定了角色表与例外，包括隔离的
Sonnet 安全评审者。 明确的模型与 effort 选择必须能挺过 companion 派发、原生
agent 生成和受支持的循环执行。Codex `ultra` 是 Codex
运行时的选择，不是声称公开模型 API 接受该值。
不支持的传输组合必须在派发前显式失败。
这仅改变模型集成；批准、权限与评审边界仍由上述既有契约治理。安装证据与实际的
provider 选择必须与本地 fixture 测试分开报告。

## 非目标

1. 没有已批准的 plan，就不自动实现。
2. 没有匹配的支持层级门禁，就不做发布声称。
3. 不从跨家族评审静默回退到同家族评审。
4. 任何派生产物都不得成为判断来源。
5. 任何 host 专属分发都不得意外加载另一 host 的私有兼容界面。
6. 任何 AI 路径都不得修改宪法文件或 self-audit 策略。

## 未决事项

- 完整的 peer-Lead 协作仍分阶段引入；当前 L3 工作是 Mode 2 的 live notice messaging，加上在 host API 允许处生成的 delivery hook。
- 组织范围的治理仍在本仓库之外，属于 ContextHarness V2。
- 更广的散文质量门禁必须先证明确定论价值才能晋升；语义散文规则保持建议性质。

## 链接

- `Plans.md` — 任务账本与 phase 证据。
- `docs/spec/` — 仍属于本产品契约一部分的详细 sub-spec。
- `GOD_plans.md` — 发布与 S3-S5 证据跟踪。


### Plugin 分发身份（2026-10-14）

分发用的 plugin ID 在共享 marketplace 与各 host manifest 中统一为
`harness`。Claude manifest 由 `harness.toml [project].name` 生成。 仓库 slug
与 marketplace ID 仍保持 `claude-code-harness` 与
`claude-code-harness-marketplace`。内部配置、环境变量和项目 memory
路径不因分发 ID 变更而改变。 Hook root 检查与缓存查找使用新的 plugin
ID。缓存同步要求发布版本与 plugin 身份都匹配后才变更 marketplace
clone；它绝不创建未安装的缓存，也绝不改变用户的 plugin 注册。 marketplace
保留旧到新的 `renames` 条目作为仅追加的迁移历史。受支持的 Claude
版本把启用的/配置键迁到新
ID；用户在原有范围安装并检查只有一份副本处于激活状态。更旧的构建走文档记载的保留数据手动路径。迁移指引区分共享的项目配置与个人的用户/本地配置，且不承诺在没有证据的情况下自动转移以名称为作用域的
plugin 数据。
