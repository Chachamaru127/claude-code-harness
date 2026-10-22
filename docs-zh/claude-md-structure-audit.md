# CLAUDE.md 结构审计 — Phase 47.1.1 调查报告

调查日期: 2026-04-20
对象: `CLAUDE.md` v2026-04-19 时点 (142 行，Phase 50.1.1 的 pointer 添加后)
Phase 47 的目标: session-start 读取成本的实测 → 是否可以分割到 `.claude/rules/` 的判断

## (a) 各 section 的行数统计

用 `awk` 按 `## H2` 边界统计行数的结果:

| # | Section | 行范围 | 行数 |
|---|---------|--------|-----|
| 1 | Project Overview | 5-10 | 6 |
| 2 | Claude Code Feature Utilization | 11-18 | 8 |
| 3 | Development Rules | 19-44 | **26** |
| 4 | Repository Structure | 45-48 | 4 |
| 5 | Using Skills (Important) | 49-66 | **18** |
| 6 | Development Flow | 67-74 | 8 |
| 7 | Testing | 75-83 | 9 |
| 8 | Notes | 84-90 | 7 |
| 9 | MCP Trust Policy | 91-98 | 8 |
| 10 | Permission Boundaries | 99-114 | **16** |
| 11 | Key Commands (for development) | 115-127 | 13 |
| 12 | SSOT (Single Source of Truth) | 128-132 | 5 |
| 13 | Test Tampering Prevention | 133-142 | 10 |
|   | (header + 空行) | 1-4 | 4 |
|   | **合计** | | **142** |

### 前 3 大 section

1. **Development Rules (26 行)**: 5 个 sub-section (Commit / Version / CHANGELOG / Language / Code Style)
2. **Using Skills (18 行)**: Top Skill Categories 表格 (5 行) + trigger 说明
3. **Permission Boundaries (16 行)**: guardrail 7 行表格 + 说明

没有超过 30 行的 section。142 行整体约 3.5KB（session-start context 整体的 1-2%）。

## (b) 可分割 section 候选列表

可以移至 `.claude/rules/` 的候选:

| 候选 | 当前位置 | 分割目标方案 | 优点 | 顾虑点 |
|------|----------|---------|---------|-------|
| **MCP Trust Policy** | CLAUDE.md 91-98 (8 行) | `.claude/rules/mcp-trust-policy.md` | 与现有 `codex-cli-only.md` 整合，外部 MCP 添加流程独立管理 | 8 行分割价值有限 |
| **Permission Boundaries** | CLAUDE.md 99-114 (16 行) | `.claude/rules/permission-boundaries.md` | 与 settings.json deny 联动，表格易于扩展 | session-start 时每次都希望看到的重要信息 |
| **Development Rules** | CLAUDE.md 19-44 (26 行) | `.claude/rules/development-rules.md` 整体或按 sub-section 分散 | 最大 section 的轻量化 | CHANGELOG 已分离到 `github-release.md`，剩余部分很短 |
| **Notes** | CLAUDE.md 84-90 (7 行) | 删除或合并到 Repository Structure | section header + 4 项开销大 | 太小单独分割没有价值 |

列出 2 个以上候选满足 DoD (b)。但由 (d) 的判断决定是否分割。

## (c) `@` 记法可行性的调查

### 调查方法

用 grep 确认现有 repo 内 `@path/to/file.md` 模式的使用:

```bash
grep -rE '@[a-zA-Z0-9_/.-]+\.md' CLAUDE.md .claude/rules/*.md
# → 0 件
```

其他位置的使用:
- `.claude/worktrees/flamboyant-shannon/templates/*/commands/review-cc-work.md:83`: 在 **prompt body 内**以 `@Plans.md 从...` 的形式使用
- `docs/constitution.md:99`: `@docs/constitution.md 的质量门满足条件。` (self-reference，prose)

### 判定

1. **CC 2.1.111+ 的 `@file.md` 记法官方规格**: Claude Code 的 CLAUDE.md 会自动包含，但 `@path/to/file.md` 记法通过额外 import 的功能**确认为已文档化的稳定功能的证据无法获得**。作为 prompt body 内的参考引导可以使用，但 CLAUDE.md 本身已自动加载的现状下存在双重加载的风险
2. **现有使用经验**: 在 CLAUDE.md 内未使用。pointer 始终使用 `[.claude/rules/xxx.md](path)` 的普通 markdown 链接形式
3. **smoke test 的存在**: `tests/test-claude-md-auto-include.sh` 不存在。作为功能通过 smoke test 确认的对象不合适，是 CC 版本兼容性的问题

**结论**: `@` 记法**无稳定运行的保证**。现状的 pointer 方式（普通 markdown 链接 + session-start 时 assistant 需要时用 Read 追查）最安全。

## (d) 最终判断和依据

### 判断: **现状维持（不分割）**

### 依据

1. **定量数据**: 142 行 / 最大 section 26 行从 CC 的 session-start context 来看是轻量的。不分割 token pressure 也不高
2. **pointer 方式的安全性**: 现有 CLAUDE.md 已设计为 "concise overview + detailed pointer" 模式（CHANGELOG → `github-release.md`, skill catalog → `docs/CLAUDE-skill-catalog.md`, feature table → `docs/CLAUDE-feature-table.md`）。详细信息已外置，CLAUDE.md 剩余的是 "session-start 时必须参考的 overview 和 index"
3. **`@` 记法的不确定性**: CC 2.1.111+ 中 `@` 记法能否升级为 auto-include 没有保证。现有 pointer（普通链接）可以 assistant 需要时用 Read 追查的方式运行。迁移到 `@` 的 divergence risk 大于收益
4. **分割的主观成本**: 将 section 移到 `.claude/rules/` 会使 source-of-truth 分散到 2 处。现状下只需阅读 CLAUDE.md 就能一览 Harness 固有运营规则的 "目录" 的优点会丧失
5. **hook 警告的处理**: `PostToolUse` hook 在超过 130 行时发出警告的机制是从 v4.3.1 左右引入的，这是 "接近 150 行时需要重新考虑" 的意思，不是 "应该立即分割" 的意思。Phase 50.1.1 增加 1 行是必要最小的 pointer 添加，是有意的

### 未来的分割触发条件（未来应对规则）

- **Trigger A**: 单一 section 超过 30 行时，只分割该 section
- **Trigger B**: CLAUDE.md 整体超过 180 行时，考虑整体重构
- **Trigger C**: CC 官方文档明确 `@` 记法的 auto-include 行为时，考虑 section 重新配置 + 用 `@` 记法统一 import

现时点 (142 行，最大 26 行) 不满足 Trigger A/B/C 中的任何一个，因此现状维持是最优解。

## (e) 本 Phase 的成果

本 Phase 仅进行调查，**本体 `CLAUDE.md` 的结构未做更改**。
Phase 50.1.1 的 pointer 1 行添加作为单独任务已实施。

## 相关文件

- `CLAUDE.md` (调查对象，无更改)
- `.claude/rules/` 下的 17 个文件 (分割目标候选)
- `docs/CLAUDE-feature-table.md` (已外置的示例)
- `docs/CLAUDE-skill-catalog.md` (已外置的示例)
- `docs/CLAUDE-commands.md` (已外置的示例)
