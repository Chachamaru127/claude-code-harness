# 変更履歴

[English](CHANGELOG.md) | [現在の使い方](README_ja.md)

CLIは入力したコマンドで操作するアプリです。
フックは作業の節目に自動で動く処理です。
作業ツリーは、タスク用に分けたプロジェクトの写しです。
preflightは着手や公開の前の検査、schemaは記録の形式を定義するものです。
MCPはアシスタントから外部の機能を使う接続方式です。
high、xhigh、maxなどの推論量は実行先ごとの設定値で、完了率ではありません。

各版は、その時点で変わった内容です。
当時の既定値とコマンドは後の版で変わっているため、導入は現在のREADMEを使ってください。
**Unreleased**は版を付けて公開する前の変更です。

[元の履歴全文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md)をバイト単位で変更せず保存しています。
当時の技術詳細と相対リンクは、[元コミット6c198b4c76f9の変更履歴](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md)から参照できます。
内部の工程番号と作業台帳は保存版へ分けました。
既存の比較参照はそのまま保ち、元にない比較リンクは作っていません。

## [Unreleased]

## [5.16.0] - 2026-10-15

### Changed

- 将共享 marketplace 和所有执行地的分发插件 ID 统一为 `harness`。
  仓库名、marketplace 名、项目设置路径相同。
  对应的 Claude Code 遵循 marketplace 的改名映射。
  更新分发源到同一 scope 引入新 ID，确认只有 1 个有效副本。
  不保证自动传输插件专用数据。
  参见[切换步骤](https://github.com/Chachamaru127/claude-code-harness/blob/main/docs/onboarding/plugin-rename_ja.md)。

- 重写了英语版和日语版的 README、全版本的变更日志。
  保留了更新判断所需的条件，并链接到原始变更日志全文。
  开头的短动画展示了工作流程，针对减少动画的设置也准备了静止版本。
- 从源码构建需要 Go 1.26.0。
  对齐了模块和工作区，用同一版本重新生成了 4 个平台的附带执行文件。
  使用附带版本的用户无需安装 Go。
- 将 `golang.org/x/sys` 从 0.47.0 更新到 0.49.0，`modernc.org/sqlite` 从 1.56.0 更新到 1.60.1。
  相关的 libc 是 1.77.1，memory 是 1.12.1。
- 在基准测试维护中，Dependabot 仅针对检查中固定的 `@vercel/agent-eval` 1.4.x 的补丁更新提出建议。
  停止了不符合固定条件的大版本更新和小版本更新建议。

### Fixed

- 修复了对使用别产品 claude-mem 的用户，只要存在 `~/.claude-mem/` 就发出旧记忆区域警告的问题。
  仅在存在 harness-mem 的识别信息时才进行判定。
- 修复了外部通信检查将 `late.txt` 和 `config.json` 误认为通信目标的问题。
  `evil.sh` 等拥有已注册顶级域名的主机继续被拒绝。
- 在质量判定、写入后审查、会话压缩前的 hook 中使用可解析的模型 ID `claude-haiku-5-5`。
  修复了因缩写名导致未识别错误的问题。
- 即使从其他位置执行 hook，也将状态文件保存到项目根目录下。
  优先使用 hook 输入的工作位置而非 `CLAUDE_PROJECT_DIR`，将 worktree 各自的锁和计划监视分开。
- 在集成测试中不读取用户的 Git 设置，停止后台运行的 Git 维护处理。
  如果清理时出现竞争则短时等待，并记录写入中的进程。
  不改变用户的项目设置。
- 将基准测试的依赖条件修正为 `undici ^7.30.0`、`brace-expansion ^5.0.12`、`@grpc/grpc-js ^1.14.6`。
  修复了因公开的漏洞信息导致检查停止的问题。
## [5.15.0] - 2026-09-06

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5150---2026-09-06) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L62)

### Added

- 添加了日语的产品指南。
  可以在智能手机上阅读委托方法和可期待的结果。
  模型设置可以打开确认。

### Changed

- 在英语版、日语版、Codex 版的说明中记载了任务执行、角色的默认值、手动模型选择、进度、恢复方法。
  将任务件数的进度和验收检查的合格分开。
- Claude 的详细计划和建议角色默认使用 Fable 5.1/high。
  Codex 的高性能枠是 GPT-6 astra。
  轻量级施工角色、Codex 各角色的现有推理量、隔离的 Sonnet 安全判定角色保持独立设置。
- 将执行步骤对齐到作业范围、可恢复的输入、独立的委托、可观测的完成证据。
  保持所需的检查、审查次数上限、权限边界。

### Fixed

- 在 Linux 和 macOS 上以数值形式初始化和恢复交接时刻。
  结构化的交接也可以在 Linux 上恢复。
- 修复了建议角色的回归测试改变用户设置的问题。
  继续检查项目中明示的模型选择。
- 在委托给外部 CLI 前对齐相应的工作位置指定格式。
  修复了审查对象偏离委托项目的问题。
- 将大计划和工作状况通过标准输入传递。
  在留下证据的同时修复了因 OS 命令参数上限无法启动的问题。
- 在 Codex 初始设置中连接管理对象的判定角色。
  修复了默认角色隐藏该模型和指示的问题。
  保持自定义角色指定，区分原生委托的权限继承和外部 CLI 的只读审查。
- 外部委托时也保持 Codex 明示的模型和推理量。
  `ultra` 也是对象。
  建议角色的默认值从安装目标而非目标项目读取。
- 在执行和保护检查中将工作位置和写入计划对齐。
  拒绝未对应的设置覆盖或额外的写入路径。
- 向 Claude 版和 Codex 版附带了建议角色和迭代执行所需的辅助处理。
  在迭代执行的启动和恢复时保持计划、完成条件、失败证据、上次的建议。
- 在 Go 的施工处理中保持委托内容和审查修正事项。
  任意使用的判定契约要求明示的判定，仅在矛盾文章中包含 `APPROVE` 不会判定为合格。
- 向浏览器审查的指示传递完成条件、推测的范围、对象外内容、判定角色的注意事项。
  不改变结果格式和调用方法。


## [5.14.1] - 2026-08-31

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5141---2026-08-31) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L113)

### Fixed

- 在秘密文件读取例外中，将声明和命令开头的 `~/` 对齐到进程的主目录。
  仅为表示的修正。
  单独的 `~` 和 `~/`、`$HOME`、`~user` 不会展开或新建许可。
- 修复了将没有输入文件的 `cat > file`、`cat >> file`、`cat > file <<EOF` 误认为读取的问题。
  不会无端拒绝后续的环境文件指定。
  位于 `cat FILE`、输入重定向、输出指定前后的输入文件继续被拒绝。
  `&>` 和 `&>>` 也无法隐藏输入文件。


## [5.14.0] - 2026-08-31

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5140---2026-08-31) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L131)

### Added

- 添加了任意设置 `destructive_delete: defer`。
  对不确定的删除进行拒绝并保存到等待列表 `.claude/state/deferred-ops.jsonl`，无人执行继续。
  重试时保持拒绝状态，不重复注册。
  默认保持 `warn`，不改变警告允许的场景。
- 设置位置是 `harness.toml [safety.permissions] destructiveDelete`、项目 YAML 的 `safety.destructive_delete`、`HARNESS_DESTRUCTIVE_DELETE_POLICY`。
  可以静态确认所有权的对象允许。
  根目录外、`..`、未解析变量、glob、单独的 `.` 进入 defer 的等待列表。
  有前缀命令的相对路径和项目内的路径与 warn 相同处理。
- 本人可以用 `bin/harness deferred list` 查看列表，用 `bin/harness deferred approve <id>` 批准 1 件。
  仅在下次执行同一命令时允许 1 次，之后的尝试再次拒绝并注册。
  没有批量批准和自动批准。
  进度画面也显示等待项目和批准命令。
- 代理可以读取列表，但拒绝批准命令、保护对象批准记录、审计记录的写入。
  记录批准者，用同一锁处理注册、批准、消费。
  任意解释器的写入仍有检查上的局限。


## [5.13.2] - 2026-08-29

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5132---2026-08-29) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L168)

### Fixed

- 修复了向未安装版本先创建不完整插件缓存的问题。
  补充了现有缓存的 `agents/` 不足，不改变版本信息的文件。
- marketplace 复制仅在 Git HEAD 指向同一版本时才同步。
  不从复制中删除跟踪的调查文件。
  修复了误认更新目标版本的问题。
  非公开路径的清理仅在缓存侧进行。

### Changed

- 在同步报告中更正了插件组件不足的原因，记录了修复的优先级。
  未改变声明文件和 Go 生成代码。


## [5.13.1] - 2026-08-26

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5131---2026-08-26) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L187)

### Changed

- 在开发计划中优先处理了无人执行在开头确认时停止的问题。
  计划了记忆处理修理、日语文章规则的添加和退役、与 CLI 标准功能的重复确认。
  这不意味着在本版本中添加了执行功能。


## [5.13.0] - 2026-08-25

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5130---2026-08-25) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L193)

### Added

- 同一 PC 上的 Claude Code、Codex、Cursor、Grok、Hermes 会话可以互相查看和联系。
  名牌保留到会话结束，每轮更新保持声明的名称和工作。
  全员通知也会到达其他 worktree。
  不删除 harness-mem 侧的未知注册项。
- 会话注册时以 export 格式向 `CLAUDE_ENV_FILE` 传递收发者的识别信息。
  `session-send` 介绍 `bin/harness inbox send --team/--from/--to/--subject`。
  完成通知、编辑范围声明、交接是对象，基于猜测的商量不是。
- 消息验证默认 OFF。
  用 `[livemsg] verification = "off" | "on"` 选择。
  按环境变量、项目 YAML、项目 TOML、插件 TOML、默认值的顺序解决。
  OFF 时不验证。
  ON 时机械检查文件、提交、Git 状态，如果是 HOLD 则不发送并返回理由。
- 有只读判定角色的调用口，但实际发送未连接。
  不在时记录 `not_observed` 并使用机械检查结果，不将文章主张视为已判定。
  Hermes 仅准备了每轮的发送，不生成停止操作的 hook。

### Fixed

- 在 HOLD 判定时实际停止发送。
  不将版本号或邮箱地址误认为不存在的文件。
  无斜杠的表示要求已知扩展名。
- 即使 Hermes 的操作限制 hook 未对应也生成发送处理。
  对没有所需 home 设置的主机明确跳过。
  在列表中保留 team 和 agent 并显示，防止静默的未送达。
  布线检查确认实际的生成物。


## [5.12.0] - 2026-08-24

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5120---2026-08-24) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L225)

### Added

- Codex Breezing 施工角色根据管理对象的角色设置或中央分配使用 `gpt-5.6-luna`/`max`。
  外部辅助处理不接受的 `max` 转换为 Codex 执行设置。
  判定角色、建议角色、高性能枠保持 `gpt-5.6-sol`/`xhigh`。
- Codex 审查向本地 app-server 中继明示模型、判定模型、推理量。
  `review --commit` 在启动前拒绝，仅记录成功的委托。
  将中断传递给辅助处理和中继，最大 1 秒后终止残留子进程并回收。

### Changed

- Codex 版更新后重新执行初始设置，重启 Codex。
  预检后，仅备份并批量迁移 Harness 所有的旧通知设置 2 种格式。
  不改变自定义设置或模糊格式并失败。
  添加未设置的 `features.multi_agent` 和 `features.default_mode_request_user_input`。
- 向 Claude 版和 Codex 版附带施工角色、判定角色设置和审查辅助处理。
  Codex 版还包括范围外变更检查用的执行文件。
  如果主环境检查被拒绝则不启动执行目标。
  主会话和明示的执行目标是施工角色默认固定的对象外。
- 将发布步骤对齐到用标签启动的处理和发布后的验证。
  Windows 命名管道仅用测试输入和静态检查确认。
  实际 Windows 的 app-server 执行未观测到。


## [5.11.0] - 2026-08-22

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5110---2026-08-22) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L242)

### Changed

- 将删除策略的默认值从 `ask` 改为 `warn`。
  静态无法确定的项目相对目标记录警告并继续。
  外部路径、`..`、未解析变量、glob、单独的 `.` 继续确认。
  可以用 `HARNESS_DESTRUCTIVE_DELETE_POLICY=ask` 或项目设置恢复传统默认值。
- 将明示的非法值恢复为 ask。
  当项目根目录下有不想丢失的未跟踪数据以及保护处理开发时，用 TOML 的 `destructiveDelete = "ask"` 或 YAML 的 `safety.destructive_delete: ask` 选择传统确认。
  不改变执行前限制。


## [5.10.0] - 2026-08-22

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5100---2026-08-22) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L248)

### Added

- 添加了 `destructive_delete = ask | warn`。
  设置位置是 YAML 的 `safety.destructive_delete`、TOML 的 `[safety.permissions] destructiveDelete`、`HARNESS_DESTRUCTIVE_DELETE_POLICY`。
  本版本的默认值是 ask。
  warn 时以 `R05_WARN` 警告允许无法确定的项目相对路径和自会话临时区域的删除并记录。
  外部路径、`..`、未解析变量、glob、单独的 `.` 和 `/` 确认。
  优先后续的拒绝和确认规则。
  符号链接仍有已知的检查局限。

### Changed

- 将发布标签统一为仅 `vX.Y.Z`。
  保留以前带插件名的标签作为历史。
  安装不依赖这些标签。
  日英 README 整理了重复的表和链接，保持对应分类。


## [5.9.0] - 2026-08-17

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#590---2026-08-17) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L259)

### Added

- 对安全风险选择运行时检查，对画面风险选择浏览器检查。
  批准时不能悄悄降低检查阶段。
  浏览器环境不足时记录为未验证。
  验收判断读取保存的执行结果，不将未验证条件设为可发货。
- 作业范围的检查用 `[scope_leash] enforce_level = off|warn|enforce` 选择，默认是 warn。
  在执行前检查声明外的写入，通知停止时落下的范围。
  将施工报告保存到 `.claude/state/review/`。
- 可以将 Playwright 录像作为浏览器验证证据嵌入接受 HTML。
  没有录像时用带理由的文章保留。
  计划和审查时进行 1 次再调查，考虑与最初不同系统的方案 1 个。
- 日语文章检查默认 OFF。
  用 `writing_lint.enabled` 启用。
  使用个人的 JSONL 字典，检查 Markdown 和文本、句末连续、文体混在。
  写入后仅提供建议。
  重大意见残留时停止 1 次，重新进入时警告。
  只有本人的 `scripts/writing-rule-approve.sh` 才能将规则草案正式注册。
- 计划、进度、接受画面对应智能手机。
  在进度画面显示文章规则的批准等待。
  安装后可以用 diagram-design 绘图。
  将完成条件分为机械检查、文章判定、目的。
  任意基准不看接收方检查，仅针对说服用文书。
  判定角色使用新会话、固定基准、绝对评价、实物确认。
- 将 writing_lint 和 quality_pack 正式包含在设置格式中。
  施工步骤在保持批准边界的同时，不被通常的临时区域清理阻止本人工作。
  验证的联动也在插件检查中确认。

### Fixed

- 会话历史警告在 600 行超限和存在可退出项目两者同时满足时才发出。
  保留 30 天内的项目，无法读取日期的项目计为可退出。
  维护时在末尾保留 2,000 行委派、读入指示、会话事件、变更文件记录。
  有 agent-trace 时是 1,000 行。
- 子目录操作追溯到最近的 `.harness` 或 `.git`，在 home 前停止。
  没有标记时使用原始工作位置。
  在同一根目录下判定保护设置、预批准、测试优先设置、工作模式。
  `.claude` 不作为标记。
- 除重定向和 `tee` 外，还检查 `ln`、`cp`、`mv`、`install` 对保护路径的写入。
  以最后明示的发送目标为对象，发送目标是隐式 1 参数形式的不在对象内。
  Grok 的公开检查接受有意附带的声明、hook、执行文件。

### Changed

- 将 SQLite 从 1.55.0 更新到 1.56.0，jsonschema/v6 从 6.0.2 更新到 6.0.3，重新生成了 4 个平台的执行文件。
  相关版本是 libc 1.74.4、go-isatty 0.0.24。
  向 Grok 版附带 hook，`harness gen` 用 `--host grok` 生成 `.grok/hooks/harness-pretool.json`。
  实机的项目 hook 读入已确认，但分发物的重新安装和读入未确认。
- `--parallel N` 是同时执行的期望值。
  实际执行数由 Claude Code 决定。
  当时的默认值是 20，超出部分等待。
  嵌套启动的默认值是深度 3。
  Harness 不覆盖这些标准值。


## [5.8.0] - 2026-08-14

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#580---2026-08-14) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L401)

### Added

- 可以向 Grok 委托无画面工作。
  默认只读，检查范围外变更，隐藏秘密。
  如果没有 Grok 执行文件则作为未设置返回退出代码 3。
  修正迭代将次数、判定、意见保存到 `.claude/state/repair-loop/`，从该记录检查 `MAX_REVIEWS`。
- 任意 `--blind-judge` 添加不看基准的接收方。
  针对公开画面文章、文书、理解负荷的 HTML。
  代码、试验、设置、格式定义不在对象内。
  差异作为建议保留，不覆盖主判定。

### Changed

- 根据实际账户列表更正了 Grok 分配。
  轻量枠和通常枠是 `grok-4.5`，高性能枠、建议角色、判定角色是 `grok-4.6`/xhigh，公开和长文枠是 `grok-4.6`/high。
  两者都有 500k 输入枠，但 4.5 不接受 xhigh。
  以前的依据是同名的别 CLI。
- 根据目标判断删除确认。
  项目内和包含自会话 ID 的临时区域可以推进。
  临时区域根目录、别会话、范围外链接、glob、模糊变量和替换、xargs 的追加对象、记忆区域的递归删除确认。
  绝对路径管道和单次字面赋值可以解决。
  有单引号内或转义的 `$` 时不进行变量解析。
- 记录了标准的并发数、深度、通信目标限制、认证信息的掩码处理。
  macOS 的掩码处理返回拒绝，因此 denyRead 的替换仅作为提案。
- 确认的 Grok 列表是 4.6 受理 low、medium、high、xhigh，4.5 受理 low、medium、high。
  Claude 标准的 `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`（默认 20）和 `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`（默认 3）是执行源的设置，不是 Harness 设置。

### Fixed

- Cursor 执行文件探索先确认 `agent`。
  因为是通用名，仅在解决路径的元素与 Cursor 的识别名一致时才采用，不启动未知执行文件来查明身份。
  区分记录了 Grok 的标准 hook 能力和 Harness 分发不足。
  本版本的生成仍未对应。


