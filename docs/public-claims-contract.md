# Public Claims Contract

Status: active

This contract applies to the public README, landing pages, release copy, social
copy, screenshots, testimonials, and independent coverage lists. Public text
may describe only behavior verified against the current implementation. Missing
or stale evidence is `unavailable`, not proof that a claim is true.

## Publication Rules

1. Implementation claims require a verification date and current evidence.
   Missing evidence must fail closed.
2. Host tier rows derive at build time from `hosts/registry.json`; manifests
   cannot copy or override them.
3. Private archives may retain `verified`, `rejected`, and `unavailable`
   testimonial records. Public builds accept only `verified` records whose
   `access_status` is `direct_public`.
4. `source_capture_ref` is a required retained full-source `.png`, `.jpg`, or
   `.webp` under the evidence root. `public_crop_ref` is optional and is the only
   image intended for public display.
5. Publication basis is controlled: `direct_public_source` or
   `minimal_attributed_quote`. Quotes must be a single trimmed excerpt of at
   most 280 Unicode characters.
6. Independent coverage is stored and rendered separately from testimonials;
   an article about the project is not a user endorsement.
7. Login-required or unavailable sources, invalid or indirect URLs, missing or
   invalid captures, oversized quotes, and quantified or absolute speed/safety
   claims in English or Japanese fail closed.
8. Full-source captures stay in the private evidence archive. A public crop,
   when present, contains only the minimum source area needed for attribution
   and the quotation; unrelated replies, people, engagement counts, customer
   data, and authentication material are excluded.

The current executable gate is
`scripts/validate-publication-records.py --evidence-root <dir> <records.json>`.
It accepts testimonial or implementation-claim manifests; any ineligible
record makes the whole build input exit nonzero. Independent coverage never
enters either collection.

## Machine-Readable Policy

<!-- public-claims-policy:start -->
```json
{
  "schema_version": "publication-policy.v1",
  "record_schema_version": "publication-records.v1",
  "validator": "scripts/validate-publication-records.py",
  "host_tier_source": "hosts/registry.json",
  "host_tier_overrides": "forbidden",
  "collections": {
    "testimonials": "testimonials",
    "independent_coverage": "independent_coverage",
    "implementation_claims": "implementation_claims"
  },
  "direct_source_url": {
    "schemes": ["https"],
    "blocked_hosts": ["bit.ly", "t.co", "tinyurl.com", "google.com", "bing.com"],
    "blocked_path_segments": ["login", "signin", "auth", "search"]
  },
  "testimonial": {
    "required": [
      "kind",
      "source_url",
      "posted_at",
      "language",
      "quote",
      "retrieved_at",
      "publication_basis",
      "access_status",
      "source_capture_ref",
      "status"
    ],
    "optional": ["public_crop_ref"],
    "status_values": ["verified", "rejected", "unavailable"],
    "publishable_statuses": ["verified"],
    "access_status_values": ["direct_public", "login_required", "unavailable"],
    "publishable_access_statuses": ["direct_public"],
    "publication_basis_values": ["direct_public_source", "minimal_attributed_quote"],
    "source_capture_extensions": [".png", ".jpg", ".webp"],
    "source_capture_min_width": 800,
    "source_capture_min_height": 600,
    "public_crop_min_width": 240,
    "public_crop_min_height": 100,
    "quote_max_characters": 280
  },
  "implementation_claim": {
    "required": ["kind", "text", "verified_at", "evidence_refs", "status"],
    "kind_value": "implementation_claim",
    "status_values": ["verified", "rejected", "unavailable"],
    "publishable_statuses": ["verified"]
  },
  "blocked_claim_patterns": [
    "\\d+(?:\\.\\d+)?\\s*(?:[xX](?!\\w)|×)",
    "\\d+(?:\\.\\d+)?\\s*[%％]\\s*(?:speed\\s*up|speedup|faster|safer|more\\s+secure|高速化?|速度向上|安全性向上)",
    "\\d+(?:\\.\\d+)?\\s*倍.{0,12}(?:高速化?|速く|速度|効率|生産性|安全)",
    "(?:absolutely\\s+safe|100\\s*[%％]\\s*(?:secure|safe)|completely\\s+safe|fully\\s+secure|guaranteed\\s+safe|zero\\s+risk|never\\s+fails|fail[- ]?proof|絶対(?:に)?安全|完全(?:に)?安全|失敗しない|必ず成功|リスクゼロ)"
  ]
}
```
<!-- public-claims-policy:end -->

## Record Shape

Public testimonial input is actual JSON:

```json
{
  "schema_version": "publication-records.v1",
  "collection": "testimonials",
  "records": []
}
```

Every record must contain only the required testimonial fields plus optional
`public_crop_ref`. The validator resolves capture paths under the explicit
`--evidence-root`, rejects traversal and missing files, and checks image magic
instead of trusting a filename extension.

Retrieval proves only that the cited source was directly observable on that
date. It does not validate unrelated technical claims inside the source.
Rejected and unavailable records remain private audit data. Independent
articles link to their original source under an independent coverage heading,
never inside testimonial build input.
