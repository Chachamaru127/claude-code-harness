#!/usr/bin/env python3
"""Fail-closed validator for testimonial records entering a public build."""

from __future__ import annotations

import argparse
from datetime import date
import json
from pathlib import Path
import re
import struct
import sys
from typing import Any
from urllib.parse import urlparse
import zlib


ROOT = Path(__file__).resolve().parents[1]
POLICY_DOC = ROOT / "docs" / "public-claims-contract.md"


def fail(message: str) -> None:
    raise ValueError(message)


def load_policy() -> dict[str, Any]:
    text = POLICY_DOC.read_text(encoding="utf-8")
    start = "<!-- public-claims-policy:start -->"
    end = "<!-- public-claims-policy:end -->"
    if text.count(start) != 1 or text.count(end) != 1:
        fail("policy: machine-readable policy markers must occur exactly once")
    block = text.split(start, 1)[1].split(end, 1)[0]
    match = re.search(r"```json\s*(\{.*?\})\s*```", block, re.DOTALL)
    if not match:
        fail("policy: JSON block is missing")
    return json.loads(match.group(1))


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"{path}: invalid JSON: {exc}")
    if not isinstance(value, dict):
        fail(f"{path}: manifest must be an object")
    return value


def validate_date(value: Any, field: str) -> None:
    if not isinstance(value, str):
        fail(f"{field}: expected ISO date string")
    try:
        date.fromisoformat(value)
    except ValueError:
        fail(f"{field}: expected YYYY-MM-DD")


def validate_url(value: Any, field: str, policy: dict[str, Any]) -> None:
    if not isinstance(value, str):
        fail(f"{field}: expected direct HTTPS URL")
    parsed = urlparse(value)
    host = (parsed.hostname or "").lower()
    schemes = set(policy["schemes"])
    blocked_hosts = set(policy["blocked_hosts"])
    if parsed.scheme not in schemes or not host or not parsed.path.strip("/"):
        fail(f"{field}: expected direct HTTPS source URL")
    if host in blocked_hosts or any(host.endswith(f".{item}") for item in blocked_hosts):
        fail(f"{field}: URL shorteners and redirect hosts are not direct sources")
    path_segments = {segment.lower() for segment in parsed.path.split("/") if segment}
    if path_segments.intersection({item.lower() for item in policy["blocked_path_segments"]}):
        fail(f"{field}: login, authentication, and search URLs are not direct sources")


def png_dimensions(data: bytes, field: str) -> tuple[int, int]:
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        fail(f"{field}: invalid PNG signature")
    offset = 8
    width = height = 0
    expected_pixel_bytes = 0
    saw_idat = saw_iend = False
    compressed = bytearray()
    while offset + 12 <= len(data):
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        kind = data[offset + 4 : offset + 8]
        end = offset + 12 + length
        if end > len(data):
            fail(f"{field}: truncated PNG chunk")
        payload = data[offset + 8 : offset + 8 + length]
        expected_crc = struct.unpack(">I", data[offset + 8 + length : end])[0]
        if zlib.crc32(kind + payload) & 0xFFFFFFFF != expected_crc:
            fail(f"{field}: invalid PNG checksum")
        if kind == b"IHDR":
            if offset != 8 or length != 13:
                fail(f"{field}: invalid PNG header")
            width, height = struct.unpack(">II", payload[:8])
            bit_depth, color_type, compression, filter_method, interlace = payload[8:13]
            channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(color_type)
            valid_depths = {
                0: {1, 2, 4, 8, 16},
                2: {8, 16},
                3: {1, 2, 4, 8},
                4: {8, 16},
                6: {8, 16},
            }
            if channels is None or bit_depth not in valid_depths[color_type]:
                fail(f"{field}: unsupported PNG color format")
            if compression != 0 or filter_method != 0 or interlace != 0:
                fail(f"{field}: unsupported PNG encoding")
            row_bytes = (width * channels * bit_depth + 7) // 8
            expected_pixel_bytes = height * (1 + row_bytes)
        elif kind == b"IDAT":
            saw_idat = True
            compressed.extend(payload)
        elif kind == b"IEND":
            if length != 0 or end != len(data):
                fail(f"{field}: invalid PNG end marker")
            saw_iend = True
            break
        offset = end
    if width <= 0 or height <= 0 or not saw_idat or not saw_iend:
        fail(f"{field}: incomplete PNG image")
    try:
        pixels = zlib.decompress(bytes(compressed))
        if not pixels or len(pixels) != expected_pixel_bytes:
            fail(f"{field}: empty PNG pixel data")
    except zlib.error:
        fail(f"{field}: corrupt PNG pixel data")
    return width, height