## [5.7.0] - 2026-08-12

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#570---2026-08-12) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L427)

本版本还记录了 Claude Code 不读取 `.claude-plugin/settings.json` 权限规则的缺陷。
仅分发规则不能作为对话中生效的证据。
请用 `/permissions` 确认有效规则。

### Fixed

- `harness work-mode` 使用实际会话 ID。
  按 `--session-id`、export 的 `HARNESS_SESSION_ID`、2 小时内最新 hook ID 的顺序解决，拒绝旧监视 ID。
  会话结束时解除，残留状态在 24 小时后过期。
  实际 ID 的测试通过了，但向新 Claude 会话反映环境文件需要发布后确认。
- Codex 模式的直接写入禁止和判定角色的写入禁止现在可以读取 Breezing 状态和原生角色识别。
  判定结果在字符串上和链接解决后都位于 `.claude/state/` 内时才能写入。
  拒绝父引用和链接逃脱。
  要求角色注册的 agent_id，不将 leader 误判为判定角色。
- 省去对 `~/.claude/projects/<slug>/memory/**` 和 `~/.claude/plans/**` 的写入确认。
  不将设置、skill、角色、命令、hook、插件、相似名称的备份区域作为例外。
  不改变范围外的检查。
- 修复了 grep 早期终止和 pipefail 导致测试误失败的问题。
  更正了汇总合并后的计划内提交参照。
  浅复制时将可达性作为未观测处理，不设为已验证。
- 以前的全局指定 `HARNESS_WORK_MODE=1` 在非施工中也省略了项目外的写入确认。
  本版本记录了该局限，准备了会话单位的工作设置。
  保持保护路径的拒绝和范围外的破坏检查。

### Added

- `harness work-mode on|off|status` 可以操作会话单位的状态。
  无法识别时失败，保持现有会话信息。
  测试判定条件的值和设置有实际供给源，不进行手拼输入验证。
- 更改了 Grok 的模型分配，但参照的列表后来发现是同名的别 CLI。
  请在使用前的设置前确认 5.8.0 的更正。
  本版本 Codex 的 max 受理未确认因此保持了 xhigh。
- 之后更正当时的 Grok 表选择了 grok-3-mini (low/high)、grok-4.20-non-reasoning、高性能、商量、判定、公开用 grok-4.3，长文用 grok-4.20-0309-reasoning。
  从操作角色中排除了响应专用多角色模型。
  此表使用了别产品的列表，在 5.8.0 中已更正。

### Changed

- 在保护步骤中区分了仅对代理的权限设置和 hook、OS 强制子进程整体的隔离。
  强限制缩小范围，在扩大到全局设置前在 1 个项目试用。
  excludedCommands 仅匹配启动名，不继承子进程权限。
- 将会话历史警告从 500 行提高到 600 行。
  保持 30 天保留和 `SESSION_LOG_MAX_LINES` 覆盖。
  将 x/sys 从 0.46.0 更新到 0.47.0，SQLite 从 1.54.0 更新到 1.55.0，重新生成了执行文件。
  也更新了 CI 处理和基准测试，agent-eval 是 1.4.0。
- 将 CI 用 CodeQL 从 4.37.1 更新到 4.37.3、Scorecard 从 2.4.3 更新到 2.4.4、setup-python 从 6.3.0 更新到 7.0.0。
  未使用已删除的 pip-install 输入。
  20 个基准测试设置在 agent-eval 1.4.0 中用密钥改名通过了类型检查。

### Security

- 将基准测试依赖更新为审计过的 agent-eval `~1.4.0`、undici `^7.29.0`、nanoid `^3.3.17`、brace-expansion `^5.0.9`。
  消除了 3 个高危险度，5 个低危险度留在 moderate 检查阈值以下。
  使用中的 CLI 和 ExperimentConfig 在类型检查上保持兼容。


## [5.6.0] - 2026-08-01

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#560---2026-08-01) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L618)

### Security

- 秘密读取例外在解决相对路径和绝对路径后检查是否在 worktree 内。
  也拒绝指向范围外的链接。
  代理不能编辑 `.claude-code-harness.config.json` 和 `.yaml`。
  releaseAuto 的更改是本人手动编辑。
  可以写入公开用设置模板。
- 保护分支检查识别开头 `+` 的强制 push 指定。
  确认 `git push origin +main` 和 `+refs/heads/main`，拒绝保护目标的 hard reset。
  保护外的 `+feature/x` 与以前相同。

### Added

- 每轮指示回答语言。
  按项目 YAML 的 `i18n.language`、`CLAUDE_CODE_HARNESS_LANG`、英语的顺序决定。

### Fixed

- 将语言介绍在运行时读取修正为 YAML。
  在保护功能测试中不让本人的例外设置继承，防止检查无效化和后续检查未执行。
- 修复了 macOS 进度更新中中断后仍使用唯一临时文件名的问题。
  还修理了其他 9 处临时文件和 173 处 pipefail/grep 检查，添加了复发检查。
  保持判定条件。
  静态检查不针对用变量或函数间接组装成的命令。
- 修复了让本人按介绍调用 `/harness-plan-brief`、`/harness-progress`、`/harness-accept`。
  保持 Cursor 分发的显示设置的传统转换。


## [5.5.0] - 2026-07-29

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#550---2026-07-29) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L732)

### Fixed

- 即使在自律执行中也能检测 worktree 外的 GNU 长形式递归删除和 find 删除。
  在传递给 shell 执行的 heredoc 中检查秘密读取，不误检测文档正文或注释中的删除命令表示。
- 秘密读取的预批准仅在当前目标作业一致时才反映。
  不保留到无关的未来执行。

### Added

- 将警告、确认、拒绝记录到 `.claude/state/audit/guardrail-fires.jsonl`。
  不记录通常的许可。
  不保存命令和路径的原始值，仅保留哈希和长度。
  在秘密读取和计费中也省略这些。
- 链接解决后位于 OS 临时区域或缓存内的写入省去确认。
  worktree 内的递归删除也仅在能确认全部对象都在内部时才省去。
  确认动态目标、前置命令、管道、后台执行、父引用。
  未跟踪和未提交的文件可能丢失。
- 保护分支 push 预批准要求有效期、作业范围、命令匹配、次数上限。
  默认上限是 10 次，每次使用递增。
  范围未解决时确认。
  对象仅是保护规则 R12，不改变 5 种执行前限制。


## [5.4.0] - 2026-07-26

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#540---2026-07-26) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L810)

### Added

- 可以用 `bin/harness inbox send --team <t> --from <id> --to <agent> "正文"` 个别联系。
  用 `inbox sent` 查看已读。
  在轮次边界发送，去除控制字符作为数据处理。
  上限是每件 768 字节、合计 4,096 字节。
  危险操作的批准仅在该对话的控制台进行。
  没有未读时不显示。
- 用 `session declare --task <id>` 和 `session list` 可以查看名称、工作、经过时间。
  合并共享名牌和本地列表，也显示 Git 外的对话。
  Codex 和 Cursor 的发送按环境变量、hook 的 session_id 顺序解决目标。
  不明时警告但不停止工作。
- `/breezing` 必要时进行计划、实现，在新会话中最多进行 3 轮审查和 Codex 的别判定并报告。
  未指定范围的计划以当前可着手的全部作业为对象，显示必、需要、任意、排除及理由。
- 验证受理 `claude-opus-5`。
  将常读规则从 103.2KB 减少到 29.2KB，保持批准和拒绝的契约。
  将场景别步骤移至参照先。

### Changed

- 将标准施工目标改为 Claude 的原生辅助。
  可以用 `--backend codex|cursor` 更改。
  Claude 的高性能枠和建议角色是 Opus 5/xhigh，Fable 也可选，通常判定是 Fable 5/xhigh，施工角色是 Sonnet 5。
  Cursor 的高性能枠是 Fable 5/xhigh。
  Codex 的通常、高性能、判定、建议角色保持 GPT-5.6-sol/xhigh，公开和长文是 high，轻量枠是 GPT-5.4-mini。
- 在会话压缩前自动提交仅更改的 `Plans.md`。
  不包含其他文件。
  提交失败或 `precompactAutoCommit: false` 时按以前停止。

### Fixed

- 文件使用权限用共享名牌和本地列表确认生存。
  也保护其他 worktree 的对话在 60 分钟期限后。
  没有共享名牌时恢复传统判定。
  未完成任务导致的停止禁止仅限首次，重新进入时警告并允许停止。
  修复了调查会话无法结束的迭代。

### Removed

- 从模型候选中排除了 Opus 4.8。
  `HARNESS_BRAIN_MODEL=opus` 和 `opus5` 都选择 Opus 5。


## [5.3.1] - 2026-07-20

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#531---2026-07-20) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L912)

### Fixed

- 进度和开始时的件数读取实际任务的 Status 栏，不区分大小写地按当前和旧表示读取。
  修复了由凡例、例、本文提及造成的虚假工作中件数和偏差警告。


## [5.3.0] - 2026-07-19

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#530---2026-07-19) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L926)

### Changed

- 将验证过的执行步骤中的 Codex CLI、Cursor、Grok 设为正式对应。
  不是能力相同的声明。
  Cursor 没有文件系统隔离，Grok 没有 Claude 形式的操作前限制，Codex CLI 的 Bash 限制不表示 Codex app 的同等性。
  不提升 Codex app、OpenCode、Hermes、Copilot CLI、Antigravity。

### Added

- 用项目 JSON 的 `runtimefloor.releaseAuto: true` 可以任意允许版本标签 push 和非破坏性 GitHub 发布操作。
  默认 OFF，设置不存在或解析失败时拒绝。
  删除发布物、npm 发布、Vercel、Kubernetes、Terraform 继续拒绝。
  发布前要求全部发送目的地的执行检查，有一个失败就停止。

### Fixed

- 将基准测试的 20 个测试用项目中的 Vitest 更新到 `^4.1.0`，对应 CVE-2026-47429。
  provider-utils 的低危险度 1 件因上游未修复而保留。
  检查最低版本。


## [5.2.0] - 2026-07-17

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#520---2026-07-17) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L949)

### Added

- `harness release --check` 不改变版本而提出更新方案。
  条件是从最后版本标签起 7 天、有 Security 项则 2 天、有 Breaking 标题则立即。
  退出代码始终为 0。
  开始时仅显示候选，不将检查不能作为无候选的实证。

### Added

- 独立的测试布线审计仅建议追加，不服申述限 1 次。
  写入后警告测试删除、`|| true` 添加、`set +e`、判定条件减少。
  不拒绝操作。
  将 Hermes、LSP、发布能力主张检查连接到 CI。

### Changed

- 将别仓库的交接对齐到 harness-mem 的工作记录。
  版本管理参照处理 6 文件 7 表示的 `scripts/sync-version.sh`。
  发布方案不计数带插件名的标签，也认识 Breaking Changes 标题。

### Fixed

- 在各环境构建中将 Go 固定到 go.mod 指定，重新生成检查与执行文件的版本管理元数据一致。
  重新添加跟踪的调查 7 文件后，不因 gitignore 默默排除。


## [5.1.0] - 2026-07-16

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#510---2026-07-16) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1013)

### Added

- 初始设置识别 Maven 和 Gradle 的 Java、Kotlin。
  两者都有标记时优先 Java，介绍对应的测试命令和命名。
- 添加了记录对应分类的列表和结构检查。
  Grok 是 `--check` 附带初始设置、专用分发、分配的内部兼容枠。
  本版本公开上的正式对应仅限 Claude。
  Hermes 是手动链接的候选，没有初始设置、分发、模型分配、同等的操作限制。
- 在重复搜索相同识别符或进行多模块同型修改前，使用语法结构搜索。
  在 Harness MCP 连接的 TypeScript 和 TSX 补全确认中要求语言服务器诊断。
  不停止其他格式和未连接。
  参照、定义、hover 调用未连接。
- 最初的 Grok 分发和分配指定了 grok-4.5 和 grok-composer-2.5-fast。
  在后续版本中更正了列表的依据。
  不要将当时的 ID 作为当前的安装步骤使用。

### Fixed

- 完成后报告以日语指定否则默认英语。
  也在 Windows 上确实进行工作中的停止检查。
  生成跳过明示的未对应主机，防止中途生成后失败。
  发布标签与 VERSION 不一致时不发布。
- 公开模板 `.env.example`、`.env.template`、`.env.sample`、`.env.dist` 仅允许完全匹配的名称写入和 staged。
  拒绝追加后缀、本人秘密、秘密区域嵌套、指向秘密的链接，即使在改变工作位置的 Git 命令中。
  不能用部分备注隐藏检查已对应的主张。
- 向 Codex 版附带所需的列表辅助处理，用空指定覆盖 Claude 专用角色 hook 和异步 hook。
  Codex 和 Cursor 生成 hook 仅使用对应键，保持共享命令检查和发送。
  Cursor 未设置是退出代码 3。
  将介绍和测试对齐到出货的内部兼容分类。


## [5.0.0] - 2026-07-08

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#500---2026-07-08) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1129)

### Breaking Changes

- 将 skill、hook、分发的重新设计从 4.x 系切换到主流。
  从 4.16.x 更新后请执行 `/reload-plugins`。

### Added

- 计划时按作业范围预先确认秘密读取、外部发送、破坏操作。
  停止未声明的操作。
  执行判定的追加连接在后续版本进行。
  秘密许可路径用 `HARNESS_RUNTIME_FLOOR_SECRET_ALLOW` 或 JSON 的 `runtimefloor.secretAllow` 声明。
  拒绝全开放、非法设置、项目外绝对路径。
- `harness doctor` 警告 7 天以上旧或 Git 未注册的 Harness worktree。
  启动处理从获取的 1 个基准提交创建 worktree。
  清理仅处理 Harness worktree 和对应分支，有未保存变更时默认跳过。
  删除需要 force，拒绝从对象内执行。
- 执行前的 5 项限制对象是计费、外部通信、秘密读取、生产发布、worktree 外的破坏。
  允许有限范围地清理 OS 临时区域和缓存。
  在施工前后比较设置和认证信息保存位置，在范围外写入时停止。
  通常的执行缓存不在对象内。
  要求比较检查能执行才能进行任意自动许可。
- 并行作业的集成对齐到基准，引入未提交，检查契约后提交。
  失败时恢复 worktree。
  共享追加文件决定负责，worktree 内不升级版本，生成物在本流 1 次重新生成。
- Failure Codifier 从失败中只读提出规则提案。
  3 次 medium、5 次 high 置信度，正式采用由本人进行。
  判定历史保存为追加专用，按项目保存，可以用字符匹配参照过去 3 件。
  两者都不自动更改规则。
- Night Watch 默认 OFF (`NIGHT_WATCH_ENABLED=false`)，需要任意安装。
  报告未解决迭代、72 小时停滞作业、168 小时未决判断。
  用文件更新时刻测量工作陈旧度。
  复制检查分为一致、偏差、未设置，自动同步 OFF。
- 用退役名称列表检查迁移残留。
  Breezing 的自由文委托可以分割确认为 3～7 任务，否时不执行。
  Claude 的高性能枠可以用 `HARNESS_BRAIN_MODEL=fable` 选择 Fable 5。
  未指定是 Opus 4.8，未知值失败。
- 在 Cursor 实机上确认操作前拒绝，将 Shell 名对齐到 Bash。
  对应分类保持候选。
  AppleScript 仅允许应用的显示和启动，不通过 System Events 注入输入。
  标准功能列表分为观测到和版本未确认。
- 将自我学习引入计划与出货功能分开记录。
  自动规则提升和批准 OFF。
  记录外部施工和集成的结果，区分尝试、失败、完成。
- 可以用 `bin/harness wt fingerprint capture/diff` 确认监视的变更。
  对象是 Claude 设置和插件注册、认证区域 `~/.aws/`、`~/.ssh/`、`~/.gnupg/`、`~/.config/gcloud/`、`~/.netrc`。
  排除通常的 Claude 项目记录和缓存写入。
  通过前后比较检测，不是 OS 的文件隔离。
  比较命令不成功时也将 `HARNESS_AUTO_APPROVE=on` 恢复为 OFF。

### Changed

- 将自我审查定义为同一模型系列而非施工会话状态的共享。
  可以在新 Cursor 会话的建议后、主判定前使用，但不移换主判定。

### Fixed

- 公开 skill 将发布传递给标签启动处理，验证非草稿 GitHub Release 和 4 个以上附件。
  安全审查明示已批准审计的范围，使用隔离的新 Sonnet 4.6 会话。
  将还原内容限定为判定、件数、地点、修正方针，减少因模型保护导致的中断。
  不是无停止的保证。


## [4.16.4] - 2026-06-28

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4164---2026-06-28) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1241)

### Changed

- 对许可列表外主机发送的命令（`curl`、`wget`、`nc`、`scp`、`rsync`）每次执行都确认。
  在自己观察的调查会话中可以去掉仅此确认。
  在启动 Claude Code 前设置 `HARNESS_RUNTIME_FLOOR_EGRESS=off`。
  在启动 shell 中 `export`，或在 `~/.claude/settings.json` 写入 `{ "env": { "HARNESS_RUNTIME_FLOOR_EGRESS": "off" } }`。
  仅在值为 `off` 时去掉，未设置和其他值继续确认。
  值从对话启动者的 hook 执行环境读取，因此隔离的施工角色或被注入指示的施工角色无法更改。
  无法去掉计费、秘密读取、生产发布、worktree 外破坏的确认。


## [4.16.3] - 2026-06-24

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4163---2026-06-24) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1267)

### Fixed

- 向重新加载插件的分发和缓存附带直接调用的 hook 脚本。
  不使用不足的旧根。
  在 Codex 的 `breezing --cursor` 中包含辅助脚本，可以启动。
  推理量未指定时传递默认值。


## [4.16.2] - 2026-06-24

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4162---2026-06-24) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1291)

### Fixed

- 也向公开版本添加了执行前的安全确认。
  以前仅存在于手头测试版。
  5 种操作一定回到本人确认，显示 `RUNTIME_FLOOR:<category>`。
  对象是计费、外部发送、秘密读取、生产发布、worktree 外删除。
  本版本无法通过设置或环境变量去掉。
  仅外部发送确认在 4.16.4 可以去掉。
  允许清理 OS 临时区域和缓存（`/tmp`、`/var/tmp`、`/private/tmp`、`$TMPDIR`、用户缓存）。
  继续确认在 `~/Desktop`、`~/Documents`、`/etc`、`/opt` 中的删除。
