#!/usr/bin/env bash
# codex-companion.sh — Proxy to official codex-plugin-cc companion
#
# 公式プラグイン openai/codex-plugin-cc の codex-companion.mjs を
# 動的に発見して呼び出す。Harness のスキル・エージェントは
# raw `codex exec` ではなく、このプロキシ経由で Codex を呼び出す。
#
# Usage:
#   bash scripts/codex-companion.sh task --write "Fix the bug"
#   bash scripts/codex-companion.sh review --base HEAD~3
#   bash scripts/codex-companion.sh setup --json
#   bash scripts/codex-companion.sh status
#   bash scripts/codex-companion.sh result <job-id>
#   bash scripts/codex-companion.sh cancel <job-id>
#
# Subcommands: task, review, adversarial-review, setup, status, result, cancel
#
# Effort 伝播:
#   task サブコマンド実行時に calculate-effort.sh で effort を計算し、
#   --effort フラグで companion に渡す。calculate-effort.sh がない場合は
#   環境変数 CODEX_EFFORT（未設定時: medium）にフォールバックする。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRIMARY_ENV_GUARD="${SCRIPT_DIR}/codex-primary-environment-guard.sh"
MODEL_ROUTER="${SCRIPT_DIR}/model-routing.sh"
EXECUTION_ROOT="${HARNESS_CODEX_EXECUTION_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

is_valid_codex_effort() {
  case "${1:-}" in
    none|minimal|low|medium|high|xhigh) return 0 ;;
    *) return 1 ;;
  esac
}

resolve_codex_model_for_task() {
  if [ "${HARNESS_DISABLE_MODEL_ROUTING:-0}" = "1" ]; then
    return 0
  fi
  if [ ! -x "${MODEL_ROUTER}" ]; then
    return 0
  fi
  local tier
  tier="${CODEX_MODEL_TIER:-${HARNESS_MODEL_TIER:-standard}}"
  bash "${MODEL_ROUTER}" --host codex --tier "${tier}" --field model 2>/dev/null || true
}

args_have_codex_model() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --model|-m|--model=*) return 0 ;;
    esac
    shift || true
  done
  return 1
}

extract_target_cwd() {
  shift || true
  while [ $# -gt 0 ]; do
    case "$1" in
      --cd|-C)
        printf '%s\n' "${2:-$PWD}"
        return 0
        ;;
      --cd=*|-C=*)
        printf '%s\n' "${1#*=}"
        return 0
        ;;
    esac
    shift || true
  done
  printf '%s\n' "$PWD"
}

task_has_write_intent() {
  [ "${1:-}" = "task" ] || return 1
  shift || true
  while [ $# -gt 0 ]; do
    case "$1" in
      --write|--full-auto|--dangerously-bypass-approvals-and-sandbox)
        return 0
        ;;
      --sandbox|-s)
        case "${2:-}" in
          workspace-write|danger-full-access) return 0 ;;
        esac
        shift 2
        continue
        ;;
      --sandbox=*|-s=*)
        case "${1#*=}" in
          workspace-write|danger-full-access) return 0 ;;
        esac
        ;;
    esac
    shift || true
  done
  return 1
}

guard_primary_environment_if_needed() {
  if [ ! -x "${PRIMARY_ENV_GUARD}" ]; then
    return 0
  fi
  if task_has_write_intent "$@"; then
    local target_cwd
    target_cwd="$(extract_target_cwd "$@")"
    HARNESS_CODEX_EXECUTION_ROOT="${EXECUTION_ROOT}" \
      bash "${PRIMARY_ENV_GUARD}" --mode write --target-cwd "${target_cwd}"
  fi
}

should_use_structured_task_exec() {
  [ "${1:-}" = "task" ] || return 1
  shift || true
  for arg in "$@"; do
    case "$arg" in
      --output-schema|--output-schema=*) return 0 ;;
    esac
  done
  return 1
}

