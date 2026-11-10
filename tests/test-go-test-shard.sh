#!/usr/bin/env bash
# Checks the shard assignment behind the required test-go check: every package
# appears exactly once, the assignment is deterministic, and verify rejects an
# incomplete or duplicated list.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

shard_script="./tests/go-test-shard.sh"
expected="$(cd go && go list ./... | LC_ALL=C sort)"
[ -n "$expected" ] || fail "go list returned no packages"

single="$("$shard_script" assign 1 1)"
[ "$single" = "$expected" ] || fail "assign 1 1 must list every package"

first="$("$shard_script" assign 1 2)"
second="$("$shard_script" assign 1 2)"
[ "$first" = "$second" ] || fail "assignment must be deterministic"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/shard-1" "$tmp/shard-2"
"$shard_script" assign 1 2 > "$tmp/shard-1/packages.txt"
"$shard_script" assign 2 2 > "$tmp/shard-2/packages.txt"

combined="$(cat "$tmp"/shard-*/packages.txt | LC_ALL=C sort)"
[ "$combined" = "$expected" ] || fail "two shards must cover every package exactly once"
[ -z "$(printf '%s\n' "$combined" | uniq -d)" ] || fail "a package is assigned to both shards"

count_a="$(wc -l < "$tmp/shard-1/packages.txt" | tr -d ' ')"
count_b="$(wc -l < "$tmp/shard-2/packages.txt" | tr -d ' ')"
difference=$(( count_a - count_b ))
(( difference >= -1 && difference <= 1 )) || fail "shards differ by more than one package: ${count_a} vs ${count_b}"

"$shard_script" verify "$tmp" 2 > /dev/null || fail "verify must accept a complete assignment"

mv "$tmp/shard-2/packages.txt" "$tmp/shard-2/packages.txt.off"
if "$shard_script" verify "$tmp" 2 > /dev/null 2>&1; then
  fail "verify must reject a missing shard list"
fi
mv "$tmp/shard-2/packages.txt.off" "$tmp/shard-2/packages.txt"

cp "$tmp/shard-2/packages.txt" "$tmp/shard-2/packages.txt.orig"
head -n 1 "$tmp/shard-1/packages.txt" >> "$tmp/shard-2/packages.txt"
if "$shard_script" verify "$tmp" 2 > /dev/null 2>&1; then
  fail "verify must reject a package assigned twice"
fi
mv "$tmp/shard-2/packages.txt.orig" "$tmp/shard-2/packages.txt"

if "$shard_script" assign 0 2 > /dev/null 2>&1; then
  fail "assign must reject index 0"
fi
if "$shard_script" assign 3 2 > /dev/null 2>&1; then
  fail "assign must reject an index above total"
fi
if "$shard_script" assign x 2 > /dev/null 2>&1; then
  fail "assign must reject a non-numeric index"
fi

echo "PASS: go-test-shard assigns every package once across 2 shards"
