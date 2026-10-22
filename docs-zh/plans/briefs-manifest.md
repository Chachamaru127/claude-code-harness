# Optional Briefs and Skill Manifest

`harness-plan create` 仅在需要时附加 brief。brief 不替换 Plans.md，而是作为固定实现前提的辅助资料。

project spec SSOT 视为比 brief 上位的正本。brief 固定画面或 API 等个别任务的简短前提，spec SSOT 固定项目整体的正确条件。

详见: `docs/plans/spec-ssot.md`

## Design Brief

包含 UI 的任务制作 `design brief`。

最低限度包含的内容:

- 要达成什么
- 谁来使用
- 重要的画面状态
- 外观和操作的约束
- 完成条件

## Contract Brief

包含 API 的任务制作 `contract brief`。

最低限度包含的内容:

- 接收什么 / 返回什么
- 输入验证的条件
- 失败时的行为
- 外部依赖
- 完成条件

## Skill Manifest

`scripts/generate-skill-manifest.sh` 将 repo 内的 `SKILL.md` frontmatter 制作为 stable JSON。

使用场景:

- skill surface 的审计
- mirror 间的比较
- 自动 docs 生成的输入

输出包含以下内容:

- `name`
- `description`
- `do_not_use_for`
- `allowed_tools`
- `argument_hint`
- `effort`
- `user_invocable`
- `surface`
- `related_surfaces`

`related_surfaces` 包含类似 `skills`、`codex/.codex/skills`、`opencode/skills` 的 mirror 信息。

## 执行例

```bash
scripts/generate-skill-manifest.sh --output .claude/state/skill-manifest.json
```