def jpeg_dimensions(data: bytes, field: str) -> tuple[int, int]:
    if len(data) < 4 or not data.startswith(b"\xff\xd8") or not data.endswith(b"\xff\xd9"):
        fail(f"{field}: incomplete JPEG image")
    offset = 2
    dimensions: tuple[int, int] | None = None
    saw_scan_data = False
    sof_markers = set(range(0xC0, 0xC4)) | set(range(0xC5, 0xC8)) | set(range(0xC9, 0xCC)) | set(range(0xCD, 0xD0))
    while offset < len(data) - 2:
        if data[offset] != 0xFF:
            fail(f"{field}: invalid JPEG marker")
        while offset < len(data) and data[offset] == 0xFF:
            offset += 1
        if offset >= len(data):
            fail(f"{field}: truncated JPEG marker")
        marker = data[offset]
        offset += 1
        if marker in {0xD8, 0xD9} or 0xD0 <= marker <= 0xD7:
            continue
        if offset + 2 > len(data):
            fail(f"{field}: truncated JPEG segment")
        length = struct.unpack(">H", data[offset : offset + 2])[0]
        if length < 2 or offset + length > len(data):
            fail(f"{field}: invalid JPEG segment length")
        if marker == 0xDA:
            saw_scan_data = offset + length < len(data) - 2
            break
        if marker in sof_markers:
            if length < 7:
                fail(f"{field}: invalid JPEG frame")
            height, width = struct.unpack(">HH", data[offset + 3 : offset + 7])
            dimensions = (width, height)
        offset += length
    if dimensions is None or dimensions[0] <= 0 or dimensions[1] <= 0 or not saw_scan_data:
        fail(f"{field}: JPEG dimensions are missing")
    return dimensions


