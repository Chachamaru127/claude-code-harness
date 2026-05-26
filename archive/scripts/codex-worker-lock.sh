#!/usr/bin/env bash
#
# codex-worker-lock.sh
# タスク所有権・ロック機構
#
# Usage:
#   ./scripts/codex-worker-lock.sh acquire --path PATH --worker WORKER_ID
#   ./scripts/codex-worker-lock.sh release --path PATH --worker WORKER_ID
#   ./scripts/codex-worker-lock.sh heartbeat --path PATH --worker WORKER_ID
#   ./scripts/codex-worker-lock.sh check --path PATH
#   ./scripts/codex-worker-lock.sh cleanup
#

set -euo pipefail

# スクリプトディレクトリ
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 共通ライブラリ読み込み
# shellcheck source=lib/codex-worker-common.sh
source "$SCRIPT_DIR/lib/codex-worker-common.sh"

# ============================================
# ローカル設定（main で初期化）
# ============================================
TTL_MINUTES=""
HEARTBEAT_MINUTES=""
LOCK_DIR=""  # 絶対パスで初期化される
LOCK_LOG=""  # 絶対パスで初期化される

# 設定初期化（check_dependencies 後に呼び出す）
init_lock_config() {
    validate_config || {
        log_error "設定ファイルが不正です"
        exit 1
    }
    TTL_MINUTES=$(get_config "ttl_minutes")
    HEARTBEAT_MINUTES=$(get_config "heartbeat_minutes")

    # Security: 絶対パスで固定（CWD 依存を排除）
    local repo_root
    repo_root=$(get_repo_root) || exit 1
    LOCK_DIR="$repo_root/.claude/state/locks"
    LOCK_LOG="$repo_root/.claude/state/locks.log"
}

# ============================================
# ロック固有関数
# ============================================

# ロックディレクトリの検証と初期化
# Security: symlink 攻撃を防止（親ディレクトリ含む）
# Note: LOCK_DIR は init_lock_config() で絶対パスに設定済み
init_lock_dir() {
    local repo_root
    repo_root=$(get_repo_root) || exit 1

    # リポジトリルートを解決
    local real_repo_root
    real_repo_root=$(realpath "$repo_root" 2>/dev/null) || {
        log_error "リポジトリルートを解決できません: $repo_root"
        exit 1
    }

    # LOCK_DIR は既に絶対パス（init_lock_config で設定）
    local full_lock_dir="$LOCK_DIR"

    # 親ディレクトリの symlink チェック（Security: 各階層を検証）
    local check_path="$repo_root"
    for segment in .claude state locks; do
        check_path="$check_path/$segment"
        if [[ -L "$check_path" ]]; then
            log_error "パス階層に symlink が含まれています（セキュリティ上禁止）: $check_path"
            exit 1
        fi
    done

    # ディレクトリが存在する場合、リポジトリ内か確認
    if [[ -e "$full_lock_dir" ]]; then
        local real_lock_dir
        real_lock_dir=$(realpath "$full_lock_dir" 2>/dev/null) || {
            log_error "ロックディレクトリを解決できません: $full_lock_dir"
            exit 1
        }

        # Security: /repo と /repo2 を区別
        if [[ "$real_lock_dir" != "$real_repo_root" && "$real_lock_dir" != "$real_repo_root/"* ]]; then
            log_error "ロックディレクトリがリポジトリ外: $real_lock_dir"
            exit 1
        fi
    fi

    # ディレクトリ作成（Security: 700 権限）
    mkdir -p "$full_lock_dir"
    chmod 700 "$full_lock_dir"
}

# ロックキー生成（SHA256 先頭8文字）
generate_lock_key() {
    local path="$1"
    local normalized
    normalized=$(normalize_path "$path")
    calculate_sha256 "$normalized" 8
}

# ロックファイルパス取得
get_lock_file() {
    local path="$1"
    local key
    key=$(generate_lock_key "$path")
    printf '%s/%s.lock.json' "$LOCK_DIR" "$key"
}

# ロックファイルの複数フィールドを一度に取得（Performance 最適化）
# Usage: read_lock_fields "$lock_file" worker heartbeat path
# Returns: tab-separated values
read_lock_fields() {
    local lock_file="$1"
    shift
    local fields=("$@")

    if [[ ! -f "$lock_file" ]]; then
        return 1
    fi

    # 単一の jq 呼び出しで複数フィールドを取得
    local jq_filter
    jq_filter=$(printf '.%s, ' "${fields[@]}")
    jq_filter="${jq_filter%, }"  # 末尾のカンマを削除

    jq -r "[$jq_filter] | @tsv" "$lock_file"
}

# ログ記録
log_event() {
    local event="$1"
    local path="$2"
    local worker="$3"
    mkdir -p "$(dirname "$LOCK_LOG")"
    printf '%s\t%s\t%s\t%s\n' "$(now_utc)" "$event" "$path" "$worker" >> "$LOCK_LOG"
}

