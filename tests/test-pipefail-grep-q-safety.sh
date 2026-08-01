#!/bin/bash
# tests/test-pipefail-grep-q-safety.sh
# Phase 129.1 - pipefail 下で結果が反転する `producer | grep -q` 構文の検出
#
# 何を検出するか:
#   `printf '%s' "$x" | grep -q P` のように、producer の出力をパイプで
#   `grep -q` に渡す書き方。`grep -q` は最初の一致で終了してパイプを閉じるため、
#   分割書き込み中の producer が EPIPE で失敗する。`set -o pipefail` はその失敗を
#   パイプライン全体の結果へ昇格させるので、探す文字列が実在するのに「無い」と
#   判定される。一致が入力の前方にあるほど再現する。
#
#   実測 (PR #285, skills/harness-accept/SKILL.md frontmatter 2019 バイト, 200 回):
#     2 行目の項目 200/200 誤判定 / 3 行目の項目 200/200 誤判定 / 8 行目の項目 0/200
#
# 正しい書き方:
#   `grep -q P <<<"$x"`        (変数が producer の場合。パイプが無いので EPIPE が起きない)
#   `grep -q P file`           (ファイルが producer の場合。cat が不要)
#
# 検出の限界 (静的走査であること):
#   - 変数経由で組み立てたコマンド文字列は対象外
#   - producer が関数呼び出しやコマンド置換の場合も対象外 (EPIPE 自体は起きうるが、
#     機械的な変換先が一意に決まらないため検出対象から外す)
#
# Usage: bash tests/test-pipefail-grep-q-safety.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SELF_REL="tests/$(basename "${BASH_SOURCE[0]}")"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); echo "✗ $1" >&2; }

# ---- 走査対象 ----
# pipefail が有効なシェルスクリプトだけを対象にする。pipefail が無ければ
# grep が一致している限りパイプライン全体は成功するため実害がない。
# macOS の /bin/bash は 3.2 のため `mapfile` (bash 4+) は使えない。
TARGET_FILES=()
while IFS= read -r _f; do
  TARGET_FILES+=("$_f")
done < <(
  find tests scripts hooks -type f -name '*.sh' 2>/dev/null \
    | grep -v '/node_modules/' \
    | grep -v "^${SELF_REL}$" \
    | sort
)