- `/harness-release` 在发送标签时结束。
  GitHub Release 的发布由该标签运行的 GitHub Actions（`.github/workflows/release.yml`）进行。
  因为要停止 Claude Code 2.1.183 以上的发布命令本身。
  此后每 5 秒最多 60 次（约 5 分钟）确认非草稿且附件 4 个以上的发布物。
  超时因标签已发送而不作为失败而作为警告。
  推定（高置信度，本版本脚本）：在标签发布处理没有的项目中无法生成发布物。
  附件不足 4 个的项目即使发布成功也以警告结束。
- 拒绝将秘密文件明示给 Git 的操作。
  目标命令是 `git add`、`git stage`、`git commit <路径>`。
  目标文件是 `.env`、`.env.local`、`.env.production`、`*.pem`、`*.key`、`*.p12`、`*.pfx`、`id_rsa`、`id_ed25519`、`secrets/`、`.ssh/`、`.aws/`、`.npmrc`、`.pypirc`、`credentials`。
  要从对外发送的 Git 历史中去除秘密，通常需要重写历史和强制更新。
  Harness 用强制 push 规则拒绝此操作。
  不能保证消除他人获取的副本。
  即使在新提交中删除文件，旧的仍留在历史中。
  提交正文的字符（如 `-m "fix .env loading"`）不作为路径处理。
  批量 `git add .` 和 `git add -A` 保持允许，交给 `.gitignore` 和现有写入保护。
  也检查通过 `git -C <dir>`、`$(...)`、反引号、引号、转义引号隐藏的方式。
- 添加了日英术语表 `docs/onboarding/glossary.md`，可从 README 安装步骤打开。
  说明生成物中出现的 spec（产品规范）、contract（合议条件）、`cc:完了`（完成已验证）、置信度%等。
  本版本置信度参考是 75% 以上进行、40～74% 注意、40% 以下商量。
  是判断辅助，不是成功概率的保证。


## [4.16.1] - 2026-06-19

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4161---2026-06-19) | [原始提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1355)

### Fixed

- 将 `/harness-review` 和 `/harness-release` 内审查出现的 APPROVE 保存到 `.claude/state/review-result.json`。
  这样下次 `git commit` 不会因 "Run /harness-review before committing" 而停止。
  也在判定角色结束时工作的 hook 中保存，判定角色保持只读。
  仅更改 `VERSION`、`.claude-plugin/plugin.json`、`harness.toml`、`CHANGELOG.md` 的提交和合并不消费批准。
  因此发布时的版本更新提交通过。
  将判断保留在 `.claude/state/commit-cleanup-audit.jsonl`。
  Git 无法使用时传统删除批准。
- 缩短了 skill 说明以减少截断风险，但合计仍超过 6,000 字符目标。
  在 `docs/i18n.md` 中说明输出语言的决定方式。
  优先顺序是 `.claude-code-harness.config.yaml` 的 `i18n.language`、`CLAUDE_CODE_HARNESS_LANG`、默认英语。
  也可以每会话委托。
  机械用 JSON 和提交前缀保持英语。
  安全判定不写攻击代码仅展示事实。
  模型侧安全功能导致判定角色中途停止的情况仍存在。
  `docs/known-limitations.md` 建议切换到 Opus 4.8 或人工审查以安全为中心的变化。
## [4.16.0] - 2026-06-18

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4160---2026-06-18) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1393)

### Added

- 通过 `HARNESS_SESSION_RELAY=monitor|both` 可以启用会话间的单独通信。
  默认关闭。
  Claude 以 5 秒间隔进行监控，Cursor 和 Codex 在辅助处理中接管。
  正文是数据而非审批。
  即时配送仅在 Claude 之间进行，不与 harness-loop 组合使用。
  通过 waitingFor 的提示识别超过 10 分钟的作业停滞。
  通信内容存储在 Harness 内部（`.claude/sessions/relay-signals.jsonl`），不调用其他工具。
  harness-mem 的消字处理生效。

### Fixed

- 创建新的 harness.toml 配置时，不会覆盖现有文件或其他插件的声明。
  仅在没有同步目标时跳过"无钩子"提示，若仅保留同步目标则报错。
  Windows 的记忆命令通过执行环境启动 JavaScript。
  末尾显示遵循所选语言。
  修正了 `setup-codex.sh --project` 复制到项目中的 `AGENTS.md`。
  Codex 已支持钩子，而 Harness 当时未连接，暂定保护写入 `.codex/rules/`。
  推测（中等置信度）：此版本前复制的版本在重新复制前会保留"钩子未连接"状态。
  统一了 Cursor 的依据文档至内部兼容分区。

## [4.15.0] - 2026-06-05

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4150---2026-06-05) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1447)

### Added

- 将「施工角色不能改写约束自己的设置」这一承诺的正本放在 `harness.toml`。
  将 4 条拒绝规则复制到分发的 `.claude-plugin/settings.json`。
  对象是针对 `.claude/settings*` 和 `.claude-plugin/settings*` 的 `Edit`（部分编辑）和 `Write`（文件写入）。
  4 条中任何一条缺失都会导致 CI（自动检查更改的处理）失败。
  之后 5.7.0 的记录指出 Claude Code 不读取插件的 `.claude-plugin/settings.json` 的 `permissions`。
  当时的运行环境未重新测试。
  [当前插件设置的官方规格](https://code.claude.com/docs/en/plugins-reference#settings) 中适用的只有 `agent`（默认角色）和 `subagentStatusLine`（施工角色的状态显示）。
  文件中有规则并不构成当时保护已生效的证据。
  要应用拒绝规则，需写入本人的用户设置或项目设置。
- 在 `/harness-review` 和诊断会话使用的自我审计中增加了检查项。
  读取 `.claude/settings.local.json` 的 `hooks`，指出所有者未预期的 `command` 型钩子。
  因为此文件通常在 Git 管理外，不经过代码审查。
  这是执行审计时的检查，不是常态监视。

### Changed

- 将对 `.claude-plugin/settings.json` 和 `.claude/settings.local.json` 的写入分类为保护路径的警告。
  与 `.claude-plugin/plugin.json` 同等处理。
  成为对绕过拒绝规则路径（如 shell 重定向）的警告。

### Fixed

- 委托的累计也包括会话途中的记录，修复了开始和结束之间的遗漏。


## [4.14.0] - 2026-06-04

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4140---2026-06-04) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1491)

### Added

- 将对 Codex 和 Cursor 的委托逐行记录到 `.claude/state/orchestration-ledger.jsonl`。
  项目包括委托对象、操作、写入有无、结束代码、耗时、Session ID。
  不记录委托正文和秘密。
  状态确认和设置确认的查询不计数。
  项目累计保存在 `orchestration-totals.json`。
  可以用 `harness-orchestration` skill 生成可共享的 HTML 汇总表。
  各委托对象表示使用中、设置完毕未使用、未设置之一，未设置不视为异常。
  全作业完成时仅在终端输出一次摘要。
  是执行量的指标，不是品质或完成的证明。


## [4.13.3] - 2026-06-01

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4133---2026-06-01) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1517)

### Fixed

- 修复了 Cursor 初次使用时辅助文件探索、前提条件、作业树整合、失败显示。
  恢复了同一 PC 的文件使用权限、对话注册、编辑冲突通知、Go、Markdown、shell 的全员通知。
  是协作建议而非强制锁定。
  不与别的副本和 PC 共享，通知以追加方式增加。
  整理接收正文，作为数据处理。
- Cursor 留下未提交更改时，Leader 在作业树内汇总为 1 次提交后再纳入。
  此提交用 `--no-verify` 跳过钩子，在主流侧提交时通过通常保护与 pre-commit。
  提交信息如设定 `TASK_SUMMARY` 则使用，否则为 `cursor: cursor-do delegated change`。
  辅助脚本按 `CLAUDE_PLUGIN_ROOT`、`HARNESS_PLUGIN_ROOT`、`CLAUDE_PROJECT_DIR`、当前文件夹、已安装插件的顺序查找。
  找不到则以结束代码 2 停止。
  作业树路径为 Git 根起的绝对路径。
  使用权限在同一仓库的作业树之间共享。
  60 分钟经过和所有者注册消失同时发生时失效，整理超过 24 小时的注册。
  无法访问 Git 管理外或使用权限保存位置时，不含使用权限、无警告地继续编辑。
  接收以路径、发送者、经过时间仅 4,096 字节以内传递，通知正文被丢弃。

### Changed

- Breezing 和 Cursor 委托以开始显示和 2〜4 段的计划合计 5 行以内显示，中途结果也简短传达。
  改掉了仅 1 行开始就沉默的行为。


## [4.13.2] - 2026-05-30

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4132---2026-05-30) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1616)

### Added

- `/cursor:ask` 以只读方式将提问、调查、设计咨询传递给 Cursor（composer-2.5-fast）。
  答案由 Claude 摘要为 3〜5 行。
  `/cursor:do` 将 1 件写入作业通过专用作业树（`.claude/worktrees/cursor-do-<id>`）委托给 Cursor。
  Leader 确认差异后纳入，将 Plans.md 的作业标记为 `cc:done [hash]`（完成的识别符）。
  两者都需要预先设置。
  `.cursorignore` 隐藏 `.env`、`*.pem`、`*.key`、`.ssh`、`.aws`、`.git`。
  在 `~/.claude/settings.json` 的 `sandbox.network.allowedDomains` 加入 `*.cursor.sh`，在 `sandbox.filesystem.allowWrite` 加入 `~/.cursor`。
  Cursor 本身无法将文件写入限定在特定文件夹。
  写入安全通过专用作业树、Leader 的差异确认、经由 Harness 的保护纳入来维持。

### Changed

- `/harness-review --cursor` 将 Cursor 作为建议的别意见加入。
  判断由主审查决定。
  主审查为 REQUEST_CHANGES（需修改）时为驳回。
  主审查为 APPROVE（批准）时，即使 Cursor 反对也维持批准，记录差异。
  `--dual --cursor` 由 Claude、Codex、Cursor 三方审视。
  `/breezing --cursor --reviewer-only` 仅将审查委托给 Cursor。
  用于 Anthropic 使用限制或 Codex 审查认证失败时。
- 为 Opus 4.8 调整了指示。
  深度推理不以「ultrathink」文字而以推理量指定。
  复杂度分数 3 以上为 `high`，含代码风险为 `xhigh`。
  审查在判断前以重大度和置信度记录所有指摘。
  明确了并行施工角色的启动条件。
  咨询角色改为 Opus 4.8。
  施工角色和判断角色保持 Sonnet 4.6。
  缩短了开始显示，在 4.13.3 中放宽。
- 按分发目标使用内部 skill 路径，不包含别的分发目标的信息。
  对 Cursor 的引入通过 `scripts/setup-cursor.sh` 复制实文件夹。
  因为 Cursor 拒绝 `~/.cursor/plugins/local` 的链接。
  `scripts/setup-cursor.sh --check` 仅生成分发物并检查，不进行引入。
  在 Cursor 中将 Harness workflow skill 显示为 skill 而非隐藏。
  Cursor 是内部兼容，不是公开上的正式对应。
  `scripts/diagnose-harness-skill-duplication.sh` 列举重复的 Harness skill 而不删除。
  清理步骤在 `docs/local-harness-environment-cleanup.md`。

### Removed

- 移除了无调用方的模板生成角色。
  初始设置和计划直接继续该作业。

### Fixed

- 检测 Git 钩子和省略签名的标志时，即使与 shell 分隔符相邻也能检测到。
  还修复了从旧 harness.toml 恢复 plugin.json 版本的问题。


## [4.13.1] - 2026-05-29

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4131---2026-05-29) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1679)

### Changed

- Claude 以外的施工将直接传递给 Codex 或 Cursor，而不启动额外的 Claude 施工角色。
  纳入前 Leader 加上公开主张、整合性、插件契约的检查。


## [4.13.0] - 2026-05-29

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4130---2026-05-29) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1686)

### Added

- `scripts/set-impl-backend.sh [--user] <claude|codex|cursor>` 可以选择施工目标。
  `/breezing` 和 `/harness-work` 的施工将传递到该目标。
  优先级为命令指定、`HARNESS_IMPL_BACKEND`、项目 `env.local`、本人 `~/.config/claude-harness/impl-backend.env`、最后是 Claude。
  判断和咨询始终保留在 Claude，不传递给选定的施工目标。
  因为施工目标不对自己的作业做判断。
  Skill 正文用 Opus 撰写，但此版本的判断角色定义为 Sonnet 4.6。
  Cursor 是本地任意使用的候选。
  不依赖输出，仅通过专用作业树、Leader 的差异确认、纳入来引入。
  读取委托以 ask 模式进行，不使用全自动化执行（`--force`）。
  `--debug` 或 `HARNESS_CURSOR_DEBUG=1` 将命令和错误输出到标准错误。
  遮蔽 `--api-key`、`--auth-token`、`Authorization:` 的值。

### Changed

- 施工整体的委托不采用 Cursor ACP 的逐次通信。
  逐次显示、埋入别 IDE、每操作权限需要时重新评估。
  Shell 整理不改变行为。


## [4.12.11] - 2026-05-28

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#41211---2026-05-28) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1704)

### Changed

- 增加了 Cursor 候补的分发、分配根据、静态检查。
  公开对应需要观测执行步骤，不主张同等的操作限制。


## [4.12.10] - 2026-05-28

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#41210---2026-05-28) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1724)

### Fixed

- 将公开的完成条件统一为反映到默认分支，以及从该分支可达的提交有 tag 和公开物。


## [4.12.9] - 2026-05-28

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4129---2026-05-28) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1730)

### Changed

- 介绍了 Claude 2.1.143〜152 和 Codex 0.131〜134 的禁止操作、skill 重新读取、消息显示、Codex profile。
  标准 Auto 模式同意变更也不改变 Harness 任意选择和拒绝的默认。


## [4.12.8] - 2026-05-27

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4128---2026-05-27) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1736)

### Changed

- 不简单的计划在确定前向独立的应援咨询。
  在计划中保留轻作业的例外和咨询的根据，记录日英提示的条件。
- 在计划中确认规格和作业的整合、过去记忆、产品价值、安全性、实际运行条件。
  不读取秘密的值。


## [4.12.7] - 2026-05-27

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4127---2026-05-27) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1748)

### Fixed

- Harness 自身的公开前检查中，确认自仓库的分支保护是否偏离审查条件。


## [4.12.6] - 2026-05-27

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4126---2026-05-27) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1755)

### Changed

- 在 main 的各 push 和变更提案上执行 CodeQL 漏洞检查。

### Fixed

- 继续 TOML 解析的异常输入测试，分发检查要求所有目标平台的钩子执行文件。

### Security

- 在简易引入和 Codex 更新提示中，废除了自动向全体添加任意工具的替代路径。
  此路径是通过不定版本 `npm install -g` 的引入和更新。
  任意开发工具通过 Homebrew 或指定版本的包管理命令引入。
  记录意图的执行文件分发、安全报告、分支保护的判断。


## [4.12.5] - 2026-05-27

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4125---2026-05-27) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1781)

### Fixed

- 修复了 Breezing 的 agent-eval 依赖，对应了残留的 Dependabot 漏洞指摘。
- 将 benchmark 的 undici、minimatch、uuid 对齐到修复版，试用作业指向跟踪中的评估对象。

### Security

- 添加了针对目标 benchmark 范围的 npm 更新和审计。
  不向一次性试用的项目注册大量更新提案。


## [4.12.4] - 2026-05-27

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4124---2026-05-27) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1796)

### Added

- 在 SECURITY.md 中记载了非公开的漏洞报告处和公开 issue 上的处理方式。

### Fixed

- 恢复默认英语。
  可通过指令、`i18n.language: ja`、`CLAUDE_CODE_HARNESS_LANG=ja` 选择日语。

### Security

- 在证据标签中拒绝绝对路径、父参照、嵌套、简单名称以外的内容。
  试验路径通过参数传递而非 shell 代码。
  YAML 路径也通过参数传递而不嵌入 Python 正文。


## [4.12.3] - 2026-05-25

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4123---2026-05-25) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1812)

### Changed

- 新的作业行使用 `pm:requested`、`cc:todo`、`cc:wip`、`cc:done`、`pm:approved`。
  现有的日语和大写表示法保持可读，不在未明示迁移的情况下整体重写。

### Fixed

- 在公开时的版本同步中包含了 Codex 的声明。
  保护理由可以用英语默认、日语选择。
  环境文件异常和孤立重复执行的回收保持已检查的行为。


## [4.12.2] - 2026-05-24

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4122---2026-05-24) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1830)

### Fixed

- 将 README 检查对齐到 Cursor 导引、5 个基本操作、Go 的保护处理、日语的任意选择。


## [4.12.1] - 2026-05-24

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4121---2026-05-24) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1836)

### Changed

- 引入日英 README，使执行步骤、对应范围、迁移可读，使用经批准的图。
  计划同时创建 spec.md 的产品规格和 Plans.md 的作业清单，留下规格变更或省略的理由。
  优先规格。


## [4.12.0] - 2026-05-23

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4120---2026-05-23) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1845)

### Added

- 可以从使用的 CLI 选择引入步骤。
  分开了 Claude、Codex CLI、OpenCode 的初始设置和对应极限。
  现有使用者在更改前看到只读的迁移报告。
  在健全性、分发、公开检查中确认分发内容，在 HTML 中留下整合和公开的判断根据。
  入口是 `docs/onboarding/index.md`。
- 此版本 Claude 为正式对应，Codex CLI 和 OpenCode 为内部兼容，Codex app、Cursor、Copilot CLI 为候补，Antigravity 为未对应。
  `harness doctor --migration-report` 调查旧缓存、操作不足、重复、链接、备份、记忆而不删除。
  OpenCode 的实环境同等性未观测。
  `release-preflight.sh --check-adapters` 检查保存状态、连接、复制、分发、能力、初始设置、CI。


## [4.11.4] - 2026-05-21

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4114---2026-05-21) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1889)

### Added

- 通信目标限制的手动步骤在 `docs/sandbox-allowlist-recipe.md`。
  说明 `HTTP/2 403 / x-deny-reason: host_not_allowed`（隔离环境中未允许连接目标的错误）。
  介绍允许 29 域名、拒绝 9 域名、排除 6 命令。
  `templates/sandbox-settings.json.template` 也改为相同内容。
  以前是 8 域名，`git clone`、`pip`、`go mod`、`cargo` 可能失败。
- 模板的完整复制仅限于 `~/.claude/settings.json` 没有 `sandbox` 键时。
  用 `jq 'has("sandbox")' ~/.claude/settings.json` 确认。
  现有则合并内容，保持 `filesystem`（文件访问规则）和 `failIfUnavailable`（隔离失败时停止的设置）。
  备份设置，合并数组，保持文件权限。
  检查主机完全一致，完全重启 Claude。
  新设置恰好允许 29 件、拒绝 9 件。合并后会超过。
  Firecrawl 需要 `FIRECRAWL_API_KEY`。
  本人设置此角色不自我编辑。
