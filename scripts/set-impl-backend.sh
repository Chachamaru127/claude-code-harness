#!/usr/bin/env bash
# set-impl-backend.sh
# 実装バックエンド（claude|codex|cursor）を env.local に永続化する（冪等）。
#
# 使い方:
#   bash scripts/set-impl-backend.sh <claude|codex|cursor>            # プロジェクトスコープ（env.local）
#   bash scripts/set-impl-backend.sh --user <claude|codex|cursor>     # ユーザースコープ（全プロジェクト共通）
#   bash scripts/set-impl-backend.sh --show                           # 現在解決されるバックエンドを表示
#   bash scripts/set-impl-backend.sh --unset [--user]                 # 設定を削除（既定: プロジェクト）
#
# 効果:
#   - 対象ファイルに `export HARNESS_IMPL_BACKEND=<value>` を書き込む（冪等）
#     - 既定（プロジェクト）: ${REPO_ROOT}/env.local
#     - --user 指定時（ユーザー）: ${HOME}/.config/claude-harness/impl-backend.env
#   - すでに同じ値なら何もしない。別の値なら in-place 置換（重複行を残さない）。ファイルが無ければ新規作成
#
# スコープと優先順位:
#   - プロジェクト env.local はユーザースコープより優先される（resolve-impl-backend.sh の precedence）
#   - ユーザースコープは全プロジェクト共通の既定値として働く
#
# 注意:
#   - env.local / ユーザーファイルはリポジトリにコミットしない
#
# テスト用オーバーライド:
#   - HARNESS_ENV_LOCAL: env.local（プロジェクト）のパス上書き
#   - HARNESS_USER_BACKEND_FILE: ユーザースコープファイルのパス上書き

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "$0")/.." && pwd))"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_LOCAL="${HARNESS_ENV_LOCAL:-${REPO_ROOT}/env.local}"
USER_FILE="${HARNESS_USER_BACKEND_FILE:-${HOME}/.config/claude-harness/impl-backend.env}"
KEY="HARNESS_IMPL_BACKEND"

usage() {
  echo "使い方: $0 <claude|codex|cursor> [--user] | --show | --unset [--user]" >&2
}

# 妥当な値かどうか判定する
is_valid_backend() {
  case "$1" in
    claude | codex | cursor) return 0 ;;
    *) return 1 ;;
  esac
}

# 引数を解析する: --user スコープフラグ + アクション（value | --show | --unset）
use_user=0
action=""
VALUE=""
for arg in "$@"; do
  case "$arg" in
    --user) use_user=1 ;;
    --show) action="show" ;;
    --unset) action="unset" ;;
    claude | codex | cursor) action="set"; VALUE="$arg" ;;
    *)
      echo "[set-impl-backend] 不明な引数: ${arg}" >&2
      usage
      exit 2
      ;;
  esac
done

if [ -z "${action}" ]; then
  usage
  exit 2
fi

# 対象ファイルをスコープから決める
if [ "${use_user}" = "1" ]; then
  TARGET="${USER_FILE}"
  SCOPE="ユーザー"
else
  TARGET="${ENV_LOCAL}"
  SCOPE="プロジェクト"
fi

case "${action}" in
  show)
    # 現在解決されるバックエンドを resolve-impl-backend.sh に委譲して表示する
    exec bash "${SCRIPT_DIR}/resolve-impl-backend.sh"
    ;;
  unset)
    if [ -f "${TARGET}" ] && grep -qE "^export ${KEY}=" "${TARGET}" 2>/dev/null; then
      tmp_file="$(mktemp "${TARGET}.XXXXXX")"
      grep -vE "^export ${KEY}=" "${TARGET}" > "${tmp_file}" || true
      mv "${tmp_file}" "${TARGET}"
      echo "[set-impl-backend] ${KEY} を ${TARGET}（${SCOPE}スコープ）から削除しました。"
    else
      echo "[set-impl-backend] ${KEY} は ${TARGET}（${SCOPE}スコープ）に設定されていません（変更なし）。"
    fi
    exit 0
    ;;
esac

# action=set: 対象ファイルの親ディレクトリを用意する（ユーザーファイル用）
mkdir -p "$(dirname "${TARGET}")"
if ! is_valid_backend "${VALUE}"; then
  echo "[set-impl-backend] 不正な値: '${VALUE}'（claude|codex|cursor のいずれかを指定）" >&2
  exit 2
fi

# Use `export KEY=VALUE` so that `source env.local` propagates the variable
# to subprocesses. Without `export`, `source env.local` only sets a
# shell-local variable and spawned processes never see it.
ENTRY="export ${KEY}=${VALUE}"

# すでに同じ値の設定行が存在するか確認（冪等）
if grep -qE "^export ${KEY}=${VALUE}$" "${TARGET}" 2>/dev/null; then
  echo "[set-impl-backend] ${ENTRY} はすでに ${TARGET}（${SCOPE}スコープ）に設定されています（変更なし）。"
  exit 0
fi

# 既存の設定行（別の値）があれば in-place で置換し、重複を残さない
if grep -qE "^export ${KEY}=" "${TARGET}" 2>/dev/null; then
  # 一時ファイルは対象ファイルと同じディレクトリに作り、mv を atomic に保つ
  tmp_file="$(mktemp "${TARGET}.XXXXXX")"
  # 既存の設定行を新しい値に置換する。最初の 1 行だけ ENTRY に差し替え、残りの設定行は除去する。
  awk -v entry="${ENTRY}" -v key="export ${KEY}=" '
    index($0, key) == 1 {
      if (!replaced) { print entry; replaced = 1 }
      next
    }
    { print }
  ' "${TARGET}" > "${tmp_file}"
  mv "${tmp_file}" "${TARGET}"
  echo "[set-impl-backend] ${TARGET}（${SCOPE}スコープ）の ${KEY} を ${VALUE} に更新しました。"
  exit 0
fi

# 対象ファイルに追記（ファイルが存在しない場合は新規作成）
{
  echo ""
  echo "# 実装バックエンドの永続選択（claude|codex|cursor）"
  echo "${ENTRY}"
} >> "${TARGET}"

echo "[set-impl-backend] ${ENTRY} を ${TARGET}（${SCOPE}スコープ）に追記しました。"
