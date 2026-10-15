#!/usr/bin/env python3
"""Exercise renamed hook root lookup without touching an installed plugin."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parents[1]
assert tomllib.loads((ROOT / "harness.toml").read_text())["project"]["name"] == "harness", "generator still uses the reserved plugin ID"
assert json.loads((ROOT / ".claude-plugin/plugin.json").read_text())["name"] == "harness"
marketplace = json.loads((ROOT / ".claude-plugin/marketplace.json").read_text())
assert marketplace["name"] == "claude-code-harness-marketplace"
assert marketplace["renames"] == {"claude-code-harness": "harness"}
for adapter in [".codex-plugin", ".cursor-plugin", ".grok-plugin"]:
    assert json.loads((ROOT / adapter / "plugin.json").read_text())["name"] == "harness"
assert [p["name"] for p in marketplace["plugins"]] == ["harness"]

for hooks_file in ["hooks/hooks.json", ".claude-plugin/hooks.json"]:
    hooks = json.loads((ROOT / hooks_file).read_text())["hooks"]["PreToolUse"]
    commands = [h["command"] for event in hooks for h in event["hooks"] if h.get("type") == "command" and "_ hook pre-tool" in h.get("command", "")]
    assert commands, "pre-tool command missing"
    for command in commands:
        expected = ["hook", "pre-tool-use-file-lease"] if command.endswith("_ hook pre-tool-use-file-lease") else ["hook", "pre-tool"]
        with tempfile.TemporaryDirectory(prefix="harness-identity-") as tmp:
            base = Path(tmp)
            unrelated = base / "cwd"
            unrelated.mkdir()
            home = base / "home"
            home.mkdir()
            log = base / "invocations"
            def plugin(path, name):
                (path / "bin").mkdir(parents=True)
                (path / ".claude-plugin").mkdir()
                (path / ".claude-plugin/plugin.json").write_text(json.dumps({"name": name}))
                binary = path / "bin/harness"
                binary.write_text('#!/bin/sh\nprintf "%s\\n" "$@" >> "$HARNESS_IDENTITY_LOG"\n')
                binary.chmod(0o755)
            explicit = base / "explicit"
            plugin(explicit, "harness")
            env = {**os.environ, "HOME": str(home), "CLAUDE_PLUGIN_ROOT": str(explicit), "CLAUDE_PROJECT_DIR": "", "HARNESS_IDENTITY_LOG": str(log)}
            subprocess.run(command, shell=True, cwd=unrelated, env=env, check=True, capture_output=True)
            assert log.read_text().splitlines() == expected
            log.unlink()
            (explicit / ".claude-plugin/plugin.json").write_text('{"name":"claude-code-harness"}')
            subprocess.run(command, shell=True, cwd=unrelated, env=env, check=True, capture_output=True)
            assert not log.exists(), "legacy plugin executed through renamed hooks"
            (explicit / ".claude-plugin/plugin.json").write_text('{"name":"unrelated"}')
            subprocess.run(command, shell=True, cwd=unrelated, env=env, check=True, capture_output=True)
            assert not log.exists(), "wrong plugin executed"
            cache = home / ".claude/plugins/cache/claude-code-harness-marketplace/harness/5.15.0"
            plugin(cache, "harness")
            subprocess.run(command, shell=True, cwd=unrelated, env=env, check=True, capture_output=True)
            assert log.read_text().splitlines() == expected, "new cache lookup failed"
print("PASS: generator identity and real hook root/cache resolution")
