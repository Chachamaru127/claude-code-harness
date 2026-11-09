# Release Preflight

`scripts/release-preflight.sh` 是公开前用于先期判断「现在可以 release 吗」的只读检查。
以 vendor-neutral 为前提，不依赖 AWS 固定或特定 deploy 基础设施。

## 检查内容

- working tree 是否 clean
- `CHANGELOG.md` 是否有 `[Unreleased]`
- `.env.example` 和 `.env` 是否有较大偏差。`.env` 不存在的 repo 仅记录 warning，不阻止 managed secrets 前提的运用
- 现有的 `healthcheck` / `preflight` 命令是否通过
- 警告 `agents/` / `core/` / `hooks/` / `scripts/` 的 shipped surface 中是否残留 `mockData` / `dummy` / `localhost` / `TODO` / `FIXME` 等残渣
- tag 创建前执行 `node scripts/build-opencode.js` / `node scripts/validate-opencode.js` / `bash scripts/sync-skill-mirrors.sh --check`，确认 `opencode/`、`skills-codex/`、`codex/.codex/skills/` 的 mirror drift 为 0
- 能获取的情况下，CI 最新状态是否成功

mirror drift gate 是 release tag 前的 fail gate。如果 `build-opencode.js` 生成了差异，preflight 将失败，需先 commit 该差异再创建 tag。

Actions runtime audit (2026-05-11): repo workflows 使用 `actions/checkout@v6`；Node setup 使用 `actions/setup-node@v6`；Go setup 使用 `actions/setup-go@v6`。这些 v6 action 行在 Node 24 action runtime 上运行，避免了 Node 20 弃用警告。

## 用法

```bash
scripts/release-preflight.sh
scripts/release-preflight.sh --root /path/to/other/repo
```

## 环境变量

- `HARNESS_RELEASE_PROJECT_ROOT`: 需要检查其他 repo 时的 root
- `HARNESS_RELEASE_HEALTHCHECK_CMD`: repo 特有的 healthcheck 命令
- `HARNESS_RELEASE_CI_STATUS_CMD`: 需要替换 CI 状态确认命令时的命令

## 与 dry-run 的关系

`/release --dry-run` 也必须通过 preflight。
dry-run 的含义是「不执行公开操作」，而 preflight 的含义是「确认是否处于可以公开的状态」。
两者是不同的，dry-run 时也不省略 preflight。

## GitHub Release workflow

`.github/workflows/release.yml` 也在 GitHub Release 创建或向现有 release 上传 asset 之前执行 `bash ./scripts/release-preflight.sh --check-adapters`。

tag-triggered workflow 在 detached HEAD 上运行，因此无法获取 CI status 时将其作为 warning boundary。release-ready 的判断以前提 preflight failure 为 0（clean tree、mirror drift、adapter smoke、distribution archive gate 等）为条件。

`tests/test-distribution-archive.sh` 从 `git archive HEAD` 验证分发物的形态。这是 committed artifact 的验证，不包含 dirty / untracked local files。因此，在 release claim 之前应与 clean-tree preflight 结合使用。
