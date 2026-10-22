# Codex upstream snapshot - 2026-05-10

本 snapshot 为追踪 Codex `0.130.0` stable 的记录。
Phase 67.1.1 中固定 upstream 事实，Phase 67.1.2 以后将实现对象分开到 provider / app-server /
plugin workflow docs。

确认日：

- 2026-05-10 (Asia/Tokyo)

対象 release：

- tag: `rust-v0.130.0`
- name: `0.130.0`
- prerelease: `false`
- published_at: `2026-05-08T23:09:55Z`
- release URL: <https://github.com/openai/codex/releases/tag/rust-v0.130.0>
- compare: <https://github.com/openai/codex/compare/rust-v0.129.0...rust-v0.130.0>

现有 Harness 的追従完毕点：

- Codex `0.124.0` stable (Phase 56)
- Codex `0.125.0` / `0.128.0` stable (Phase 58)
- Claude Code `2.1.112`-`2.1.132` follow-up (Phase 62)

分类：

- `A: 検証強化`: 在本次 snapshot / Feature Table / CHANGELOG / tests 中固定 upstream 追踪。
- `C: 自動継承`: 继承 Codex 本体的修正。不叠加 Harness wrapper。
- `P: Plans 化`: 对 Harness 有使用价值，但本 snapshot 中不进行 runtime 实现，切为 Phase 67 task。
- `B: 書いただけ 0 件`: 不创建不连接到实现·测试·后续 Plans 的说明性项目。

## Version-by-version breakdown

| Version | Upstream item | 这样会更好 | Category | Harness surface | Harness action |
|---------|---------------|------------|----------|-----------------|----------------|
| Codex `0.130.0` stable | plugin details show bundled hooks | 更容易判断 plugin 是否附赠 hook | P | Codex plugin workflow docs / setup review | Phase 67.1.2 中将 plugin-bundled hooks 的显示连接到 docs，维持 Harness 不推测生成 inline hook 的方针 |
| Codex `0.130.0` stable | plugin sharing exposes link metadata/discoverability controls | 更容易处理 shared plugin 的 link 信息和 discoverability | P | plugin sharing policy | Phase 67.1.2 中作为 marketplace / private sharing 的责任边界 docs 化 |
| Codex `0.130.0` stable | top-level `codex remote-control` | remote control 的入口更容易理解 | P | Codex workflow docs | Phase 67.1.2 中将 `codex remote-control` 记为 official top-level command |
| Codex `0.130.0` stable | app-server Thread pagination APIs | thread 列表的大规模扩展更能承受 | P | app-server / session docs | Phase 67.1.2 中将 Thread pagination APIs 连接到 app-server policy |
| Codex `0.130.0` stable | Bedrock `aws login` profile credentials | Bedrock profile credentials 的获取路径明确 | P | provider setup docs | Phase 67.1.2 中追加 `aws login` / `amazon-bedrock` / console-login credentials 的边界 |
| Codex `0.130.0` stable | `view_image` through selected environments | 可以通过 selected environment 确认图像 | P | multi-environment review docs | Phase 67.1.2 中将 selected-environment `view_image` 设为不与 read-only first / one primary write environment 矛盾的形式 |
| Codex `0.130.0` stable | live app-server threads refresh latest config snapshot | live thread 更容易反映最新 config snapshot | P | app-server config lifecycle | Phase 67.1.2 中将 live threads from latest config snapshot 的期望值 docs 化 |
| Codex `0.130.0` stable | turn diff accuracy after `apply_patch` including partial failures | `apply_patch` 后的 turn diffs 更准确 | C | review / diff UX | 继承本体修正。Harness 侧不追加 turn diffs 的 workaround |
| Codex `0.130.0` stable | ThreadStore summaries/resume/fork improvements | summary / resume / fork 更稳定 | C | session runtime | 继承本体修正。不将 Plans SSOT 或 harness-loop state 双重化 |
| Codex `0.130.0` stable | remote compaction emits `response.processed` and omits `service_tier` under API auth | remote compaction 的 event / auth 行为更稳定 | C | remote compaction telemetry | 继承本体修正。Harness telemetry 将 `response.processed` 作为观测对象保留，`service_tier` 缺失不作为错误处理 |
| Codex `0.130.0` stable | Windows sandbox runtime bin cache | Windows sandbox 启动时的 runtime bin 解决更快更稳定 | C | Windows sandbox runtime | 继承本体修正。Harness 不追加 Windows workaround |
| Codex `0.130.0` stable | docs use `cargo install --locked` | install 步骤的再现性提升 | P | setup docs | Phase 67.1.3 中盘点 Codex install guidance，如有旧 cargo install 示例则向 `cargo install --locked` 靠拢 |
| Codex `0.130.0` stable | configurable OTel trace metadata | 更易于按环境附加 trace metadata | P | telemetry policy | Phase 67.1.3 中以不与 privacy-first / local-first policy 矛盾的形式评估 OTel trace metadata |
| Codex `0.130.0` stable | built-in MCPs first-class runtime servers | 更容易将 built-in MCPs 作为 runtime server 处理 | P | MCP setup docs | Phase 67.1.3 中将 built-in MCPs 和 plugin-provided MCP 的边界 docs 化 |
| Codex `0.130.0` stable | `CODEX_HOME` environments TOML provider | 可以在 `CODEX_HOME` 配下处理 environments TOML provider | P | Codex setup / environment policy | Phase 67.1.3 中固定 `CODEX_HOME` environments TOML provider 和 repo-local config 的优先顺序 |
| Codex `0.130.0` stable | remove skills list extra roots | skill root 的重复·多余探索减少 | C | skill runtime | 继承本体修正。Harness skill manifest generator 维持现状 |

## Phase 67 follow-up plan

| Task | Scope |
|------|-------|
| 67.1.1 | 添加本 snapshot、Feature Table、CHANGELOG、upstream integration test |
| 67.1.2 | 将 Codex provider / app-server / multi-environment policy 更新到 `0.130.0` stable |
| 67.1.3 | 将 Codex setup / telemetry / MCP / environment docs 更新到 `0.130.0` stable |
| 67.1.4 | 执行 Phase 67 的 integration validation 和 Plans marker 更新 |

## B: 書いただけ 0 件的理由

- `A` 作为本次 snapshot 和 `tests/test-claude-upstream-integration.sh` 的验证强化固定。
- `P` 连接到 Phase 67.1.2 / 67.1.3 的 docs / policy work。
- `C` 明记作为 Codex 本体 runtime fix 继承的理由。
- 不保留只载于 Feature Table 和 CHANGELOG 就结束的项目。

## No-op adaptation decision for this snapshot

本 snapshot 本身为 no-op adaptation。

理由：

- `codex remote-control`、app-server Thread pagination APIs、selected-environment `view_image`、
  Bedrock `aws login`、plugin hooks 是 docs / policy 边界更新在先，不是立即更改 runtime wrapper 的根据。
- `apply_patch` 后的 turn diffs、ThreadStore summaries/resume/fork improvements、Windows sandbox runtime bin cache 是 Codex 本体的修正，Harness 侧若做双重 workaround 会与将来的行为竞争。
- OTel trace metadata、built-in MCPs、`CODEX_HOME` environments TOML provider 虽然方便，但先在 Phase 67.1.3 中固定 privacy / setup precedence / MCP ownership 的边界后再采用。