# ロック取得
cmd_acquire() {
    local path=""
    local worker=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                if [[ -z "${2:-}" ]]; then
                    log_error "--path には値が必要です"
                    exit 1
                fi
                path="$2"; shift 2 ;;
            --worker)
                if [[ -z "${2:-}" ]]; then
                    log_error "--worker には値が必要です"
                    exit 1
                fi
                worker="$2"; shift 2 ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [[ -z "$path" ]] || [[ -z "$worker" ]]; then
        log_error "--path と --worker は必須です"
        exit 1
    fi

    # Security: パス検証
    if ! validate_repo_path "$path"; then
        exit 1
    fi

    # Security: ロックディレクトリ検証
    init_lock_dir

    local lock_file
    lock_file=$(get_lock_file "$path")
    local normalized_path
    normalized_path=$(normalize_path "$path")

    # 既存ロックチェック（Performance: 1回の jq で複数フィールド取得）
    if [[ -f "$lock_file" ]]; then
        local lock_data
        lock_data=$(read_lock_fields "$lock_file" worker heartbeat) || {
            log_warn "ロックファイルの読み込みに失敗: $lock_file"
            rm -f "$lock_file"
        }

        local existing_worker
        local heartbeat
        existing_worker=$(echo "$lock_data" | cut -f1)
        heartbeat=$(echo "$lock_data" | cut -f2)

        # TTL チェック
        local heartbeat_epoch
        local now_epoch
        local ttl_seconds=$((TTL_MINUTES * 60))

        heartbeat_epoch=$(parse_utc_to_epoch "$heartbeat")
        now_epoch=$(date "+%s")

        if (( now_epoch - heartbeat_epoch > ttl_seconds )); then
            log_warn "TTL 超過: 既存ロックを解放 (worker=$existing_worker)"
            log_event "expired" "$normalized_path" "$existing_worker"
            rm -f "$lock_file"
        else
            log_error "ロック取得失敗: $normalized_path は $existing_worker がロック中"
            exit 1
        fi
    fi

    # 新規ロック作成（原子的作成）
    local now
    now=$(now_utc)

    # Security: 本人のみ読み書き可能な権限で作成
    local tmp_file
    tmp_file=$(mktemp "$LOCK_DIR/tmp.XXXXXX")
    jq -n \
        --arg path "$normalized_path" \
        --arg worker "$worker" \
        --arg acquired "$now" \
        --arg heartbeat "$now" \
        '{
            path: $path,
            worker: $worker,
            acquired: $acquired,
            heartbeat: $heartbeat
        }' > "$tmp_file"
    chmod 600 "$tmp_file"

    # ln で原子的配置（既存ファイルがあれば失敗）
    if ! ln "$tmp_file" "$lock_file" 2>/dev/null; then
        rm -f "$tmp_file"
        log_error "ロック取得失敗: $normalized_path は他の Worker がロック中（競合）"
        exit 1
    fi

    chmod 600 "$lock_file"
    rm -f "$tmp_file"
    log_event "acquire" "$normalized_path" "$worker"
    log_info "ロック取得: $normalized_path (worker=$worker)"
}

# ロック解放
cmd_release() {
    local path=""
    local worker=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                if [[ -z "${2:-}" ]]; then
                    log_error "--path には値が必要です"
                    exit 1
                fi
                path="$2"; shift 2 ;;
            --worker)
                if [[ -z "${2:-}" ]]; then
                    log_error "--worker には値が必要です"
                    exit 1
                fi
                worker="$2"; shift 2 ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [[ -z "$path" ]] || [[ -z "$worker" ]]; then
        log_error "--path と --worker は必須です"
        exit 1
    fi

    # Security: パス検証
    if ! validate_repo_path "$path"; then
        exit 1
    fi

    local lock_file
    lock_file=$(get_lock_file "$path")
    local normalized_path
    normalized_path=$(normalize_path "$path")

    if [[ ! -f "$lock_file" ]]; then
        log_warn "ロックが存在しません: $normalized_path"
        exit 0
    fi

    local existing_worker
    existing_worker=$(jq -r '.worker' "$lock_file")

    if [[ "$existing_worker" != "$worker" ]]; then
        log_error "ロック解放失敗: $normalized_path は $existing_worker のロックです"
        exit 1
    fi

    rm -f "$lock_file"
    log_event "release" "$normalized_path" "$worker"
    log_info "ロック解放: $normalized_path (worker=$worker)"
}