run_structured_task_exec() {
  local passthrough=()
  local saw_write=0
  local saw_sandbox=0
  local saw_model=0
  local current=""

  # Codex 0.123.0+ inherits root-level shared flags for `codex exec`.
  # These exec-local sandbox defaults are kept only to encode Harness task intent:
  # `task --write` means workspace-write, and read-only remains the safe default.
  # If the caller provides --sandbox/-s/--full-auto/bypass explicitly, preserve it.
  # `--full-auto` is deprecated in current Codex guidance, so Harness must not
  # add it by default here; explicit caller intent is passed through unchanged.
  shift || true # drop "task"
  while [ $# -gt 0 ]; do
    current="$1"
    case "$current" in
      --background|--resume-last|--resume|--fresh|--prompt-file)
        echo "ERROR: structured task mode does not support ${current}" >&2
        exit 2
        ;;
      --write)
        saw_write=1
        passthrough+=(--sandbox workspace-write)
        shift
        ;;
      --sandbox|-s|--full-auto|--dangerously-bypass-approvals-and-sandbox)
        saw_sandbox=1
        passthrough+=("${current}")
        shift
        if [ "${current}" = "--sandbox" ] || [ "${current}" = "-s" ]; then
          passthrough+=("${1:-}")
          shift || true
        fi
        ;;
      --effort)
        # codex exec does not accept the companion-only --effort flag.
        # Structured task mode goes through codex exec directly, so translate
        # it into the official config override instead of silently dropping it.
        if is_valid_codex_effort "${2:-}"; then
          passthrough+=(-c "model_reasoning_effort=\"${2}\"")
        fi
        shift
        shift || true
        ;;
      --effort=*)
        local effort_value="${current#*=}"
        if is_valid_codex_effort "${effort_value}"; then
          passthrough+=(-c "model_reasoning_effort=\"${effort_value}\"")
        fi
        shift
        ;;
      *)
        case "$current" in
          --model|-m|--model=*) saw_model=1 ;;
        esac
        passthrough+=("${current}")
        shift
        if [ "${current}" = "--model" ] || [ "${current}" = "-m" ] || \
           [ "${current}" = "--output-schema" ] || \
           [ "${current}" = "-o" ] || [ "${current}" = "--output-last-message" ] || \
           [ "${current}" = "-c" ] || [ "${current}" = "--config" ] || \
           [ "${current}" = "-C" ] || [ "${current}" = "--cd" ] || \
           [ "${current}" = "--add-dir" ] || [ "${current}" = "-i" ] || \
           [ "${current}" = "--image" ] || [ "${current}" = "--color" ] || \
           [ "${current}" = "--local-provider" ]; then
          passthrough+=("${1:-}")
          shift || true
        fi
        ;;
    esac
  done

  if [ "${saw_write}" -eq 0 ] && [ "${saw_sandbox}" -eq 0 ]; then
    passthrough+=(--sandbox read-only)
  fi

  if [ "${saw_model}" -eq 0 ]; then
    local routed_model
    routed_model="$(resolve_codex_model_for_task)"
    if [ -n "${routed_model}" ]; then
      passthrough+=(--model "${routed_model}")
    fi
  fi

  exec codex exec "${passthrough[@]}"
}

build_codex_task_model_args() {
  if args_have_codex_model "$@"; then
    return 0
  fi
  local routed_model
  routed_model="$(resolve_codex_model_for_task)"
  if [ -n "${routed_model}" ]; then
    printf '%s\n' "--model" "${routed_model}"
  fi
}

# 公式プラグインの companion を検索
# Claude/Codex どちらの plugin ディレクトリでも見つかるようにし、
# cache と marketplace 配下の両方を対象にする。
PLUGIN_DIRS=()
[ -d "${HOME}/.claude/plugins" ] && PLUGIN_DIRS+=("${HOME}/.claude/plugins")
[ -d "${HOME}/.codex/plugins" ] && PLUGIN_DIRS+=("${HOME}/.codex/plugins")

COMPANION=""
if [ "${#PLUGIN_DIRS[@]}" -gt 0 ]; then
  # パスからバージョンセグメントを抽出し数値比較（macOS BSD sort 互換）
  COMPANION=$(find "${PLUGIN_DIRS[@]}" -name "codex-companion.mjs" \
    \( -path "*/openai-codex/*" -o -path "*/codex-plugin-cc/*" -o -path "*/plugins/codex/*" \) \
    2>/dev/null \
    | awk -F/ '{version="0.0.0"; for(i=1;i<=NF;i++){if($i~/^[0-9]+\.[0-9]+(\.[0-9]+)?$/){version=$i}} print version,$0}' \
    | sort -t. -k1,1n -k2,2n -k3,3n \
    | tail -1 \
    | cut -d' ' -f2-)
fi

if [ -z "$COMPANION" ]; then
  echo "ERROR: codex-plugin-cc が見つかりません。" >&2
  echo "インストール: plugin marketplace add openai/codex-plugin-cc" >&2
  echo "または: /codex:setup を実行してください" >&2
  exit 1
fi

# ---- Effort 伝播（task サブコマンドのみ）----
# task サブコマンドの場合、タスク説明から effort を計算して --effort フラグで渡す。
# calculate-effort.sh が存在しない場合は CODEX_EFFORT 環境変数（デフォルト: medium）を使う。
SUBCOMMAND="${1:-}"
guard_primary_environment_if_needed "$@"
if should_use_structured_task_exec "$@"; then
  STRUCTURED_TASK_EXEC=1
else
  STRUCTURED_TASK_EXEC=0
