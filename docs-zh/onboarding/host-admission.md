# Host 准入（N+1）

最后更新：2026-07-09（Phase 111.1）

本页是**将新 agent host 添加到 Claude Code Harness 的检查清单**。
它与 `docs/spec/planning-and-host-adapter.md` 中的多 host 栏 **H1–H8** 以及
机器 SSOT `hosts/registry.json` 配对。

## 为什么需要注册表

没有注册表，每个新 host 都会在以下位置复制 case 语句：

- `scripts/build-host-plugin-dist.sh`
- `scripts/model-routing.sh`
- `scripts/release-preflight.sh`
- README / matrix / onboarding tier 表格

这种雪花成本无法扩展。新 host 从**一行注册表**加上
薄型 setup/冒烟脚本开始。

## SSOT 布局

| 文件 | 角色 |
|------|------|
| `hosts/registry.json` | 机器 SSOT：id、tier、setup、dist、routing、floor_member、smoke 路径 |
| `hosts.toml` | `harness gen` 的 hook 生成描述符（event/deny/codec）——独立关注点 |
| `scripts/lib/host-registry.sh` | 读取注册表的 Bash/node 辅助函数 |
| `tests/test-host-registry.sh` | Tier 表格和脚本路径必须与注册表匹配 |

## 准入检查清单（12 项）

在将公开 tier 提高到 `future/unsupported` 之前完成。

1. **原生拦截或明确无**
   Host 能在操作运行前停止它吗？如果不能，设置
   `safety_model: none`，**最高**公开 tier 为 packaging / candidate，直到存在
   文档化的 post-gate 模型。

2. **Deny 语义**
   记录 fail-closed 与 fail-open（例如 Cursor 非 exit-2 为 fail-open）。

3. **事件覆盖**
   仅 Shell？文件写入？MCP？读取？诚实记录仅 Bash 的差距。

4. **安装单元测试**
   隔离的 HOME / install root；不向 operator 的实时配置写入。

5. **CI 中的静态 smoke**
   包形状，dist manifest 中无 `..`，核心 skills 存在。

6. **可选运行时标志**
   `HARNESS_<HOST>_*_SMOKE_REQUIRED=1` 用于 CLI 预期存在时的硬失败。

7. **引导路由命名**
   `docs/bootstrap-routing-contract.md` 中的条目（不是虚假的 SessionStart 对等）。

8. **support-claim 措辞**
   在 H1–H8 通过之前（`tests/test-support-claim-wording.sh`）阻止此 host 的 EN `supported` 和 JP 正式対応 / 対応済み。

9. **证据研究报告**
   `docs/research/<host>-adapter-candidate.md`，包含已观察 / 缺失 / 命令。

10. **Floor 加入或明确排除**
    `floor_member: true` 仅在 `harness hook pre-tool --host <id>` 实时 deny 之后；
    否则为 `false`，永不声称 3cli 对等。

11. **公开措辞模板**
    注册表 `blocked_public_phrases` + onboarding 中允许与禁止的短语。

12. **能力矩阵行**
    每个能力单元格都有强度语言；同名不等于同等执行。

## 如何添加 host `example`

1. 实现薄型 `scripts/setup-example.sh`（`--check` + 隔离安装）。
2. 在 `build-host-plugin-dist.sh` 中添加 dist profile **或者** 由注册表字段驱动的通用复制 profile（优先通用）。
3. 如果 host 是执行/路由 surface，在 `model-routing.sh` 中添加路由目录。
4. 向 `hosts/registry.json` 追加一行。
5. 添加 `tests/test-example-adapter-*.sh` 并将 `smoke.adapter` 指向它。
6. 更新 README / matrix / onboarding tier 表格（或稍后从注册表生成）。
7. 运行：

```bash
bash tests/test-host-registry.sh
bash tests/test-host-plugin-dist.sh
bash tests/test-model-routing.sh
bash tests/test-support-claim-wording.sh
```

8. 在 H1–H8 通过一条声明路径之前**不要**设置 `tier: supported`（Phase 111）。

## 注册表字段契约

| 字段 | 含义 |
|-------|------|
| `id` | 稳定 slug（`grok`、`cursor`） |
| `display_name` | 公开表格标签（`Grok`、`Claude Code`） |
| `tier` | `supported` \| `internal-compatible` \| `candidate` \| `future/unsupported` |
| `setup_script` | 路径或 null |
| `dist_host` | `build-host-plugin-dist.sh --host` 的值 |
| `routing_host` | `model-routing.sh --host` 的值 |
| `safety_model` | 用于 docs/tests 的自由形式枚举字符串 |
| `floor_member` | 布尔值——共享 pre-tool floor |
| `smoke.adapter` / `smoke.setup_check` | preflight 的命令/路径 |
| `blocked_public_phrases` | 不得作为公开声明出现的模式 |

## 相关

- `docs/bootstrap-routing-contract.md`
- `docs/tool-capability-matrix.md`
- `docs/plans/phase-111-multi-host-supported.md`
- `docs/spec/planning-and-host-adapter.md`（H1–H8）
