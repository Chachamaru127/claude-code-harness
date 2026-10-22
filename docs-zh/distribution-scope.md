# Distribution Scope

最后更新：2026-05-14

本文档将 `claude-code-harness` 中"存在于 repo 但不包含在 Claude Code plugin 分发 payload 中"的内容明确化。
`Plans.md`、README、`.gitattributes`、分发脚本、验证脚本中遇到疑问时，
将本表作为正本处理。

## Scope 表

| Path | 状态 | 存在理由 | 强制信号 |
|------|--------|---------------|--------------------|
| `.claude-plugin/` | Distribution-included | Claude Code plugin manifest / hooks / settings | `claude plugin validate`、`test-distribution-archive.sh` |
| `.cursor-plugin/` | Source-repo adapter only | Cursor 适配器候选 manifest；不是 Claude plugin archive payload | `.gitattributes export-ignore`、`test-distribution-archive.sh` |
| `.codex-plugin/` | Source-repo adapter only | Codex 适配器 manifest；不是 Claude plugin archive payload | `.gitattributes export-ignore`、`test-distribution-archive.sh` |
| `bin/harness*` | Distribution-included | Go-native guardrail / lifecycle runtime | `validate-plugin`、`go test`、archive required entries |
| `skills/` | Distribution-included | Claude Code 用 primary skill surface | `validate-plugin`、mirror sync checks |
| `agents/` | Distribution-included | worker / reviewer / advisor | `validate-plugin`、agent frontmatter tests |
| `hooks/`、`monitors/` | Distribution-included | 运行时 hook / monitor definitions | `hooks/hooks.json`、`validate-plugin` |
| `output-styles/` | Distribution-included | Claude Code output style | `plugin.json`、archive required entries |
| `templates/`、`workflows/` | Distribution-included | project init / rules / workflow templates | `check-consistency.sh`、template registry checks |
| `scripts/` runtime files | Distribution-included | hook handlers、setup、sync、review、plan、loop runtime | `validate-plugin`、runtime hook tests |
| `assets/`、公开 `docs/` | Distribution-included | README assets 和公开用户文档 | README claim drift checks |
| `commands/` | Compatibility-retained | 旧 slash command 资产。仅在存在时验证 | `validate-plugin` |
| `codex/`、`opencode/`、`skills-codex/` | Source-repo mirror only | 替代客户端 mirror / setup 导轨。不会包含在 Claude plugin archive 中 | `test-codex-package.sh`、`opencode-compat.yml`、`.gitattributes` |
| `go/`、`tests/`、`benchmarks/`、`.github/` | Development-only and distribution-excluded | source / CI / benchmark / validation | `.gitattributes`、`test-distribution-archive.sh` |
| `.claude/`、`.cursor/`、`CLAUDE.md`、`AGENTS.md`、`Plans.md` | Development-only and distribution-excluded | repo-local agent context、local plans、editor setup | `.gitattributes`、`test-distribution-archive.sh` |
| `.private/` | Local-only and distribution-excluded | 放在 `skills/` 下时会在 `claude --plugin-dir .` 的 inventory 中出现的 private/dev-only skills 的退避处 | `.gitignore`、`test-public-plugin-inventory.sh` |
| `scripts/ci/`、`scripts/evidence/`、`scripts/sandbox-test/` | Development-only and distribution-excluded | CI helpers、evidence fixtures、本地 sandbox 示例 | `.gitattributes`、`test-distribution-archive.sh` |
| `mcp-server/` | Development-only and distribution-excluded | 可选功能。在 repo 中保留用于开发/调查，但不包含在分发 payload 中 | `.gitignore`、`.gitattributes`、CHANGELOG history |
| `harness-ui/`、`harness-ui-archive/`、`remotion/` | Development-only and distribution-excluded | 可选 UI / video 实验和存档 | `.gitignore`、`.gitattributes`、CHANGELOG history |
| `docs/research/`、`docs/private/`、`docs/notebooklm/`、`docs/slides/`、`docs/presentation/`、`docs/social/` | Private or generated reference | 调查记录、公开前草稿、生成中间产物 | `.gitignore`、`.gitattributes`、`test-distribution-archive.sh` |

## 当前决定

- `commands/` 不视为已删除。目前为 **Compatibility-retained**。
- `codex/` / `opencode/` 是 repo 上的 mirror 作为验证对象，但从 Claude Code plugin archive 排除。
- `.codex-plugin/` / `.cursor-plugin/` 是适配器元数据，不是 Claude Code plugin archive payload。host-specific install package 由 `scripts/build-host-plugin-dist.sh` 生成。
- `.claude/` / `.cursor/` / `CLAUDE.md` / `AGENTS.md` / `Plans.md` 是 repo-local context，不是 plugin payload。
- private/dev-only skills 不放在 `skills/` 下。即使 `.gitignore` 了也会在 `claude --plugin-dir .` 的 local inventory 中露出，因此退避到 `.private/skills/` 等 public plugin surface 之外。
- `mcp-server/` 不视为已删除。目前为 **Development-only and distribution-excluded**。
- `scripts/hook-handlers/memory-bridge.sh` 和 `memory-*.sh` 在 local bridge 中也是 **Distribution-included**。因为 hook 引用，需要在 repo 中 tracked。
- 在 README 或 `Plans.md` 中写"已删除"时，仅在实际从 tree 中消失时使用。
- "分发外""兼容维持""开发专用"根据本文件的标签区分使用。

## 更新规则

发生以下任一情况时，同一 PR / commit 中也更新本表。

1. 更改了 README 的 architecture / install / compatibility 说明时
2. 更改了 `.gitignore` 或 build script 的排除规则时
3. 更改了 `commands/` 或 `mcp-server/` 等容易被误解存在理由的目录的处理方式时
4. 更改了 `.gitattributes` 的 `export-ignore` 或 `tests/test-distribution-archive.sh` 的 required / forbidden list 时
