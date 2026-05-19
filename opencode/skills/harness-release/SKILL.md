---
name: harness-release
description: "Generic release automation for projects using Keep a Changelog + GitHub. Single confirmation gate then end-to-end automation: bump detection, CHANGELOG promotion, tag, GitHub Release. Trigger: release, version bump, publish. Do NOT load for: implementation, review, planning, setup."
---

# Harness Release (汎用)

Keep a Changelog + GitHub を使う**あらゆるプロジェクト向け**の汎用リリース自動化スキル。

**設計原則**: 単一確認ゲート。ユーザーは 1 回だけ全体計画を見て承認する。承認後はファイル書き換え → commit → push → tag → GitHub Release までを中断なく実行する。

> **Literal invocation note**: この skill の入口は `harness-release`, `/release`, `/release patch`, `/release --dry-run` のような literal command をそのまま使う。

## Bare invocation contract

if $ARGUMENTS == "":
  → 「今までの作業をコミットしてリリースしたい」と解釈し、Review Gate 検出を実行する
  → 対象 work が 1 つに確定できる場合だけ Step 0 (Review Gate) へ自動進行する
  → 対象が不明または review state が無い場合は AskUserQuestion で選択肢を出してから進める

引数なし呼び出し時の最初の応答で必ず次の literal marker を出力する:

`RELEASE_AUTOSTART: target=<work-summary>, base_ref=<ref>, mode=<patch|minor|major|auto>`

「タスクが不明確」「指示を待ちます」「タスクがありません」「追加の指示をお待ちします」は禁止行動。

<!-- 上記ブロックは AUTO-START CONTRACT。skill-editing.md「最冒頭 3 行以内」ルール準拠。patterns.md P27 解法 3 点セット (機械可読条件 + 禁止行動 literal + AUTOSTART marker) -->

`harness-release` / `/release` だけが入力された場合、これは
**「今までの作業をコミットしてリリースしたい」** という意味として扱う。
「タスクがありません」「指示を待ちます」で止まってはいけない。

bare release では、通常の release preflight の前に **Review Gate** と **Work Commit Gate** を実行する。

1. `git status --porcelain` と `git log @{upstream}..HEAD` / `main..HEAD` を確認し、「今までの作業」の対象を特定する
2. `.claude/state/review-result.json` と `.claude/state/review-approved.json` を確認し、対象 work に `APPROVE` 済み review があるか確認する
3. APPROVE 済み review が無い場合は `AskUserQuestion` で確認する
4. ユーザーが「レビューから開始」を選んだら、`harness-review` を起動し、`APPROVE` になるまで release へ進まない
5. `harness-review` が `REQUEST_CHANGES` を返した場合は release を保留し、`harness-work` で修正してから `harness-review` を再実行する。これを `APPROVE` までループする
6. `harness-review` が `APPROVE` を返した後、working tree の作業 commit を作る
7. working tree clean になってから通常の release preflight / confirmation gate / tag / GitHub Release へ進む

### Review Gate AskUserQuestion

`harness-release` 実行時に review approval が確認できない場合は、推測で release しない。
次の Ask を出す。

```text
question: "harness-release は今までの作業をコミットしてリリースしますが、この作業の APPROVE review が見つかりません。どう進めますか？"
options:
  - label: "レビューから開始 (Recommended)"
    description: "harness-review を実行し、APPROVE になった場合だけ commit/release へ進みます。"
  - label: "release dry-run"
    description: "ファイルを書き換えず、release 計画と不足 gate だけ確認します。"
  - label: "中止"
    description: "review も release も行わず止めます。"
```

ユーザーが「レビューから開始」を選んだ場合は、同じセッション内で `harness-review` から始める。
`harness-review` の対象決定は `harness-review` 側の bare review contract に従う。
review が `APPROVE` なら、そのまま `harness-release` の Work Commit Gate へ戻る。
review が `REQUEST_CHANGES` なら release は保留し、`harness-work` で修正してから `harness-review` を再実行する。
この修正後再レビュー loop は `APPROVE` まで継続する。

