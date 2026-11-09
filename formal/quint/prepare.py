"""Explicitly fetch the pinned, project-local checker; verification never downloads."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tarfile
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parent
VERSIONS = json.loads((ROOT / 'versions.json').read_text())
CACHE = ROOT / '.cache'


def jar_path():
    return CACHE / ('apalache-dist-' + VERSIONS['apalache']) / 'apalache/lib/apalache.jar'


def require_hash(path, expected):
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
        raise ValueError('missing or changed pinned artifact: ' + str(path))


def prepare(archive=None):
    if jar_path().is_file():
        require_hash(jar_path(), VERSIONS['jar_sha256'])
        return jar_path()
    CACHE.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='fetch-', dir=CACHE) as directory:
        stage = Path(directory)
        source = Path(archive) if archive else stage / 'apalache.tgz'
        if not archive:
            with urllib.request.urlopen(VERSIONS['archive_url'], timeout=120) as response, source.open('wb') as out:
                shutil.copyfileobj(response, out)
        require_hash(source, VERSIONS['archive_sha256'])
        with tarfile.open(source) as package:
            package.extractall(stage, filter='data')
        unpacked = stage
        require_hash(unpacked / 'apalache/lib/apalache.jar', VERSIONS['jar_sha256'])
        destination = CACHE / ('apalache-dist-' + VERSIONS['apalache'])
        if destination.exists():
            raise ValueError('incomplete checker directory: remove only this generated directory and retry: ' + str(destination))
        destination.mkdir()
        (unpacked / 'apalache').rename(destination / 'apalache')
    return jar_path()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, help='Use an already downloaded archive; the same hash is required')
    args = parser.parse_args()
    print(prepare(args.archive))
