# Issue #105 Response Draft

状态: prepared for Phase 55 / task 55.4.1

Issue: [#105 Can the default language be changed to English?](https://github.com/Chachamaru127/claude-code-harness/issues/105)

## Draft Reply

感谢您提出此问题。

是的。对于新分发的 surface，用户面默认语言现在是英语，同时日语保留为显式 opt-in。

变更内容：

- 新的 setup 模板默认渲染为英语。
- config schema 和 example 将 `i18n.language` 默认为 `en`。
- 发布的 skill metadata 在 `description` 中使用英语，同时保留 `description-en` 和 `description-ja`。
- 日语用户仍可用 `i18n.language: ja`、`CLAUDE_CODE_HARNESS_LANG=ja` 或日语 locale 模板来 opt in。
- 日语 workflow 的可发现性得以保留。诸如 `実装して`、`レビューして` 和 `計画作って` 等重要日语触发器仍被 skill metadata 或使用文本覆盖。
- 诸如 `cc:完了`、`pm:確認済` 和 `cc:WIP` 等内部 Plans.md status marker 仍是协议值。它们有意不作为本次变更的一部分被翻译，以便现有 Plans 工具继续工作。

验证命令：

```bash
bash scripts/i18n/check-translations.sh
bash tests/test-i18n-default-language.sh
bash tests/test-i18n-skill-frontmatter.sh
bash tests/test-i18n-locale-roundtrip.sh
bash tests/test-setup-language-rendering.sh
bash scripts/sync-skill-mirrors.sh --check
node scripts/build-opencode.js
node scripts/validate-opencode.js
bash tests/test-codex-package.sh
./tests/validate-plugin.sh
bash scripts/ci/check-consistency.sh
cd go && go test ./... && go vet ./...
```

CI 路径也通过 `.github/workflows/validate-plugin.yml` 运行 i18n 回归套件，并且 `scripts/ci/check-consistency.sh` 现在包含 i18n gate，因此分发 preflight 能在发布前捕获语言 drift。

## Pre-Close Guardrails

这些 guardrail 是关闭 issue 时的状态迁移安全注意事项。

| Item | Current state | Target state | Required behavior |
| --- | --- | --- | --- |
| Default locale | 历史上部分用户面 surface 假定为日语。 | 新的分发 surface 默认为英语。 | 缺失或未设置的 locale 解析为 `en`。 |
| Explicit Japanese | 现有用户可能设置 `i18n.language: ja` 或 `CLAUDE_CODE_HARNESS_LANG=ja`。 | 日语保持为 opt-in。 | 有效的 `ja` 必须被保留，不得被启动或验证覆盖。 |
| Skill metadata | Skill 可能包含双语 metadata 和镜像副本。 | `description` 等于 `description-en`；`description-ja` 仍然存在。 | 镜像检查和 i18n 检查必须覆盖 root、Codex 和 OpenCode 的 skill surface。 |
| Status markers | Plans 工具存储日语协议 marker。 | 协议 marker 保持不变。 | Writer 保持规范 marker；Reader 保持别名兼容。 |
| Setup templates | 默认模板和日语模板共存。 | 默认 setup 输出英语；日语 setup 保持可达。 | 模板渲染测试必须验证两条路径和未解析的占位符。 |

不变量：

- 在本 issue 期间不要翻译内部 Plans.md 状态 marker。
- 不要删除日语模板、日语 README 或日语 skill 路由文本。
- 不要在验证期间重写显式的用户 locale 状态。
- 重新运行 locale 检查或 setup 渲染测试必须是幂等的。
- 镜像验证必须证明打包的 skill surface 与其事实来源一致。

回滚：

- 功能性回滚优先采用向前修复：恢复失败的 surface，重新运行 i18n 套件，然后重新运行完整 preflight。
- 如果 CI gate 本身造成误报，只回退 gate 变更，同时保持已发布的英语/日语状态完整。
- 由于本任务添加的是验证和文档，因此不需要破坏性数据回滚。

中止条件：

- 任何 i18n 回归命令失败。
- `sync-skill-mirrors.sh --check` 报告 drift。
- `build-opencode.js` 或 `validate-opencode.js` 造成意外的分发 drift。
- `validate-plugin.sh`、`check-consistency.sh`、Go tests 或 Go vet 失败。

Dry-run 与验证：

- 将草案回复中的所有命令视为关闭前的 dry-run。
- 比较 `node scripts/build-opencode.js && node scripts/validate-opencode.js` 前后的 `git status --short`；只应保留有意的 docs、CI 或 gate 变更。
- 在响应草案和验证输出一致之前，保持 Issue #105 为开启状态。
