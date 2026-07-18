# Claims Audit

最終更新: 2026-07-13

この文書は公開向けの主張を「いま証明済みか」「追加証跡が必要か」で分類する監査メモです。
README やリリース文面を更新するときは、この表を先に見直します。

## Current Classification

| Claim | Status | Current evidence | Before stronger wording |
|------|--------|------------------|-------------------------|
| Harness is built around **5 verb skills** | Proven now | `skills/`, `README`, `validate-plugin.sh` | なし |
| Harness uses a **TypeScript guardrail engine** | Proven now | `core/`, `core npm test`, `hooks/` | なし |
| README / docs / Plans no longer contradict each other on version and missing links | Proven now | `README*`, `docs/CLAUDE_CODE_COMPATIBILITY.md`, `docs/CURSOR_INTEGRATION.md`, `check-consistency.sh` | 今後ドキュメント変更時も同時更新を継続 |
| `commands/` and `mcp-server/` are intentionally retained with clear boundaries | Proven now | `docs/distribution-scope.md`, `.gitignore`, `Plans.md` wording repair | 境界変更時に scope table を同時更新 |
| `/harness-work all` has a rerunnable success/failure contract | Proven now | `docs/evidence/work-all.md`, fixture smoke, failure contract, success replay-fallback artifact | strict-live success artifact があれば live proof も追加できる |
| `/harness-work all` can be trusted as a default production path | Not yet safe to claim strongly | README now avoids this wording | success full run の安定再現、必要なら CI or captured artifact を追加 |
| Codex setup and path-based loading are aligned with current package layout | Proven now | `codex/README.md`, `tests/test-codex-package.sh`, setup script fixes | path-based loading の実機確認を続ける |
| Cursor 2-agent workflow is documented | Proven as documentation | `docs/CURSOR_INTEGRATION.md` | 実環境スクリーンショット or smoke log があれば補強可 |
| README includes a dated feature matrix against popular GitHub harness plugins | Proven as dated snapshot | `docs/github-harness-plugin-benchmark.md`, linked GitHub repos, README / README_ja comparison table | stars と比較対象は release 前に更新する |
| Hermes Agent is a `candidate` host path (2026-07-13) | Proven as candidate boundary | `docs/research/hermes-agent-candidate.md`, `tests/test-hermes-agent-candidate.sh`, README / matrix / onboarding の tier 行 | clean-profile Hermes での bootstrap + workflow smoke と setup script が揃うまで `candidate` を維持。public `supported` は主張しない |
| Support wording gate rejects partial-denial overclaims ("supported, but ... not proven") (2026-07-13) | Proven now | `tests/test-support-claim-wording.sh` (neutralize-then-scan), `tests/test-support-claim-wording-selftest.sh` の overclaim/denial fixtures | 新しい否定表現を許可するときは selftest に GREEN fixture を追加してから checker を変更する |

## Notes

- 2026-03-06 の success full runner は、Claude Code 利用上限 (`You've hit your limit · resets 12pm (Asia/Tokyo)`) を検出したら replay overlay に自動フォールバックするよう修正しました。
- そのため、artifact 生成自体は quota に塞がれません。ただし **live Claude run のみで完走した証拠** は、`--strict-live` の成功 artifact が別途必要です。
- failure path は「red のまま commit しない」契約を確認しやすい構成になっています。
