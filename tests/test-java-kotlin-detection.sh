#!/usr/bin/env bash
# Regression coverage for Java/Kotlin project and test-framework detection.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DETECTOR="${ROOT_DIR}/scripts/detect-test-framework.sh"
TMP_DIR="$(mktemp -d)"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

pass() {
  echo "ok - $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "not ok - $1" >&2
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

assert_detection() {
  local label="$1"
  local fixture="$2"
  local framework="$3"
  local command="$4"
  local language="$5"
  local test_pattern="$6"
  local detected_via="$7"
  local output

  output="$(bash "$DETECTOR" --project-root "$fixture")"
  if DETECTION_JSON="$output" python3 - "$framework" "$command" "$language" "$test_pattern" "$detected_via" <<'PY'
import json
import os
import sys

keys = ("framework", "command", "language", "test_pattern", "detected_via")
expected = dict(zip(keys, sys.argv[1:]))
actual = json.loads(os.environ["DETECTION_JSON"])
raise SystemExit(0 if all(actual.get(key) == value for key, value in expected.items()) else 1)
PY
  then
    pass "$label"
  else
    fail "$label (got: $output)"
  fi
}

mkdir -p "$TMP_DIR/maven-java"
touch "$TMP_DIR/maven-java/pom.xml"
assert_detection \
  "Maven Java uses the system Maven test command" \
  "$TMP_DIR/maven-java" "maven" "mvn test" "java" "**/*{Test,Tests}.java" "pom.xml"

mkdir -p "$TMP_DIR/maven-wrapper"
touch "$TMP_DIR/maven-wrapper/pom.xml" "$TMP_DIR/maven-wrapper/mvnw"
assert_detection \
  "Maven wrapper takes precedence over system Maven" \
  "$TMP_DIR/maven-wrapper" "maven" "./mvnw test" "java" "**/*{Test,Tests}.java" "pom.xml"

mkdir -p "$TMP_DIR/maven-kotlin/src/main/kotlin"
touch "$TMP_DIR/maven-kotlin/pom.xml" "$TMP_DIR/maven-kotlin/src/main/kotlin/Application.kt"
assert_detection \
  "Maven Kotlin uses Kotlin Test and Tests naming" \
  "$TMP_DIR/maven-kotlin" "maven" "mvn test" "kotlin" "**/*{Test,Tests}.kt" "pom.xml"

mkdir -p "$TMP_DIR/gradle-java"
touch "$TMP_DIR/gradle-java/build.gradle"
assert_detection \
  "Gradle Java uses the system Gradle test command" \
  "$TMP_DIR/gradle-java" "gradle" "gradle test" "java" "**/*{Test,Tests}.java" "build.gradle"

mkdir -p "$TMP_DIR/gradle-kotlin/src/main/kotlin"
touch "$TMP_DIR/gradle-kotlin/build.gradle.kts" "$TMP_DIR/gradle-kotlin/gradlew" \
  "$TMP_DIR/gradle-kotlin/src/main/kotlin/Application.kt"
assert_detection \
  "Gradle wrapper and Kotlin Tests naming are selected together" \
  "$TMP_DIR/gradle-kotlin" "gradle" "./gradlew test" "kotlin" "**/*{Test,Tests}.kt" "build.gradle.kts"

mkdir -p "$TMP_DIR/hybrid-maven"
touch "$TMP_DIR/hybrid-maven/pom.xml" "$TMP_DIR/hybrid-maven/vitest.config.ts"
printf '%s\n' '{"scripts":{"test":"vitest"}}' > "$TMP_DIR/hybrid-maven/package.json"
assert_detection \
  "Maven takes precedence over Node markers in a hybrid repository" \
  "$TMP_DIR/hybrid-maven" "maven" "mvn test" "java" "**/*{Test,Tests}.java" "pom.xml"

mkdir -p "$TMP_DIR/hybrid-gradle"
touch "$TMP_DIR/hybrid-gradle/build.gradle.kts"
printf '%s\n' '{"scripts":{"test":"jest"}}' > "$TMP_DIR/hybrid-gradle/package.json"
assert_detection \
  "Gradle takes precedence over Node package metadata" \
  "$TMP_DIR/hybrid-gradle" "gradle" "gradle test" "java" "**/*{Test,Tests}.java" "build.gradle.kts"

mkdir -p "$TMP_DIR/mixed-jvm/src/main/java" "$TMP_DIR/mixed-jvm/src/main/kotlin"
touch "$TMP_DIR/mixed-jvm/pom.xml" "$TMP_DIR/mixed-jvm/src/main/java/App.java" \
  "$TMP_DIR/mixed-jvm/src/main/kotlin/App.kt"
assert_detection \
  "Mixed JVM detection deterministically prefers Kotlin test naming" \
  "$TMP_DIR/mixed-jvm" "maven" "mvn test" "kotlin" "**/*{Test,Tests}.kt" "pom.xml"

if ROOT_DIR="$ROOT_DIR" python3 <<'PY'
import os
import re

text = open(os.path.join(os.environ["ROOT_DIR"], ".claude/rules/tdd-paths.yaml"), encoding="utf-8").read()

def language_block(name: str) -> str:
    match = re.search(rf"^  {name}:\n(?P<body>(?:^(?:    |\s*$).*\n?)*)", text, re.MULTILINE)
    if not match:
        raise SystemExit(f"missing {name} language block")
    return match.group("body")

java = language_block("java")
kotlin = language_block("kotlin")
for needle in (
    '"src/main/java/**/*.java"',
    '"src/test/java/**/*Test.java"',
    '"src/test/java/**/*Tests.java"',
    'mvnw: "./mvnw test"',
    'gradlew: "./gradlew test"',
    'build.gradle: "gradle test"',
):
    if needle not in java:
        raise SystemExit(f"java block missing {needle}")
for needle in (
    '"src/main/kotlin/**/*.kt"',
    '"src/test/kotlin/**/*Test.kt"',
    '"src/test/kotlin/**/*Tests.kt"',
    'mvnw: "./mvnw test"',
    'gradlew: "./gradlew test"',
    'build.gradle.kts: "gradle test"',
):
    if needle not in kotlin:
        raise SystemExit(f"kotlin block missing {needle}")
PY
then
  pass "TDD path rules preserve Java and Kotlin naming plus build-tool commands"
else
  fail "TDD path rules preserve Java and Kotlin naming plus build-tool commands"
fi

extract_toml_allow() {
  sed -n '/^\[safety.permissions\]$/,/^deny = \[/p' "$1" \
    | sed -E -n 's/^[[:space:]]*"([^"]+)",?[[:space:]]*$/\1/p'
}

extract_json_allow() {
  jq -r '.permissions.allow[]' "$1"
}

harness_allow="$(extract_toml_allow "$ROOT_DIR/harness.toml")"
plugin_allow="$(extract_json_allow "$ROOT_DIR/.claude-plugin/settings.json")"
template_allow="$(extract_json_allow "$ROOT_DIR/templates/claude/settings.security.json.template")"
jvm_permissions="$(
  printf '%s\n%s\n%s\n' "$harness_allow" "$plugin_allow" "$template_allow" \
    | grep -E '^Bash\((\./)?(mvn|mvnw|gradle|gradlew)([ :])' \
    || true
)"

if [ -n "$jvm_permissions" ]; then
  fail "JVM commands must require user approval (found: $(printf '%s' "$jvm_permissions" | tr '\n' ' '))"
elif [ "$harness_allow" != "$plugin_allow" ] || [ "$harness_allow" != "$template_allow" ]; then
  fail "harness.toml, generated plugin settings, and security template allowlists must match"
else
  pass "JVM commands require approval and all permission surfaces remain in parity"
fi

if [ "$FAIL_COUNT" -ne 0 ]; then
  echo "failed $FAIL_COUNT checks; passed $PASS_COUNT checks" >&2
  exit 1
fi

echo "passed $PASS_COUNT checks"
