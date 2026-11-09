# Phase 21 Release Checklist

最终更新: 2026-03-06

本检查表是在决定发布包含 `trust repair`、`evidence pack`、`positioning refresh` 的变更时的确认表。

## Surfaces

- [ ] `VERSION` 与 `.claude-plugin/plugin.json` 一致
- [ ] README / README_ja 使用 latest release badge
- [ ] README / README_ja 没有死链
- [ ] `docs/distribution-scope.md` 与 `Plans.md` 的描述一致
- [ ] `docs/claims-audit.md` 的分类与本次文案不矛盾

## Evidence

- [ ] `./tests/validate-plugin.sh`
- [ ] `./tests/validate-plugin-v3.sh`
- [ ] `./scripts/ci/check-consistency.sh`
- [ ] `cd core && npm test`
- [ ] `./scripts/evidence/run-work-all-smoke.sh`
- [ ] 如有需要 `./scripts/evidence/run-work-all-success.sh --full`
- [ ] 若要展示 live Claude 走完全程 `./scripts/evidence/run-work-all-success.sh --full --strict-live`
- [ ] 如有需要 `./scripts/evidence/run-work-all-failure.sh --full`

## Artifact Review

- [ ] `docs/evidence/work-all.md` 的说明与产出物一致
- [ ] 已确认 `out/evidence/work-all/` 中最近的 artifact
- [ ] 在 release note 中明确注明 success / failure 中哪一项尚未验证

## Release Decision

- [ ] 已判定本次变更是否伴随 release metadata 更新
- [ ] 已获得创建 GitHub Release / tag 的明确审批
- [ ] 告知文案中未把 `trust repair`、`evidence pack`、`positioning refresh` 混在一起，而是分开整理

## Current Recommendation (2026-03-06)

- 只是发布带 replay fallback 的 evidence tooling 是可以的。
- 但若要强烈宣称「live Claude 原样走完了 happy path」，请先取得 `--strict-live` 的 artifact。
