#!/usr/bin/env bash
# Phase 64.1.1 / 64.1.3: archive-aware Plans.md grep helper (shared library)
#
# Plans.md または .claude/memory/archive/Plans-*.md (archive 群) の
# いずれかに pattern が一致すれば成功とする。
# Plans.md の archive 操作 (古い Phase を別ファイルへ切り出す cleanup) との
# 整合性のため、Phase 51-58 系の永続要求 grep をこの helper 経由に置換する。
# 意図 = 「記録が現存することを検証」は維持し、検索範囲だけを拡張 (= test 改ざんではない)。
# 承認: .claude/rules/test-quality.md 例外フォーマットでユーザー明示承認済み (2026-05-08)。
#
# 使用方法:
#   source "${ROOT_DIR}/tests/lib/grep_plans_or_archive.sh"
#   grep_plans_or_archive 'PATTERN' || { echo "..."; exit 1; }
#
# 必須環境変数:
#   ROOT_DIR — repo root の絶対パス。呼び出し元で先に export または set されていること。
#
# テスト用 override:
#   GPOA_PLANS_FILE     — Plans.md パスを上書き (デフォルト: ${ROOT_DIR}/Plans.md)
#   GPOA_ARCHIVE_DIR    — archive ディレクトリパスを上書き (デフォルト: ${ROOT_DIR}/.claude/memory/archive)
#   tests/test-grep-plans-or-archive.sh が 4 状態 (Plans only / archive only / both / miss) を検証する。

grep_plans_or_archive() {
    local pattern="$1"
    local plans="${GPOA_PLANS_FILE:-${ROOT_DIR}/Plans.md}"
    local archive_dir="${GPOA_ARCHIVE_DIR:-${ROOT_DIR}/.claude/memory/archive}"

    if [ -f "${plans}" ] && grep -q -- "${pattern}" "${plans}" 2>/dev/null; then
        return 0
    fi

    # Also check archive/Plans.md (moved here during claude-first fork cleanup)
    local archive_plans="${ROOT_DIR}/archive/Plans.md"
    if [ -f "${archive_plans}" ] && grep -q -- "${pattern}" "${archive_plans}" 2>/dev/null; then
        return 0
    fi

    if [ -d "${archive_dir}" ]; then
        for archive_file in "${archive_dir}"/Plans-*.md; do
            [ -f "${archive_file}" ] || continue
            if grep -q -- "${pattern}" "${archive_file}" 2>/dev/null; then
                return 0
            fi
        done
    fi

    return 1
}
