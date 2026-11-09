"""Compile Quint through a pinned file-only transport and execute bounded processes."""
import json
import os
import re
from pathlib import Path
import signal
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
from .prepare import VERSIONS, jar_path, require_hash


def java_command():
    return os.environ.get('JOB_LEASE_JAVA') or (str(Path(os.environ['JAVA_HOME']) / 'bin/java') if os.environ.get('JAVA_HOME') else 'java')


def run_command(command, *, env=None, timeout=90):
    process = subprocess.Popen(command, env=env, text=True, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, start_new_session=True)
    try:
        stdout, stderr = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.communicate()
        raise
    return subprocess.CompletedProcess(command, process.returncode, stdout, stderr)


def compile_model(source, main, invariant, output):
    if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', main):
        raise ValueError('unsupported TLA module name')
    require_hash(jar_path(), VERSIONS['jar_sha256'])
    package = ROOT / 'node_modules/@informalsystems/quint/package.json'
    if not package.is_file() or json.loads(package.read_text()).get('version') != VERSIONS['quint']:
        raise ValueError('pinned Quint missing: npm ci --prefix formal/quint --ignore-scripts --no-audit --no-fund')
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    target = output / (main + '.tla')
    target.unlink(missing_ok=True)
    env = os.environ.copy()
    env.update(ROUTECLI_QUINT_OUTPUT=str(output), JAVA_TOOL_OPTIONS='-Xmx1g -Xss16m')
    result = run_command(['node', str(ROOT / 'compile.cjs'), 'compile', str(source.resolve()),
                          '--main', main, '--invariant', invariant, '--target', 'tlaplus',
                          '--apalache-version', VERSIONS['apalache']], env=env)
    (output / 'compile.stdout.log').write_text(result.stdout)
    (output / 'compile.stderr.log').write_text(result.stderr)
    if result.returncode != 0 or not target.is_file():
        print(result.stdout)
        print(result.stderr, file=sys.stderr)
        raise ValueError('Quint compilation failed: ' + str(output))
    return target
