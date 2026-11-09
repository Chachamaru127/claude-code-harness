# Hardening Parity

最终更新: 2026-07-09 (Phase 111.0)

本文档整理了 Harness 在**多个 host** 上提供相同安全性的程度的通用策略。

要点有 3 个。

- 共通化的是「将什么视为危险」的**策略**（R01–R13 + runtime floor）
- 实现根据 host 的 native pre-action hook 和 codec 进行区分
- **相同的 capability 名，enforcement 强度也因 host 而异**（禁止 false parity）

## Shared kernel (3cli hook floor)

Claude Code (`PreToolUse`)、Codex CLI (`PreToolUse`, **仅 Bash**)、Cursor
(`preToolUse`) 通过生成 hook 汇聚到同一个入口:

```text
host native hook → bin/harness hook pre-tool --host <claude|codex|cursor>
                → runtimefloor + R01–R13 policy
                → exit 2 + host deny envelope
```

证据和详情: `docs/research/3cli-hook-floor-contract-2026-06.md`、
`hosts.toml`、`bash tests/test-3cli-hook-floor.sh`。

**Grok 目前不在 floor 范围内**。不可向 Grok 主张 PreToolUse 级 deny。

## Policy Matrix

| Policy | 示例 | Severity | Claude Code | Codex CLI | Cursor |
|--------|----|----------|-------------|-----------|--------|
| No verification bypass | `git commit --no-verify` | Deny | PreToolUse deny | Bash PreToolUse floor + quality gate | preToolUse deny (when hooked) |
| Protected branch destructive reset | `git reset --hard main` | Deny | PreToolUse deny | Bash PreToolUse floor + quality gate | preToolUse deny (when hooked) |
| Direct push to protected branch | `git push origin main` | Confirm/Deny | PreToolUse | Bash floor + merge gate 推荐 | preToolUse + Lead/merge discipline |
| Force push | `git push --force` | Deny | PreToolUse deny | Bash PreToolUse floor + merge gate | preToolUse deny (when hooked) |
| Protected files editing | `package.json`, workflows 等 | Warn/Fail | PreToolUse warn | quality gate fail (较强) | guidance + outer review |
| Pre-push secrets scan | token-like string | Deny | Bash 前 deny 或 fail | Bash floor + quality gate | preToolUse when shell is mapped |

## Protected Files Profile

默认的 protected files 限定于「破坏影响面广、但正常实现中不会每次都触碰」的文件。

- `package.json`
- `Dockerfile`
- `docker-compose.yml`
- `.github/workflows/*.yml`
- `.github/workflows/*.yaml`
- `schema.prisma`
- `wrangler.toml`
- `index.html`

设计意图:

- **基本使用 warn 而非 deny**（正当的变更确实存在）
- `.env` 和私钥通过**单独规则 deny**（protected path）
- Codex 的 merge gate 对 protected files 更容易视为 fail

## Runtime Mapping

### Claude Code

- **PreToolUse**: 多种 tool 类型执行前 deny / ask / warn
- **PostToolUse**: 写入后的警告
- **PermissionRequest**: 安全 read-only / test 的自动许可

### Codex CLI

Codex **拥有 hook**（2026-06 3cli floor 以后）。但:

1. **PreToolUse 仅限 Bash**
   non-Bash（例如: Read `~/.ssh/...`）不会被 hook hard-deny
2. **执行前 contract 注入**
   在 companion / instructions 中明确禁止事项
3. **post-exec quality gate + merge gate**
   不通过的产出物不合并到 main
4. **worktree fingerprint**
   通过敏感 path 的事后差分进行补充

「Codex 没有 hook」是**过时描述**。正确的简述是
**「Bash PreToolUse floor + 事后 gate。non-Bash 与 Claude 不对称」**。

### Cursor

- Project `.cursor/hooks.json` → `harness hook pre-tool --host cursor`
- 实时 deny 已在 Phase 83.7 观测到（阻止 protected path Write）
- **没有传统的 FS jail**（官方 security 文档 + spike 经验）
- permissions allowlist 是 **best-effort**（不是 security guarantee）
- non-exit-2 可能变成 fail-open

### Grok

- Plugin install / skill discovery 是 candidate 证据
- 不是 Harness 共享 pre-tool floor 的**成员**
- 不主张 SessionStart / PreToolUse 同等能力

## Known Asymmetry

| 项目 | Claude Code | Codex CLI | Cursor | Grok |
|------|-------------|-----------|--------|------|
| 执行前中断 | 强（多 tool） | 仅 Bash 强 | tool deny 可 | 未 claim |
| FS 限制 | 依赖权限模型 | worktree + fingerprint | **弱 / 无** | 未 claim |
| 命令单位 deny | 强 | Bash floor | 强但有 fail-open | 未 claim |
| 合并到 main 前的阻止 | 可能 | merge gate | Lead review + cherry-pick | 运营依赖 |
| Floor membership | yes | yes | yes | **no** |

总之:

- **Claude Code** 擅长当场广泛阻止
- **Codex CLI** 是 Bash 事前停止 + 不让输出通过的二段
- **Cursor** 可以 deny，但 containment 无法委托给 host
- **Grok** 尚在 shared floor 之外

## Operator Guidance

- 安全性优先的工作优先使用 Claude Code 路径
- Codex 作为实现 / 审查辅助使用，在合并到 main 前通过 quality gate
- Cursor write 以 dedicated worktree + Lead review + cherry-pick 为前提
- 不期待 Grok 实现危险操作的执行前停止（其当前 tier 为 `candidate` 的原因）

## Validation Surface

- 不得与 `docs/tool-capability-matrix.md` 的 `pre_use_guard` 行矛盾
- `bash tests/test-3cli-hook-floor.sh`（3cli）
- `bash tests/test-support-claim-wording.sh`（公开措辞）
- host 升级须以同一 claim path 满足 H1–H8（`docs/spec/planning-and-host-adapter.md`）

## Related

- `docs/research/3cli-hook-floor-contract-2026-06.md`
- `docs/research/cursor-adapter-candidate.md`
- `docs/research/grok-adapter-candidate.md`
- `docs/plans/phase-111-multi-host-supported.md`
