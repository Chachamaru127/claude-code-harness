#!/usr/bin/env bash
# Verify current compatibility facts and the shipped fail-closed publication gate.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPAT_DOC="$ROOT_DIR/docs/CLAUDE_CODE_COMPATIBILITY.md"
CONTRACT_DOC="$ROOT_DIR/docs/public-claims-contract.md"
AUDIT_DOC="$ROOT_DIR/docs/research/public-claims-audit-2026-07-10.md"
REGISTRY="$ROOT_DIR/hosts/registry.json"
VALIDATOR="$ROOT_DIR/scripts/validate-publication-records.py"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "test-public-claims-contract: FAIL: $1" >&2
  exit 1
}

for file in "$COMPAT_DOC" "$CONTRACT_DOC" "$AUDIT_DOC" "$REGISTRY" "$VALIDATOR"; do
  [ -f "$file" ] || fail "missing ${file#$ROOT_DIR/}"
done

version="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
plugin_version="$(jq -r '.version' "$ROOT_DIR/.claude-plugin/plugin.json")"
harness_version="$(sed -n 's/^version = "\([^"]*\)"/\1/p' "$ROOT_DIR/harness.toml" | head -1)"
[ "$plugin_version" = "$version" ] \
  || fail "plugin.json version $plugin_version differs from VERSION=$version"
[ "$harness_version" = "$version" ] \
  || fail "harness.toml version $harness_version differs from VERSION=$version"
grep -Fq "Plugin version: \`$version\`" "$COMPAT_DOC" \
  || fail "compatibility doc does not use VERSION=$version"
grep -Fq "Go-native" "$COMPAT_DOC" \
  || fail "compatibility doc does not describe the Go-native runtime"
grep -Fq 'TDD required when the task says so.' "$ROOT_DIR/README.md" \
  || fail "README must keep task-scoped TDD wording"
grep -Fq 'enabled = false' "$ROOT_DIR/harness.toml" \
  || fail "TDD local-trial default must remain disabled"
grep -Fq 'level = "off"' "$ROOT_DIR/harness.toml" \
  || fail "TDD local-trial level must remain off"

for stale in \
  'Plugin version: `3.10.2`' \
  'Node.js: `18+`' \
  'TypeScript guardrail'" engine" \
  'validate-plugin-v3.sh' \
  'cd core && npm test'
do
  if grep -Fq "$stale" "$COMPAT_DOC"; then
    fail "stale compatibility claim remains: $stale"
  fi
done

python3 - "$CONTRACT_DOC" "$REGISTRY" <<'PY'
from __future__ import annotations

import json
from pathlib import Path
import re
import sys


contract_path = Path(sys.argv[1])
registry_path = Path(sys.argv[2])
text = contract_path.read_text(encoding="utf-8")
start = "<!-- public-claims-policy:start -->"
end = "<!-- public-claims-policy:end -->"
if text.count(start) != 1 or text.count(end) != 1:
    raise SystemExit("public claims policy markers must occur exactly once")
block = text.split(start, 1)[1].split(end, 1)[0]
match = re.search(r"```json\s*(\{.*?\})\s*```", block, re.DOTALL)
if not match:
    raise SystemExit("machine-readable public claims policy JSON is missing")
policy = json.loads(match.group(1))

testimonial = policy["testimonial"]
required = {
    "kind",
    "source_url",
    "posted_at",
    "language",
    "quote",
    "retrieved_at",
    "publication_basis",
    "access_status",
    "source_capture_ref",
    "status",
}
if set(testimonial["required"]) != required:
    raise SystemExit(f"testimonial required fields drifted: {testimonial['required']}")
if testimonial["optional"] != ["public_crop_ref"]:
    raise SystemExit("public_crop_ref must be the only optional public image field")
if set(testimonial["status_values"]) != {"verified", "rejected", "unavailable"}:
    raise SystemExit("testimonial status enum drifted")
if testimonial["publishable_statuses"] != ["verified"]:
    raise SystemExit("only verified testimonials may be publishable")
if testimonial["access_status_values"] != ["direct_public", "login_required", "unavailable"]:
    raise SystemExit("testimonial access status enum drifted")
if testimonial["publishable_access_statuses"] != ["direct_public"]:
    raise SystemExit("only direct-public sources may be publishable")
if testimonial["publication_basis_values"] != ["direct_public_source", "minimal_attributed_quote"]:
    raise SystemExit("publication basis allowlist drifted")
if testimonial["quote_max_characters"] != 280:
    raise SystemExit("testimonial quote limit must remain 280 characters")
if testimonial["source_capture_extensions"] != [".png", ".jpg", ".webp"]:
    raise SystemExit("source capture extension allowlist drifted")
if (testimonial["source_capture_min_width"], testimonial["source_capture_min_height"]) != (800, 600):
    raise SystemExit("full-source minimum dimensions drifted")
if (testimonial["public_crop_min_width"], testimonial["public_crop_min_height"]) != (240, 100):
    raise SystemExit("public-crop minimum dimensions drifted")
if policy["validator"] != "scripts/validate-publication-records.py":
    raise SystemExit("shipped validator path drifted")
if policy["host_tier_source"] != "hosts/registry.json" or policy["host_tier_overrides"] != "forbidden":
    raise SystemExit("host tiers must be registry-derived and non-overridable")
if policy["collections"]["testimonials"] == policy["collections"]["independent_coverage"]:
    raise SystemExit("independent coverage must remain separate from testimonials")
claim = policy["implementation_claim"]
if set(claim["required"]) != {"kind", "text", "verified_at", "evidence_refs", "status"}:
    raise SystemExit("implementation claim required fields drifted")
if claim["kind_value"] != "implementation_claim":
    raise SystemExit("implementation claim kind drifted")
if set(claim["status_values"]) != {"verified", "rejected", "unavailable"}:
    raise SystemExit("implementation claim status enum drifted")
if claim["publishable_statuses"] != ["verified"]:
    raise SystemExit("only verified implementation claims may be publishable")

registry = json.loads(registry_path.read_text(encoding="utf-8"))
tiers = {host["id"]: host["tier"] for host in registry["hosts"]}
for host in ("cursor", "grok"):
    if tiers.get(host) != "internal-compatible":
        raise SystemExit(f"{host} tier must remain internal-compatible")
PY

python3 - "$TMP_DIR" <<'PY'
from __future__ import annotations

import copy
import json
from pathlib import Path
import struct
import sys
import zlib


root = Path(sys.argv[1])
evidence = root / "evidence"
manifests = root / "manifests"
evidence.mkdir()
manifests.mkdir()

def png_bytes(width: int, height: int) -> bytes:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    row = b"\x00" + (b"\xff\xff\xff\xff" * width)
    pixel = zlib.compress(row * height)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", pixel) + chunk(b"IEND", b"")

(evidence / "full-source.png").write_bytes(png_bytes(1280, 720))
(evidence / "public-crop.png").write_bytes(png_bytes(720, 240))
(evidence / "tiny.png").write_bytes(png_bytes(1, 1))
(evidence / "not-an-image.png").write_text("not an image", encoding="utf-8")
(evidence / "wrong-extension.gif").write_bytes(png_bytes(1280, 720))
(evidence / "truncated.png").write_bytes(b"\x89PNG\r\n\x1a\n")
(evidence / "truncated.jpg").write_bytes(b"\xff\xd8\xff")
(evidence / "truncated.webp").write_bytes(b"RIFF\x04\x00\x00\x00WEBP")
(evidence / "implementation-proof.txt").write_text("focused test: pass\n", encoding="utf-8")

record = {
    "kind": "testimonial",
    "source_url": "https://example.com/posts/direct-source",
    "posted_at": "2026-01-21",
    "language": "ja",
    "quote": "The evidence-backed workflow was useful.",
    "retrieved_at": "2026-07-10",
    "publication_basis": "minimal_attributed_quote",
    "access_status": "direct_public",
    "source_capture_ref": "full-source.png",
    "public_crop_ref": "public-crop.png",
    "status": "verified",
}

def manifest(item: dict[str, str]) -> dict[str, object]:
    return {
        "schema_version": "publication-records.v1",
        "collection": "testimonials",
        "records": [item],
    }

def write(name: str, item: dict[str, str]) -> None:
    (manifests / f"{name}.json").write_text(json.dumps(manifest(item), ensure_ascii=False), encoding="utf-8")

def claim_manifest(item: dict[str, object]) -> dict[str, object]:
    return {
        "schema_version": "publication-records.v1",
        "collection": "implementation_claims",
        "records": [item],
    }

def write_claim(name: str, item: dict[str, object]) -> None:
    (manifests / f"{name}.json").write_text(json.dumps(claim_manifest(item), ensure_ascii=False), encoding="utf-8")

write("pass", record)
cases: list[tuple[str, dict[str, str], str]] = []

missing = copy.deepcopy(record)
missing.pop("source_url")
cases.append(("missing-source-url", missing, "source_url"))
for status in ("rejected", "unavailable"):
    item = copy.deepcopy(record)
    item["status"] = status
    cases.append((f"status-{status}", item, "status"))
for access in ("login_required", "unavailable"):
    item = copy.deepcopy(record)
    item["access_status"] = access
    cases.append((f"access-{access}", item, "access_status"))

bad_basis = copy.deepcopy(record)
bad_basis["publication_basis"] = "permission_unknown"
cases.append(("bad-publication-basis", bad_basis, "publication_basis"))
missing_capture = copy.deepcopy(record)
missing_capture["source_capture_ref"] = "missing-source.png"
cases.append(("missing-capture", missing_capture, "source_capture_ref"))
bad_image = copy.deepcopy(record)
bad_image["source_capture_ref"] = "not-an-image.png"
cases.append(("non-image-capture", bad_image, "source_capture_ref"))
bad_extension = copy.deepcopy(record)
bad_extension["source_capture_ref"] = "wrong-extension.gif"
cases.append(("bad-capture-extension", bad_extension, "source_capture_ref"))
bad_crop = copy.deepcopy(record)
bad_crop["public_crop_ref"] = "not-an-image.png"
cases.append(("bad-public-crop", bad_crop, "public_crop_ref"))
same_crop = copy.deepcopy(record)
same_crop["public_crop_ref"] = "full-source.png"
cases.append(("same-source-and-crop", same_crop, "public_crop_ref"))
tiny_source = copy.deepcopy(record)
tiny_source["source_capture_ref"] = "tiny.png"
cases.append(("tiny-source", tiny_source, "source_capture_ref"))
for extension in ("png", "jpg", "webp"):
    truncated = copy.deepcopy(record)
    truncated["source_capture_ref"] = f"truncated.{extension}"
    cases.append((f"truncated-{extension}", truncated, "source_capture_ref"))

for name, url in (("invalid-url", "not-a-url"), ("non-direct-url", "https://bit.ly/redirect")):
    item = copy.deepcopy(record)
    item["source_url"] = url
    cases.append((name, item, "source_url"))

oversized = copy.deepcopy(record)
oversized["quote"] = "a" * 281
cases.append(("oversized-quote", oversized, "quote"))
coverage = copy.deepcopy(record)
coverage["kind"] = "independent_coverage"
cases.append(("coverage-as-testimonial", coverage, "kind"))
obsolete_image = copy.deepcopy(record)
obsolete_image["image_ref"] = "public-crop.png"
cases.append(("obsolete-image-field", obsolete_image, "image_ref"))

claims = {
    "25x": "Delivery became 25X faster.",
    "25-percent": "Delivery had a 25% speedup.",
    "two-times-jp": "開発が2倍高速になった。",
    "25-percent-jp": "開発を25％高速化した。",
    "absolutely-safe": "This workflow is absolutely safe.",
    "100-percent-secure": "This workflow is 100% secure.",
    "safe-jp": "この運用は絶対に安全です。",
    "never-fails-jp": "この運用は失敗しない。",
}
for name, quote in claims.items():
    item = copy.deepcopy(record)
    item["quote"] = quote
    cases.append((f"claim-{name}", item, "quote"))

for name, item, expected in cases:
    write(name, item)

claim_record: dict[str, object] = {
    "kind": "implementation_claim",
    "text": "The workflow records validation evidence before review.",
    "verified_at": "2026-07-10",
    "evidence_refs": ["implementation-proof.txt"],
    "status": "verified",
}
write_claim("claim-pass", claim_record)
claim_cases: list[tuple[str, dict[str, object], str]] = []
missing_claim_evidence = copy.deepcopy(claim_record)
missing_claim_evidence["evidence_refs"] = ["missing-proof.txt"]
claim_cases.append(("claim-missing-evidence", missing_claim_evidence, "evidence_refs"))
unverified_claim = copy.deepcopy(claim_record)
unverified_claim["status"] = "unavailable"
claim_cases.append(("claim-unavailable", unverified_claim, "status"))
overbroad_claim = copy.deepcopy(claim_record)
overbroad_claim["text"] = "The workflow makes delivery 25X faster."
claim_cases.append(("claim-overbroad", overbroad_claim, "text"))
coverage_claim = copy.deepcopy(claim_record)
coverage_claim["kind"] = "independent_coverage"
claim_cases.append(("claim-coverage", coverage_claim, "kind"))
for name, item, expected in claim_cases:
    write_claim(name, item)

with (root / "cases.tsv").open("w", encoding="utf-8") as handle:
    for name, _, expected in cases:
        handle.write(f"{name}\t{expected}\n")
    for name, _, expected in claim_cases:
        handle.write(f"{name}\t{expected}\n")
PY

python3 "$VALIDATOR" \
  --evidence-root "$TMP_DIR/evidence" \
  "$TMP_DIR/manifests/pass.json" >/dev/null \
  || fail "valid publication record was rejected"
python3 "$VALIDATOR" \
  --evidence-root "$TMP_DIR/evidence" \
  "$TMP_DIR/manifests/claim-pass.json" >/dev/null \
  || fail "valid implementation claim was rejected"

while IFS=$'\t' read -r case_name expected_error; do
  stdout_file="$TMP_DIR/${case_name}.stdout"
  stderr_file="$TMP_DIR/${case_name}.stderr"
  if python3 "$VALIDATOR" \
    --evidence-root "$TMP_DIR/evidence" \
    "$TMP_DIR/manifests/${case_name}.json" \
    >"$stdout_file" 2>"$stderr_file"; then
    fail "ineligible fixture unexpectedly passed: $case_name"
  fi
  grep -Fqi "$expected_error" "$stderr_file" \
    || fail "$case_name failed without expected field '$expected_error': $(tr '\n' ' ' < "$stderr_file")"
done < "$TMP_DIR/cases.tsv"

for row in \
  '| Version and bundled binary | NOT REPRODUCED |' \
  '| Global TDD enforcement | NOT REPRODUCED |' \
  '| Compatibility documentation | REPRODUCED |' \
  '| Host tier drift | NOT REPRODUCED |'
do
  grep -Fq "$row" "$AUDIT_DOC" || fail "dated audit is missing row: $row"
done

echo "test-public-claims-contract: ok"
