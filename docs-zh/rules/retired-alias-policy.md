# Retired Alias Policy

Harness 的 **exclusion-based verification（退役别名残留检查）** 运用规则的 SSOT。
Phase 97 中作为 `templates/registry/retired-aliases.v1.yaml` + `bin/harness retired-alias scan` 重新引入。

## 为什么需要此规则

major migration 后，仅靠"新功能是否可用"的 inclusion-based 验证，容易遗漏已删除路径、旧概念、退役命令名的**偶发残留**。
v4.0.0 Hokage 之后偶然发现 13 处 v3 残留的教训表明，需要一个从反方向确认"删除的东西是否还残留"的关卡。

## 5 条规则

### 规则 1: 退役时同步更新 registry

"删除/改名/退役 X 的 PR"与"向 `retired-aliases.v1.yaml` 添加条目"须在**同一 PR** 中完成。不允许先 merge 删除部分，再延迟更新 registry。

### 规则 2: 条目须符合 schema，reason 为必填项

须遵循 `templates/schemas/retired-alias.v1.json`，`id` / `kind` / `pattern` 为必填项。
`reason` 须填写"为什么退役"。allowlist 采用 prefix match，保持最小粒度。

### 规则 3: allowlist 遵守 3 项原则

- **历史记录**: `CHANGELOG.md`、`.claude/memory/archive/` 始终属于 allowlist 对象
- **迁移指南**: `docs/MIGRATION-*.md` 等新旧对比文档
- **特定上下文**: 仅在特定文件中的有意提及才通过 prefix 添加（禁止整目录）

### 规则 4: 执行 retroactive validation

添加新条目后，在历史 commit 上运行 `harness retired-alias scan`，
确认能按预期检测到残留。如果只输出 0 条，可能是 allowlist 范围过宽或 pattern 过弱。

### 规则 5: false positive 为零（HEAD 始终为 0 条）

在当前 HEAD 上 scan 时保持**命中 0 条**。
如有命中，则通过 (1) 修正真正的残留、(2) 属于正当历史记录则添加到 allowlist、
(3) pattern 错误则修正条目的任一方式解决。

## exclusion-based verification 的运用

| 操作 | 命令 / 关卡 |
|------|-------------------|
| 本地确认 | `bin/harness retired-alias scan` |
| CI | `scripts/ci/check-consistency.sh` retired-alias section |
| 正本 registry | `templates/registry/retired-aliases.v1.yaml` |
| schema | `templates/schemas/retired-alias.v1.json` |

scanner 用固定字符串（相当于 grep -F）扫描 repo，
通过每个条目的 allowlist（+ 全局 allowlist）进行 prefix 排除。
命中 1 条即 exit 1。

## 更新步骤

1. 确定退役对象并选择 `kind`（`path` / `concept` / `command` / `skill`）
2. 在 `templates/registry/retired-aliases.v1.yaml` 中添加条目
3. 执行 `cd go && go test ./internal/retiredalias/...` 确认 schema / HeadZeroHits
4. 确认 `bin/harness retired-alias scan` 为 0 条
5. 在 PR 的 CHANGELOG `[Unreleased]` 中添加 Before/After（删除原因 + 替代方案）

旧 `deleted-concepts.yaml` + `check-residue.sh`（Phase 40、Phase 91.7 已移除）
的思想，以最小作用域重新引入 Go selfaudit 层的现行版本。