- 拒绝 9 域名是云 metadata endpoint（内部服务信息获取处）和粘贴网站。
  堵住 SSRF（对内部云服务的不正当请求）和信息泄露的路径。
  即使在 `allowedDomains` 中，`deniedDomains` 也优先拒绝。


## [4.11.3] - 2026-05-19

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4113---2026-05-19) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1993)

### Changed

- 在 `/harness-release` 和 `/harness-review` 末尾输出固定的 1 行。
  内容是「↑この結果は Claude が要約します。Enter キーで次へ進むか、新規 prompt で別の指示を出してください。」
  是对 slash 命令结果看起来停滞的问题的对策。
  此版本始终日语，4.16.0 起跟随语言设置。
  其他 skill 不变。


## [4.11.2] - 2026-05-19

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4112---2026-05-19) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2035)

### Fixed

- 无参数公开请求时，显示默认对象并开始着手。
  修复了等待追加指示而沉默的问题。
  保持保护检查和批准条件。


## [4.11.1] - 2026-05-18

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4111---2026-05-18) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2073)

### Fixed

- 修复了 `/harness-review` 和 `/ci` 返回 skill 列表，启动后沉默停止的问题。
  仅对有危险副作用的 skill 专用的设置阻止了两者的启动。
  无参数的 `/harness-review` 输出 `REVIEW_AUTOSTART:` 行后开始。
  介绍了使用该设置的条件和诊断沉默 skill 的步骤。


## [4.11.0] - 2026-05-18

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4110---2026-05-18) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2111)

### Added

- 通过 TOML 的 `[[safety.guardrail.protectedPathAskList]]` 可以将环境文件 shell 写入作为完全匹配设为确认处理。
  理由必须记录。
  不是变更为允许。
  直接编辑、秘密和密钥、Git 内部、钩子、shell 设置、外部路径、与拒绝对象混合的写入都会被拒绝。
  检测仅限重定向和 tee，sed 的直接写入不在对象内。
  也检查任意的本地 skill 复制。
- CI 在 Linux、macOS、Windows 上构建和检查。
  将自动处理的依赖固定到提交，周次更新设置 7 天等待期。
  用 CodeQL、Scorecard、语法检查增加公开的证据。
  不主张别产品作为全 CLI 对应。
- 可任意选择背景对话的终端通知。
  `HARNESS_TERMINAL_NOTIFY=1` 或 `bell` 为铃声，`title` 为窗口标题，`osc9` 为 macOS 和 iTerm 的通知，`notify` 为 Linux 的桌面通知。
  未设置和 `0` 为无显示。
  不需要 `HARNESS_WEBHOOK_URL` 也能使用。
  标准的 `/goal` 为短持续备忘录，验收条件放在 Plans.md。
  在 Harness 安全设置模板 `templates/claude/settings.security.json.template` 中增加了 2 个基准。
  使用需要复制到本人设置。
  `worktree.baseRef: "fresh"` 从 `origin/<默认分支>` 创建新作业树，不带入未发送的提交。
  需要带入时在项目设置中选择 `head`。
  `autoMode.hard_deny` 的 7 件在 Auto 模式也拒绝。
  `Bash(sudo:*)`、`Bash(rm -rf:*)`、`Bash(rm -fr:*)`、`Bash(git push -f:*)`、`Bash(git push --force:*)`、`Bash(git reset --hard:*)`、`mcp__codex__*`。
  在保护分支、认证信息、生产部署上决定不使用 `claude agents --dangerously-skip-permissions`。

### Changed

- 审查默认只读，准备了轻量 `--quick` 和 `--codex-closeout`。
  提交、push、公开按施工和公开的步骤进行。
  自动处理为最小权限，不留获取用令牌。
  停止旧变更检查，但让公开和 benchmark 完走。

### Fixed

- 从公开分发中排除本地信息、非公开的开发 skill、别 CLI 的复制、试用数据、隔离设置的示例。
  将 OpenCode 的名称和设置项目对齐到对应格式。


## [4.10.0] - 2026-05-12

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4100---2026-05-12) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2292)

### Added

- 可以使用命名的多个计划。
  在 `plans/manifest.json` 注册 `default` 和追加计划，用 `--plan NAME` 选择。
  最后选择保存在 `.claude/state/active-plan.json`。
  单个 `Plans.md`（`plans.md`、`PLANS.md` 也可）则无需更改。
  注册路径仅为项目根的相对路径。
  拒绝绝对路径、`..`、仓库外链接。
  长时间执行、CI、issue 联动不依赖保存的选择，附加 `--plan NAME`。
  不将测试先行强制作为整体默认。
  分开产品规格和作业台账。

### Fixed

- `harness codex-loop start` 在执行角色立即掉落时以 `startup_failed` 失败，非 0 结束并留下执行日志末尾。
  孤立作业显示 `runner_lost_job_running`，在停止和异常结束时中止。
  作业树钩子不接受 JSON 格式的作业位置。
  通知将已显示标记为已读并显示日期，跳过旧作业位置。
  在创建 tag 前检查复制偏差。
  在 Codex 0.130.0 提示中留下版本根据。


## [4.9.0] - 2026-05-10

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#490---2026-05-10) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2333)

### Added

- 为非工程师添加了 3 种单页 HTML。
  `/harness-plan-brief` 在着手前显示 Claude 的理解、选项、风险、验收条件、附根据的置信度（0〜100）。
  本人的判断与请求的 SHA-256 哈希（为核对请求计算的识别符）一起记录。
  `/harness-accept` 显示出货、等待、拒绝。
  确认条件 80% 以上为出货，50% 以上为等待，50% 未満或确认 0 件为拒绝。
  `/harness-progress` 显示进度%、作业中、近期完成 5 件、未着手 5 件、5 种警告（范围膨胀、时间超出、失败反复、费用、高风险文件）。
  进度页面在 Write、Edit、MultiEdit、Bash 后以最短 60 秒间隔自动更新。
  此钩子默认为插件启用。
  计划概要和验收以相同请求哈希关联。
  各页末尾有根据栏。
- 别项目的记忆搜索仅在每次执行附加 `--cross-project-group <name>` 时可用。
  组写在 `.claude/rules/cross-project-groups.yaml`，遮蔽字典写在 `.claude/rules/client-redaction.yaml`。
  遮蔽分阶段进行。
  记忆服务器在排除 `<private>` 内容后以项目范围筛选，然后经过字典、日语固有名词处理、HTML 作成前的最终检查。
  最终检查中片假名连续 5 字以上则不生成 HTML 以结束代码 1 停止。
  搜索记录在 `.claude/state/audit/cross-project-search.jsonl`，仅留下哈希而非搜索语句本身。
  是决定形式的检查，非个人信息保护的全面保证。
  字典未记载的表示或别文字种的名字可能通过。


## [4.8.1] - 2026-05-09

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#481---2026-05-09) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2436)

### Fixed

- 计划检查可以读取跟踪的储藏历史。
  不需要将完成作业留在当前计划。
  将通信拒绝列表正本对齐到 harness.toml，在生成设置偏差时在同步中警告。

### Security

- 从 be2a1781 起，修复了对话开始时的同步将 6 个投稿网站通信拒绝从设置中删除的 bug。
  将 `pastebin.com`、`transfer.sh`、`0x0.st`、`paste.ee`、`termbin.com`、`ix.io` 的拒绝对齐到 `harness.toml`，即使同步也保持。

此网络设置当时是从 `harness.toml` 输出到插件设置的，当时尚未在本体上验证有效性。
  [当前官方规格](https://code.claude.com/docs/en/plugins-reference#settings) 中插件设置有效的只有 `agent` 和 `subagentStatusLine`，所以请将通信拒绝列表复制到本人用户设置或项目设置。


## [4.8.0] - 2026-05-08

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#480---2026-05-08) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2492)

### Changed

- 追从 Claude Code 2.1.112〜2.1.132。
  MCP 工具型钩子（直接调用外部道具的处理、`type: "mcp_tool"`）暂不采用。
  继续使用现有 shell 途经钩子。
  记忆 MCP 的正式发布、包裹处理延迟的测量、Claude Code 的认证提示出来后重新评估。
  钩子不看推理量而放宽保护。
  钩子从输入 JSON 读取 Session ID，Bash 命令可使用 Claude Code 的 `CLAUDE_CODE_SESSION_ID`。
  确认了即使以 `env`、`sudo`、`watch` 包裹，强制 push、hard reset、对保护分支 push 的检查也会停止。

### Added

- 停止的施工角色最多重启 1 次。
  条件是作业中超过 10 分钟或出现停滞日志。
  超过 30 分钟的对话时，以 `ENABLE_PROMPT_CACHING_1H=1` 启动 Claude Code 可使用 1 小时缓存。
  这是 Claude Code 侧的功能。
- 输出的遮蔽处理为任意，`HARNESS_OUTPUT_GOVERNANCE_ENABLE=1` 不存在时不运行。
  替换的是 `sk-` 后跟 20 字符以上英数字的键。
  `sk-ant-` 后跟 20 字符以上英数字或连字符的键也是对象。
  Read、Grep、Glob、TodoWrite、Bash 的输出不在对象内。
  因此命令显示和文件内的键不被遮蔽。
  记录文件 `.claude/state/output-audit.jsonl` 也保留遮蔽前的正文。
  因此文件本身会放入键，需要保护或删除。
- skill 启动记录仅保存在 `.claude/state/skill-trigger-stats.jsonl`，Session ID 取先头 12 字符。
  `HARNESS_SKILL_TELEMETRY_DISABLE=1` 可停止。
- 在通信拒绝模板 `templates/claude/settings.security.json.template` 中增加了 6 个投稿网站，从 3 个变为 9 个。
  追加了 `pastebin.com`、`transfer.sh`、`0x0.st`、`paste.ee`、`termbin.com`、`ix.io`。
  因为是模板，复制到 `sandbox.network.deniedDomains` 才会生效。
  原文曾介绍在 `.claude-plugin/settings.json` 中追加。
  之后 5.7.0 的记录指出不读取此插件设置的 `permissions`。
  当时的运行环境未重新测试。
  [当前插件设置的官方规格](https://code.claude.com/docs/en/plugins-reference#settings) 中适用的只有 `agent`（默认角色）和 `subagentStatusLine`（施工角色的状态显示）。
  `sandbox` 不在对象内，所以通信拒绝项目要写在用户设置或项目设置中来应用。
  `skillOverrides` 默认未设置。
  向组织推荐 `name-only`，向教育推荐 `user-invocable-only`。
- 将计划和公开的引导、Claude、Codex、OpenCode 的复制对这些入口对齐。


## [4.7.0] - 2026-05-06

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#470---2026-05-06) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2577)

### Added

- 可通过 `harness mem status|setup|update|doctor|off|purge` 管理记忆功能。
  规定了所有范围和安全删除条件。
  对证据不足、形同虚设的通过、考试省略、无法复现的修正，附加信息处理方式后追加记录到本地。

### Changed

- 插件的 `Setup:init` 默认为 Claude Code 和 Codex 尝试一次记忆初始化设置。
  不中断工作。
  SessionStart 不进行此设置。
  `CLAUDE_CODE_HARNESS_MEM_AUTO_SETUP=0` 可停止此尝试。
  咨询役从过去证据不足的记录中读取简短线索。
  该记录首先写入本地，在可行范围内发送到 harness-mem。
  不读取记忆内部。
  咨询役的回答保持为 PLAN（计划）、CORRECTION（修正）、STOP（停止）。


## [4.6.1] - 2026-05-05

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#461---2026-05-05) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2589)

### Fixed

- 将 Breezing 包含在 OpenCode 生成中，与技能复制保持一致。


## [4.6.0] - 2026-05-05

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#460---2026-05-05) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2595)

### Added

- 在标签前对版本文件和声明进行结构性检查。
  为开发者添加了以 Go 为中心的实施方案和机器可读的技能设计信息，在 Claude、Codex、OpenCode 中进行检查。

### Changed

- 将 Codex 步骤对齐到标准的援助 API。
  媒体和通知需要明确的手动启动。
  将繁重的执行细节移至参考，保留入口和停止条件。
  对齐了更新后的技能复制。

### Fixed

- 在插件中而非使用位置查找迭代处理的辅助文件。
  修正了审查链接、发布版本偏差、未追踪文件检查、未对应的角色项目、文档配置、执行文件和库的识别、模板重复误检测。
  角色安全性通过 hook、Go 检查、启动前确认来保持，而非通过被忽视的设置字段。


## [4.5.4] - 2026-05-04

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#454---2026-05-04) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2623)

### Fixed

- 新复制的语言和声明检查仅使用公开追踪文件，不要求个人的本地技能。


## [4.5.3] - 2026-05-04

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#453---2026-05-04) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2629)

### Fixed

- 将缓存同步限定为仅已追踪的声明区域，排除旧的非公开内容和 OS 信息。
  在追踪 bin 外构建公开辅助处理，保留现有附件。
  不公开分发本地上游调查和媒体用备忘录。


## [4.5.2] - 2026-05-04

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#452---2026-05-04) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2637)

### Changed

- 基本工作的 skill 保持为可发现状态。
  停止广泛的内部辅助自动读取，保留明确的使用。
  包括基本复制在内也进行检查。

### Fixed

- 移除了每轮规则重复插入和施工役的审查预读。
  在缓存修复中保留 skill 和输出格式，允许加载有效插件。


## [4.5.1] - 2026-05-03

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#451---2026-05-03) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2650)

### Changed

- 将敏感路径分为拒绝、确认、警告，分别管理动作设置、secret、hook、导入信息。
  添加了 Codex 0.125 和 0.128 的权限设置、通信策略、记录限制、更新、旧 full-auto 专用指南。


## [4.5.0] - 2026-05-03

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#450---2026-05-03) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2657)

### Changed

- 将对 `main` 和 `master` 的直接 push 从拒绝改为确认。
  可通过 `.claude-code-harness.config.yaml` 的 `safety.protected_branch_push` 或 `harness.toml` 的 `protectedBranchPush` 选择 `ask`（确认）、`deny`（拒绝）、`allow`（允许）。

### Fixed

- 在 Windows 的 Git Bash、MSYS、Cygwin 中从入口解析 .exe，正确生成 worktree 路径。
  拒绝 JSON 格式的工作位置。
  在没有 Unix flock 的 Windows 中，根据位置回退到 mkdir 或无锁定。
  也修正了 Windows 上 Breezing 因找不到执行文件或 worktree 路径而退回 Solo 模式的问题。

### Added

- 记录了 Claude 2.1.120~126 和 Codex 0.125、0.128 的差异，添加了 Windows worktree 回归检查。


## [4.4.0] - 2026-04-26

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#440---2026-04-26) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2685)

### Added

- 添加了 Codex Breezing 的默认设置和迭代批量执行，追踪 Claude 2.1.116~119、Codex 0.123~124。
  可通过 updatedInput.answers 传递答案。
  尚未支持和试验版的能力仅作提案，不通过推测来实现。

### Fixed

- 迭代开始接受 `6G-6` 等标题 ID、`Plans.md:546`、范围。
  通过绝对脚本路径启动，保持实际失败代码和日志，在停止时终止子作业。
  导入保持当前链接，不移动旧链接，保留备份文件，防止同名备份冲突。
- 即使没有环境信息，hook 也验证插件根目录。
  通过缓存同步修复分发目标路径，契约中未使用的字段不保留 null 值以省略，防止公开检查的误失败。

### Security

- 在通信拒绝列表 `sandbox.network.deniedDomains` 中添加了云 metadata endpoint（返回服务认证信息等的目的地）。
  确认危险删除的 R05 也针对 `find -delete`、`find -exec rm`、macOS 的 `/private/etc`、`/private/var`、`/private/tmp`、`/private/home`、`~/Library`。

此网络配置是当时从 `harness.toml` 输出到插件设置的，尚未重新验证当时本体的实效性。
[当前的官方规范](https://code.claude.com/docs/en/plugins-reference#settings)中插件设置中仅 `agent` 和 `subagentStatusLine` 生效，请将通信拒绝列表复制到本人用户设置或项目设置。


## [4.3.3] - 2026-04-20

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#433---2026-04-20) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2815)

### Fixed

- 在未安装 harness-mem（不存在 `~/.claude-mem/`）的情况下，不在每次会话开始时输出 `harness-mem unhealthy` 警告，退出代码为 0。
  已安装但无法访问或损坏时，退出代码为 1 并保持警告。


## [4.3.2] - 2026-04-20

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#432---2026-04-20) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2871)

### Fixed

- 在会话偏差检查中使用末尾的有限区域。
  修正了记忆 hook 的 null 安全测试和迁移异常排除中的内部检查。
  不改变使用步骤。


## [4.3.1] - 2026-04-19

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#431---2026-04-19) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2922)

### Added

- 会话监控逐行警告 3 个问题。
  记忆健全性确认 `~/.claude-mem/` 并连接到记忆守护进程 `HARNESS_MEM_HOST:HARNESS_MEM_PORT`（默认 `127.0.0.1:37888`）。
  咨询役和判定役未响应时，超过默认 600 秒则通知。
  `orchestration.advisor_ttl_seconds` 可更改。
  计划偏差在工作中有 5 件以上或 Plans.md 24 小时不变时通知。
  `monitor.plans_drift.wip_threshold` 和 `monitor.plans_drift.stale_hours` 可更改。
  三项都写入 `.claude-code-harness.config.yaml`。
  健全性确认使用插件或 PATH 中的 `harness`，不使用项目内的 `bin/`。
  因为不会被替换为嵌入在仓库中的可执行文件。

### Fixed

- 在新建和恢复的会话中，首次输入时从 harness-mem 传递上次摘要。
  处理虽然同时包含，但未连接。
  需要 harness-mem 守护进程运行且装有 `curl` 和 `jq`。
  如果记忆未设置或无法访问，静默跳过，其他 hook 继续。


## [4.3.0] - 2026-04-19

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#430---2026-04-19) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3000)

### Fixed

- 无参数的 `/harness-review` 自动开始，输出 `REVIEW_AUTOSTART:` 行。
  施工役无法改变 Plans.md 的状态表示。
  hook 拒绝改写 `cc:` 表示的 Write 和 Edit。
  也无法在 worktree 内复制其他仓库或直接启动咨询役，助言由领导者传达。
  施工役提交 5 项有依据的自我检查。
  如有不足，领导者最多打回 2 次，之后向上提交。
  规则通过 `harness.toml` 的 `[worker.self_review]` 设置。
  共同指出传递给同一 `/breezing` 的下一位施工役，结束时丢弃。
  审查上限从 3 增加到 10，可按项目更改。
  Codex 判定停滞时，领导者可接管。


## [4.2.0] - 2026-04-18

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#420---2026-04-18) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3046)

### Added

- 会话压缩（历史的摘要）在长时间施工役执行中或 `Plans.md` 有未提交变更时停止。
  不停止判定役和咨询役的会话。
  也支持从子目录启动和 `plansDirectory`（计划保存位置指定）。
- 启用插件后，`harness-session-monitor` 自动开始。
  即使在 worktree（独立工作副本）内，也正确记录分支和最后提交。
- prompt cache（处理后输入的重用）可通过 `ENABLE_PROMPT_CACHING_1H=1 claude` 任意使用。
  将保持时间从 5 分钟延长到 1 小时。
  超过 30 分钟的会话选择 1 小时，其他选择 5 分钟。
  `scripts/enable-1h-cache.sh` 将 `export ENABLE_PROMPT_CACHING_1H=1` 写入 `env.local`。
  通过 `source env.local` 传递给 Claude 的子进程。
- 判定役和咨询役使用 `xhigh`（`high` 和 `max` 之间的推理量）。可通过 `/effort xhigh` 指定。
  除 Opus 4.7 外为 `high`。
  `harness-review` skill 在没有调用方覆盖的情况下为 `high`。
- 高分辨率确认短边 2576px、3.75MP（375 万像素）以内。
  超过的图像事先缩小。
  Task Budgets（API 费用和令牌上限指定）的公开测试版，此版本不采用。
  再入处理仅输出 JSON（结构化数据）。

### Changed

- 角色从目录读取，监视从 `monitors/monitors.json` 读取，不使用无效的插件声明字段。
- 在插件的角色中，frontmatter（定义开头的设置栏）的 `permissionMode` 和 `hooks:` 被无声忽略。
  角色单位的指定可能无效。
  此版本将限制记录到 `docs/agent-frontmatter-policy.md`，未改变动作本身。
  在 4.6.0 中移除了不支持的设置。
- Opus 4.7 按字面执行指示。
  将 Harness 的 4 个角色和 7 个 skill 的指示更正为上限等明确值。
  独有指示也可能需要类似调整。
- `/undo` 不执行自主操作。
  `/ultrareview`（Claude Code 标准审查）为辅助，不替换 Harness 的接受判断。

### Removed

- 删除了 `harness.toml` 的 `[telemetry]`（`otel_endpoint`、`webhook_url`），因为运行时未使用。
  通过环境变量 `HARNESS_WEBHOOK_URL` 设置通知目标。

### Fixed

- 同步不返回无效声明字段。
  `claude plugin validate` 的 `monitors: Invalid input` 和 `agents: Invalid input` 已消失。
  `harness codex-loop start 41.1-41.4` 等范围指定再次工作。
  恢复了被 arm64 可执行文件覆盖的 POSIX `bin/harness`（通过 shell 的入口）。
- 修复了从相邻安装目标搜索辅助脚本、恢复时残留的旧失败状态、同一执行的重复再入。
  即使咨询超时，也保留途中的文本。
  即使高风险预先确认和重试阈值咨询失败，也继续执行任务，不提供建议。
  首次 push 前无 CI 结果为警告。

### Security

- Claude Code 2.1.110 本体对 `PermissionRequest`（权限要求时的处理）的 `updatedInput`（改写的输入）重新评估 `permissions.deny`（拒绝规则）。
  `PreToolUse`（操作前的处理）的 `additionalContext`（传递给模型的补充信息）也在操作失败后保持。
  在本体侧堵住了通过反斜杠、复合命令、环境变量前缀的 Bash 绕道。
  Harness 侧对这些本体修正，通过 34 项回归检查重新确认了保护规则 R01~R13。



## [4.1.1] - 2026-04-16

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#411---2026-04-16) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3170)

### Added

- 从 `.claude-code-harness.config.yaml` 或模板读取咨询的有效化、形式、次数上限、重试阈值、模型。
  咨询状态 `.claude/state/advisor/` 自动创建。

### Fixed

- 通过链接的命令找到可执行文件的实际位置，即使安装后也能运行迭代命令。


## [4.1.0] - 2026-04-16

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#410---2026-04-16) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3180)

### Added

- 恢复了 `/maintenance`，并响应了引导它的整理警告。
  `plans` 退避已完成工作，`session-log` 按月分割 session-log.md。
  `logs` 删除 `.claude/logs/` 的旧文件，`state` 截断 `agent-trace.jsonl`。
  `all` 按顺序执行这 4 个。
  附加 `--dry-run` 则仅显示目标，不更改。
  阈值和排除可通过文本指定。
  通过 `harness codex-loop start all --max-cycles 3`、`status`、`stop`，在后台重复 Codex 的施工、判定、保存。
  状态保留在 `.claude/state/codex-loop/`。

### Changed

- 将 Codex 特有的 skill 正本与共享版分开，在公开处理中处理主版本和次版本更新。

### Fixed

- 在分发和复制的检查中，将 Codex 的判定和执行步骤与实际正本对照。

### Removed

- 从分发和检查中移除了 `allow1` skill。


## [4.0.4] - 2026-04-14

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#404---2026-04-14) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3295)

### Fixed

- 在市场引入中包含了 macOS Apple Silicon、macOS Intel、Linux amd64 的 hook 可执行文件（共约 32MB）。
  在 4.0.4 之前通过 `/plugin marketplace add` 引入时，未收到可执行文件。
  因此 Linux amd64（含 WSL2）和 Apple Silicon 上保护完全未运行。
  如果从市场安装了 4.0.0~4.0.3，请更新。
  此版本不包含 Windows。
  推定（确信度高）：在没有可执行文件的环境中，hook 什么都不做。
  可执行文件不存在或未对应时，向标准错误输出诊断，标准输出无内容，退出代码 0。
  hook 以外的命令同样，对话继续但保护未运行。
  同步保持 `./skills/`。

### Added

- 从公开分发中排除开发用内容。
  检查 skill 路径，在版本更新中添加比较链接。

### Changed

- 通用公开处理 VERSION、package.json、pyproject.toml、Cargo.toml，执行前一次确认具体内容。
  将 Harness 专用的预先检查和后处理移至内部包装处理。


## [4.0.3] - 2026-04-13

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#403---2026-04-13) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3409)

### Fixed

- 因声明的 skill 领域错误，引入的插件 skill 为 0 件。
  在开发用复制中可通过另一路径读取，因此未注意到。
  请通过 `claude plugin update claude-code-harness` 更新到修正版。
  在 4.0.4 之前，同步有时会恢复此修正，因此更新至 4.0.4 之后。


## [4.0.2] - 2026-04-12

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#402---2026-04-12) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3432)

### Added

- 通过 `harness doctor --residue`、变更检查、公开前检查，检测已知的迁移残留。
  历史异常为保留证据，不代表允许现行的旧引用。

### Removed

- 整理了 3.x 现行引用的残留，记录了迁移的负责范围。


## [4.0.1] - 2026-04-11

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#401---2026-04-11) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3473)

### Security

- 在 Harness 自身的权限检查中也作为第 2 层重复 Claude Code 2.1.89~2.1.98 的修正。
  不将通过反斜杠转义空白或标志的命令视为安全。
  前面可附加的环境变量仅为 `LANG`、`LANGUAGE`、`TZ`、`NO_COLOR`、`FORCE_COLOR`、`LC_*`。
  附加其他变量则不视为安全。
  连续的空白和制表符在检查前统一为一个空白。
  保护路径的检查也查看链接目标。
  拒绝损坏的链接和循环链接，允许尚不存在的路径以创建新文件。
  保护 `.husky/` 的 Git hook。
  "保留"的判定现在可以传达给 Claude Code。

### Changed

- 审查从判定、理由、对应、重大度读取，分离技术数据。
  此版本规定用日语发布审查。
  在 4.12.4 中恢复为英语默认。
  无参数则按最后标签、`main`、最近 10 次提交的顺序选择基准，限定在 10 次提交内。
  将 skill 名从临时 `HAR:*` 恢复为 `harness-*`（例：`harness-review`）。
  介绍了长时间处理的监控。

### Fixed

- 同步不覆盖有效的声明设置。
  开始条件拒绝相似的别事件，将检查和记忆配线对齐到 Go 的执行名。


## [4.0.0] - 2026-04-09

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#400---2026-04-09) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3643)

### Breaking Changes

- hook 不再调用 shell 和 Node 处理，而是调用附带的 Go 程序（`bin/harness hook ...`）。
  请通过 `harness sync` 重新创建 hook 设置。
  旧 `run-hook.sh` 废除。
  hook 不再需要 Node。
  将对保护分支的直接 push 从警告改为拒绝。
  在 4.5.0 中放宽为确认。
  将调用旧 shell 处理的独自 hook 重新指向新命令。

### Added

- 通过 Go 运行 37 个 hook 处理和保护规则。
  配置文件从 `harness.toml` 通过 `bin/harness sync` 创建，状态保存在 SQLite（`state/harness.db`）。
  新命令为 `bin/harness doctor --migration`（迁移状态）、`bin/harness validate`（skill 和角色定义检查）、`harness status`（角色状态）。
  为 macOS Apple Silicon、macOS Intel、Linux amd64 创建了可执行文件，附加到 GitHub Release。
  推定（确信度高、4.0.4 起）：市场引入未到达 4.0.4，保护未运行。


## [3.17.1] - 2026-04-06

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3171---2026-04-06) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3774)

### Fixed

- 在将 harness-mem 放入标准位置 `~/.harness-mem/runtime/harness-mem` 的环境中，记忆联动找不到，什么都不说就结束了。
  因此会话开始时没有返回上次的上下文。
  修正为首先查找此位置。
  如果设置了 `HARNESS_MEM_ROOT`，则优先使用。

### Changed

- 记录了 Claude Code 2.1.91~92 的功能（Harness 并非新实现）。
  `disableSkillShellExecution`、插件的 `bin/`、MCP 的 `maxResultSizeChars`（最大 500K）、援助役的启动修正。


## [3.17.0] - 2026-04-04

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3170---2026-04-04) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3807)