def webp_dimensions(data: bytes, field: str) -> tuple[int, int]:
    if len(data) < 20 or data[:4] != b"RIFF" or data[8:12] != b"WEBP":
        fail(f"{field}: incomplete WebP image")
    if struct.unpack("<I", data[4:8])[0] + 8 != len(data):
        fail(f"{field}: invalid WebP container length")
    offset = 12
    dimensions: tuple[int, int] | None = None
    saw_image_data = False
    while offset + 8 <= len(data):
        kind = data[offset : offset + 4]
        length = struct.unpack("<I", data[offset + 4 : offset + 8])[0]
        start = offset + 8
        end = start + length
        if end > len(data):
            fail(f"{field}: truncated WebP chunk")
        payload = data[start:end]
        if kind == b"VP8X" and len(payload) >= 10:
            width = 1 + int.from_bytes(payload[4:7], "little")
            height = 1 + int.from_bytes(payload[7:10], "little")
            dimensions = (width, height)
        elif kind == b"VP8 " and len(payload) >= 10 and payload[3:6] == b"\x9d\x01\x2a":
            width = struct.unpack("<H", payload[6:8])[0] & 0x3FFF
            height = struct.unpack("<H", payload[8:10])[0] & 0x3FFF
            dimensions = (width, height)
            saw_image_data = True
        elif kind == b"VP8L" and len(payload) >= 5 and payload[0] == 0x2F:
            bits = int.from_bytes(payload[1:5], "little")
            dimensions = ((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1)
            saw_image_data = True
        offset = end + (length % 2)
    if offset != len(data) or dimensions is None or not saw_image_data or dimensions[0] <= 0 or dimensions[1] <= 0:
        fail(f"{field}: WebP dimensions are missing")
    return dimensions


def validate_image(
    reference: Any,
    field: str,
    evidence_root: Path,
    extensions: set[str],
    minimum_width: int,
    minimum_height: int,
) -> tuple[Path, int, int]:
    if not isinstance(reference, str) or not reference.strip():
        fail(f"{field}: image reference is required")
    relative = Path(reference)
    if relative.is_absolute() or ".." in relative.parts:
        fail(f"{field}: image reference must remain under the evidence root")
    if relative.suffix.lower() not in extensions:
        fail(f"{field}: unsupported source image extension")
    root = evidence_root.resolve()
    target = (root / relative).resolve()
    if target != root and root not in target.parents:
        fail(f"{field}: image reference escapes the evidence root")
    if not target.is_file():
        fail(f"{field}: image does not exist")
    data = target.read_bytes()
    extension = relative.suffix.lower()
    if extension == ".png":
        width, height = png_dimensions(data, field)
    elif extension == ".jpg":
        width, height = jpeg_dimensions(data, field)
    else:
        width, height = webp_dimensions(data, field)
    if width < minimum_width or height < minimum_height:
        fail(f"{field}: image dimensions {width}x{height} are below {minimum_width}x{minimum_height}")
    return target, width, height


def validate_evidence_file(reference: Any, field: str, evidence_root: Path) -> None:
    if not isinstance(reference, str) or not reference.strip():
        fail(f"{field}: evidence reference is required")
    relative = Path(reference)
    if relative.is_absolute() or ".." in relative.parts:
        fail(f"{field}: evidence reference must remain under the evidence root")
    root = evidence_root.resolve()
    target = (root / relative).resolve()
    if target != root and root not in target.parents:
        fail(f"{field}: evidence reference escapes the evidence root")
    if not target.is_file():
        fail(f"{field}: evidence file does not exist")


def validate_blocked_claim(text: str, field: str, policy: dict[str, Any]) -> None:
    for pattern in policy["blocked_claim_patterns"]:
        if re.search(pattern, text, re.IGNORECASE):
            fail(f"{field}: quantified or absolute speed/safety claim is blocked")


def validate_record(
    record: Any,
    index: int,
    policy: dict[str, Any],
    evidence_root: Path,
) -> None:
    prefix = f"records[{index}]"
    if not isinstance(record, dict):
        fail(f"{prefix}: record must be an object")

    testimonial = policy["testimonial"]
    required = set(testimonial["required"])
    optional = set(testimonial["optional"])
    fields = set(record)
    missing = sorted(required - fields)
    if missing:
        fail(f"{prefix}.{missing[0]}: required field is missing")
    unknown = sorted(fields - required - optional)
    if unknown:
        fail(f"{prefix}.{unknown[0]}: unsupported field")

    if record["kind"] != "testimonial":
        fail(f"{prefix}.kind: independent coverage cannot enter the testimonial collection")
    if record["status"] not in testimonial["publishable_statuses"]:
        fail(f"{prefix}.status: only verified records are publishable")
    if record["access_status"] not in testimonial["publishable_access_statuses"]:
        fail(f"{prefix}.access_status: source is not directly public")
    if record["publication_basis"] not in testimonial["publication_basis_values"]:
        fail(f"{prefix}.publication_basis: unsupported publication basis")

    validate_url(
        record["source_url"],
        f"{prefix}.source_url",
        policy["direct_source_url"],
    )
    validate_date(record["posted_at"], f"{prefix}.posted_at")
    validate_date(record["retrieved_at"], f"{prefix}.retrieved_at")

    language = record["language"]
    if not isinstance(language, str) or not re.fullmatch(r"[a-z]{2,3}(?:-[A-Za-z0-9]{2,8})*", language):
        fail(f"{prefix}.language: invalid language tag")

    quote = record["quote"]
    if not isinstance(quote, str) or not quote.strip() or quote != quote.strip():
        fail(f"{prefix}.quote: quote must be non-empty and trimmed")
    if len(quote) > testimonial["quote_max_characters"] or "\n" in quote or "\r" in quote:
        fail(f"{prefix}.quote: quote is not a minimal single-line excerpt")
    validate_blocked_claim(quote, f"{prefix}.quote", policy)

    extensions = set(testimonial["source_capture_extensions"])
    source_path, source_width, source_height = validate_image(
        record["source_capture_ref"],
        f"{prefix}.source_capture_ref",
        evidence_root,
        extensions,
        testimonial["source_capture_min_width"],
        testimonial["source_capture_min_height"],
    )
    if "public_crop_ref" in record:
        crop_path, crop_width, crop_height = validate_image(
            record["public_crop_ref"],
            f"{prefix}.public_crop_ref",
            evidence_root,
            extensions,
            testimonial["public_crop_min_width"],
            testimonial["public_crop_min_height"],
        )
        if crop_path == source_path:
            fail(f"{prefix}.public_crop_ref: public crop must differ from the full-source capture")
        if crop_width > source_width or crop_height > source_height:
            fail(f"{prefix}.public_crop_ref: public crop cannot exceed source dimensions")


def validate_implementation_claim(
    record: Any,
    index: int,
    policy: dict[str, Any],
    evidence_root: Path,
) -> None:
    prefix = f"records[{index}]"
    if not isinstance(record, dict):
        fail(f"{prefix}: record must be an object")
    claim_policy = policy["implementation_claim"]
    required = set(claim_policy["required"])
    fields = set(record)
    missing = sorted(required - fields)
    if missing:
        fail(f"{prefix}.{missing[0]}: required field is missing")
    unknown = sorted(fields - required)
    if unknown:
        fail(f"{prefix}.{unknown[0]}: unsupported field")
    if record["kind"] != claim_policy["kind_value"]:
        fail(f"{prefix}.kind: expected implementation_claim")
    if record["status"] not in claim_policy["publishable_statuses"]:
        fail(f"{prefix}.status: only verified claims are publishable")
    validate_date(record["verified_at"], f"{prefix}.verified_at")
    text = record["text"]
    if not isinstance(text, str) or not text.strip() or text != text.strip():
        fail(f"{prefix}.text: claim must be non-empty and trimmed")
    validate_blocked_claim(text, f"{prefix}.text", policy)
    evidence_refs = record["evidence_refs"]
    if not isinstance(evidence_refs, list) or not evidence_refs:
        fail(f"{prefix}.evidence_refs: at least one evidence file is required")
    for evidence_index, reference in enumerate(evidence_refs):
        validate_evidence_file(
            reference,
            f"{prefix}.evidence_refs[{evidence_index}]",
            evidence_root,
        )


def validate_manifest(path: Path, policy: dict[str, Any], evidence_root: Path) -> int:
    manifest = read_json(path)
    if manifest.get("schema_version") != "publication-records.v1":
        fail(f"{path}: schema_version must be publication-records.v1")
    collection = manifest.get("collection")
    allowed_collections = {
        policy["collections"]["testimonials"],
        policy["collections"]["implementation_claims"],
    }
    if collection not in allowed_collections:
        fail(f"{path}: unsupported public collection")
    records = manifest.get("records")
    if not isinstance(records, list) or not records:
        fail(f"{path}: records must be a non-empty array")
    for index, record in enumerate(records):
        if collection == policy["collections"]["testimonials"]:
            validate_record(record, index, policy, evidence_root)
        else:
            validate_implementation_claim(record, index, policy, evidence_root)
    return len(records)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifests", nargs="+", type=Path)
    parser.add_argument("--evidence-root", required=True, type=Path)
    args = parser.parse_args()

    try:
        policy = load_policy()
        count = sum(validate_manifest(path, policy, args.evidence_root) for path in args.manifests)
    except (KeyError, TypeError, ValueError) as exc:
        print(f"publication gate: FAIL: {exc}", file=sys.stderr)
        return 1
    print(f"publication gate: ok ({count} verified testimonial record(s))")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
