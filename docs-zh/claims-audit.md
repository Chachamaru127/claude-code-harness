# Claims Audit

最后更新：2026-07-13

本文档是将公开主张按"现在已证明"和"需要追加证据"分类的审计备忘录。
更新 README 和发布文案时，先查阅此表。

## 当前分类

| Claim | 状态 | 当前证据 | 使用更强措辞之前 |
|------|--------|------------------|-------------------------|
| Harness built around **5 verb skills** | 现在已证明 | `skills/`、`README`、`validate-plugin.sh` | 无 |
| Harness uses a **TypeScript guardrail engine** | 现在已证明 | `core/`、`core npm test`、`hooks/` | 无 |
| README / docs / Plans no longer contradict each other on version and missing links | 现在已证明 | `README*`、`docs/CLAUDE_CODE_COMPATIBILITY.md`、`docs/CURSOR_INTEGRATION.md`、`check-consistency.sh` | 今后文档变更时继续同步更新 |
| `commands/` and `mcp-server/` are intentionally retained with clear boundaries | 现在已证明 | `docs/distribution-scope.md`、`.gitignore`、`Plans.md` 措辞修复 | 边界变更时同步更新 scope 表 |
| `/harness-work all` has a rerunnable success/failure contract | 现在已证明 | `docs/evidence/work-all.md`、fixture smoke、failure contract、success replay-fallback artifact | 如果有 strict-live success artifact 也能追加 live proof |
| `/harness-work all` can be trusted as a default production path | 尚不安全作强声称 | README 现在避免此措辞 | success full run 的稳定再现，需要的话追加 CI 或 captured artifact |
| Codex setup and path-based loading are aligned with current package layout | 现在已证明 | `codex/README.md`、`tests/test-codex-package.sh`、setup script 修复 | 继续实机确认 path-based loading |
| Cursor 2-agent workflow is documented | 作为文档已证明 | `docs/CURSOR_INTEGRATION.md` | 有实环境截图或 smoke log 可以加强 |
| README includes a dated feature matrix against popular GitHub harness plugins | 作为带日期的快照已证明 | `docs/github-harness-plugin-benchmark.md`、linked GitHub repos、README / README_ja comparison table | stars 和比较对象在 release 前更新 |
| Hermes Agent is a `candidate` host path (2026-07-13) | 作为候选边界已证明 | `docs/research/hermes-agent-candidate.md`、`tests/test-hermes-agent-candidate.sh`、README / matrix / onboarding 的 tier 行 | 在 clean-profile Hermes 的 bootstrap + workflow smoke 和 setup script 齐全之前保持 `candidate`。不主张 public `supported` |
| Support wording gate rejects partial-denial overclaims ("supported, but ... not proven") (2026-07-13) | 现在已证明 | `tests/test-support-claim-wording.sh`（neutralize-then-scan）、`tests/test-support-claim-wording-selftest.sh` 的 overclaim/denial fixtures | 允许新否定表达时，先在 selftest 中添加 GREEN fixture 再修改 checker |

## 备注

- 2026-03-06 的 success full runner，在检测到 Claude Code 使用上限（`You've hit your limit · resets 12pm (Asia/Tokyo)`）时，已修改为自动 fallback 到 replay overlay。
- 因此 artifact 生成不会被 quota 阻塞。但是**仅通过 live Claude run 完成的证据**，`--strict-live` 的成功 artifact 需要另外准备。
- failure path 的结构使"保持 red 而不 commit"契约易于确认。