### Added

- 通过 `harness-review --dual`，Claude 和 Codex 的判定役并行判定并汇总结果。
  任何一个要求修正则整体也为修正要求。
  在输出的 `dual_review` 栏中显示各模型的判定和分歧理由。
  在 Codex 不可用的环境中，仅用 Claude 判定。
  通常的 `harness-review` 和 `harness-review code` 不变。
- `harness-review --security` 聚焦于 OWASP Top 10（常见 Web 弱点 10 分类）、认证和授权、信息泄露，用比通常更严格的标准判定。
- Claude Code 2.1.89 起，Auto 模式的判定器拒绝命令时记录到 `permission-denied.jsonl`。
  Breezing 施工役被拒绝时通知领导者。
  Claude Code 的 `defer` 判断仅为指南，Harness 的 `defer` 规则尚无。
- 压缩后，恢复保存的工作状态。
  任务完成的通知仅在设置 `HARNESS_WEBHOOK_URL` 时发送到 Slack、Discord、任意 URL。
  未设置则什么都不发送。
  OTel 的记录仅在设置 `OTEL_EXPORTER_OTLP_ENDPOINT` 时通过 HTTP 发送，未设置则保留在本地 JSONL。
  向 Codex 施工役传递根据文件数、依赖、词语、完成条件计算的推理量（以前始终为 medium）。

### Changed

- Harness 通过返回 JSON 和退出代码 2 停止命令。
  Claude Code 2.1.90 之前，这种停止方式无法确保有效。
  要确保 Guardrail 的拒绝，请使用 2.1.90 之后。
  其他的 Claude Code 2.1.87~90 的修正，通过附加的包装处理继承。
- 订正了 7 项过大的功能表述。
  HTTP hook 仅为模板，OTel 为独自 JSONL，分析画面和 Slack 联动为计划中，LSP 和桌面定期执行为 Claude Code 标准，Auto 模式在引入的第 1 阶段非默认。
- 在公开指南中加入了 `--dry-run`、`--complete`、`--announce`、复制同步、版本选择、劣化确认列表，明确记载不在 npm 分发。


## [3.16.0] - 2026-04-01

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3160---2026-04-01) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3924)

### Added

- 任意团队设置。
  `scripts/plans-issue-bridge.sh` 从 Plans.md 创建课题管理的亲课题和子课题（issue）的草案。
  不创建课题本身。
  正本保持为 Plans.md。
- 通过 `/harness-release --dry-run`，运行不依赖特定服务的公开前检查（`scripts/release-preflight.sh`）。
  确认 worktree、变更履历、环境差异、健全性、CI、发布物的残留。
- 可通过 `harness-plan create` 附加任意的画面（UI）概要或联动（API）概要。
  通过 `scripts/generate-skill-manifest.sh` 创建机器可读的 skill 列表（`skill-manifest.v1`）。

### Changed

- 在计划和公开的指南、Claude、Codex、OpenCode 的复制中，统一了这些入口。

## [3.15.0] - 2026-03-28

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3150---2026-03-28) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3949)

当时本体上的有效性未重新验证。
[当前官方规格](https://code.claude.com/docs/en/plugins-reference#settings) 中插件设置有效的只有 `agent` 和 `subagentStatusLine`。
插件文件中有设置并不构成保护已生效的证据。

### Added

- Claude Code 的 TaskCreated、FileChanged、CwdChanged 钩子在作业创建、Plans.md 和规则更改、作业树切换后促使重新读取。
- 重作业与施工角色、判定角色、模板角色从完成条件和验证方针开始（`effort` 和 `initialPrompt` 的设置）。

### Changed

- 使用 Claude Code 2.1.85 的 `if` 条件，权限钩子仅在 `git status`、`git diff`、`pytest`、`npm run lint` 等较安全的 Bash 上运行。
  危险命令由现有 guardrail 处理。
- Harness 在插件设置文件中添加了 `sandbox.failIfUnavailable: true` 和 `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1`。
  但 Claude Code 不读取此文件的隔离和权限设置。
  如需在隔离不可用时停止的动作和从子进程去除认证信息的动作，请写入自己的 Claude Code 设置。
- 将规则对象路径列表在 YAML 中结构化，从公开复制中除去了内部专用 skill。


## [3.14.0] - 2026-03-25

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3140---2026-03-25) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4006)

### Changed

- Claude 和 Codex 使用相同的 guardrail。
  检测并警告省略钩子和签名（`--no-verify`、`--no-gpg-sign`）、保护分支的 `git reset --hard`、`main` 或 `master` 的直接 push、保护文件的编辑。
  此版本未写明要阻止其中任何一个。
  Codex 执行时传递此规则，在纳入前检查省略标志、保护文件编辑、秘密信息混入。
  在 Codex 的 AGENTS.md 中加入了 Harness 规则的详情。

### Fixed

- 在 Marketplace 安装的环境中缺少记忆用钩子部件，SessionStart、UserPromptSubmit、PostToolUse、Stop 钩子报错。
  修复为将记忆用钩子通过 1 个联动部件传递。
  还修复了缓存同步的插件位置解析。


## [3.13.0] - 2026-03-25

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3130---2026-03-25) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4036)

### Added

- 为 `harness-work` 和 `breezing` 准备了 Codex 专用版，使用 Codex 自身的角色操作（启动、发送、等待、结束）。
  其他作业与 Claude 共用。
  放在 `~/.codex/skills/` 后，任何项目都可以使用。
  与 Claude Code 的差异有 3 点。
  作业树通过 `git worktree add` 显式创建，审查仅由 Codex 进行而不切换到判定角色，团队执行仅在附加 `--breezing` 时开始。
- 在 `harness-review` 中增加了第 5 个视角「AI 的残留」。
  从差异中查找假数据、虚拟用户、`localhost` 的 URL、`TODO` 和 `FIXME`、跳过的测试、直写的 API 密钥等，分为 minor 或 major。
- 在安装 harness-mem 的情况下，在 SessionStart、UserPromptSubmit、Stop 钩子中保存对话记忆，在下次开始时显示前次摘要（Continuity Briefing）。


## [3.12.0] - 2026-03-21

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3120---2026-03-21) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4092)

### Added

- Plans.md 不存在时通过 `harness-plan create --ci` 创建。
  将对话中「追加」「修正」等请求中不在 Plans.md 内的项目自动补写。
- 所有方式都在实现后进行审查。
  优先使用 Codex，不行则使用内部的判定角色。
  如有修正要求则修正后重新审查，最多 3 次。
  阻止合格的只有 critical 和 major，minor、推荐、范围外不阻止。
- 提交后报告做了什么、前后差异、更改文件、Plans.md 的剩余作业。
  Breezing 在全部任务完成后汇总报告。

### Changed

- Breezing 施工角色在作业树内提交，Leader 进行判定、修正指示（最多 3 次）、仅纳入合格部分。
  只有 Leader 可以重写 Plans.md。
- 由于 codex-cli 0.115.0 废弃了 `-a never`，之前版本的 Harness 调用 Codex 会全部失败。
  请更新。
  Codex 调用通过 `--full-auto`、审查通过只读隔离运行。
  当时为适应 CLI 的指定，不是当前权限的引导。


## [3.11.0] - 2026-03-20

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3110---2026-03-20) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4161)

当时本体上的有效性未重新验证。
[当前官方规格](https://code.claude.com/docs/en/plugins-reference#settings) 中插件设置有效的只有 `agent` 和 `subagentStatusLine`。
插件文件中有设置并不构成保护已生效的证据。

### Added

- 在 Claude Code 2.1.78 之后，通过 StopFailure 钩子记录 API 错误（利用框限制 429、认证失败 401 等）导致对话未正常停止的情况。
  记录位置为 `${CLAUDE_PLUGIN_DATA}` 存在时在那里，否则为 `.claude/state/stop-failures.jsonl`。
  429 时通知 Leader。
  通过 `scripts/show-failures.sh` 可以查看按错误代码、时间段别的摘要。
  自动恢复（等待后重开）和推理量自动更改仅为设计，未实现。
- 在插件设置文件中加入了隔离设置 `allowRead` 的示例（`.env.example`、`docs/**`）。
  如要在当前官方规格中使用此示例，请复制到本人的用户设置或项目设置。
  当时本体上的有效性未重新验证。

### Changed

- Claude Code 2.1.77 之后，即使钩子返回 allow，设置的 deny 也优先。
  钩子引导与此一致。
  Claude Code 将 `/fork` 改名为 `/branch`。
- 在插件设置文件中加入了拒绝旧 Codex MCP 工具（`mcp__codex__*`）的规则。
  但 Claude Code 不读取此文件的权限规则。
  如需阻止，请写入自己的设置。
- 在引入步骤中增加了 `CLAUDE_PLUGIN_DATA` 和 `ANTHROPIC_CUSTOM_MODEL_OPTION`。
  施工角色和判定角色的推理量为 medium。


## [3.10.6] - 2026-03-19

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3106---2026-03-19) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4238)