# heartbeat 更新
cmd_heartbeat() {
    local path=""
    local worker=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                if [[ -z "${2:-}" ]]; then
                    log_error "--path には値が必要です"
                    exit 1
                fi
                path="$2"; shift 2 ;;
            --worker)
                if [[ -z "${2:-}" ]]; then
                    log_error "--worker には値が必要です"
                    exit 1
                fi
                worker="$2"; shift 2 ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [[ -z "$path" ]] || [[ -z "$worker" ]]; then
        log_error "--path と --worker は必須です"
        exit 1
    fi

    # Security: パス検証
    if ! validate_repo_path "$path"; then
        exit 1
    fi

    local lock_file
    lock_file=$(get_lock_file "$path")
    local normalized_path
    normalized_path=$(normalize_path "$path")

    if [[ ! -f "$lock_file" ]]; then
        log_error "ロックが存在しません: $normalized_path"
        exit 1
    fi

    local existing_worker
    existing_worker=$(jq -r '.worker' "$lock_file")

    if [[ "$existing_worker" != "$worker" ]]; then
        log_error "heartbeat 更新失敗: $normalized_path は $existing_worker のロックです"
        exit 1
    fi

    local now
    now=$(now_utc)

    jq --arg heartbeat "$now" '.heartbeat = $heartbeat' "$lock_file" > "$lock_file.tmp"
    # Security: 権限を維持
    chmod 600 "$lock_file.tmp"
    mv "$lock_file.tmp" "$lock_file"

    log_info "heartbeat 更新: $normalized_path (worker=$worker)"
}

# ロック状態確認
cmd_check() {
    local path=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                if [[ -z "${2:-}" ]]; then
                    log_error "--path には値が必要です"
                    exit 1
                fi
                path="$2"; shift 2 ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [[ -z "$path" ]]; then
        log_error "--path は必須です"
        exit 1
    fi

    # Security: パス検証
    if ! validate_repo_path "$path"; then
        exit 1
    fi

    local lock_file
    lock_file=$(get_lock_file "$path")
    local normalized_path
    normalized_path=$(normalize_path "$path")

    if [[ ! -f "$lock_file" ]]; then
        echo '{"locked": false}'
        exit 0
    fi

    local worker
    local heartbeat
    worker=$(jq -r '.worker' "$lock_file")
    heartbeat=$(jq -r '.heartbeat' "$lock_file")

    # TTL チェック
    local heartbeat_epoch
    local now_epoch
    local ttl_seconds=$((TTL_MINUTES * 60))

    heartbeat_epoch=$(parse_utc_to_epoch "$heartbeat")
    now_epoch=$(date "+%s")

    if (( now_epoch - heartbeat_epoch > ttl_seconds )); then
        # TTL 超過: 読み取り専用（削除は acquire/cleanup で行う）
        echo '{"locked": false, "expired": true, "hint": "run cleanup or acquire to release"}'
    else
        jq -c '. + {locked: true}' "$lock_file"
    fi
}

# 期限切れロックのクリーンアップ
cmd_cleanup() {
    # Security: ロックディレクトリ検証
    init_lock_dir

    local cleaned=0
    local now_epoch
    now_epoch=$(date "+%s")
    local ttl_seconds=$((TTL_MINUTES * 60))

    for lock_file in "$LOCK_DIR"/*.lock.json; do
        [[ -f "$lock_file" ]] || continue

        # Performance: 1回の jq で複数フィールド取得
        local lock_data
        lock_data=$(read_lock_fields "$lock_file" heartbeat worker path) || continue

        local heartbeat
        local worker
        local path
        heartbeat=$(echo "$lock_data" | cut -f1)
        worker=$(echo "$lock_data" | cut -f2)
        path=$(echo "$lock_data" | cut -f3)

        local heartbeat_epoch
        heartbeat_epoch=$(parse_utc_to_epoch "$heartbeat")

        if (( now_epoch - heartbeat_epoch > ttl_seconds )); then
            log_warn "TTL 超過: $path (worker=$worker)"
            log_event "expired" "$path" "$worker"
            rm -f "$lock_file"
            cleaned=$((cleaned + 1))
        fi
    done

    log_info "クリーンアップ完了: $cleaned 件のロックを解放"
}

# 使用方法
usage() {
    cat << EOF
Usage: $0 COMMAND [OPTIONS]

Commands:
  acquire   --path PATH --worker WORKER_ID   ロック取得
  release   --path PATH --worker WORKER_ID   ロック解放
  heartbeat --path PATH --worker WORKER_ID   heartbeat 更新
  check     --path PATH                      ロック状態確認
  cleanup                                    期限切れロックのクリーンアップ

Options:
  --path PATH       対象ファイルパス
  --worker WORKER_ID Worker 識別子

Settings:
  TTL: $TTL_MINUTES 分
  Heartbeat 間隔: $HEARTBEAT_MINUTES 分
  ロックディレクトリ: $LOCK_DIR

Examples:
  $0 acquire --path src/auth/login.ts --worker worker-1
  $0 heartbeat --path src/auth/login.ts --worker worker-1
  $0 release --path src/auth/login.ts --worker worker-1
  $0 check --path src/auth/login.ts
  $0 cleanup
EOF
}

# メイン処理
main() {
    check_dependencies
    init_lock_config

    if [[ $# -eq 0 ]]; then
        usage
        exit 0
    fi

    local cmd="$1"
    shift

    case "$cmd" in
        acquire)   cmd_acquire "$@" ;;
        release)   cmd_release "$@" ;;
        heartbeat) cmd_heartbeat "$@" ;;
        check)     cmd_check "$@" ;;
        cleanup)   cmd_cleanup ;;
        -h|--help) usage; exit 0 ;;
        *)
            log_error "Unknown command: $cmd"
            usage
            exit 1
            ;;
    esac
}

main "$@"
