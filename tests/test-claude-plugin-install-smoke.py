#!/usr/bin/env python3
"""Install the local renamed package only in an isolated Claude config/home."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
real_paths = [Path.home() / ".claude/plugins/installed_plugins.json", Path.home() / ".claude/settings.json"]
def stamps():
    return [(p.stat().st_mtime_ns, p.stat().st_size) if p.exists() else None for p in real_paths]
before = stamps()
with tempfile.TemporaryDirectory(prefix="harness-plugin-smoke-") as tmp:
    base = Path(tmp)
    home = base / "home"
    config = home / ".claude"
    project = base / "project"
    config.mkdir(parents=True)
    project.mkdir()
    env = {**os.environ, "HOME": str(home), "CLAUDE_CONFIG_DIR": str(config), "XDG_CONFIG_HOME": str(home / ".config"), "CLAUDE_PROJECT_DIR": str(project), "CLAUDE_PLUGIN_ROOT": "", "CLAUDE_CODE_HARNESS_MEM_AUTO_SETUP": "0"}
    def cli(*args):
        result = subprocess.run(["claude", "--bare", "plugin", *args], cwd=project, env=env, capture_output=True, text=True, timeout=90)
        assert result.returncode == 0, result.stderr + result.stdout
        return result.stdout
    cli("marketplace", "add", str(ROOT))
    cli("install", "harness@claude-code-harness-marketplace", "--scope", "user")
    listed = json.loads(cli("list", "--json"))
    assert "harness@claude-code-harness-marketplace" in json.dumps(listed), listed
    assert (config / "plugins/installed_plugins.json").exists(), "installation did not use isolated config"
assert stamps() == before, "real user plugin registrations/settings were touched"
print("PASS: isolated Claude manager installs harness; real user settings unchanged")