### Fixed

- 在 `claude plugin install` 安装的环境中缺少组装好的处理本体，PreToolUse、PostToolUse、PermissionRequest 的全部钩子以 MODULE_NOT_FOUND 失败。
  因此 R01〜R09 的 guardrail（阻止危险操作的保护）完全未运行。
  将处理本体包含在插件中。
  如以插件方式安装了 3.0.0〜3.10.5，因为 guardrail 未运行，请更新。
- 向 `localhost:9090` 发送的测量用 HTTP 钩子不是模板而是默认有效。
  在没有测量服务器的环境中，每次 Write、Edit、Bash、Task 都出现连接拒绝错误和最多 5 秒等待。
  已设为非默认。
  如需使用，将 `docs/examples/hooks-metrics-http.json` 复制到自己的钩子设置。
- 移除了损坏的 `codex-review` 链接。
  许可证在插件信息和分发信息中都是 MIT（分发信息之前是 Proprietary）。

### Changed

- 将角色禁止工具名从旧名 `Task` 对齐到官方名 `Agent`。

### Added

- 将背景 Breezing 施工角色出现的 MCP 提问画面（`elicitation_dialog`）与权限确认一起记录。
- 将 Harness Ops 的回复格式包含在插件中。
  通过 `/config` → Output style → `Harness Ops` 选择。


## [3.10.5] - 2026-03-15

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3105---2026-03-15) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4294)

### Fixed

- 修复了 `scripts/i18n/set-locale.sh ja` 也切换重新创建的 skill 领域说明为日语的问题。
  之前此领域保持英语。

### Changed

- 从跟踪中除去了本地 Superset 状态和告知开发用 skill。


## [3.10.4] - 2026-03-15

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3104---2026-03-15) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4314)

### Added

- 将角色的回合上限设为施工角色 100、判定角色 50、模板角色 75。
  达到上限时 Leader 回收途中结果，抑制暴走和 token 费用。
- 将通知（`permission_prompt`、`idle_prompt`、`auth_success`）记录到 `.claude/state/notification-events.jsonl`。
  背景 Breezing 中出现的权限确认之后也可调查。
- 在功能表中增加了 Claude Code 2.1.74 的 `/context` 命令。
  显示输入框的用法，可以调查压缩多的原因。


## [3.10.3] - 2026-03-14

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3103---2026-03-14) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4342)

### Changed

- Codex 的命令名是 `$harness-plan`、`$harness-sync`、`$harness-work`、`$breezing`、`$harness-review`。
  旧名 `$work`、`$plan-with-agent`、`$verify` 等不能使用。
  `scripts/setup-codex.sh` 和 `scripts/codex-setup-local.sh` 将已停止的旧 skill 从 `~/.codex/skills` 移到备份。
- 引导了结束时间钩子的等待时间设置 `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS`。
- 这是面向参与开发的人。
  通常更改不改变版本信息而记录在 Unreleased，提交前和 CI 自动不升版而仅确认整合。

### Added

- 云对话（`--remote`）中将 `HARNESS_IS_REMOTE` 留在 `CLAUDE_ENV_FILE`，其他钩子可以此判断云或本地。
- 背景 Breezing 施工角色跳过无法回答的 MCP 提问画面。
  通常对话中向本人提问并记录结果。
  压缩后将作业中和未着手的作业恢复。
- 记录了 Claude Code 2.1.76 的功能及用法（Harness 的新增实现）。
  面向大仓库的 `worktree.sparsePaths` 和旧作业树清理、`-n` 或 `--name` 的对话名、`/effort`（low、medium、high）、停止背景角色时保留途中结果、自动压缩 3 次连续失败时停止。

### Breaking Changes

- Claude 2.1.76 中 `--plugin-dir` 只接受 1 个路径。
  多个插件如 `--plugin-dir path1 --plugin-dir path2` 这样重复。
  Harness 单独使用则无需更改。


## [3.10.2] - 2026-03-12

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3102---2026-03-12) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4430)

### Fixed

- 完成任务数达到总数时，TaskCompleted 向 harness-mem 记录 work_completed 一次。
  不等待停止。
  用成功标记防止重复，无法识别对话和 API 不通时静默跳过。
  还对齐了 Claude 2.1.74 的文档和公开版信息。


## [3.10.1] - 2026-03-12

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3101---2026-03-12) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4463)

### Added

- 将 SubagentStart 和 SubagentStop 钩子按 `worker`、`reviewer`、`scaffolder`、`video-scene-generator` 区分，记录各角色开始和结束。
- 记录了 Claude Code 的功能（Harness 的新增实现）。
  Chrome 联动（`--chrome`、试验版）、语言服务器（`.lsp.json`）、团队依赖、`--teammate-mode`、`CLAUDE_CODE_DISABLE_BACKGROUND_TASKS`、`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`、`cleanupPeriodDays`、`/btw`、插件 CLI 命令、远程操作、角色定义的 `skills` 栏。

### Changed

- Breezing 施工角色的出厂默认保持 `bypassPermissions`。
  这是跳过所有权限确认的设置。
  `--auto-mode` 为任意选择，仅在对应的父对话中试用。
  模板和角色定义保持 `bypassPermissions`，仅更改文档不会切换默认。


## [3.10.0] - 2026-03-11

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3100---2026-03-11) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4509)

### Added

- `scripts/statusline-harness.sh` 配合 `/statusline use scripts/statusline-harness.sh` 可以启用 2 行状态显示。
  第 1 行是模型、分支、staged（选为提交对象的文件）和更改文件数、角色和作业树（独立作业用副本）。
  第 2 行是输入使用率（模型输入框使用比例）、对话费用、经过时间、输出风格。
  使用率 70% 黄、90% 红。
- 引导了 Claude Code 本体的功能。不是 Harness 的默认值。
  `/sandbox` 通过 OS 隔离处理。macOS 使用 Seatbelt，Linux 使用 bubblewrap。
  作为补充 `bypassPermissions`（跳过权限确认模式）的层而阶段性引入。
- 模型引导是 `opusplan`（计划用 Opus、执行用 Sonnet）、`CLAUDE_CODE_SUBAGENT_MODEL`（应援角色模型覆盖）、`availableModels`（用户可选模型的限制）。
- `Esc+Esc` 或 `/rewind` 可以回退。
  管理型 Code Review（面向 Teams/Enterprise 的试验公开）在 `REVIEW.md` 写指示，与本地的 `harness-review` 并用。
- 长文输入的引导是 `sonnet[1m]`（Sonnet 的 100 万 token 输入框）、各模型的 prompt cache（处理后输入再利用）、`CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`（停止推理量自动调整的指定）。


## [3.9.0] - 2026-03-11

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#390---2026-03-11) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4573)

### Added

- 启用 `/output-style harness-ops` 后，整理进度、检查、判定、咨询、最多 3 个判断选项。
  将推荐方案放在开头。
