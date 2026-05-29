#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/check-cch-branch-protection-policy.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  if ! grep -q "$pattern" "$file"; then
    fail "expected pattern '$pattern' in $file"
  fi
}

[ -x "$SCRIPT" ] || fail "missing executable policy script"

cat > "$TMP_DIR/good.json" <<'EOF'
{
  "required_pull_request_reviews": null,
  "required_status_checks": {
    "strict": true,
    "contexts": ["actionlint", "validate", "test-go"]
  },
  "allow_force_pushes": {
    "enabled": false
  },
  "allow_deletions": {
    "enabled": false
  }
}
EOF

"$SCRIPT" --json "$TMP_DIR/good.json" > "$TMP_DIR/good.out"
assert_contains "$TMP_DIR/good.out" "CCH branch protection policy: ok"

cat > "$TMP_DIR/good-checks.json" <<'EOF'
{
  "required_pull_request_reviews": null,
  "required_status_checks": {
    "strict": true,
    "contexts": [],
    "checks": [
      {"context": "actionlint", "app_id": 15368},
      {"context": "validate", "app_id": 15368},
      {"context": "test-go", "app_id": 15368}
    ]
  },
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF

"$SCRIPT" --json "$TMP_DIR/good-checks.json" > "$TMP_DIR/good-checks.out"
assert_contains "$TMP_DIR/good-checks.out" "CCH branch protection policy: ok"

cat > "$TMP_DIR/review-required.json" <<'EOF'
{
  "required_pull_request_reviews": {
    "required_approving_review_count": 1
  },
  "required_status_checks": {
    "strict": true,
    "contexts": ["actionlint", "validate", "test-go"]
  },
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF

if "$SCRIPT" --json "$TMP_DIR/review-required.json" > "$TMP_DIR/review-required.out" 2>&1; then
  fail "policy script should reject drifted review settings"
fi
assert_contains "$TMP_DIR/review-required.out" "required_pull_request_reviews must match the CCH review gate contract"

cat > "$TMP_DIR/missing-check.json" <<'EOF'
{
  "required_pull_request_reviews": null,
  "required_status_checks": {
    "strict": true,
    "contexts": ["actionlint", "validate"]
  },
  "allow_force_pushes": {
    "enabled": false
  },
  "allow_deletions": {
    "enabled": false
  }
}
EOF

if "$SCRIPT" --json "$TMP_DIR/missing-check.json" > "$TMP_DIR/missing-check.out" 2>&1; then
  fail "policy script should reject missing required status checks"
fi
assert_contains "$TMP_DIR/missing-check.out" "required status checks must include test-go"

echo "test-cch-branch-protection-policy: ok"