ユーザーに戻してよいのは次の場合だけ。

1. 修正に仕様正本 / Plans.md / API / permission / migration / billing などの意思決定が必要で、`AskUserQuestion` が必要
2. 修正方針が複数あり、どれを採るかでユーザー価値や互換性が変わる
3. ユーザーが Ask で `release dry-run` または `中止` を選んだ

`REQUEST_CHANGES` 単体を最終停止理由にしてはいけない。

### Work Commit Gate

bare release で working tree に未コミット変更がある場合、release version bump commit とは別に、
review 済み work commit を先に作る。

```bash
git status --short
git diff --stat
git add <reviewed files>
git commit -m "<type>: <summary>"
```

commit message は review summary / Plans.md task / branch name から短く生成する。
判断できない場合は `AskUserQuestion` で 2〜3 個の commit message 候補を出す。
work commit 作成後に `.claude/state/review-result.json` の `commit_hash` を確認または更新し、
release preflight へ進む。

通常の release preflight に入った後は、これまで通り working tree dirty を fail とする。
dirty tree のまま version bump / tag / GitHub Release に進まない。

## Quick Reference

```bash
/release              # 今までの作業を review gate → commit → release する
/release patch        # bump を patch に明示指定
/release minor        # bump を minor に明示指定
/release major        # bump を major に明示指定
/release --dry-run    # 計画の表示のみ、実行しない
```

## 前提条件

このスキルが動くプロジェクトは以下を満たす必要があります:

