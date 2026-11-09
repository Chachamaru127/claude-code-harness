# Team Mode and Issue Bridge

`Plans.md` 保持为正本，GitHub Issue 联动仅在 opt-in 的 team mode 中使用。

## 分工

- solo 开发不使用 issue bridge
- team mode 中创建 1 个 tracking issue，并在其下为每个 task 以 dry-run 生成 sub-issue payload
- issue bridge 不更新 Plans.md
- 仅以 dry-run 结束，不对 GitHub 做实际更新

## 转换规则

`scripts/plans-issue-bridge.sh` 将 Plans.md 的各个 task 展开为以下形式。

- tracking issue
  - 用作汇总的父 issue
  - 在 body 中放入 phase 列表和 task 列表
- sub-issue
  - 每个 task 的独立 payload
  - 在 body 中保留 `task id`、`DoD`、`Depends`、`Status`

## 実行例

```bash
scripts/plans-issue-bridge.sh --team-mode --plans Plans.md
```

指定 `--format markdown` 可切换为便于人阅读的 dry-run。

## 有什么好处

- 可以原样保持 Plans.md 为正本
- 只有团队作业才能建立基于 issue 的全景
- solo 开发不会增加额外负担
