# Plans.md Archive Pattern

Plans.md (project root) 的已完成 Phase を切り出し到 `.claude/memory/archive/Plans-*.md` 的 archive 运作模式，以及维持 test 整合性的机制之 SSOT。Phase 64 (v4.8.0 之後) 引入。

## 为何需要此模式

Plans.md 作为项目的作业计划书，随着已完成的 Phase 堆积，行数会不断膨胀。
auto-cleanup hook 在超过 200 行时促使 archive，但过去的 archive 尝试中发现了 2 个问题:

1. **test 不兼容**: `tests/test-claude-upstream-integration.sh` 对 Plans.md 内的 Phase 51-58 系详细任务行有持久要求（超过 10 处的硬编码 grep），archive 后 test 会失败
2. **archive 文件的 commit 遗漏**: `.claude/memory/archive/` 在 gitignore 下，Plans.md 的 archive list link 在 GitHub 上是 dead link

此模式旨在一次性解决两者，使 archive 功能得以运作。

## Archive 命名规则

```
.claude/memory/archive/Plans-YYYY-MM-DD-phaseNN-MM.md
```

- `YYYY-MM-DD`: archive 实施日期
- `phaseNN-MM`: 切出的 Phase 范围 (例: `phase47-61`)

例: `Plans-2026-05-08-phase47-61.md`

## Archive 文件的格式

```markdown
# Plans Archive — Phase 47 / 48 / ... / 61

Archived on YYYY-MM-DD from Plans.md (lines XX-YY).

- Phase 47: 短い説明
- Phase 48: 短い説明
- ...

---

## Phase 47: ...
[元の Plans.md からそのままコピー]
```

开头的 archive 元信息 (Archived on, line range, Phase summary list) 为必填。各 Phase 内容从原始 Plans.md 直接转录。

## Plans.md 侧的更新

archive 执行时，更新 Plans.md 开头部分的 3 点:

1. **最终 archive / 上次 archive**: 将日期和 link 提升一级

   ```markdown
   最終アーカイブ: 2026-05-08（Phase 47-61 → `.claude/memory/archive/Plans-2026-05-08-phase47-61.md`）
   前回アーカイブ: 2026-04-19（Phase 44 + 45 + 46 → `.claude/memory/archive/Plans-2026-04-19-phase44-46.md`）
   ```

2. **在 `## 📦 Archive` section 的 archive list 开头添加新条目**: archive 文件的 link + 1 行摘要

3. **删除 archive 范围的 Phase 全部**: 从文件中删除相应的 line range

## test 整合性: grep_plans_or_archive helper

Phase 64.1.1 引入的 helper。放置为 `tests/lib/grep_plans_or_archive.sh` 的 library，供 `tests/test-claude-upstream-integration.sh` source 使用。

```bash
grep_plans_or_archive 'PATTERN' || {
  echo "Plans.md (or archive) is missing the expected PATTERN reference"
  exit 1
}
```

### 动作规格 (4 状态)

| 情况 | helper return code | 含义 |
|------|--------------------|------|
| 仅在 Plans.md 中匹配 pattern | `0` (success) | archive 前的通常状态 |
| 仅在 archive 中匹配 pattern | `0` (success) | archive 后的状态。已从 Plans.md 删除但仍存留于 archive |
| 两者都匹配 | `0` (success) | 过渡期的混在状态 |
| 两者都没有 | `1` (failure) | 真正消失。test 以 exit 1 报告失败 |

`tests/test-grep-plans-or-archive.sh` 以 unit test 固定此 4 状态。

### test override (unit test 用)

helper 可通过环境变量覆盖目标路径:

```bash
export GPOA_PLANS_FILE="${TMPDIR}/Plans.md"
export GPOA_ARCHIVE_DIR="${TMPDIR}/archive"
```

production code (= test-claude-upstream-integration.sh) 中不进行 override，从 ROOT_DIR 自动解析。

## git track 设置 (.gitignore exception)

为了让 CI 也能看到 archive，`.claude/memory/` 以条件方式 track:

```gitignore
.claude/*
!.claude/rules/
!.claude/output-styles/
!.claude/memory/
.claude/memory/*
!.claude/memory/archive/
.claude/memory/archive/*
!.claude/memory/archive/Plans-*.md
```

此 exception 使得:

- ✅ 类似 `Plans-2026-05-08-phase47-61.md` 的 Plans archive 会被 track
- ❌ session-log 和 codex-learnings 等其他 archive 继续被忽略
- ❌ `.claude/state/` 等继续被忽略

## 标准步骤 (operator checklist)

### 前提
- Plans.md 超过 200 行，auto-cleanup hook 促使 archive
- 要切出的 Phase 范围明确（例: 7 天前完成的连续 Phase 群）
- `tests/lib/grep_plans_or_archive.sh` 存在于 repo（Phase 64.1.1 以降）

### 执行
1. `cp Plans.md Plans.md.bak.$(date +%s)` 备份
2. 创建 archive 文件为 `.claude/memory/archive/Plans-YYYY-MM-DD-phaseNN-MM.md`（上述格式）
3. 从 Plans.md 删除相应 Phase 范围
4. 更新 Plans.md header 的 archive list
5. `bash tests/test-claude-upstream-integration.sh` 确认 archive-aware grep 的动作
6. `./tests/validate-plugin.sh` 确认 48/48 PASS
7. `bash scripts/ci/check-consistency.sh` 确认全合格
8. `bash scripts/check-residue.sh` 确认 0 件
9. 删除 backup (`rm Plans.md.bak.*`)
10. `git add Plans.md .claude/memory/archive/Plans-YYYY-MM-DD-*.md` stage
11. commit + push

### retroactive validation (遵循 `.claude/rules/migration-policy.md` 规则 4)

确认 archive 前的 commit 和 archive 后 HEAD 双方 test 都 PASS:

```bash
# 現 HEAD で test
bash tests/test-claude-upstream-integration.sh

# archive 直前 commit で test
git stash push -u
git checkout <archive-prior-sha> -- Plans.md tests/test-claude-upstream-integration.sh
bash tests/test-claude-upstream-integration.sh
git checkout HEAD -- Plans.md tests/test-claude-upstream-integration.sh
git stash pop
```

双方都 PASS 是 helper 对 archive 过渡具有稳健性的证据。

## 已知的运作注意事项

### settings.json drift (持续调查中)

Phase 64 实现期间，`.claude-plugin/settings.json` 的 `deniedDomains` 定期恢复到 paste-site 6 件删除状态的现象观测到 3 次。原因不明。作为 Phase 64 的范围外，在另一个 issue 中追踪。

### 过去 archive 的 retroactive track

`.gitignore` exception 以 `!.claude/memory/archive/Plans-*.md` glob 将所有 Plans archive 设为 track 对象，但本地存在的过去 archive（如 `Plans-2025-12-25.md` 等）可能包含敏感信息，不纳入首次 commit。经个别 review 后，在另一个 PR 中依次 add。

## 相关文件

- `tests/lib/grep_plans_or_archive.sh` — helper 实现
- `tests/test-claude-upstream-integration.sh` — source helper 进行 archive-aware grep 的 production test
- `tests/test-grep-plans-or-archive.sh` — helper 的 4 状态 unit test
- `.gitignore` (line 25-32) — archive 的 git track 设置
- `.claude/rules/migration-policy.md` — retroactive validation 的规则 4（本文模式的理论依据）
- `.claude/rules/test-quality.md` — 测试篡改禁止规则（含例外承认步骤）