- Agent Teams（`breezing` 使用的团队执行）需要 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`。
  `teammateMode`（应援角色显示格式）有 `auto`、`in-process`、`tmux` 3 种。
  参考是应援角色每人 5〜6 任务，团队 3〜5 人。Harness 是施工角色 1〜3 人和判定角色 1 人。
  引导了让施工角色提出计划、批准后执行的手续。
  `TeammateIdle`（应援角色空闲通知）和 `TaskCompleted`（任务完成通知）可以以结束代码 2 驳回。

### Changed

- 下草稿的 v3.7.3 和 v3.8.0 内容包含在此版本中，未单独发布。
- 引导了 Claude Code 2.1.72 的 `ExitWorktree`（从作业用副本显式退出）和每次调用的 Agent `model` 指定复活。
  `/clear` 保持背景角色。`/plan` 接受说明参数。
  Bash 自动批准也增加了。
  推理量是 `low`、`medium`、`high` 3 阶段。Claude Code 2.1.72 中 `max` 废除。
- 在角色定义中写入了 `permissionMode: bypassPermissions`（跳过权限确认的指定）。
  这是当时的设置错误。4.2.0 发现插件角色中被忽略，4.6.0 删除。
- 从 Claude Code 2.1.71 之后的官方文档引导了 `/agents`（角色对话管理）和 `--agents`（启动时角色定义）。
  应援角色的 `background`（背景执行）和 `local` 记忆（项目内保存）也在对象内。
  还引导了 `CronCreate`/`CronList`/`CronDelete`（定期任务创建、列表、删除）、`CLAUDE_CODE_DISABLE_CRON`（停止定期执行的指定）、Desktop Scheduled Tasks。
- Auto Mode 默认更改在此时仅为预定。
  试验公开计划于 2026-03-12 开始。


## [3.7.2] - 2026-03-10

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#372---2026-03-10) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4725)

### Fixed

- 丢弃测量的多余显示，钩子输出仅 JSON。
  修复了任务 0 件时混入单独 0 行的问题。

### Changed

- 通过执行测试检查对话摘要和利用记录钩子的多余显示。


## [3.7.1] - 2026-03-09

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#371---2026-03-09) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4736)

### Changed

- 将施工角色和判定角色的类型名对齐到 `claude-code-harness:worker` 和 `claude-code-harness:reviewer`。
  之前各文件名称不同，施工角色的写入前 guard 和判定角色的完成记录未能可靠运行。
  此版本起适用。
- Breezing 施工角色在背景运行无法出现权限确认，因此以 `bypassPermissions`（跳过所有权限确认的设置）运行。
  可能通过意外的改写或危险命令。
  Claude Code 2.1.71 之后，可以用 `/breezing --auto-mode` 或 `/harness-work --breezing --auto-mode` 选择 Auto Mode。
  Auto Mode 只自动允许预先确定的安全操作，阻止 `rm -rf` 或 `git push --force` 等。
  计划分 3 阶段。
  现在是任意，验证后成为默认，稳定后废除 `bypassPermissions`。
- 各施工角色在不同的 git worktree（作业用其他副本）中运行。
  并行编辑同一文件也不会冲突，完成后由 Leader 整合。


## [3.7.0] - 2026-03-08

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#370---2026-03-08) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4773)

### Added

- 作业 3 次失败时，不仅停止，还分类原因，保存修正任务方案。
  `approve fix <task_id>` 批准则作为 `.fix` 任务添加到 Plans.md，`reject fix <task_id>` 则拒绝。
- `/harness-sync --snapshot` 保存当前进度。
  下次对话开始或 `/resume` 时显示最新摘要和自前次以来的变化。
- 有 1 件以上完成作业时，在状态栏自动附加 7 字符提交识别符（`cc:完了 [a1b2c3d]`）。
  无识别符的行仍然有效。
- Breezing 在施工角色每完成 1 件作业时显示 1 行进度。
- 可以在 Plans.md 各阶段任意放置 `Purpose:` 行（目的）。
  仅在本人陈述目的时书写。


## [3.6.0] - 2026-03-08

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#360---2026-03-08) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4859)

### Breaking Changes

- Plans 将包含完成条件和依赖的 5 列设为必填，删除了 3 列格式。
  请在同步前迁移任务行。

### Added

- `harness-plan create` 推断可检查的完成条件和依赖，以影响和危险度排序。
  影响和危险度都高的作业附加 `[needs-spike]` 标记并添加技术验证作业。
  确认完成条件空栏、无法检查的条件、循环依赖。
- 在计划审查中增加了第 5 个视角「对用户而言的价值」。
- 有 1 件以上完成作业时，每次同步都进行回顾。
  `--no-retro` 可以省略。
- Breezing 在开始前确认范围、依赖、危险度。
  从无依赖的作业开始分配，在前提完成后依次继续。
  单独施工先确认目的和影响。


## [3.5.0] - 2026-03-07

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#350---2026-03-07) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4899)

### Added

- 60 秒内连续 3 次操作失败则上报咨询。
  组合使用 `TeammateIdle`（应援角色空闲通知）和 `/loop 5m /sync-status` 定期确认。
  引导了对话压缩（历史摘要）后仍保持背景角色结果的手续。
  推荐版本固定的插件安装（`owner/repo@vX.X.X`）。

### Changed

- 增加了 Claude Code 2.1.70〜2.1.71 更新时的注意事项。
  `--resume` 不重新注入 skill。
  对话压缩后图片保留。
  `--print` 停止、插件钩子、并排安装的不具合由 Claude Code 本体修复。

### Fixed

- 在无法创建实际符号链接（指向其他位置的链接）的 Windows 副本中，也能在 `SessionStart`（对话开始时的处理）前找到作业 skill。

### Security

- 如果失败次数保存位置或父目录是符号链接，则省略写入。


## [3.4.2] - 2026-03-06

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#342---2026-03-06) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4936)

### Changed

- 将日英 README 改为引入后的动作和有根据的比较，对齐 Codex 引入为路径指定的读入。

### Added

- 增加了可确认全部作业执行成功和失败的证据集、日英步骤和保护图。

### Fixed

- 在证据生成中保持 Claude 和试验的实际结束代码而非反转的值。
  公开前检查主张和分发范围的偏差。


## [3.4.1] - 2026-03-06

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#341---2026-03-06) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4962)

### Changed

- 将日英功能表名称对齐到 `harness-work` 和 `harness-review`。

### Fixed

- 将功能表旧名（`task-worker`、`code-reviewer`、`work`、`all skills`）改为 `harness-work`、`harness-review`、`harness-*` 全 skill。
  防止 `/breezing` 和 `/harness-work` 引入时的误解。


## [3.4.0] - 2026-03-06

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#340---2026-03-06) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4980)

### Added

- 对应了 InstructionsLoaded。
  团队等待和完成的钩子可以通过返回 `{"continue": false, "stopReason": "..."}` 停止该角色。
- 引导了 Claude Code 2.1.69 的 `${CLAUDE_SKILL_DIR}` 引用、角色 ID 和种类、`/reload-plugins`、`includeGitInstructions: false`、git 子文件夹中的项目。

### Changed

- Breezing 角色确认优先使用 `agent_id`，无则使用 `session_id`。
  Skill 引用从 skill 自身位置解析。
  项目模板仅分发有文档记录的权限形式默认值。

### Fixed

- 修复了 `false` 停止响应掉落的问题，停止理由得以可靠反映。


## [3.3.1] - 2026-03-05

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#331---2026-03-05) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5010)

### Changed

- 将日英图表对齐到橙色，更新了 logo，删除了重复的图和表。

### Added

- 增加了 4 视角审查图和基本步骤与保护的日语图。


## [3.3.0] - 2026-03-05

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#330---2026-03-05) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5036)

### Added

- 从文件数、重要位置、作业用语、过去失败计算复杂度，3 以上则传递 `ultrathink`。
  仅复杂作业深度思考，简单作业保持快速。
- 引入了使用 LLM 的 3 个 agent 钩子。
  因在每次相应操作时运行，会增加模型调用费用和等待时间。
  Write 和 Edit 之前检查秘密信息、TODO 的临时放置、安全。
  写入后每次用 haiku 轻量审查。
  结束时如有未完成的 `cc:WIP` 作业则警告。
  压缩前也拾取作业中的作业。
- 作业树创建时将施工角色信息记录到 `.claude/state/worktree-info.json`，删除时整理 Codex 临时文件和日志。
  对话开始时将 `HARNESS_VERSION`、`HARNESS_EFFORT_DEFAULT=medium`、`HARNESS_BREEZING_SESSION_ID` 写入 `CLAUDE_ENV_FILE`。
- 向 `localhost:9090` 的测量用 HTTP 钩子原本是模板和说明，实际在 3.10.6 之前为默认有效。
  没有测量服务器时会出现连接错误和等待。

### Changed

- 配合 Claude Code 2.1.68，引导了包括 command、prompt、http、agent 钩子和推理量的交接。
  请优先后续上游条件。

### Fixed

- 更正为 prompt 钩子在 Stop 以外的全事件可用，删除了不存在文档的链接。


## [3.2.0] - 2026-03-04

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#320---2026-03-04) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5075)

### Added

- `/harness-work --no-tdd` 可以省略 TDD（实现前编写失败测试的测试先行推进方式）。
- 对话开始时，在搜索 skill 前检测损坏的 Windows 符号链接（指向 skill 位置的链接）。
  `scripts/fix-symlinks.sh` 替换为目录实体副本。

### Changed

- 将 TDD（测试先行）从任意改为默认。
  不再需要旧 `[feature:tdd]`。
  没有 `[skip:tdd]` 的作业中任务全部通知。
  施工角色和单独施工可以从失败的测试到合格。

## [3.1.0] - 2026-03-03

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#310---2026-03-03) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5101)

### Added

- `/harness-work`根据作业数量选择方式。
  1件为单独，2~3件为并行，4件以上为Breezing。
  Codex（`--codex`）仅在指定时使用。
  `/breezing`执行`/harness-work --breezing`。
- 在Codex的`config.toml`中加入了支援后的记忆联动（`[notify]`）和判定角色的只读隔离。
  也提供了Codex特有的限制说明。

### Changed

- 将Codex联动改为仅CLI，删除了MCP服务器的引用。
  标志与当时的CLI对齐，长指示通过标准输入传递以避免参数长度限制。

### Fixed

- 将指示文件名设为唯一，防止并行执行时的冲突。
  错误不再丢弃，而是记录到日志。
  也修复了技能信息和分配的错误。

### Removed

- 删除了转送用的15个技能和旧后缀名称。
  别名包括`breezing`（旧）、`codex-review`、`handoff`、`harness-init`、`harness-update`、`impl`、`maintenance`、`parallel-workflows`、`planning`、`plans-management`、`release-har`、`setup`、`sync-status`、`troubleshoot`、`verify`、`work`、`*-harness`、`x-release-harness`。
  各功能的转移目标如下（并非此版本的原文，而是根据v3的构成记录）。
  planning、plans-management、sync-status为`harness-plan`（同步后来分为`harness-sync`）。
  work、impl、parallel-workflows、旧breezing为`harness-work`。
  codex-review、verify、troubleshoot为`harness-review`。
  release-har、x-release-harness、handoff为`harness-release`。
  setup、harness-init、harness-update、maintenance为`harness-setup`。


## [3.0.0] - 2026-03-02

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#300---2026-03-02) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5142)

### Breaking Changes

- 将42个技能整理为5操作、11角色归纳为3角色。
  hook改为Node的带类型处理，状态移至SQLite，复制改为链接。
  此版本的迁移期间保留旧技能和旧角色。

### Added

- 将启动、状态切换、结束、分支、恢复归纳为1个会话管理，准备了移至SQLite的旧状态的处理和结构检查。

### Fixed

- 修正了SQLite的模块类型，将篡改检查从每次写入2次改为1次。

### Removed

- 使用rsync的复制、单独的Bash保护部件、分散的状态文件，被新处理替换。


## [2.26.1] - 2026-03-02

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2261---2026-03-02) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5193)

### Added

- 在日英README各添加了6张图，展示作业步骤、并行施工、保护、技能、团队。

### Fixed

- 在提交前的判定表中加入了合格后的自动整理，与执行步骤保持一致。


## [2.26.0] - 2026-03-02

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2260---2026-03-02) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5203)

### Added

- `/work`在判定合格后、提交前执行Claude Code标准的`/simplify`。
  `--deep-simplify`还使用code-simplifier插件，`--no-simplify`则省略。
  `/simplify`和`/batch`是Claude Code 2.1.63以上的功能，Harness仅负责启动和提议。
- `/breezing`发现对多数文件的相同更改（迁移、批量替换、全体添加）时，提议委派给标准的`/batch`。
- 介绍了Claude Code的`type: "http"`hook，准备了Slack、计测、dashboard的示例。
  此hook将hook数据POST到设定的URL。
  Harness不设定发送目标。添加发送目标后，数据将传递到该服务。

### Changed

- 将版本参考从Claude Code 2.1.49以上提高到2.1.63以上。
  介绍了工作树间的自动记忆共享和通过`/clear`更新技能缓存。
  在`/work`的状态中记录了整理是通常、详细还是省略方式进行的。


## [2.25.0] - 2026-02-24

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2250---2026-02-24) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5231)

### Added

- 在`CLAUDE_CODE_SIMPLE`（限制Claude Code 2.1.50以上功能的模式）中，37技能、11角色、记忆在无警告的情况下被禁用。
  在`SessionStart`（启动时）和`Setup`（设置时）检测。
  向终端的`stderr`（错误显示目标）和`additionalContext`（传递给模型的对话补充信息）发出警告。
  影响以"技能禁用"、"角色禁用"、"仅hook动作"3种分类显示。
  在兼容性文档中介绍限制和回避方法。
  即使检测到也不会恢复已禁用的功能。

### Changed

- 在兼容性表中将SIMPLE模式从"需要注意"改为"已支持"，并记载了影响范围。
  已支持指检测和说明，不代表功能恢复。



## [2.24.0] - 2026-02-24

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2240---2026-02-24) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5260)

### Added

- 在兼容性表中记录了Claude Code 2.1.50~2.1.51的功能。
  包括记忆泄漏修复、完成作业整理、WorktreeCreate和WorktreeRemove hook、声明式工作树分离、SIMPLE模式、远程操作。
  此版本的Harness仅记载工作树hook为将来支持。
- 在角色启动失败时的诊断中添加了`claude agents list`（Claude Code 2.1.50以上）。
- 后台运行的角色可通过`Ctrl+F`停止（Claude Code 2.1.49以上）。
  不推荐`Esc`。

### Changed

- 将推荐Claude Code版本从2.1.49以上提高到2.1.51以上。


## [2.23.6] - 2026-02-24

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2236---2026-02-24) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5288)

### Added

- 在`release-har`技能的分支规则中，允许单独项目直接push到常规的`main`。
  强制push仍然禁止。
  项目模板`templates/AGENTS.md.template`也解除了单独项目的main直接push禁止。
  新建项目的规则中也允许。

### Changed

- 在Codex施工角色的质量检查中，将Python测试省略、无条件通过判定、测试设置放宽也视为篡改。


## [2.23.5] - 2026-02-23

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2235---2026-02-23) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5309)

### Added

- 将测试篡改检测扩展到12种以上。
  包括判定放宽（`toBe`→`toBeTruthy`）、等待上限虚增、无条件通过判定、Python的省略指定。
- 设置`HARNESS_AUTO_TEST=run`后，自动测试hook实际执行相关测试并返回结果。
  未设置时仅建议执行测试。
- 此外，检测到`git push`后的CI失败，在下次输入中加入CI修正建议。
- `sync-rules-to-agents.sh`将`.claude/rules/*.md`复制到`codex/AGENTS.md`的规则栏，使Codex能读取项目规则。
  `codex-exec-wrapper.sh`在`codex exec`之前执行此同步。
  之后将`[HARNESS-LEARNING]`的学到保存到`codex-learnings.md`，排除秘密。
- 在`/breezing`中，如果`.claude/state/review-result.json`记录了当前HEAD提交的APPROVE，则省略最终阶段的手动APPROVE确认。
- Codex的执行方针（`harness.rules`）中，无需确认即可执行`npm test`、`yarn test`、`pnpm test`。
  对`git push --force`、`git reset --hard`、`rm -rf`、`git clean -f`、`DROP TABLE`、`DELETE FROM`进行确认。

### Changed

- `/breezing`的施工角色数量最低为1。
  上限为独立作业数、`--parallel N`、计划上限、5中的最小值。
- `release-har`技能首先输出`--dry-run`的试行显示。
  估算版本提升幅度，写出带比较链接的4节公开说明。
  仅在添加`--announce`时加入公告。


## [2.23.3] - 2026-02-22

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2233---2026-02-22) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5348)

### Added

- 在Codex分发中包含了`generate-slide`技能，在日英README中说明了`/generate-slide`的用法。

### Changed

- 将Breezing以外的Codex施工和别判定与`codex exec`对齐，介绍MCP而非CLI的设置和诊断。

### Fixed

- 在设置中确认Codex CLI的实际可用性，将复制和回归检查与CLI限定合同对齐。


## [2.23.2] - 2026-02-22

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2232---2026-02-22) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5380)

### Fixed

- 将Codex的施工和团队步骤与标准支援API和`${CODEX_HOME:-~/.codex}/state/harness/`对齐。
  `--claude`同时委派判定，`--claude --codex-review`在启动前失败。
  从OpenCode中删除了当时的开发专用Breezing。


## [2.23.1] - 2026-02-22

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2231---2026-02-22) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5402)

### Changed

- Codex设置新增文件，备份管理对象的现有文件并更新，保留仅用户自己的文件。
  在项目和个人设置中使用相同的合并，将导入说明移到可折叠栏。

### Added

- 在设置中添加了计划、施工、判定的不足5角色，不重复注册现有角色。


## [2.23.0] - 2026-02-21

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2230---2026-02-21) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5428)

### Added

- Codex的计划咨询使用标准支援和Lead中继的分析角色、批评角色的对话。
  添加了计划、施工、判定的5角色。

### Changed

- Breezing的3个引用为保持Codex特有的内容，从共享副本中排除。
  Codex的团队执行需要`config.toml`的`[features] multi_agent = true`。
  Harness的环境确认检查此设置。


## [2.22.0] - 2026-02-21

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2220---2026-02-21) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5454)

### Added

- 此版本将默认保护规则放入`.claude-plugin/settings.json`分发。
  当时说明Claude Code 2.1.49以上在安装时应用，`/harness-init`不需要。
  之后的5.7.0记录了Claude Code不读取此插件文件的权限规则。
  除非在会话内的`/permissions`中显示，否则请勿认为这些规则有效。
- `ConfigChange`hook仅在Breezing执行期间将配置文件更改记录到团队历史，不阻止操作。
- 停止时hook读取最后的回复（Claude Code 2.1.47以上），仅保存长度和SHA-256哈希。
  不保存正文。
  写入时先写入临时文件再替换，不留中间状态。

### Security

- 此版本的文件不具有全局权限。
  拒绝：`.env`和秘密文件、SSH密钥（`id_rsa`、`id_ed25519`、`.ssh/`）、`.aws/`、`.npmrc`、`sudo`、`rm -rf`和`rm -fr`、数据库CLI的`psql`、`mysql`、`mongo`、`mongod`。
  确认：`git push --force`、`git reset --hard`、`git clean -f`、常规的`git rebase`和`git merge`、`npm`、`bun`、`pnpm`的`install`、`npx`、`npm exec`。
  此版本的默认值，非当前方针。

### Changed

- 在Breezing的说明中添加了Claude Code 2.1.49以上的工作树分离（`isolation: "worktree"`）。
  并行的施工角色编辑分离的工作树内的文件。
  之后整合时，相同行的更改可能需要解决。
  也反映了2.1.47以上的角色模型指定行为。
- 仅`video-scene-generator`角色获得了后台执行（`background: true`）。
- 对齐了Codex和OpenCode的团队引用，将版本参考从Claude Code 2.1.38提高到2.1.49。


## [2.21.0] - 2026-02-20

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2210---2026-02-20) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5506)

### Added

- `/breezing`在施工前判定计划。
  计划角色（`plan-analyst`）和批评角色（`plan-critic`）先讨论。
  默认ON，可通过`--no-discuss`省略。
  在创建作业前，检查范围、模糊性、文件担当重复、依赖整合、测试先行的标志。
- 在Plans.md的作业上添加`[feature:tdd]`会先创建测试。
- 8个以上作业分成群，当前群完成60%时建议下一群。
  施工角色之间可直接通信，完成hook进行中间判定和建议下一群。

### Fixed

- 即使同时完成越过阈值也通知，按会话单位去除重复。
  压缩后保持计划继承，映射旧作业ID到当前作业仅计算1次。
  使用安全的字符串匹配和JSON处理，jq不存在时回退到Python。


## [2.20.13] - 2026-02-19

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#22013---2026-02-19) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5545)

### Changed

- Codex步骤使用标准的启动、等待、发送、恢复、结束和专用状态区域。
  在设置中添加multi_agent和角色的默认值。
  `--claude`同时委派施工和判定，不能与`--codex-review`并用。

### Fixed

- 将施工和Breezing的Claude判定目标与明示的委派对齐。


## [2.20.11] - 2026-02-19

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#22011---2026-02-19) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5570)

### Changed

- 从分发中删除了Harness UI的dashboard（`/harness-ui`、2.12.0添加）。
  不分发素材、技能、模板、hook，也不执行会话开始时的注册。

### Fixed

- Issue #50: 从分发中删除了嵌入绝对路径的记忆用8个包装脚本（`scripts/harness-mem*`、`scripts/hook-handlers/memory-*.sh`）。
  hook和设置也不调用这些。


## [2.20.10] - 2026-02-18

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#22010---2026-02-18) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5585)

### Changed

- 将Codex设置的默认值改为个人区域`${CODEX_HOME:-~/.codex}`。
  可通过`--project`放到项目。
  Codex上的施工以Codex为默认，通过`--claude`委派。
  恢复状态也遵循此分配。


## [2.20.9] - 2026-02-15

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2209---2026-02-15) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5607)

### Changed

- 将Codex侧的别判定文档与Claude CLI的`claude -p`委派对齐。


## [2.20.8] - 2026-02-14

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2208---2026-02-14) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5623)

### Changed

- 将推荐Claude Code版本从2.1.38以上提高到2.1.41以上。
  在Bedrock、Vertex、Foundry上使用Breezing必须2.1.41以上。
  此版本修复了团队模型ID的问题。
  2.1.41以上也显示hook的错误输出。
- 说明了`/rename`による会話的自动命名和`claude auth login`、`claude auth status`、`claude auth logout`（Claude Code 2.1.41以上）。
  兼容性表记录到2.1.42。


## [2.20.7] - 2026-02-14

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2207---2026-02-14) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5635)

### Fixed

- 将停止时的模型判定替换为返回正确JSON的命令。
  修复了每次因自然语言回复而解析失败的问题。


## [2.20.6] - 2026-02-14

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2206---2026-02-14) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5645)

### Fixed

- 将通知hook修正为有效的PostToolUse名称，从hook输出中删除子进程的多余显示。


## [2.20.5] - 2026-02-12

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2205---2026-02-12) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5656)

### Fixed

- 修复为在`/breezing --codex`时启动Codex施工角色。
  之前此参数被忽略，启动了标准的施工角色。
  Codex格式中，手册禁止Lead的源码编辑。
  通常格式保持标准施工角色。
  施工角色同时启动N人，N为独立作业数、`--parallel N`、3的最小值。
  压缩后的恢复也恢复所选格式。


## [2.20.4] - 2026-02-11

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2204---2026-02-11) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5669)

### Fixed

- 将Harness的显示和`codex-review`技能与仅`codex exec`（Codex CLI）的描述对齐。
  从Codex和OpenCode的副本中删除了开发专用技能。

### Security

- PreToolUse hook以理由拒绝`mcp__codex__*`的调用。
  也禁止使用`codex-cli-only`规则，防止误用退役的Codex MCP服务器。
  改用Codex CLI（`codex exec`）。


## [2.20.3] - 2026-02-10

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2203---2026-02-10) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5686)

### Fixed

- 正确编码hook JSON，不将数据嵌入代码而是通过参数传递。
  状态区域权限设为700，等待事件5秒内去重，JSONL从500行整理到400行。
  使用安全的字符串匹配和类型转换防止解析和注入问题。


## [2.20.2] - 2026-02-10

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2202---2026-02-10) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5702)

### Added

- TeammateIdle和TaskCompleted hook将团队事件记录到`.claude/state/breezing-timeline.jsonl`。
- 在记忆的说明中，将Claude Code的自动记忆、Harness的判断和步骤、角色的记忆分开。
  互不替代。

### Changed

- 将版本参考从Claude Code 2.1.30以上提高到2.1.38以上。
  介绍了团队hook、角色记忆、高速格式、自动记忆、技能加载量调整（上下文2%、2.1.32以上）、通过`Task(agent_type)`限制支援类型。
  将500行技能上限从强制改为参考。


## [2.20.1] - 2026-02-10

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2201---2026-02-10) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5721)

### Fixed

- 修复了写入后的shell解析和10个hook的Python输入竞争。
  通过可移植的printf和字符串匹配、日英警告，减少建议hook的附带错误阻止作业的问题。


## [2.20.0] - 2026-02-08

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2200---2026-02-08) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5734)

### Changed

- 将28个技能归纳为19个。
  `/memory`吸收了`/sync-ssot-from-memory`和`/cursor-mem`。
  `/setup`吸收了`/setup-tools`、`/harness-mem`、`/codex-setup`、`/2agent`、`/localize-rules`。
  `/ci`、`/agent-browser`、`/x-release-harness`不出现于slash命令（`user-invocable: false`）。
  Claude的自动加载保留。
- 将Breezing分为3段。
  准备段保持用户的权限格式，中间段的Lead仅进行作业调整，最终段由Lead进行验证和提交。
- 支援始终以`mode: "bypassPermissions"`运行，因此不出现权限确认。
  保护由PreToolUse hook、禁止工具、启动指示、`.claude/rules/`、Lead的监视承担。
  解决了后台支援自动被Bash拒绝的问题（prompts unavailable）。
- GitHub的公开说明用英语书写。

### Added

- 首次`/codex-review`时一次性确认Codex的可用性。
- 在macOS上如果没有`timeout`和`gtimeout`，引导执行`brew install coreutils`。

### Fixed

- 合并了保护hook的JSON解析为1次，检查链接目标，删除了`eval`。
  Codex的命令使用不依赖环境的时间限制。

### Removed

- 将集成的技能移至`skills/_archived/`。
  从仓库中删除了构建产物（包括`mcp-server/dist/`）、开发备忘录、锁文件。


## [2.19.0] - 2026-02-08

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2190---2026-02-08) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5787)

### Changed

- 将5个施工命令归纳为`/work`（Claude施工）和`/breezing`（团队完走）2个。
  都接受`--codex`，此版本通过Codex MCP委派施工。
  都进行相同的对话式范围确认。
- `/work`根据作业数选择进行方式。
  1件直接，2~3件并行，4件以上迭代。
- 将状态文件统一为`work-active.json`，也读取旧的`ultrawork-active.json`。

### Removed

- `/ultrawork`迁移到`/work all`。
- `/breezing-codex`迁移到`/breezing --codex`。
- `/codex-worker`迁移到`/work --codex`。
- 将旧技能移至`skills/_archived/`。


## [2.18.11] - 2026-02-06

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21811---2026-02-06) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5820)

### Added

- 在Breezing（团队形式）v2中，分离了协调角色的Lead、施工角色、独立的只读判定角色。
  hook强制每个对话的判定角色只读和施工角色的文件担当。
  `--codex-review`添加Codex的判定。
  在完成报告中包含各角色的计测。
- 在Codex格式（`--codex`、`ultrawork-active.json`的`codex_mode: true`）中，Claude成为管理角色。
  除Plans.md的状态标记更新外，禁止所有Edit和Write。

### Changed

- Codex判定读取`decisions.md`和`patterns.md`，将输出从1500字扩展到2500字。
  critical和high为0件则合格，仅low和medium不停。


## [2.18.10] - 2026-02-06

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21810---2026-02-06) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5857)

### Added

- 为7个角色添加了项目或个人单位的持续记忆。
  只读判定和分析不能使用Bash、Write、Edit。
  不将秘密、个人信息、源码片段保存到记忆。


## [2.18.7] - 2026-02-05

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2187---2026-02-05) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5868)

### Changed

- 通常的Git push不确认。
  强制push和force-with-lease确认。


## [2.18.6] - 2026-02-05

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2186---2026-02-05) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5876)

### Fixed

- 可靠地解析Codex的`harness.rules`（命令权限规则）。
  对于`git clean -n`（未跟踪文件删除预告）和`sudo -n true`（无交互sudo确认）这样的安全确认，不会因不必要的权限确认而停止。
  Claude的安全模板`templates/claude/settings.security.json.template`使用有效的`:*`语法（与命令参数匹配的表示法）。
  仅对破坏性形式确认。


## [2.18.5] - 2026-02-05

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2185---2026-02-05) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5889)

### Added

- 通过`gogcli-ops`技能介绍使用Google Workspace CLI操作Drive、Sheets、Docs、Slides。
  包括认证、账户选择、从URL到ID的转换。
  默认仅读取，写入需确认。
  此技能后来已退役。

## [2.18.4] - 2026-02-04

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2184---2026-02-04) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5900)

### Added

- 在对话中可以用 `/codex-setup` 或 `/setup-tools codex` 引入 Codex CLI。
  项目单位的引入由 `scripts/codex-setup-local.sh` 进行。
  `/harness-init` 和 `/harness-update` 可以任意同步 Codex CLI 文件。
  2.20.0 中 `/codex-setup` 和 `/setup-tools` 集成到了 `/setup`。


## [2.18.2] - 2026-02-04

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2182---2026-02-04) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5910)

### Added

- 在 Codex CLI 分发中包含了 skill、暂定规则保护、初始设置、`$skill`（按名称调用 skill 的指定）用的指示和分发检查。
  引入用 `scripts/setup-codex.sh`，步骤在 `codex/README.md`。

### Changed

- 在 README 中增加了 Codex CLI 引入步骤。


## [2.18.1] - 2026-02-04

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2181---2026-02-04) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5925)

### Added

- 在视频生成中增加了日语语音的提供者。
  `aivis` 是外部服务 Aivis Cloud API，可以指定 `speaker_id` 或 `intonation_scale`。
  `voicevox` 是语音森等等的 VOICEVOX 声音。
  同梱说话者设置示例。

### Changed

- 将 MCP 服务器改为任意。
  删除了插件的 `.mcp.json`，因为不分发 `mcp-server`，所以引入后不会注册。
  需要的话另行设置。


## [2.18.0] - 2026-02-04

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2180---2026-02-04) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5941)

### Added

- 对应了 Claude Code 2.1.30。
  Harness 侧的变更如下。
  诊断 skill 将复杂对话问题转交 `/debug`。
  角色记录格式 v0.3.0 记录各作业的输入量、工具使用次数、所需时间。
  notebookLM 和审查通过 PDF 的页面范围（`pages`）读取。
  审查、CI、公开使用详细的 `git log` 指定。
- 也引导 Claude Code 标准功能。
  面向不支持动态客户端注册的 MCP 服务器的 `--client-id` 和 `--client-secret` OAuth、应援中的 MCP 利用（2.1.30 修正）、`--resume` 约 68% 的记忆削减、减少动作的 `reducedMotion` 设置。


## [2.17.10] - 2026-02-04

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21710---2026-02-04) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5957)

### Added

- 在 PreCompact 和 SessionEnd 钩子中，压缩前保存对话状态，结束时整理。
- 角色记录格式 v0.2.0 记录哪个插件编辑了。
- 准备了隔离设置模板 `templates/sandbox-settings.json.template`。

### Changed

- `deploy`、`generate-video`、`memory`、`verify` 在分支的隔离上下文中运行。
- 为避免与 Claude Code 标准命令冲突，改名了 `/release`。
  v2.17.10 分发物中为 `/release-harness`，2.18.0 时为 `/release-har`。


## [2.17.9] - 2026-02-04

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2179---2026-02-04) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5972)

### Changed

- 新项目设置模板为 `review.mode: codex`。
  新设置项目的判定默认发送到 Codex（OpenAI）。
  使用别的判定角色时更改 `review.mode`。
- `/ultrawork --codex` 仅在需要时创建作业树。
  作业 1 件、依赖全部串行、文件重叠时直接执行。


## [2.17.8] - 2026-02-04

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2178---2026-02-04) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5983)

### Fixed

- 修复为可以从 Skill 工具启动 `/release`。
  因为去掉了 `disable-model-invocation: true`，所以即使不输入 Claude 也可以自行启动公开 skill。


## [2.17.6] - 2026-02-04

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2176---2026-02-04) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5992)

### Added

- 以 JSON 格式、语义检查、模板列表处理视频场景，阻止通过父参照逃逸。
  在日英 README 中增加了简短的开始步骤。

### Changed

- 为 28 skill 添加了日语说明，整理了 README 的引入顺序。

### Fixed

- 将场景错误提取和 slide_in 切换名称对齐到格式定义。


## [2.17.3] - 2026-02-03

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2173---2026-02-03) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6028)

### Added

- `/harness-review` 之后，`/ultrawork` 自动修正直到合格。
  重试最多 3 次，记录在 `ultrawork-retry.json`。
  REJECT 和 STOP 立即停止，要求手动对应。
  超过 3 次则停止。
- 按优先级执行全部现有检查脚本，第一个失败时停止。
  在判定报告中作为「How to Achieve A」显示合格所需的改善。

### Changed

- 此当时版本在 Codex MCP 可用时自动切换到 Codex 判定。
  不可用时退回并行的应援。
  等待上限通过 `timeout_ms`（毫秒）指定。
- 变更文件数从共同祖先的差异和保存前后的变更计算。
  判定视角由文件路径决定。


## [2.17.2] - 2026-02-03

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2172---2026-02-03) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6066)

### Added

- Codex 施工完成时查找匹配任务并更新为完成。
  找不到则确认，不静默丢弃更新。

### Changed

- 对齐了施工脚本的共通处理和安全数据处理。


## [2.17.1] - 2026-02-03

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2171---2026-02-03) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6089)

### Added

- 通过 `Edit`/`Write` 的编辑保存到 agent-trace（编辑记录、`.claude/state/agent-trace.jsonl`）。
  用于对话摘要、进度确认、跨对话记忆。

### Changed

- 对话结束摘要中显示项目名、当前任务、最近编辑。
  Git 状态使用 5 秒间的保存结果。

### Fixed

- 检查编辑记录的文件权限和符号链接（指向其他位置的链接）。
  锁定历史整理，防止同时处理中记录丢失。


## [2.17.0] - 2026-02-03

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2170---2026-02-03) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6113)

### Added

- 在 Codex Worker 中向 OpenAI Codex 委托施工。
  1 件通过 `codex-worker` skill，并列通过 `/ultrawork --codex` 为每个 git worktree 施工。
  质量检查确认证据、语法和类型、测试、测试篡改。
  文件担当锁定使用有效期限和生存通知，在作业完成时更新 Plans.md。

### Changed

- 明确了施工和判定的分配规则，减少误读入。

### Fixed

- 修复了 shell、Git、JSON 输入和可移植空白检查，严格 shell 格式中计算意外结束的问题。


## [2.16.21] - 2026-02-03

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21621---2026-02-03) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6140)

### Changed

- 将 `/ultrawork` 的 Codex 指定 `--codex`、`--parallel`、`--worktree-base` 明记为设计案。
  此版本不运行。
  相关脚本和参考是未跟踪的草稿，不是分发的功能。
  `/ultrawork --codex` 在 2.17.0 实现。


## [2.16.20] - 2026-02-03

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21620---2026-02-03) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6152)

### Changed

- 将分配规则对齐到 1 个，使 Codex 的施工和判定可以确定。


## [2.16.19] - 2026-02-03

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21619---2026-02-03) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6161)

### Fixed

- 将停止通知改为短词，减少理由全文的重复显示。


## [2.16.17] - 2026-02-03

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21617---2026-02-03) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6169)

### Added

- 17 skill 在补全栏输出参数引导。
  示例是 `/harness-review [code|plan|scope]` 和 `/troubleshoot [build|test|runtime]`。
  变化仅是补全栏的显示。
- 可以在对话间通知。

### Changed

- 将试验和引导对齐到仅 skill 的构成。


## [2.16.14] - 2026-02-02

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21614---2026-02-02) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6191)

### Changed

- 将施工委托自动注册到 Plans.md，途中追加的作业也包含在进度中。


## [2.16.11] - 2026-02-02

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21611---2026-02-02) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6204)

### Changed

- 将命令移到了 skill。
  `/work` 或 `/harness-review` 等调用名不变。
  `impl` 或 `verify` 等内部 skill 不出现在菜单。
- 改名: `dev-browser`→`agent-browser`、`docs`→`notebookLM`、`video`→`generate-video`。
- 在 README 中增加了诊断和删除步骤。


## [2.16.5] - 2026-01-31

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2165---2026-01-31) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6223)

### Added

- 在 `/generate-video` 中增加了 AI 图像（外部图像服务 Nano Banana Pro）、权利处理完毕的背景音乐、日语字幕、GlitchText 和 Particles 等效果。


## [2.16.0] - 2026-01-31

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2160---2026-01-31) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6237)

### Changed

- 作为试用功能，减少了 `/ultrawork` 执行中的确认。
  `rm -rf` 仅对计划中批准路径无确认执行，其他一如既往确认。
  通常的 `git push` 无确认继续。
  强制 push 继续确认。


## [2.15.0] - 2026-01-26

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2150---2026-01-26) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6250)

### Added

- `/setup-opencode` 自动进行 OpenCode 兼容设置，两边可以使用相同的 skill。
  是当时的兼容格式，不表示当前的同等对应。


## [2.14.0] - 2026-01-16

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2140---2026-01-16) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6263)

### Added

- `/work --full` 可以并行执行作业。
  同时运行数量通过 `--parallel N` 决定，`--parallel 3` 则最多 3 件。
  各施工角色自己判定自己的结果。


## [2.13.0] - 2026-01-14

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2130---2026-01-14) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6276)

### Added

- 在当时的 Codex MCP 审查中，安全性、品质、性能、无障碍 4 专家并行判定。


## [2.12.0] - 2026-01-10

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2120---2026-01-10) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6289)

### Added

- `/harness-ui` 在浏览器中打开进度仪表板。
  在 2.20.11 从分发中除名。
- 通过浏览器自动化进行画面操作和图像获取。
  当时名称为 `dev-browser`，在 2.16.11 改名为 `agent-browser`。


## [2.11.0] - 2026-01-08

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2110---2026-01-08) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6298)

### Added

- 对话之间可以收发消息。
- `crud` 生成带 Zod 输入检查的入口。


## [2.10.0] - 2026-01-04

[当时的技术记录](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2100---2026-01-04) | [元提交的原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6307)

### Added

- 通过语言服务器定义和引用搜索、语法结构搜索支援代码调查。

## 以前的版本

2.9.x 之前可以在 [GitHub Releases](https://github.com/Chachamaru127/claude-code-harness/releases) 确认。

[Unreleased]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.16.0...HEAD
[5.16.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.15.0...v5.16.0
[5.15.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.14.1...v5.15.0
[5.14.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.14.0...v5.14.1
[5.14.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.13.2...v5.14.0
[5.13.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.13.1...v5.13.2
[5.13.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.13.0...v5.13.1
[5.13.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.12.0...v5.13.0
[5.12.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.11.0...v5.12.0
[5.11.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.10.0...v5.11.0
[5.10.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.9.0...v5.10.0
[5.9.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.8.0...v5.9.0
[5.8.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.7.0...v5.8.0
[5.7.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.6.0...v5.7.0
[5.6.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.5.0...v5.6.0
[5.5.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.4.0...v5.5.0
[5.4.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.3.1...v5.4.0
[5.3.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.3.0...v5.3.1
[5.3.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.2.0...v5.3.0
[5.2.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.1.0...v5.2.0
[5.1.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.0.0...v5.1.0
[5.0.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.16.4...v5.0.0
[4.16.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.16.3...v4.16.4
[4.16.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.16.2...v4.16.3
[4.16.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.16.1...v4.16.2
[4.16.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.16.0...v4.16.1
[4.16.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.15.0...v4.16.0
[4.15.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.14.0...v4.15.0
[4.14.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.13.3...v4.14.0
[4.13.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.13.2...v4.13.3
[4.13.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.13.1...v4.13.2
[4.13.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.13.0...v4.13.1
[4.13.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.11...v4.13.0
[4.12.11]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.10...v4.12.11
[4.12.10]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.9...v4.12.10
[4.12.9]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.8...v4.12.9
[4.12.8]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.7...v4.12.8
[4.12.7]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.6...v4.12.7
[4.12.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.5...v4.12.6
[4.12.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.4...v4.12.5
[4.12.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.3...v4.12.4
[4.12.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.2...v4.12.3
[4.12.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.1...v4.12.2
[4.12.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.0...v4.12.1
[4.12.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.11.4...v4.12.0
[4.11.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.11.3...v4.11.4
[4.11.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.11.2...v4.11.3
[4.11.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.11.1...v4.11.2
[4.11.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.11.0...v4.11.1
[4.11.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.10.0...v4.11.0
[4.10.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.9.0...v4.10.0
[4.9.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.8.1...v4.9.0
[4.8.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.8.0...v4.8.1
[4.8.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.7.0...v4.8.0
[4.7.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.6.1...v4.7.0
[4.6.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.6.0...v4.6.1
[4.6.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.5.4...v4.6.0
[4.5.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.5.3...v4.5.4
[4.5.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.5.2...v4.5.3
[4.5.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.5.1...v4.5.2
[4.5.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.5.0...v4.5.1
[4.5.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.4.0...v4.5.0
[4.4.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.3.3...v4.4.0
[4.3.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.3.2...v4.3.3
[4.3.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.3.1...v4.3.2
[4.3.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.3.0...v4.3.1
[4.3.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.2.0...v4.3.0
[4.2.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.1.1...v4.2.0
[4.1.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.1.0...v4.1.1
[4.1.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.0.4...v4.1.0
[4.0.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.0.3...v4.0.4
[4.0.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.0.2...v4.0.3
[4.0.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.0.1...v4.0.2
[4.0.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.0.0...v4.0.1
[4.0.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.17.1...v4.0.0
[3.17.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.17.0...v3.17.1
[3.17.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.16.0...v3.17.0
[3.16.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.15.0...v3.16.0
[3.15.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.14.0...v3.15.0
[3.10.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.10.2...v3.10.3
[3.10.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.10.1...v3.10.2
[3.10.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.10.0...v3.10.1
[3.10.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.9.0...v3.10.0
[3.9.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.7.2...v3.9.0
[3.7.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.7.1...v3.7.2
[3.7.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.7.0...v3.7.1
[3.7.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.6.0...v3.7.0
[3.4.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.4.0...v3.4.1
[3.4.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.4.1...v3.4.2
[3.5.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.4.2...v3.5.0
[3.4.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.3.1...v3.4.0
[3.3.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.3.0...v3.3.1
[3.3.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.2.0...v3.3.0
[2.26.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.26.0...v2.26.1
[2.26.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.25.0...v2.26.0
[2.25.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.24.0...v2.25.0
[2.24.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.6...v2.24.0
[2.23.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.5...v2.23.6
[2.23.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.3...v2.23.5
[2.23.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.2...v2.23.3
[2.23.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.1...v2.23.2
[2.23.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.0...v2.23.1
[2.23.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.22.0...v2.23.0
[2.22.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.21.0...v2.22.0
[2.21.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.13...v2.21.0
[2.20.13]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.11...v2.20.13
[2.20.11]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.10...v2.20.11
[2.20.10]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.9...v2.20.10
[2.20.9]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.8...v2.20.9
[2.20.8]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.7...v2.20.8
[2.20.7]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.6...v2.20.7
[2.20.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.5...v2.20.6
[2.20.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.4...v2.20.5
[2.20.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.3...v2.20.4
[2.20.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.2...v2.20.3
[2.20.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.1...v2.20.2
[2.20.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.0...v2.20.1
[2.20.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.19.0...v2.20.0
[2.19.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.11...v2.19.0
[2.18.11]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.10...v2.18.11
[2.18.10]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.7...v2.18.10
[2.18.7]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.6...v2.18.7
[2.18.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.5...v2.18.6
[2.18.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.4...v2.18.5
[2.18.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.2...v2.18.4
[2.18.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.1...v2.18.2
[2.18.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.0...v2.18.1
[2.18.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.10...v2.18.0
[2.17.10]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.9...v2.17.10
[2.17.9]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.8...v2.17.9
[2.17.8]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.6...v2.17.8
[2.17.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.3...v2.17.6
[2.17.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.2...v2.17.3
[2.17.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.1...v2.17.2
[2.17.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.0...v2.17.1
[2.17.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.21...v2.17.0
[2.16.21]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.20...v2.16.21
[2.16.20]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.19...v2.16.20
[2.16.19]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.17...v2.16.19
[2.16.17]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.14...v2.16.17
[2.16.14]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.11...v2.16.14
[2.16.11]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.5...v2.16.11
[2.16.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.0...v2.16.5
[2.16.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.15.0...v2.16.0
[2.15.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.14.0...v2.15.0
[2.14.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.13.0...v2.14.0
[2.13.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.12.0...v2.13.0
[2.12.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.11.0...v2.12.0
[2.11.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.10.0...v2.11.0
[2.10.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.9.24...v2.10.0

- Claude Code 2.1.112〜2.1.132 追从。
  MCP 工具型钩子（直接调用外部道具的处理、`type: "mcp_tool"`）暂不采用。
  继续使用现有 shell 途经钩子。
  记忆 MCP 正式发布、包处理延迟的测量、Claude Code 认证提示出来后重新评估。
  钩子不看推理量而放宽保护。
  钩子从输入 JSON 读取 Session ID，Bash 命令可使用 Claude Code 的 `CLAUDE_CODE_SESSION_ID`。
  确认了即使以 `env`、`sudo`、`watch` 包裹，强制 push、hard reset、对保护分支 push 的检查也会停止。

### Added

- 停止的施工角色最多重启 1 次。
  条件是作业中超过 10 分钟或出现停滞日志。
  超过 30 分钟的对话时，以 `ENABLE_PROMPT_CACHING_1H=1` 启动 Claude Code 可使用 1 小时缓存。
  这是 Claude Code 侧的功能。
- 输出的遮蔽处理为任意，`HARNESS_OUTPUT_GOVERNANCE_ENABLE=1` 不存在时不运行。
  替换的是 `sk-` 后跟 20 字符以上英数字的键。
  `sk-ant-` 后跟 20 字符以上英数字或连字符的键也是对象。
  Read、Grep、Glob、TodoWrite，Bash 的输出不在对象内。
  因此命令显示和文件内的键不被遮蔽。
  记录文件 `.claude/state/output-audit.jsonl` 也保留遮蔽前的正文。
  因此文件本身会放入键，需要保护或删除。
- skill 启动记录仅保存在 `.claude/state/skill-trigger-stats.jsonl`，Session ID 取先头 12 字符。
  `HARNESS_SKILL_TELEMETRY_DISABLE=1` 可停止。
- 在通信拒绝模板 `templates/claude/settings.security.json.template` 中增加了 6 个投稿网站，从 3 个变为 9 个。
  追加了 `pastebin.com`、`transfer.sh`、`0x0.st`、`paste.ee`、`termbin.com`、`ix.io`。
  因为是模板，复制到 `sandbox.network.deniedDomains` 才会生效。
  原文曾介绍在 `.claude-plugin/settings.json` 中追加。
  之后 5.7.0 的记录指出不读取此插件设置的 `permissions`。
  当时的运行环境未重新测试。
  [当前插件设置的官方规格](https://code.claude.com/docs/en/plugins-reference#settings) 中适用的只有 `agent`（默认角色）和 `subagentStatusLine`（施工角色的状态显示）。
  `sandbox` 不在对象内，所以通信拒绝项目要写在用户设置或项目设置中来应用。
  `skillOverrides` 默认未设置。
  向组织推荐 `name-only`，向教育推荐 `user-invocable-only`。

