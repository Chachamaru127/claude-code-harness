# Bump Level Detection

`[Unreleased]` セクションの内容から bump level (patch/minor/major) を推定するロジック。

## 判定ルール

`[Unreleased]` 直下の `### <category>` 見出しを全てスキャンし、以下の優先順位で判定:

```
1. "### Breaking Changes" が含まれる             → major
2. "### Removed" が含まれる                      → major
3. "### Added" が含まれる (上記なし)             → minor
4. "### Deprecated" が含まれる (上記なし)        → minor
5. "### Fixed" / "### Changed" / "### Security" のみ → patch
6. サブセクションが 1 つもない (空)              → error
```

## 実装

```python
import re

def detect_bump(changelog_text: str) -> str:
    """Return 'major' | 'minor' | 'patch'. Raises on empty [Unreleased]."""
    # [Unreleased] セクションを抽出
    m = re.search(
        r"## \[Unreleased\]\s*\n(.*?)(?=\n## \[|\Z)",
        changelog_text,
        re.S,
    )
    if not m:
        raise RuntimeError("[Unreleased] セクションが見つかりません")
    body = m.group(1).strip()
    if not body:
        raise RuntimeError("[Unreleased] が空です。リリース対象がありません")

    # 見出しを収集
    headings = set(re.findall(r"^### (.+?)\s*$", body, re.M))

    if "Breaking Changes" in headings or "Removed" in headings:
        return "major"
    if "Added" in headings or "Deprecated" in headings:
        return "minor"
    if headings & {"Fixed", "Changed", "Security"}:
        return "patch"
    raise RuntimeError(f"認識できるサブセクションが [Unreleased] にありません: {headings}")
```

## なぜ Deprecated は minor か

Keep a Changelog の仕様上、Deprecated は「将来 Removed される予定の通告」。
機能追加/変更と同等のユーザー影響があるため minor で扱う。
実際の Removed 時点で major に上がる。

## ユーザー override

`/release patch|minor|major` と明示指定された場合はこの自動判定を skip し、指定値を使う。
ただし **bump 対象セクションが空** のときは override されていても abort する（リリース内容がないため）。

## 表記揺れは非対応

以下は認識しない:

| 書かれがちな表記 | 正しい表記 |
|-----------------|-----------|
| `### Features` | `### Added` |
| `### Bug Fixes` / `### Fix` | `### Fixed` |
| `### BREAKING CHANGE` / `### Breaking` | `### Breaking Changes` |
| `### Enhancements` | `### Changed` または `### Added` |

KaCL の標準見出しに揃えてから `/release` を呼ぶこと。
Gate 前に認識できない見出しを検出したら警告を出し、ユーザーに修正を促す。

## pre-release / build metadata の扱い

現バージョンが `1.0.0-alpha.1` のような pre-release suffix を持つ場合、このスキルは

1. suffix 部分を無視して bump 計算（`1.0.0-alpha.1` → patch → `1.0.1`）
2. suffix は破棄（`1.0.1-alpha.1` にはしない）

pre-release のまま bump したい場合は override で bump 指定しても挙動は変わらない。
pre-release を意図的に継続したいプロジェクトはこのスキル非対応。

## 空 [Unreleased] への対処

`/release` が空 [Unreleased] で呼ばれたら、以下を提案:

- 「リリース対象がありません。`[Unreleased]` に `### Fixed` 等を追加するか、マーカーだけのメンテナンスリリースを希望するなら `--empty` フラグを検討してください」

`--empty` フラグは本スキル未対応（空 release は原則作成しない）。
