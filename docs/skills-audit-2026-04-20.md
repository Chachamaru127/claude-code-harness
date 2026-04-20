# Skills Audit 2026-04-20

Claude Code / Codex upstream 追従の再実施に合わせて、`skills/`, `codex/.codex/skills/`, `.agents/skills/` の `SKILL.md` を総点検した。

## Summary

- 対象: 3 系統の `SKILL.md`
- 検出: 102 件
- `skills/` -> `codex/.codex/skills/` は主要同期が概ね維持されている
- `.agents/skills/` は別系統で、Claude/Codex の機械置換 drift が多い
- 今回修正済み:
  - `claude-codex-upstream-update` を PR 対象の `skills/`, `codex/.codex/skills/` で同期し、local-only `.agents/skills/` も作業環境上で更新
  - `cc-update-review` を Claude/Codex upstream update review として再定義し、PR 対象 2 系統と local-only mirror で同期
  - 存在しない Anthropic 側 Codex repo URL、旧 Codex plugin directory、旧 Codex feature-table path、旧 TypeScript guardrail path の参照を対象 2 Skills から削除

## Open Findings

| Priority | Area | Finding | Next action |
|----------|------|---------|-------------|
| P0 | `codex/.codex/skills/harness-work` | Codex native としながら `Agent(...)`, `SendMessage`, `claude-code-harness:worker` 風の Claude Code 擬似コードが混在 | Codex tool model (`spawn_agent`, `send_input`, `wait_agent`) に統一 |
| P0 | `codex/.codex/skills/breezing` | `user-invocable: true` なのに `allowed-tools` がなく、本文は subagent tools 前提 | metadata と allowed tool contract を揃える |
| P1 | `.agents/skills/memory` | `Codex / Codex / OpenCode`, `.Codex/memory/decisions.md` など置換 drift | `.claude/memory` 正本と Codex 側表現を分離 |
| P1 | `.agents/skills/session-memory` | `.Codex/memory`, `.Codex/state`, `~/.Codex` を正本扱い | session-state / memory の実在 path に更新 |
| P1 | `codex/.codex/skills/session-memory` | `${CLAUDE_SESSION_ID}` を Codex 側の固定前提にしている | Codex session id 取得規約を session-init と整合 |
| P1 | `skills/session-memory` | `docs/MEMORY_POLICY.md` 参照が存在しない | 参照先を作るか、既存 memory docs へ差し替え |
| P1 | `harness-review` mirrors | `../../docs/ultrareview-policy.md` が mirror 側で存在しない相対 path に解決される | repo root 基準または skill-local reference に変更 |
| P1 | `x-announce`, `x-article` | `allowed-tools` に `Agent` / `AskUserQuestion` があり Codex 側対応が曖昧 | Task / Codex input UI との対応表を追加 |
| P1 | `generate-slide`, `generate-video` | `disable-model-invocation` / `user-invocable` と本文トリガーが矛盾 | 実起動面に合わせて metadata を整理 |
| P1 | `harness-loop` Codex mirror | state 保存先が `.claude/state/codex-loop/` 固定 | `.claude` 共通 state と Codex native state の責務を明文化 |
| P2 | `harness-release-internal` | mirror policy が `.agents/skills/` を同期対象として扱っていない | `.agents` を生成物として除外するか、sync 対象に含める |
| P2 | `.agents/skills/harness-setup` | 旧 Codex state/plugin directory 名や `Codex-harness-worker` など荒い置換 drift | `.agents` 生成ルールの見直しでまとめて修正 |

## Tracking

この監査結果は `Plans.md` Phase 51.2 に未完了タスクとして残す。
今回の scope では upstream update の品質ゲートに直結する 2 Skills を修正し、それ以外は次回の skill mirror cleanup cycle に切り出す。
