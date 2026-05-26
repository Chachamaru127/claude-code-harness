#!/usr/bin/env bash
#
# codex-worker-setup.sh
# Codex Worker 機能のセットアップスクリプト
#
# Usage: ./scripts/codex-worker-setup.sh [--check-only]
#
# Options:
#   --check-only  インストール状態の確認のみ（変更なし）
#

set -euo pipefail

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 最小バージョン要件
MIN_CODEX_VERSION="0.107.0"
MIN_GIT_VERSION="2.5.0"

# グローバル変数
CHECK_ONLY=false
ERRORS=()
WARNINGS=()
CODEX_CLI_OK=false
CODEX_EXEC_OK=false

# ヘルパー関数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    WARNINGS+=("$1")
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ERRORS+=("$1")
}

# バージョン比較（semver）
version_gte() {
    local v1="$1"
    local v2="$2"

    # バージョン文字列を数値配列に変換
    IFS='.' read -ra V1 <<< "$v1"
    IFS='.' read -ra V2 <<< "$v2"

    # 各セグメントを比較
    for i in 0 1 2; do
        local n1="${V1[$i]:-0}"
        local n2="${V2[$i]:-0}"

        if (( n1 > n2 )); then
            return 0
        elif (( n1 < n2 )); then
            return 1
        fi
    done

    return 0
}

# Codex CLI 確認
check_codex_cli() {
    log_info "Codex CLI を確認中..."

    if ! command -v codex &> /dev/null; then
        log_error "Codex CLI が見つかりません"
        log_info "インストール方法: npm install -g @openai/codex"
        return 1
    fi

    local version
    version=$(codex --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0")

    if version_gte "$version" "$MIN_CODEX_VERSION"; then
        log_info "Codex CLI v$version (>= $MIN_CODEX_VERSION)"
        CODEX_CLI_OK=true
        return 0
    else
        log_error "Codex CLI v$version は古いです (>= $MIN_CODEX_VERSION 必須)"
        return 1
    fi
}

# Codex 認証確認
check_codex_auth() {
    log_info "Codex 認証を確認中..."

    if [[ "$CODEX_CLI_OK" != true ]]; then
        log_warn "Codex CLI が未インストールまたはバージョン不足のためスキップ"
        return 1
    fi

    if codex login status &> /dev/null; then
        log_info "Codex 認証: OK"
        return 0
    else
        log_warn "Codex 未認証: 'codex login' を実行してください"
        return 1
    fi
}

# Git バージョン確認（worktree サポート）
check_git_version() {
    log_info "Git バージョンを確認中..."

    if ! command -v git &> /dev/null; then
        log_error "Git が見つかりません"
        return 1
    fi

    local version
    version=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0")

    if version_gte "$version" "$MIN_GIT_VERSION"; then
        log_info "Git v$version (>= $MIN_GIT_VERSION, worktree サポート)"
        return 0
    else
        log_error "Git v$version は古いです (>= $MIN_GIT_VERSION 必須、worktree サポート)"
        return 1
    fi
}

# Codex CLI 実行確認（CLI-only）
check_codex_exec() {
    log_info "Codex CLI 実行を確認中..."

    if [[ "$CODEX_CLI_OK" != true ]]; then
        log_warn "Codex CLI が未インストールまたはバージョン不足のためスキップ"
        return 1
    fi

    local timeout_cmd=""
    if command -v timeout &> /dev/null; then
        timeout_cmd="timeout"
    elif command -v gtimeout &> /dev/null; then
        timeout_cmd="gtimeout"
    fi

    if [[ -z "$timeout_cmd" ]]; then
        log_warn "timeout/gtimeout が見つかりません（Codex CLI 実行確認をスキップ）"
        return 1
    fi

    if "$timeout_cmd" 15 codex exec "echo test" >/dev/null 2>&1; then
        log_info "Codex CLI 実行: OK"
        CODEX_EXEC_OK=true
        return 0
    else
        log_warn "Codex CLI 実行確認に失敗（認証/接続/タイムアウトを確認）"
        return 1
    fi
}

# 設定ファイル生成
generate_config() {
    local config_dir=".claude/state"
    local config_file="$config_dir/codex-worker-config.json"

    log_info "設定ファイルを生成中..."

    if [[ "$CHECK_ONLY" == true ]]; then
        if [[ -f "$config_file" ]]; then
            log_info "設定ファイル: 存在"
        else
            log_warn "設定ファイル: 未作成"
        fi
        return 0
    fi

    # ディレクトリ作成
    mkdir -p "$config_dir"

    # Codex バージョン取得
    local codex_version="unknown"
    if [[ "$CODEX_CLI_OK" == true ]]; then
        codex_version=$(codex --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    fi

    # Codex 実行状態
    local codex_exec_ready="false"
    if [[ "$CODEX_EXEC_OK" == true ]]; then
        codex_exec_ready="true"
    fi

    # 設定ファイル生成（キー名は common.sh の get_config と一致させる）
    cat > "$config_file" << EOF
{
  "codex_version": "$codex_version",
  "codex_exec_ready": $codex_exec_ready,
  "setup_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "approval_policy": "never",
  "sandbox": "workspace-write",
  "ttl_minutes": 30,
  "heartbeat_minutes": 10,
  "max_retries": 3,
  "base_branch": "",
  "gate_skip_allowlist": [],
  "require_gate_pass_for_merge": true,
  "parallel": {
    "enabled": true,
    "max_workers": 3,
    "worktree_base": "../worktrees"
  }
}
EOF

    # Security: 本人のみ読み書き可能
    chmod 600 "$config_file"
    log_info "設定ファイル生成完了: $config_file"
}

# メイン処理
main() {
    # 引数解析
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check-only)
                CHECK_ONLY=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    echo "========================================"
    echo "Codex Worker セットアップ"
    echo "========================================"
    echo ""

    # 各チェック実行
    check_codex_cli || true
    check_codex_auth || true
    check_git_version || true
    check_codex_exec || true
    generate_config || true

    echo ""
    echo "========================================"
    echo "結果サマリー"
    echo "========================================"

    if [[ ${#ERRORS[@]} -eq 0 ]] && [[ ${#WARNINGS[@]} -eq 0 ]]; then
        echo -e "${GREEN}すべてのチェックに合格しました${NC}"
        exit 0
    fi

    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo -e "${YELLOW}警告 (${#WARNINGS[@]}):${NC}"
        for w in "${WARNINGS[@]}"; do
            echo "  - $w"
        done
    fi

    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        echo -e "${RED}エラー (${#ERRORS[@]}):${NC}"
        for e in "${ERRORS[@]}"; do
            echo "  - $e"
        done
        exit 1
    fi

    exit 0
}

main "$@"
