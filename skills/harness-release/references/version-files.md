# Version File Detection & Update

Details on detecting and rewriting the four types of version files handled by this skill.

## Priority Order

```
VERSION  >  package.json  >  pyproject.toml  >  Cargo.toml
```

If multiple version files exist in a project, the one with the highest priority is the canonical source.
Normally only one of them is expected to exist.

## Detection and Reading

### VERSION (standalone file)

```bash
cat VERSION | tr -d '\n'
```

Single line, semantic version (`x.y.z`).

### package.json (npm)

```python
import json
with open("package.json") as f:
    data = json.load(f)
current_version = data["version"]
```

Top-level `"version": "x.y.z"`.

### pyproject.toml (Python)

Supports both PEP 621 (`[project]`) and Poetry (`[tool.poetry]`):

```python
import tomllib
with open("pyproject.toml", "rb") as f:
    data = tomllib.load(f)

if "project" in data and "version" in data["project"]:
    current_version = data["project"]["version"]
elif "tool" in data and "poetry" in data["tool"]:
    current_version = data["tool"]["poetry"]["version"]
else:
    raise RuntimeError("version not found in pyproject.toml")
```

**Note**: Some `pyproject.toml` configurations read the version from a separate file (e.g., `_version.py`) using `dynamic = ["version"]`. This skill does not support that case — either switch to a static version beforehand or use a `VERSION` file alongside it.

### Cargo.toml (Rust)

```python
import tomllib
with open("Cargo.toml", "rb") as f:
    data = tomllib.load(f)
current_version = data["package"]["version"]
```

## Rewriting

Rewrites are performed as "minimal field replacement". Regex substitution is recommended to avoid breaking formatting style or comments:

### VERSION

```bash
echo "$NEW_VERSION" > VERSION
```

### package.json

With `jq`:
```bash
jq --arg v "$NEW_VERSION" '.version = $v' package.json > /tmp/package.json && mv /tmp/package.json package.json
```

Without `jq`, use Python:
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

To avoid breaking TOML formatting style, replace only the first `version = "..."` line using regex:

```python
import re
with open("pyproject.toml", "r") as f:
    content = f.read()

# Replace version inside [project] or [tool.poetry] section
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

Cargo.toml follows the same approach (inside the `[package]` section):

```python
section_pattern = r"(\[package\][^\[]*?version\s*=\s*\")[^\"]+(\")"
```

## Handling Sub-packages

Monorepos with multiple version files (e.g., npm workspaces) are out of scope for this skill.
The design treats only the root file as the canonical source.
If you need to sync multiple packages, build a dedicated release orchestrator separately.

## Unsupported Version Formats

The following are not supported. Normalize to SemVer format beforehand:

- `v1.0.0` (leading `v` not accepted in the file; only tags use the `v` prefix)
- `1.0.0-alpha.1` (pre-release suffix is preserved but not bumped)
- `1.0.0+build.1` (build metadata is preserved)
- Calendar versioning (`2024.01`)
