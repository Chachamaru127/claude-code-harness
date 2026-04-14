# Version File Detection & Update

このスキルが扱う 4 種類の version file について、検出と書き換えの詳細。

## 優先順位

```
VERSION  >  package.json  >  pyproject.toml  >  Cargo.toml
```

プロジェクトに複数存在する場合、優先順が高いものを正本とする。
通常はいずれか 1 つだけ存在する想定。

## 検出と読み取り

### VERSION (単独ファイル)

```bash
cat VERSION | tr -d '\n'
```

1 行のみ、セマンティックバージョン (`x.y.z`)。

### package.json (npm)

```python
import json
with open("package.json") as f:
    data = json.load(f)
current_version = data["version"]
```

トップレベル `"version": "x.y.z"`。

### pyproject.toml (Python)

PEP 621 準拠 (`[project]`) と Poetry (`[tool.poetry]`) の両方に対応:

```python
import tomllib
with open("pyproject.toml", "rb") as f:
    data = tomllib.load(f)

if "project" in data and "version" in data["project"]:
    current_version = data["project"]["version"]
elif "tool" in data and "poetry" in data["tool"]:
    current_version = data["tool"]["poetry"]["version"]
else:
    raise RuntimeError("pyproject.toml に version が見つかりません")
```

**注意**: `pyproject.toml` では `dynamic = ["version"]` などで version を別ファイル (`_version.py` 等) から読む設定がある。この場合スキルは対応しない（事前に static version に切り替えるか、`VERSION` ファイルを併用してもらう）。

### Cargo.toml (Rust)

```python
import tomllib
with open("Cargo.toml", "rb") as f:
    data = tomllib.load(f)
current_version = data["package"]["version"]
```

## 書き換え

書き換えは「最小限のフィールド差し替え」で行う。整形スタイルやコメントを壊さないよう、regex 置換を推奨:

### VERSION

```bash
echo "$NEW_VERSION" > VERSION
```

### package.json

`jq` があれば:
```bash
jq --arg v "$NEW_VERSION" '.version = $v' package.json > /tmp/package.json && mv /tmp/package.json package.json
```

`jq` がなければ Python:
```python
import json
with open("package.json", "r") as f:
    data = json.load(f)
data["version"] = NEW_VERSION
with open("package.json", "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
```

### pyproject.toml / Cargo.toml

TOML は書き換えスタイルを壊したくないため、regex で最初の `version = "..."` 行のみ置換:

```python
import re
with open("pyproject.toml", "r") as f:
    content = f.read()

# [project] または [tool.poetry] セクション内の version を置換
section_pattern = None
if re.search(r"^\[project\]", content, re.M):
    section_pattern = r"(\[project\][^\[]*?version\s*=\s*\")[^\"]+(\")"
elif re.search(r"^\[tool\.poetry\]", content, re.M):
    section_pattern = r"(\[tool\.poetry\][^\[]*?version\s*=\s*\")[^\"]+(\")"

new_content = re.sub(
    section_pattern,
    rf"\g<1>{NEW_VERSION}\g<2>",
    content,
    count=1,
    flags=re.S,
)
with open("pyproject.toml", "w") as f:
    f.write(new_content)
```

Cargo.toml も同様 (`[package]` セクション内):

```python
section_pattern = r"(\[package\][^\[]*?version\s*=\s*\")[^\"]+(\")"
```

## サブパッケージの扱い

monorepo で複数の version file が存在するケース（例: npm workspaces）はこのスキルの対象外。
ルートの 1 ファイルだけを正本とする設計。
複数 package を同期したい場合は専用のリリースオーケストレーターを別途構築してください。

## 非対応の version 表現

以下は非対応。事前に SemVer 形式に正規化してください:

- `v1.0.0` (先頭の `v` を許容しない、tag だけが `v` プレフィックス)
- `1.0.0-alpha.1` (pre-release suffix は保持するが bump 対象にしない)
- `1.0.0+build.1` (build metadata は保持)
- Calendar versioning (`2024.01`)