1. `CHANGELOG.md` が [Keep a Changelog](https://keepachangelog.com/) 形式
2. `[Unreleased]` セクションが存在する
3. 以下のいずれかの version file を持つ:
   - `VERSION` (単独ファイル)
   - `package.json` (npm)
   - `pyproject.toml` (Python, `[project]` または `[tool.poetry]`)
   - `Cargo.toml` (Rust, `[package]`)
4. `gh` CLI がインストール済みで、認証済み
5. git リモート `origin` が GitHub を指す
6. Claude Code plugin project の場合は、`claude` CLI が `plugin tag` をサポートしている

これらが満たされない場合、Preflight で detect して abort します。

`prUrlTemplate` による multi-host review URL は将来候補として認識するが、
このスキルの release automation は今も `gh` CLI と GitHub remote を primary path とする。
owner / branch / release asset / CI metadata の自動取得は host ごとの差が大きいため、Phase 56.2.3 では docs-only に留める。

## 単一ゲートフロー

```
[Bare release only: 作業 review/commit 前段]
  ↓
  0. Review Gate (未レビューなら AskUserQuestion → harness-review)
  0.5 Work Commit Gate (review APPROVE 済み work を release bump と分けて commit)
  ↓
[Pre-Gate: 情報収集のみ、ファイル未変更]
  ↓
  1. Preflight (working tree clean / CHANGELOG / gh 等の確認)
  2. Version file 自動検出
  3. 現在バージョンの読み取り
  4. Claude plugin tag preflight (plugin project の場合のみ)
  5. [Unreleased] 内容の解析 → bump level 推定
  6. 新バージョン算出
  7. CHANGELOG 差分ドラフト作成 (メモリ上)
  8. GitHub Release notes ドラフト作成 (メモリ上)

★━━━━━━ 単一確認ゲート ━━━━━━★
  ユーザーに全計画を 1 回だけ提示:
    - 検出された version file
    - 現バージョン → 新バージョン
    - bump 判定理由 ("[Unreleased] に ### Added があるため minor" 等)
    - CHANGELOG 変更プレビュー
    - GitHub Release notes ドラフト
    - コミット対象ファイル一覧
    - 最終アクション (push + tag + release publish)

  ユーザー応答:
    "yes"        → Post-Gate へ進む
    "<修正指示>"  → 指示に応じて draft を再生成、再確認
    "cancel/no"  → 何もせず終了
★━━━━━━━━━━━━━━━━━━━━━━━★
  ↓
[Post-Gate: 承認後、中断なし]

  9. Version file 書き換え
  10. CHANGELOG.md 書き換え ([Unreleased] → [X.Y.Z] 昇格 + compare link)
  11. git add + commit
  12. Claude plugin tag validation + tag (plugin project の場合のみ)
  13. GitHub Release 用 semver tag (必要な project のみ)
  14. git push origin <branch> --tags
  15. gh release create vX.Y.Z
  16. 完了報告
```

## Pre-Gate 詳細

### 1. Preflight

```bash
# 必須ツール
command -v gh >/dev/null || { echo "gh CLI がありません"; exit 1; }
command -v python3 >/dev/null || { echo "python3 が必要です"; exit 1; }

# working tree
if [ -n "$(git status --porcelain)" ]; then
  echo "working tree に未コミット変更があります"; exit 1;
fi

# CHANGELOG
[ -f CHANGELOG.md ] || { echo "CHANGELOG.md がありません"; exit 1; }
grep -q "^## \[Unreleased\]" CHANGELOG.md || { echo "[Unreleased] セクションがありません"; exit 1; }

# plugin/mirror projects
scripts/release-preflight.sh
```

この working tree clean check は通常 release preflight の gate である。
bare release で「今までの作業」を commit したい場合は、この check の前に Review Gate と Work Commit Gate を完了させる。
未レビューの dirty tree をこの check だけで abort して終わらせてはいけない。

`scripts/release-preflight.sh` は tag 作成前に `opencode/`, `skills-codex/`, `codex/.codex/skills/` の mirror drift も検出する。`node scripts/build-opencode.js` が差分を生成した場合は release を止め、その差分を commit してから tag に進む。

### 2. Version File 自動検出

以下を優先順で探索。最初に見つかったものを正本とする:

```python
# Python snippet to run inline
import os, json, re
import tomllib  # Python 3.11+

def detect_version_file():
    if os.path.exists("VERSION"):
        with open("VERSION") as f:
            return ("VERSION", f.read().strip(), None)
    if os.path.exists("package.json"):
        with open("package.json") as f:
            data = json.load(f)
        return ("package.json", data["version"], None)
    if os.path.exists("pyproject.toml"):
        with open("pyproject.toml", "rb") as f:
            data = tomllib.load(f)
        if "project" in data:
            return ("pyproject.toml", data["project"]["version"], "[project]")
        if "tool" in data and "poetry" in data["tool"]:
            return ("pyproject.toml", data["tool"]["poetry"]["version"], "[tool.poetry]")
    if os.path.exists("Cargo.toml"):
        with open("Cargo.toml", "rb") as f:
            data = tomllib.load(f)
        return ("Cargo.toml", data["package"]["version"], "[package]")
    raise RuntimeError("No supported version file found")
```

詳細: [version-files.md](${CLAUDE_SKILL_DIR}/references/version-files.md)

### 3. Claude Plugin Tag Preflight

`.claude-plugin/plugin.json` が存在する project では、通常の GitHub Release tag とは別に Claude plugin release tag も作る。

ひとことで言うと、`git tag -a` を手で組み立てる前に、Claude Code 本体の plugin validation に通してから `{plugin-name}--v{version}` tag を作る。

Pre-Gate ではファイルを書き換えず、以下を確認する。
version sync は `grep` / `sed` で拾わず、JSON は structured parser で読む:

```bash
command -v claude >/dev/null || { echo "claude CLI がありません"; exit 1; }
claude plugin validate .claude-plugin/plugin.json

HARNESS_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-.}"
python3 "${HARNESS_PLUGIN_ROOT}/scripts/check-release-version-sync.py" --root .

claude plugin tag .claude-plugin --dry-run
```

`${HARNESS_PLUGIN_ROOT}/scripts/check-release-version-sync.py` は、存在する release surface をすべて読み取り、canonical を `VERSION > package.json > .claude-plugin/plugin.json` の順で決める。
そのうえで、以下の不一致・欠落が 1 つでもあれば tag / release に進まない:

- `VERSION`
- `package.json` の `.version`
- `.claude-plugin/plugin.json` の `.version`
- `.claude-plugin/marketplace.json` の `.metadata.version`
- `.claude-plugin/marketplace.json` の `.plugins[].version`（配列内の各 plugin entry）

不一致時は、どの surface が canonical と違うか、またはどの field が missing / invalid かを表示する。
機械処理や CI で読む場合は `--json` を使う:

```bash
python3 "${HARNESS_PLUGIN_ROOT}/scripts/check-release-version-sync.py" --root . --json
```

この check は 3 つの事故を防ぐためにある:

- `VERSION` と `.claude-plugin/plugin.json` の version がずれたまま tag を切る事故
- `package.json` / marketplace entry の version が古いまま release workflow に進む事故
- plugin manifest / marketplace entry の validation を通さず、あとで plugin install / update 側で詰まる事故

`--dry-run` では `claude plugin tag` が実際に作る tag 名と内部の `git tag -a` / push 相当コマンドが見える。ここで見えた command を Confirmation Gate の plan に含める。

### 4. Bump 自動推定

`[Unreleased]` 直下の見出しを解析して bump level を決定:

| [Unreleased] 内の見出し | 推定 bump |
|------------------------|-----------|
| `### Breaking Changes` または `### Removed` を含む | **major** |
| `### Added` を含む (Removed/Breaking なし) | **minor** |
| `### Fixed` / `### Changed` / `### Security` のみ | **patch** |
| 空セクション | **error: リリース対象なし** |

ユーザーが `/release patch|minor|major` で明示指定した場合はそちらを優先。
詳細: [bump-detection.md](${CLAUDE_SKILL_DIR}/references/bump-detection.md)

### 5. CHANGELOG ドラフト作成 (メモリ上)

以下を計算、まだ書き込まない:

1. `## [Unreleased]` の本文を切り出し
2. `## [Unreleased]` と `## [<previous>]` の間に `## [<new>] - YYYY-MM-DD` を挿入した形を作成
3. 末尾 compare link:
   - `[Unreleased]: .../compare/v<prev>...HEAD` → `v<new>...HEAD`
   - `[<new>]: .../compare/v<prev>...v<new>` を追加
4. repo URL は既存の `[Unreleased]: ` 行から動的抽出

### 6. Release Notes ドラフト作成 (メモリ上)

`## [<new>]` セクションの内容を元に、GitHub Release 用のマークダウンを生成:

```markdown
## What's Changed

**<リリーステーマ(1行)>**

### Before / After
<テーブル>

### Added / Changed / Fixed / Removed
<該当セクションをコピー>

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

詳細: [release-notes.md](${CLAUDE_SKILL_DIR}/references/release-notes.md)

## Confirmation Gate

すべてのドラフトが揃ったら、ユーザーに 1 回だけ提示:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Release Plan: v<old> → v<new> (<bump>)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Version file: <detected file>
 Bump reason:  <why this level was chosen>

 CHANGELOG changes:
   [Unreleased] に <N> 項目の変更を検出
   [<new>] - YYYY-MM-DD として確定
   Compare link を追加

 GitHub Release notes preview:
   <最初の 10 行>
   ...

 Files to modify:
   - <version file>
   - CHANGELOG.md

 Final actions:
   - git commit -m "chore: release v<new>"
   - claude plugin tag .claude-plugin --push --remote origin  # plugin project の場合
   - git tag -a v<new>                                        # GitHub Release 用 semver tag が必要な場合
   - git push origin <branch> --tags
   - gh release create v<new>

Proceed? [yes / cancel / <修正指示>]
```

## Post-Gate 詳細

承認後は中断なしで実行。失敗時は以下の方針:

| 失敗箇所 | 復旧 |
|---------|------|
| ファイル書き換え失敗 | そこで abort、ローカルは dirty なまま人間が判断 |
| commit 失敗 | hook 拒否等。ユーザーに原因を提示して修正を促す |
| plugin tag validation 失敗 | `VERSION` / `.claude-plugin/plugin.json` / marketplace entry の不一致を修正し、tag 作成には進まない |
| push 失敗 | リモート側の問題。ローカル commit/tag は残す |
| `gh release create` 失敗 | tag は push 済みなので、既存の release.yml セーフティネットが発火するか、手動で `gh release create` |

### Claude plugin project の tag 作成

`.claude-plugin/plugin.json` がある project では、commit 後にもう一度 version sync を確認してから plugin tag を作る:

```bash
HARNESS_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-.}"
python3 "${HARNESS_PLUGIN_ROOT}/scripts/check-release-version-sync.py" --root .

claude plugin tag .claude-plugin --dry-run
claude plugin tag .claude-plugin --push --remote origin
```

`claude plugin tag` が作る tag は `{plugin-name}--v{version}` 形式。既存の GitHub Release workflow が `vX.Y.Z` tag を前提にしている project では、plugin tag とは別に `git tag -a v<new>` を作る。plugin 配布の tag は `claude plugin tag` に任せ、GitHub Release 用 semver tag は release automation の互換 surface として扱う。

## `--dry-run` モード

Pre-Gate 全てを実行し、Confirmation Gate までの内容を表示するが、**gate で止まり Post-Gate に進まない**。

Claude plugin project の場合、dry-run でも `python3 "${HARNESS_PLUGIN_ROOT}/scripts/check-release-version-sync.py" --root .` と `claude plugin tag .claude-plugin --dry-run` を実行し、実際に作られる plugin tag 名と push 対象を表示する。ここで `VERSION` / `package.json` / `.claude-plugin/plugin.json` / `.claude-plugin/marketplace.json` の version surface が不一致または欠落していれば、dry-run の時点で止める。

## 環境変数

プロジェクトごとの調整に使用:

| 変数 | 説明 |
|------|------|
| `HARNESS_RELEASE_PROJECT_ROOT` | リポジトリルート (デフォルト: `$(pwd)`) |
| `HARNESS_RELEASE_BRANCH` | push 対象ブランチ (デフォルト: 現在のブランチ) |
| `HARNESS_RELEASE_HEALTHCHECK_CMD` | Preflight で追加実行するコマンド |
| `HARNESS_RELEASE_SKIP_GH` | `1` で GitHub Release 作成をスキップ |

## CHANGELOG 書き方ルール

`[Unreleased]` セクションは必ず以下のいずれかのサブセクションを持つ:

```markdown
## [Unreleased]

### Added       ← minor
### Changed     ← patch
### Deprecated  ← minor
### Removed     ← major
### Fixed       ← patch
### Security    ← patch
### Breaking Changes  ← major (Keep a Changelog 非標準だが一般的)
```

このスキルはこれらの見出しを機械的に解析するため、見出しの表記揺れ（`### Fix` / `### Bug Fixes` 等）は認識できません。KaCL 標準の見出しを使用してください。

## 関連スキル

- `harness-release-internal` - 本体 claude-code-harness のリリース時に追加で走らせる harness 固有 preflight/finalization（配布対象外）
- `harness-plan` - Plans.md 管理
- `harness-review` - リリース前のコードレビュー

## 設計思想

- **単一ゲート**: ユーザーの判断タイミングは 1 回だけ。mini-confirmation を挟むとラバースタンプ化して意味を失う
- **事前に全て描く**: Post-Gate に入ってからの「考え直し」を禁ずる。Gate 前に全 draft を揃える
- **失敗は transparent**: 途中で失敗したら自動ロールバックは試みず、ユーザーに現状を提示して判断させる
- **プロジェクト非依存**: VERSION file 形式、mirror、residue check など特定環境の前提を持たない。本体 harness 固有の処理は `harness-release-internal` に分離
