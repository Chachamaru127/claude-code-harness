# Benchmark Rubric

最终更新: 2026-03-06

本文档是 `claude-code-harness` 与其他工具进行比较时的可重现执行的 rubric。
不是 README 的印象，而是将静态证据和执行证据分开评分。

## Evidence Classes

| Class | 示例 | 使用场景 |
|------|----|-----------|
| Static evidence | README、repo tree、hooks 定义、tests、docs、package metadata | 机制有无、设计清晰度、分发导线的比较 |
| Executed evidence | test run、smoke run、benchmark logs、evidence pack、CI artifact | 主张能否重现、guardrail 是否实际有效的比较 |

## Scoring Axes

| Axis | Weight | 检查内容 |
|------|--------|-----------------|
| Runtime enforcement | 25 | Hooks、guardrails、deny/warn 行为、生命周期自动化 |
| Verification and test credibility | 25 | Unit/integration tests、consistency checks、evidence pack、CI 覆盖率 |
| Onboarding and operator clarity | 20 | install flow、docs 完整性、主张一致性、quickstart 质量 |
| Scope discipline and maintainability | 15 | distribution boundary、compatibility story、residue 管理 |
| Positioning and adoption proof | 15 | public narrative、stars/users、可重现展示、差异化 |

合计: 100 分

## Review Flow

1. 收集 Static evidence
2. 列出需要 Executed evidence 的主张
3. 将可执行的主张和未执行保留的主张分开
4. 各 axis 评分并明确证据类型
5. 写出"设计强但未验证""市场强但 runtime enforcement 薄弱"等，优势和劣势分开

## Required Output Format

比较报告至少包含以下内容。

- 比较日期
- 目标仓库 / 版本 / commit 或 default branch snapshot
- 执行的命令列表
- Static evidence 和 Executed evidence 的区分
- 各 axis 的分数
- 无法重现的项目

## Reusable Template

```md
# Benchmark Report

- Compared at:
- Repositories / versions:
- Commands executed:

## Static evidence

- Repo structure:
- Docs and claims:
- Guardrails / hooks / tests:

## Executed evidence

- Validation commands:
- Benchmark or smoke runs:
- Evidence artifacts:

## Scores

| Axis | Score | Evidence type | Notes |
|------|-------|---------------|-------|
| Runtime enforcement |  | Static / Executed |  |
| Verification and test credibility |  | Static / Executed |  |
| Onboarding and operator clarity |  | Static / Executed |  |
| Scope discipline and maintainability |  | Static / Executed |  |
| Positioning and adoption proof |  | Static / Executed |  |

## Unverified or blocked items

- 无

## Harness-specific Notes

- `/harness-work all` 这样的强主张，要在 `docs/evidence/work-all.md` 的执行证据齐全后才能获得高分
- `commands/` 或 `mcp-server/` 这样的残留物不是扣分对象，**仅在说明含糊时扣分**
- README 的主张与测试/CI/分发边界不一致时，下调 Onboarding and operator clarity