fi
if [ "$SUBCOMMAND" = "task" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  EFFORT_SCRIPT="${SCRIPT_DIR}/calculate-effort.sh"

  # 既に --effort フラグが指定されている場合、または --resume-last の場合はスキップ
  # --resume-last は継続プロンプト（「続きをやって」等）が入るため effort 計算が不正確になる
  EFFORT_ALREADY_SET=0
  for arg in "$@"; do
    if [ "$arg" = "--effort" ] || echo "$arg" | grep -qE '^--effort='; then
      EFFORT_ALREADY_SET=1
      break
    fi
    if [ "$arg" = "--resume-last" ] || [ "$arg" = "--resume" ]; then
      EFFORT_ALREADY_SET=1
      break
    fi
  done

  if [ "$EFFORT_ALREADY_SET" -eq 0 ]; then
    # タスク説明を引数から抽出（最後の非フラグ引数）
    # Boolean フラグ（値を取らない）: --write, --resume-last, --json, --full-auto, --ephemeral, --oss, --skip-git-repo-check
    # 値付きフラグ（次の引数を消費）: --base, --effort, --model, -m, -i, --image, -c, --config, -C, --cd, --add-dir, --output-schema, -o, --output-last-message, --color, --enable, --disable, --local-provider
    # 未知の --* フラグ → 安全側で値付き（次引数を消費）として扱う
    TASK_DESC=""
    EXPECT_VALUE=""
    for arg in "${@:2}"; do
      if [ -n "$EXPECT_VALUE" ]; then
        # 前のフラグの値なのでスキップ
        EXPECT_VALUE=""
        continue
      fi
      case "$arg" in
        --write|--resume-last|--json|--full-auto|--ephemeral|--oss|--skip-git-repo-check|--dangerously-bypass-approvals-and-sandbox|--background|--resume|--fresh)
          # 値を取らない boolean フラグ → スキップするだけ
          ;;
        --base|--effort|--model|-m|-i|--image|-c|--config|-C|--cd|--add-dir|--output-schema|-o|--output-last-message|--color|--enable|--disable|--local-provider)
          # 明示的に値を取るフラグ
          EXPECT_VALUE="$arg"
          ;;
        --*)
          # 未知のフラグ → 安全側で値付きとして扱う（誤って次引数を TASK_DESC にしない）
          EXPECT_VALUE="$arg"
          ;;
        *)
          # 非フラグ引数 = タスク説明
          TASK_DESC="$arg"
          ;;
      esac
    done

    # effort を計算
    COMPUTED_EFFORT=""
    if [ -f "$EFFORT_SCRIPT" ]; then
      if [ -n "$TASK_DESC" ]; then
        COMPUTED_EFFORT=$(bash "$EFFORT_SCRIPT" "$TASK_DESC" 2>/dev/null || true)
      elif [ ! -t 0 ]; then
        # stdin が利用可能（パイプ）: 内容を読み取って effort を計算
        STDIN_CONTENT=$(cat)
        if [ -n "$STDIN_CONTENT" ]; then
          COMPUTED_EFFORT=$(echo "$STDIN_CONTENT" | bash "$EFFORT_SCRIPT" 2>/dev/null || true)
          if ! is_valid_codex_effort "${COMPUTED_EFFORT:-}"; then
            COMPUTED_EFFORT="medium"
          fi
          MODEL_ARGS=()
          while IFS= read -r arg; do
            MODEL_ARGS+=("$arg")
          done < <(build_codex_task_model_args "$@")
          # stdin を再セットアップ（here-string 経由で companion に渡す）
          if [ "${STRUCTURED_TASK_EXEC}" -eq 1 ]; then
            run_structured_task_exec "$@" "${MODEL_ARGS[@]}" --effort "${COMPUTED_EFFORT}" <<< "$STDIN_CONTENT"
          else
            exec node "$COMPANION" "$@" "${MODEL_ARGS[@]}" --effort "${COMPUTED_EFFORT}" <<< "$STDIN_CONTENT"
          fi
        fi
        # stdin が空の場合（</dev/null 等）はフォールスルーして通常フローへ
      fi
    fi

    # フォールバック: 環境変数 CODEX_EFFORT → medium
    if [ -z "$COMPUTED_EFFORT" ]; then
      COMPUTED_EFFORT="${CODEX_EFFORT:-medium}"
    fi

    if ! is_valid_codex_effort "$COMPUTED_EFFORT"; then
      COMPUTED_EFFORT="medium"
    fi

    MODEL_ARGS=()
    while IFS= read -r arg; do
      MODEL_ARGS+=("$arg")
    done < <(build_codex_task_model_args "$@")

    if [ "${STRUCTURED_TASK_EXEC}" -eq 1 ]; then
      run_structured_task_exec "$@" "${MODEL_ARGS[@]}" --effort "$COMPUTED_EFFORT"
    else
      exec node "$COMPANION" "$@" "${MODEL_ARGS[@]}" --effort "$COMPUTED_EFFORT"
    fi
  fi
fi

if [ "${STRUCTURED_TASK_EXEC}" -eq 1 ]; then
  run_structured_task_exec "$@"
fi

if [ "$SUBCOMMAND" = "task" ]; then
  MODEL_ARGS=()
  while IFS= read -r arg; do
    MODEL_ARGS+=("$arg")
  done < <(build_codex_task_model_args "$@")
  exec node "$COMPANION" "$@" "${MODEL_ARGS[@]}"
fi

exec node "$COMPANION" "$@"
