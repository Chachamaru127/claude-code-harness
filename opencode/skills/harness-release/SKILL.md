---
name: harness-release
description: "汎用リリース自動化スキル。Keep a Changelog と GitHub を使うあらゆるプロジェクトで動作。単一確認ゲートで bump 判定・CHANGELOG 昇格・タグ・GitHub Release まで全自動実行する。リリース、バージョンバンプ、タグ作成、公開で起動。実装・コードレビュー・プランニング・セットアップには使わない。"
description-en: "Generic release automation for projects using Keep a Changelog + GitHub. Single confirmation gate then end-to-end automation: bump detection, CHANGELOG promotion, tag, GitHub Release. Trigger: release, version bump, publish. Do NOT load for: implementation, review, planning, setup."
description-ja: "汎用リリース自動化スキル。Keep a Changelog と GitHub を使うあらゆるプロジェクトで動作。単一確認ゲートで bump 判定・CHANGELOG 昇格・タグ・GitHub Release まで全自動実行する。リリース、バージョンバンプ、タグ作成、公開で起動。実装・コードレビュー・プランニング・セットアップには使わない。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
argument-hint: "[patch|minor|major|--dry-run]"
context: fork
effort: high
---

# Harness Release (汎用)

Keep a Changelog + GitHub を使う**あらゆるプロジェクト向け**の汎用リリース自動化スキル。

**設計原則**: 単一確認ゲート。ユーザーは 1 回だけ全体計画を見て承認する。承認後はファイル書き換え → commit → push → tag → GitHub Release までを中断なく実行する。

## Quick Reference

```bash
/release              # [Unreleased] から bump level を自動推定、確認ゲートへ
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

これらが満たされない場合、Preflight で detect して abort します。

## 単一ゲートフロー

```
[Pre-Gate: 情報収集のみ、ファイル未変更]
  ↓
  1. Preflight (working tree clean / CHANGELOG / gh 等の確認)
  2. Version file 自動検出
  3. 現在バージョンの読み取り
  4. [Unreleased] 内容の解析 → bump level 推定
  5. 新バージョン算出
  6. CHANGELOG 差分ドラフト作成 (メモリ上)
  7. GitHub Release notes ドラフト作成 (メモリ上)

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

  8. Version file 書き換え
  9. CHANGELOG.md 書き換え ([Unreleased] → [X.Y.Z] 昇格 + compare link)
  10. git add + commit
  11. git tag -a vX.Y.Z
  12. git push origin <branch> --tags
  13. gh release create vX.Y.Z
  14. 完了報告
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
```

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

### 3. Bump 自動推定

`[Unreleased]` 直下の見出しを解析して bump level を決定:

| [Unreleased] 内の見出し | 推定 bump |
|------------------------|-----------|
| `### Breaking Changes` または `### Removed` を含む | **major** |
| `### Added` を含む (Removed/Breaking なし) | **minor** |
| `### Fixed` / `### Changed` / `### Security` のみ | **patch** |
| 空セクション | **error: リリース対象なし** |

ユーザーが `/release patch|minor|major` で明示指定した場合はそちらを優先。
詳細: [bump-detection.md](${CLAUDE_SKILL_DIR}/references/bump-detection.md)

### 4. CHANGELOG ドラフト作成 (メモリ上)

以下を計算、まだ書き込まない:

1. `## [Unreleased]` の本文を切り出し
2. `## [Unreleased]` と `## [<previous>]` の間に `## [<new>] - YYYY-MM-DD` を挿入した形を作成
3. 末尾 compare link:
   - `[Unreleased]: .../compare/v<prev>...HEAD` → `v<new>...HEAD`
   - `[<new>]: .../compare/v<prev>...v<new>` を追加
4. repo URL は既存の `[Unreleased]: ` 行から動的抽出

### 5. Release Notes ドラフト作成 (メモリ上)

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
   - git tag -a v<new>
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
| push 失敗 | リモート側の問題。ローカル commit/tag は残す |
| `gh release create` 失敗 | tag は push 済みなので、既存の release.yml セーフティネットが発火するか、手動で `gh release create` |

## `--dry-run` モード

Pre-Gate 全てを実行し、Confirmation Gate までの内容を表示するが、**gate で止まり Post-Gate に進まない**。

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
