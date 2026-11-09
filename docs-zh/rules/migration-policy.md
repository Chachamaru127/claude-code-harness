# Migration Residue Policy

Harness 的 **exclusion-based verification（删除概念残骸检查）** 运用策略。
定义 Phase 40 (v4.1.0) 引入的 `deleted-concepts.yaml` + `check-residue.sh` 的
运用规则。

## 为什么需要这个规则

v4.0.0 "Hokage" 发布后，TypeScript 到 Go 的全面迁移本应"完成"了。
但发布后 2 天内，发现了 13 件"旧时代残骸"。
测试脚本中残留已删除文件路径、文档中遗留旧版本名、
README 写着需要 Node.js — 这些都是个别 review 或"包含 X 吗"这种
确认无法发现的。

要确认"大的迁移后真的没有遗留旧东西"，
需要"删除的东西没有残留吗"这种逆方向的确认（exclusion-based verification）。
遵守此规则，下次以后的 major migration 就不会重蹈覆辙。

## 5 个规则

### 规则 1: major version migration 时必须更新 deleted-concepts.yaml

"删除 X 的 PR"和"向 deleted-concepts.yaml 添加 X 的 PR"必须同时
提出。延迟禁止。

**理由**：删除后才推迟 yaml 更新的话，期间其他 PR 会混入对 X 的
引用，在不知不觉中被 merge。yaml 更新附带在删除 PR 中，
使"删除 = 扫描对象化"成为不可分的 1 个事务。

### 规则 2: 更新时机是"与删除 PR 同时"

规则 1 的强化形式。例：发出删除 TypeScript guardrail engine 的 PR 时，
在同一 PR 中向 `deleted_concepts` 添加 `"TypeScript guardrail engine"`。

"已删除"和"已扫描对象化"必须同时完成。仅有其中一方等于只完成一半。

### 规则 3: allowlist 按 3 个原则运用

deleted-concepts.yaml 的 `allowlist` 字段可以包含：

- **历史记述**：CHANGELOG.md、`.claude/memory/archive/` 始终 allowlist。
  "过去有过这种东西"的记录是正当的提及，不是残骸。
- **迁移指南**：如 `docs/MIGRATION-*.md` 这样写旧→新对比的文档。
  在比较表中举出旧名称是意图的记述。
- **个别文脉**：在特定文档中对旧概念的提及是**意图地正当**的情况。
  例：`.claude/memory/archive/v3-architecture.md` 是 v3 架构的历史记录，
  因此包含 `"Harness v3"` 是理所当然的。

allowlist 按前缀匹配应用。保持 entry 的**粒度最小**。
将 `CHANGELOG.md` 整体放入 allowlist 是正当的，但
将 `docs/` 目录整体放入是过度的，使 scanner 变得无意义。

### 规则 4: 必须实施 retroactive validation（向过去 commit 追溯验证）

追加新的 deleted-concepts.yaml entry 时，**向过去 commit 追溯
运行 scanner，确认是否如预期检测到残骸**：

```bash
git checkout <past-commit>
bash scripts/check-residue.sh
# → 期待件数検出（0 件以上であること）
git checkout -
```

由此验证"yaml 真的能检测问题吗"。
检测不到的话，可能是 allowlist 写得过宽或 pattern 有误。
早期发现偶然通过的 false allowlist 是目的。

### 规则 5: false positive 零（现 HEAD 始终为 0 件）

运行 scanner 时，现 HEAD 的**检测件数必须始终为 0**。
检测到时按以下任一处理：

1. **真正的残骸**则立即修正（修改文件删除旧引用）
2. **历史记述等应该加入 allowlist**则更新 yaml
3. **误分类**（yaml 的 pattern 意外一致）则从 yaml 删除

CI（validate-plugin.sh 的 Section 9）和 release preflight（harness-release 的 Phase 0）
都有自动检查，**merge 前保证为 0 件**。

## 附录：本期 session (v4.0.0 → v4.0.1) 的 13 件 v3 残骸事例

Phase 40 的动机事例。**此功能为什么诞生的故事。**

### 发现经过

v4.0.0 "Hokage" 发布 (2026-04-09) 是 TypeScript 实现到 Go 原生实现的
全面迁移。迁移本身完成了，但**测试脚本、文档、SKILL.md 各处
残留了 TypeScript 时代的引用作为残骸**。
这些通过以下路径偶然发现：

1. 测试执行失败 → validate-plugin.sh / check-consistency.sh 失败
2. 用户在 slash palette 发现 → SKILL.md frontmatter 的 "Harness v3"
3. 代码 review 中发现 → agents/*.md 的 v3 narrative
4. 文档 review → README.md 的 core/ engine 提及

"偶然发现"是问题。没有机制的话下次发布也会发生。

### 13 件分类

| 类别 | 件数 | 代表例 |
|---------|------|--------|
| 已删除路径引用 | 2 | `core/src/guardrails/rules.ts` |
| 已删除概念词 | 3 | "TypeScript guardrail engine" |
| SKILL.md 版本后缀 | 2 | `# Harness Work (v3)` |
| 旧运行时要求 | 1 | "Node.js 18+ is installed" |
| 历史表格 | 1 | README 文件树的 `core/` |
| 其他（个别书式 bug） | 4 | README 重复行、日语/英语 drift |

### 教训

这 13 件全部是**inclusion-based verification**（"包含 X 吗"这种确认）
无法检测的。因为"X 没有残留"的确认，
不预先具备"X 已删除"的知识就无法进行。

需要 **exclusion-based verification**（"已删除的 X 没有残留吗"这种逆方向确认）
的视角。Phase 40 是为了将该视角引入 Harness 的验证层而诞生的。

## 相关文件

- `.claude/rules/deleted-concepts.yaml` — 已删除路径/概念的 SSOT 目录
- `scripts/check-residue.sh` — scanner 实现（false positive 立即归零）
- `go/cmd/harness/doctor.go` — `bin/harness doctor --residue` 标志
- `tests/validate-plugin.sh` — Section 9: Migration residue check（CI gate）
- `skills/harness-release/SKILL.md` — Phase 0 preflight step 2（release gate）