scan_file() {
  # $1: file
  # pipefail 無効なら対象外
  grep -qE '^[[:space:]]*set[[:space:]]+-[a-zA-Z]*o[[:space:]]+pipefail|^[[:space:]]*set[[:space:]]+-o[[:space:]]+pipefail' "$1" || return 0

  # producer (printf / echo / cat) の出力を grep -q 系へパイプしている行。
  # パイプ記号が引用符の外にあるものだけを対象にする。引用符の中の `| grep -q` は
  # 説明文やメッセージの一部であって実行されないため。
  # 除外するもの:
  #   - コメント行 (行頭が #)。説明文中に構文を書けるようにするため
  #   - `|| true` / `|| :` で終わる行。pipefail が結果を昇格させないため実害がない
  perl -e '
    # 物理行を論理行へ畳む。行末の継続文字 `\` を跨ぐパイプラインを見落とさないため。
    my @logical;
    my ($buf, $start) = ("", 0);
    while (my $l = <>) {
      chomp $l;
      $start = $. unless length $buf;
      if ($l =~ s/\\$//) { $buf .= $l; next; }
      push @logical, [$start, $buf . $l];
      $buf = "";
    }
    push @logical, [$start, $buf] if length $buf;

    for my $rec (@logical) {
      my ($lineno, $line) = @$rec;
      next if $line =~ /^\s*#/;
      next if $line =~ /\|\|\s*(?:true|:)\s*$/;

      # 引用符の外にあるパイプ位置を集める
      my ($q, $i, @pipes) = ("", 0);
      while ($i < length $line) {
        my $c = substr($line, $i, 1);
        if ($q) {
          # 二重引用符の中では `\` がエスケープとして働く。単一引用符の中では働かない。
          if ($q eq q{"} && $c eq "\\") { $i += 2; next; }
          $q = "" if $c eq $q;
          $i++; next;
        }
        if ($c eq q{"} || $c eq q{'"'"'}) { $q = $c; $i++; next; }
        if ($c eq "\\") { $i += 2; next; }
        # `||` は or 演算子なのでパイプとして数えない
        if ($c eq "|") {
          if (substr($line, $i, 2) eq "||") { $i += 2; next; }
          push @pipes, $i;
        }
        $i++;
      }
      for my $p (@pipes) {
        my $before = substr($line, 0, $p);
        my $after  = substr($line, $p + 1);
        next unless $before =~ /(?:^|[^\w])(?:printf|echo|cat)\s/;
        next unless $after  =~ /^\s*grep\s+(?:-[a-zA-Z]+\s+)*-[a-zA-Z]*q/;
        print "$lineno:$line\n";
        last;
      }
    }
  ' "$1" 2>/dev/null | sed "s|^|$1:|"
}

FINDINGS=""
for f in "${TARGET_FILES[@]}"; do
  hits="$(scan_file "$f" || true)"
  [[ -n "$hits" ]] && FINDINGS+="$hits"$'\n'
done
FINDINGS="${FINDINGS%$'\n'}"

# ---- 1. 検出結果 ----

if [[ -z "$FINDINGS" ]]; then
  pass "pipefail 下の 'producer | grep -q' は検出されませんでした"
else
  count="$(printf '%s\n' "$FINDINGS" | grep -c . || true)"
  fail "pipefail 下の 'producer | grep -q' を ${count} 箇所検出しました (herestring '<<<' か grep のファイル引数へ書き換えてください)"
  printf '%s\n' "$FINDINGS" | sed 's/^/    /'
fi

# ---- 2. 除外条件が効いているか (fixture で固定) ----

FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pipefail-grep-q.XXXXXX")"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

# (a) pipefail 無し → 検出しない
cat > "$FIXTURE_DIR/no-pipefail.sh" <<'FIXEOF'
#!/bin/bash
set -eu
printf '%s' "$x" | grep -q "needle"
FIXEOF

# (b) pipefail 有り + 該当構文 → 検出する
cat > "$FIXTURE_DIR/hit.sh" <<'FIXEOF'
#!/bin/bash
set -euo pipefail
printf '%s' "$x" | grep -q "needle"
FIXEOF

# (c) pipefail 有り + `|| true` で終わる → 検出しない
cat > "$FIXTURE_DIR/or-true.sh" <<'FIXEOF'
#!/bin/bash
set -euo pipefail
printf '%s' "$x" | grep -q "needle" || true
FIXEOF

# (d) pipefail 有り + herestring (正しい書き方) → 検出しない
cat > "$FIXTURE_DIR/herestring.sh" <<'FIXEOF'
#!/bin/bash
set -euo pipefail
grep -q "needle" <<<"$x"
FIXEOF

# (e) pipefail 有り + grep -q 以外 (-c など) → 検出しない (早期終了しない)
cat > "$FIXTURE_DIR/grep-c.sh" <<'FIXEOF'
#!/bin/bash
set -euo pipefail
printf '%s' "$x" | grep -c "needle"
FIXEOF

# (f) pipefail 有り + コメント行に書かれた構文 → 検出しない
cat > "$FIXTURE_DIR/comment.sh" <<'FIXEOF'
#!/bin/bash
set -euo pipefail
# printf '%s' "$x" | grep -q "needle" は使わないこと
grep -q "needle" <<<"$x"
FIXEOF

# (g) pipefail 有り + 引用符の中に書かれた構文 → 検出しない (実行されない文字列)
cat > "$FIXTURE_DIR/quoted.sh" <<'FIXEOF'
#!/bin/bash
set -euo pipefail
echo "producer | grep -q は使わないこと"
grep -q "needle" <<<"$x"
FIXEOF

# (h) pipefail 有り + 行末の継続文字を跨ぐパイプライン → 検出する
cat > "$FIXTURE_DIR/continuation.sh" <<'FIXEOF'
#!/bin/bash
set -euo pipefail
printf '%s' "$x" \
  | grep -q "needle"
FIXEOF

# (i) pipefail 有り + 二重引用符の中のエスケープされた引用符 → 検出しない
# `\"` を閉じ引用符と誤解すると、後続の `| grep -q` が引用符の外に見えてしまう
cat > "$FIXTURE_DIR/escaped-quote.sh" <<'FIXEOF'
#!/bin/bash
set -euo pipefail
echo "he said \"use x | grep -q y\" today"
grep -q "needle" <<<"$x"
FIXEOF

expect_scan() {
  local file="$1" expected="$2" label="$3"
  local got
  got="$(scan_file "$file" || true)"
  if [[ "$expected" == "hit" && -n "$got" ]]; then
    pass "fixture: $label は検出される"
  elif [[ "$expected" == "miss" && -z "$got" ]]; then
    pass "fixture: $label は検出されない"
  else
    fail "fixture: $label の判定が期待と異なる (expected=$expected, got='${got}')"
  fi
}

expect_scan "$FIXTURE_DIR/no-pipefail.sh" miss "pipefail 無し"
expect_scan "$FIXTURE_DIR/hit.sh"         hit  "pipefail + printf | grep -q"
expect_scan "$FIXTURE_DIR/or-true.sh"     miss "|| true で終わる行"
expect_scan "$FIXTURE_DIR/herestring.sh"  miss "herestring (正しい書き方)"
expect_scan "$FIXTURE_DIR/grep-c.sh"      miss "grep -c (早期終了しない)"
expect_scan "$FIXTURE_DIR/comment.sh"     miss "コメント行に書かれた構文"
expect_scan "$FIXTURE_DIR/quoted.sh"      miss "引用符の中に書かれた構文"
expect_scan "$FIXTURE_DIR/continuation.sh"   hit  "行末の継続文字を跨ぐパイプライン"
expect_scan "$FIXTURE_DIR/escaped-quote.sh"  miss "二重引用符内のエスケープされた引用符"

# ---- 3. サマリ ----

echo
echo "============================================"
echo "PASS=$PASS FAIL=$FAIL"
if [[ "$FAIL" -eq 0 ]]; then
  echo "All assertions passed."
  exit 0
fi
exit 1
