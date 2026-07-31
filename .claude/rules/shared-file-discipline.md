# Shared File Discipline

Harness の **並列 worktree 実行時の共有ファイル編集規約**。
Phase 92.1.3 で導入。Worktree Root Discipline（`spec.md`）が「どこに worktree を置くか」を定義するのに対し、
本規約は「worktree の中で何を書いてよいか」を定義する。

## なぜこのルールが必要か

背景 (why): [docs/rules/governance-rationale.md](../../docs/rules/governance-rationale.md#shared-file-disciplinemd)

## 3 つの invariant

### Invariant 1: 共有 append ファイルは owner-assigned append-only block

`Plans.md` / `CHANGELOG.md` / `spec.md` を並列 worker が同時編集すると cherry-pick 衝突が起きる。

- 並列実行時は各ファイルに **owner を 1 人**割り当て、他 worker は触らない
- owner 不在のファイルは **Lead が統合時に編集**する（worker は触らない）
- owner が書くのは **append-only block**（既存行の書き換え・削除は owner でも禁止。Lead 統合時を除く）

**なぜ**: 同じファイルへの concurrent edit は rerere でも解消しにくい。
owner を 1 人に絞ることで、衝突面を sprint contract で事前に固定できる。

### Invariant 2: `VERSION` は worktree 内で bump しない

version bump は **release 専用操作**で、trunk 上の `./scripts/sync-version.sh bump` のみが行う。
VERSION / `.claude-plugin/plugin.json` / `harness.toml` の 3 点同期は release 時だけ。

**なぜ**: worktree 内 bump は trunk merge 後に 3 ファイルの不整合を残す。
通常 PR では VERSION を触らず CHANGELOG `[Unreleased]` に追記する（`github-release.md` 参照）。

### Invariant 3: 生成物は trunk で 1 回再生成

`bin/harness` バイナリや mirror（`opencode/skills/` 等）のような生成物は、
worktree ごとに再生成せず、**統合後に trunk で 1 回だけ**再生成する。

**なぜ**: worktree ごとの再生成はバイナリ衝突・mirror drift の温床。
Lead の cherry-pick 後に trunk で 1 回走らせれば、生成物の SSOT は trunk に保たれる。

## owner-assign 例

Phase 92.1.2（reap script）と 92.1.3（docs 規約）を並列実行する場合:

| 対象 | owner | 備考 |
|------|-------|------|
| `CHANGELOG.md` | なし | 両 worker とも触らず、Lead が統合時に 2 エントリまとめて追記 |
| `docs/team-composition.md` / `spec.md` | 92.1.3 担当 | 92.1.2 は触らない |
| `.claude/rules/shared-file-discipline.md` | 92.1.3 担当 | 本規約の正本 |
| `scripts/` / `tests/` | 92.1.2 | 新規ファイル作成のみなら衝突なし（新規は owner 概念不要） |

Lead は sprint contract（task 分解時）に上表を明記し、worker prompt の「触ってはいけない」節に反映する。

## 関連ファイル

- [`spec.md` — Worktree Root Discipline / Tri-Tool Parallel Collaboration Contract](../../spec.md)
- [`docs/team-composition.md` — parallel worktree root / チーム運用](../../docs/team-composition.md)
- [`.claude/rules/github-release.md`](github-release.md) — VERSION bump と CHANGELOG 運用
- [`scripts/ci/check-consistency.sh`](../../scripts/ci/check-consistency.sh) — 本規約ファイルの存在チェック（Section 15）
