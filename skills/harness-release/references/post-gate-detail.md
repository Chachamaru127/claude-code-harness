# Post-Gate Mechanics: PR/Main Merge, Semver Tag, Verify Publish

Full command sequences for the three Post-Gate steps the main `SKILL.md` only
summarizes: merging the release PR into the default branch, creating the
semver tag, and verifying the tag-triggered publish workflow.

## PR / Main Merge Gate

Post-Gate の release commit 後は、tag を作る前に GitHub PR を default branch へ merge する。

```bash
release_branch="$(git branch --show-current)"
default_branch="${HARNESS_RELEASE_DEFAULT_BRANCH:-main}"

git push -u origin "$release_branch"
gh pr create --base "$default_branch" --head "$release_branch" --title "chore: release v<new>" --body "<release summary>"
gh pr merge --merge --delete-branch=false

git fetch origin "$default_branch" --tags
git checkout "$default_branch"
git pull --ff-only origin "$default_branch"
git merge-base --is-ancestor "<release-commit>" "origin/$default_branch"
```

既存 PR がある場合は新規作成せず、既存 PR の body を更新して merge する。repository policy が squash merge を要求する場合は、release commit hash ではなく release bump の内容（version files + CHANGELOG + source commits）が default branch に含まれることを確認する。

tag はこの Gate 完了後、default branch の HEAD もしくは release commit 到達可能な commit に対して作る。release branch 上だけに存在する commit を指す tag で GitHub Release を作ってはいけない。

## Claude plugin project の tag 作成

`.claude-plugin/plugin.json` がある project では、PR/main merge 後に default branch 上でもう一度 version sync を確認してから semver tag を作る:

```bash
HARNESS_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-.}"
python3 "${HARNESS_PLUGIN_ROOT}/scripts/check-release-version-sync.py" --root .

git tag -a "v${NEW_VERSION}" -m "v${NEW_VERSION}"
git push origin "v${NEW_VERSION}"
```

tag は `vX.Y.Z` 形式の semver tag 1 本に統一する。`claude plugin tag` が作る `{plugin-name}--v{version}` 形式の plugin tag は 2026-08-17 に廃止した (decisions.md D69): `marketplace.json` の `source` が相対パス `"./"` で install は tag を参照しないため実効性が無く、v5.6.0 以降 3 リリース連続で欠番のまま誰も困らなかった。既存の `claude-code-harness--v5.5.0` 以前の tag は履歴として残すが、新規には作らない。

## Verify Workflow Publish

Tag push 後、`.github/workflows/release.yml` が release を自動公開する。skill は以下で結果を verify する:

```bash
OWNER="$(git remote get-url origin | sed 's|.*github.com[:/]\([^/]*/[^/]*\)\.git|\1|')"
bash scripts/release-verify-publish.sh "v${NEW_VERSION}" "${OWNER}"
```

タイムアウト: 5 秒間隔 × 60 回 = 最大 5 分 polling。

- exit 0: PASS — `draft=false` 且つ assets 4 platform 揃って公開済
- exit 2: WARN — timeout (tag は push 済のため abort せず人間判断を促す)
- exit 3: ERROR — API error (権限/認証問題、手動調査が必要)

Verify は `gh api` 経由で行う。GitHub CLI の release subcommand prefix は CC runtime hard floor で deny されるため使わない。
