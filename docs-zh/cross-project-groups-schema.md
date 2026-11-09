# cross-project-group.v1 Schema

Phase 65.3 (Cross-Project Group + 3-Layer Redaction) 引入。
`.claude/rules/cross-project-groups.yaml` 的 schema 规格。

## 目的

Plan Brief / Acceptance Demo / Progress Tracker 等 client 侧 skill 为了 opt-in 启用 **cross-project search** 而定义的组 SSOT。

cross-project search 默认为禁用。仅在通过 `--cross-project-group <name>` flag 明确指定组名时，
才对该组的 member projects 发行 `mcp__harness__harness_mem_search`。

## Schema

```yaml
schema_version: cross-project-group.v1

groups:
  - name: <string>            # group 識別子
    description: <string?>    # 任意 (group の用途説明)
    members:                  # 配列、要素 unique、空 OK
      - <string>              # member project 名
      - <string>
```

## 约束

| 字段 | 类型 | 必需 | 约束 |
|---|---|---|---|
| `schema_version` | string | ✓ | 固定为 `cross-project-group.v1` |
| `groups` | array | ✓ | 可为空数组 `[]` |
| `groups[].name` | string | ✓ | 在 `groups` 内唯一，不可为空字符串 |
| `groups[].description` | string | optional | 可选 |
| `groups[].members` | array | ✓ | 数组，元素唯一，可空 |
| `groups[].members[]` | string | - | 不可为空字符串，不可重复 |

## 校验

`scripts/load-cross-project-groups.sh` 解析 yaml，检测到无效 schema 时以 **exit 1** 停止。

检测的无效情况:

1. `schema_version` 不一致（`cross-project-group.v1` 以外）
2. `groups` 不是 array
3. `groups[].name` 缺失 / 空字符串 / 重复
4. `groups[].members` 不是 array / 元素重复 / 空字符串
5. `groups[].members[]` 不是 string

## 使用例

### CLI (loader script 直接调用)

```bash
# 全 groups を JSON で出力
bash scripts/load-cross-project-groups.sh

# 特定 group の members を JSON array で出力
bash scripts/load-cross-project-groups.sh --group "Personal Tools"
# → ["my-cli","my-dotfiles","my-scripts"]

# 存在しない group は exit 1
bash scripts/load-cross-project-groups.sh --group "Unknown"
# → stderr: "group not found: Unknown" / exit 1
```

### Skill 途径 (Phase 65.3.5 计划实现)

```bash
# 横断検索なし (default、現プロジェクトのみ)
/harness-plan-brief "新しい CI を導入したい"

# 横断検索 opt-in (Personal Tools group の全 members を検索)
/harness-plan-brief "新しい CI を導入したい" --cross-project-group "Personal Tools"
```

## Cross-Project Search 的实现 (D43 Option α)

```
client skill (Plan Brief / Accept / Progress)
   │
   │ --cross-project-group <name>
   ▼
load-cross-project-groups.sh --group <name>
   │
   │ JSON array of member projects
   ▼
For each member in members:
   mcp__harness__harness_mem_search(project=member, ...)
   │
   ▼
client 側でマージ・dedupe (relevance_score 順)
   │
   ▼
Layer 2 (dict + NER) で固有名詞 redact
   │
   ▼
Layer 3 (final scan) で残骸検出 → 0 件なら HTML 生成、検出なら exit 1
```

详细责任边界参见 [.claude/rules/cross-repo-handoff.md](../.claude/rules/cross-repo-handoff.md) 的
"3 层 Redaction 的责任边界" 和 "Phase 65.3 实现决定事项 (D43)"。

## 相关

- `.claude/rules/cross-project-groups.yaml` — 本 schema 的 SSOT (default `groups: []`)
- `scripts/load-cross-project-groups.sh` — yaml → JSON parser + validator
- `tests/test-cross-project-groups-schema.sh` — 4 案例机械验证
- `.claude/rules/cross-repo-handoff.md` — Phase 65.3 实现决定事项 (D43)
- `.claude/rules/client-redaction.yaml` — Layer 2a 字典 (Phase 65.3.2 计划引入)
- Plans.md §65.3.1-65.3.7 — Phase C 全任务
