#!/usr/bin/env bash
#
# codex-worker-common.sh
# Codex Worker スクリプト共通ライブラリ
#
# Usage: source "$SCRIPT_DIR/lib/codex-worker-common.sh"
#

# 二重読み込み防止
if [[ -n "${_CODEX_WORKER_COMMON_LOADED:-}" ]]; then
    return 0
fi
_CODEX_WORKER_COMMON_LOADED=1

# ============================================
# 色定義
# ============================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# ============================================
# ログ関数
# ============================================
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_gate() { echo -e "${BLUE}[GATE]${NC} $1"; }
log_merge() { echo -e "${BLUE}[MERGE]${NC} $1"; }

# ============================================
# 時刻関数
# ============================================

# ISO8601 UTC 現在時刻
now_utc() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

# ISO8601 UTC をエポック秒に変換（macOS/Linux 互換）
parse_utc_to_epoch() {
    local ts="$1"
    local ts_no_z="${ts%Z}"

    # macOS (BSD date)
    if date -u -j -f "%Y-%m-%dT%H:%M:%S" "$ts_no_z" "+%s" 2>/dev/null; then
        return 0
    fi

    # Linux (GNU date)
    if date -u -d "$ts" "+%s" 2>/dev/null; then
        return 0
    fi

    # フォールバック
    echo 0
}

# ============================================
# ハッシュ計算（クロスプラットフォーム）
# ============================================

# SHA256 ハッシュ計算
# Usage:
#   calculate_sha256 "input string" [chars]   # 引数から
#   echo "input" | calculate_sha256 "" [chars] # stdin から
calculate_sha256() {
    local input="${1:-}"
    local chars="${2:-64}"  # デフォルト: 全64文字

    # shasum (macOS / Linux with coreutils)
    if command -v shasum &>/dev/null; then
        if [[ -n "$input" ]]; then
            printf '%s' "$input" | shasum -a 256 | cut -c1-"$chars"
        else
            shasum -a 256 | cut -c1-"$chars"
        fi
        return 0
    fi

    # sha256sum (Linux)
    if command -v sha256sum &>/dev/null; then
        if [[ -n "$input" ]]; then
            printf '%s' "$input" | sha256sum | cut -c1-"$chars"
        else
            sha256sum | cut -c1-"$chars"
        fi
        return 0
    fi

    log_error "SHA256 コマンドが見つかりません (shasum / sha256sum)"
    return 1
}

# ファイルの SHA256 ハッシュ計算（BOM/CR 正規化付き）
calculate_file_hash() {
    local file="$1"
    local chars="${2:-8}"  # デフォルト: 先頭8文字

    if [[ ! -f "$file" ]]; then
        log_error "ファイルが存在しません: $file"
        return 1
    fi

    # BOM 除去 + CR 除去 + SHA256（クロスプラットフォーム）
    local content
    content=$(sed '1s/^\xEF\xBB\xBF//' "$file" | tr -d '\r')

    # shasum (macOS / Linux with coreutils)
    if command -v shasum &>/dev/null; then
        printf '%s' "$content" | shasum -a 256 | cut -c1-"$chars"
        return 0
    fi

    # sha256sum (Linux)
    if command -v sha256sum &>/dev/null; then
        printf '%s' "$content" | sha256sum | cut -c1-"$chars"
        return 0
    fi

    log_error "SHA256 コマンドが見つかりません"
    return 1
}

# ============================================
# パス検証（Security 強化）
# ============================================

# リポジトリルート取得
get_repo_root() {
    git rev-parse --show-toplevel 2>/dev/null || {
        log_error "Git リポジトリ外です"
        return 1
    }
}

# パスがリポジトリ内かを検証
# Security: symlink攻撃を防止
# Note: ファイルが存在しなくても、親ディレクトリが存在すれば検証可能
# Note: worktree など repo 外パスは validate_worktree_path() を使用
validate_repo_path() {
    local path="$1"
    local repo_root

    repo_root=$(get_repo_root) || return 1

    # 空パスチェック
    if [[ -z "$path" ]]; then
        log_error "パスが空です"
        return 1
    fi

    # パスを実パスに解決
    local real_path
    local target_path

    if [[ "$path" == /* ]]; then
        target_path="$path"
    else
        target_path="$repo_root/$path"
    fi

    # ファイル/ディレクトリが存在する場合は直接解決
    if [[ -e "$target_path" ]]; then
        real_path=$(realpath "$target_path" 2>/dev/null) || {
            log_error "パスを解決できません: $path"
            return 1
        }
    else
        # 存在しない場合は親ディレクトリを解決して basename を追加
        local parent_dir
        local base_name
        parent_dir=$(dirname "$target_path")
        base_name=$(basename "$target_path")

        # 親ディレクトリが存在するか確認
        if [[ -d "$parent_dir" ]]; then
            local real_parent
            real_parent=$(realpath "$parent_dir" 2>/dev/null) || {
                log_error "親ディレクトリを解決できません: $parent_dir"
                return 1
            }
            real_path="$real_parent/$base_name"
        else
            # 親も存在しない場合、論理的なパス検証のみ
            # 絶対パス変換して repo_root からの相対位置を確認
            real_path=$(cd "$repo_root" && realpath -m "$path" 2>/dev/null) || {
                # realpath -m がない環境（一部 BSD）用フォールバック
                real_path="$repo_root/$path"
            }
        fi
    fi

    # リポジトリルートも解決
    local real_repo_root
    real_repo_root=$(realpath "$repo_root" 2>/dev/null) || real_repo_root="$repo_root"

    # 実パスがリポジトリ内か確認（Security: /repo と /repo2 を区別するため / を含めて比較）
    if [[ "$real_path" != "$real_repo_root" && "$real_path" != "$real_repo_root/"* ]]; then
        log_error "リポジトリ外のパス: $path (resolved: $real_path)"
        return 1
    fi

    return 0
}

# worktree パスの検証
# Note: worktree は repo 外（../worktrees など）にあることが多いため、repo 内制限は行わない
# 代わりに、git worktree list で同一リポジトリの worktree であることを検証
validate_worktree_path() {
    local worktree="$1"

    # 空パスチェック
    if [[ -z "$worktree" ]]; then
        log_error "worktree パスが空です"
        return 1
    fi

    # ディレクトリ存在確認
    if [[ ! -d "$worktree" ]]; then
        log_error "worktree ディレクトリが存在しません: $worktree"
        return 1
    fi

    # Git リポジトリか確認
    if ! (cd "$worktree" && git rev-parse --show-toplevel >/dev/null 2>&1); then
        log_error "worktree が Git リポジトリではありません: $worktree"
        return 1
    fi

    # 同一リポジトリの worktree か確認（厳密一致）
    local worktree_abs
    worktree_abs=$(cd "$worktree" && pwd)

    # git worktree list --porcelain を使用して厳密一致
    local found=false
    while IFS= read -r line; do
        if [[ "$line" == "worktree $worktree_abs" ]]; then
            found=true
            break
        fi
    done < <(git worktree list --porcelain 2>/dev/null)

    if [[ "$found" != "true" ]]; then
        log_error "指定されたパスはこのリポジトリの worktree ではありません: $worktree"
        log_error "git worktree list で確認してください"
        return 1
    fi

    return 0
}

# パス正規化（./ 除去、\ → / 変換）
normalize_path() {
    local path="$1"
    path="${path#./}"
    path="${path//\\//}"
    printf '%s' "$path"
}

# ============================================
# 設定ファイル管理
# ============================================

# 設定ファイルパス
readonly CONFIG_FILE="${CONFIG_FILE:-.claude/state/codex-worker-config.json}"

# デフォルト設定（Security: fail-closed defaults）
declare -A CONFIG_DEFAULTS=(
    [ttl_minutes]="30"
    [heartbeat_minutes]="10"
    [max_retries]="3"
    [approval_policy]="never"
    [sandbox]="workspace-write"
    [base_branch]=""
    [require_gate_pass_for_merge]="true"  # Security: default to true
    [gate_skip_allowlist]="[]"
)

# 設定値取得
get_config() {
    local key="$1"
    local default="${CONFIG_DEFAULTS[$key]:-}"

    # 設定ファイルが存在しない場合はデフォルト
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "$default"
        return 0
    fi

    # jq で値を取得、なければデフォルト
    local value
    value=$(jq -r --arg key "$key" '.[$key] // empty' "$CONFIG_FILE" 2>/dev/null)

    if [[ -n "$value" && "$value" != "null" ]]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# 設定ファイル全体を読み込み
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        cat "$CONFIG_FILE"
    else
        echo '{}'
    fi
}

# 設定ファイルの検証（スキーマベース）
# Returns: 0 if valid, 1 if invalid
validate_config() {
    local config_file="${1:-$CONFIG_FILE}"

    if [[ ! -f "$config_file" ]]; then
        # 設定ファイルがない場合はデフォルトを使用するため valid
        return 0
    fi

    # JSON 構文チェック
    if ! jq empty "$config_file" 2>/dev/null; then
        log_error "設定ファイルが不正な JSON です: $config_file"
        return 1
    fi

    # 必須フィールドの型チェック（基本的な検証）
    local validation_errors=()

    # ttl_minutes: integer, 1-1440
    local ttl
    ttl=$(jq -r '.ttl_minutes // empty' "$config_file")
    if [[ -n "$ttl" ]] && ! [[ "$ttl" =~ ^[0-9]+$ && "$ttl" -ge 1 && "$ttl" -le 1440 ]]; then
        validation_errors+=("ttl_minutes must be integer 1-1440")
    fi

    # max_retries: integer, 1-10
    local retries
    retries=$(jq -r '.max_retries // empty' "$config_file")
    if [[ -n "$retries" ]] && ! [[ "$retries" =~ ^[0-9]+$ && "$retries" -ge 1 && "$retries" -le 10 ]]; then
        validation_errors+=("max_retries must be integer 1-10")
    fi

    # approval_policy: enum
    local policy
    policy=$(jq -r '.approval_policy // empty' "$config_file")
    if [[ -n "$policy" ]] && ! [[ "$policy" =~ ^(untrusted|on-failure|on-request|never)$ ]]; then
        validation_errors+=("approval_policy must be one of: untrusted, on-failure, on-request, never")
    fi

    # sandbox: enum
    local sandbox
    sandbox=$(jq -r '.sandbox // empty' "$config_file")
    if [[ -n "$sandbox" ]] && ! [[ "$sandbox" =~ ^(read-only|workspace-write|danger-full-access)$ ]]; then
        validation_errors+=("sandbox must be one of: read-only, workspace-write, danger-full-access")
    fi

    # require_gate_pass_for_merge: boolean
    local gate_pass
    gate_pass=$(jq -r '.require_gate_pass_for_merge // empty' "$config_file")
    if [[ -n "$gate_pass" ]] && ! [[ "$gate_pass" =~ ^(true|false)$ ]]; then
        validation_errors+=("require_gate_pass_for_merge must be boolean")
    fi

    if [[ ${#validation_errors[@]} -gt 0 ]]; then
        log_error "設定ファイル検証エラー:"
        for err in "${validation_errors[@]}"; do
            log_error "  - $err"
        done
        return 1
    fi

    return 0
}

# ============================================
# 依存コマンドチェック
# ============================================

# 必須コマンドの存在確認
# 引数なしの場合はデフォルトの依存コマンドをチェック
check_dependencies() {
    local commands=("$@")
    local missing=()

    # 引数なしの場合はデフォルトの依存コマンドを設定
    if [[ ${#commands[@]} -eq 0 ]]; then
        commands=("git" "jq")
        # SHA256 コマンドは shasum か sha256sum のどちらかがあればOK
        if ! command -v shasum &>/dev/null && ! command -v sha256sum &>/dev/null; then
            missing+=("shasum or sha256sum")
        fi
    fi

    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "必須コマンドが見つかりません: ${missing[*]}"
        return 1
    fi

    return 0
}

# ============================================
# パッケージマネージャ検出
# ============================================

# プロジェクトのパッケージマネージャを検出
detect_package_manager() {
    local project_dir="${1:-.}"
    local pkg_json="$project_dir/package.json"

    # 1. package.json の packageManager フィールド
    if [[ -f "$pkg_json" ]]; then
        local pm
        pm=$(jq -r '.packageManager // empty' "$pkg_json" 2>/dev/null | cut -d@ -f1)
        if [[ -n "$pm" ]]; then
            echo "$pm"
            return 0
        fi
    fi

    # 2. ロックファイルで判定
    if [[ -f "$project_dir/pnpm-lock.yaml" ]]; then
        echo "pnpm"
    elif [[ -f "$project_dir/yarn.lock" ]]; then
        echo "yarn"
    elif [[ -f "$project_dir/bun.lockb" ]]; then
        echo "bun"
    elif [[ -f "$project_dir/package-lock.json" ]]; then
        echo "npm"
    else
        # デフォルト
        echo "npm"
    fi
}

# パッケージマネージャの run コマンド
get_pm_run_command() {
    local pm="${1:-npm}"

    case "$pm" in
        npm)  echo "npm run" ;;
        pnpm) echo "pnpm run" ;;
        yarn) echo "yarn" ;;
        bun)  echo "bun run" ;;
        *)    echo "npm run" ;;
    esac
}

# ============================================
# ベースブランチ取得
# ============================================

# デフォルトブランチ取得
get_default_branch() {
    local config_branch
    config_branch=$(get_config "base_branch")

    # 1. 設定ファイルで指定されている場合
    if [[ -n "$config_branch" ]]; then
        echo "$config_branch"
        return 0
    fi

    # 2. Git の symbolic-ref から取得
    local remote_head
    remote_head=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')

    if [[ -n "$remote_head" ]]; then
        echo "$remote_head"
        return 0
    fi

    # 3. フォールバック
    echo "main"
}

# ============================================
# Worktree メタデータ管理
# ============================================

readonly WORKTREE_META_FILE=".codex-worker-meta.json"

# メタデータ保存
save_worktree_meta() {
    local worktree="$1"
    local task_id="$2"
    local owns="$3"
    local target_branch="$4"

    local meta_file="$worktree/$WORKTREE_META_FILE"

    jq -n \
        --arg task_id "$task_id" \
        --arg owns "$owns" \
        --arg target_branch "$target_branch" \
        --arg gate_status "pending" \
        --arg created_at "$(now_utc)" \
        '{
            task_id: $task_id,
            owns: $owns,
            target_branch: $target_branch,
            gate_status: $gate_status,
            created_at: $created_at
        }' > "$meta_file"

    # 権限設定（Security）
    chmod 600 "$meta_file"
}

# メタデータ読み込み
load_worktree_meta() {
    local worktree="$1"
    local meta_file="$worktree/$WORKTREE_META_FILE"

    if [[ -f "$meta_file" ]]; then
        cat "$meta_file"
    else
        echo '{}'
    fi
}

# メタデータ更新
update_worktree_meta() {
    local worktree="$1"
    local key="$2"
    local value="$3"

    local meta_file="$worktree/$WORKTREE_META_FILE"

    if [[ ! -f "$meta_file" ]]; then
        log_error "メタデータが存在しません: $meta_file"
        return 1
    fi

    local tmp_file
    tmp_file=$(mktemp)

    jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$meta_file" > "$tmp_file"
    mv "$tmp_file" "$meta_file"
    chmod 600 "$meta_file"
}

# ============================================
# ゲート結果管理（Security: worktree 外で中央管理）
# ============================================

readonly GATE_RESULTS_DIR=".claude/state/gates"

# ゲート結果保存（Worker 改ざん防止のため worktree 外に保存）
# Usage: save_gate_result "$worktree" "$status" "$details"
# Note: CWD に依存せず、worktree から中央リポジトリを解決
save_gate_result() {
    local worktree="$1"
    local status="$2"
    local details="${3:-}"

    # worktree から中央リポジトリのルートを解決（CWD 依存排除）
    local repo_root
    repo_root=$(cd "$worktree" && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/.git$||') || {
        # フォールバック: 現在の repo root を使用
        repo_root=$(get_repo_root) || return 1
    }

    # worktree の HEAD コミットハッシュを取得
    local head_commit
    head_commit=$(cd "$worktree" && git rev-parse HEAD 2>/dev/null) || {
        log_error "worktree の HEAD を取得できません: $worktree"
        return 1
    }

    # ゲート結果ディレクトリ作成
    local gate_dir="$repo_root/$GATE_RESULTS_DIR"
    mkdir -p "$gate_dir"
    chmod 700 "$gate_dir"

    # 結果ファイル（コミットハッシュで識別）
    local result_file="$gate_dir/${head_commit}.json"

    jq -n \
        --arg worktree "$(basename "$worktree")" \
        --arg head "$head_commit" \
        --arg status "$status" \
        --arg details "$details" \
        --arg verified_at "$(now_utc)" \
        '{
            worktree: $worktree,
            head: $head,
            status: $status,
            details: $details,
            verified_at: $verified_at
        }' > "$result_file"

    chmod 600 "$result_file"
    log_info "ゲート結果保存: $result_file (status=$status)"
}

# ゲート結果検証（merge 時に使用）
# Usage: verify_gate_result "$worktree"
# Returns: 0 if passed, 1 if not passed or not found
# Note: CWD に依存せず、worktree から中央リポジトリを解決
verify_gate_result() {
    local worktree="$1"

    # worktree から中央リポジトリのルートを解決（CWD 依存排除）
    local repo_root
    repo_root=$(cd "$worktree" && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/.git$||') || {
        # フォールバック: 現在の repo root を使用
        repo_root=$(get_repo_root) || return 1
    }

    # worktree の HEAD コミットハッシュを取得
    local head_commit
    head_commit=$(cd "$worktree" && git rev-parse HEAD 2>/dev/null) || {
        log_error "worktree の HEAD を取得できません: $worktree"
        return 1
    }

    # ゲート結果ファイル
    local result_file="$repo_root/$GATE_RESULTS_DIR/${head_commit}.json"

    if [[ ! -f "$result_file" ]]; then
        log_error "ゲート結果が見つかりません: $result_file"
        log_error "品質ゲートを実行してください: ./scripts/codex-worker-quality-gate.sh --worktree $worktree"
        return 1
    fi

    # ステータス確認
    local status
    status=$(jq -r '.status' "$result_file" 2>/dev/null)

    if [[ "$status" == "passed" ]]; then
        log_info "ゲート結果検証OK: commit=$head_commit, status=$status"
        return 0
    else
        log_error "ゲート未通過: commit=$head_commit, status=$status"
        return 1
    fi
}

# ============================================
# ファイル権限管理（Security）
# ============================================

# セキュアなファイル作成
create_secure_file() {
    local file="$1"
    local content="${2:-}"

    # ディレクトリ作成
    mkdir -p "$(dirname "$file")"

    # umask 077 で作成（本人のみ読み書き可能）
    (
        umask 077
        if [[ -n "$content" ]]; then
            printf '%s' "$content" > "$file"
        else
            touch "$file"
        fi
    )
}

# 一時ファイル作成（trap で自動削除、既存 trap を保持）
create_temp_file() {
    local prefix="${1:-codex-worker}"
    local tmp_file

    tmp_file=$(mktemp "/tmp/${prefix}.XXXXXX")

    # 既存の EXIT trap を保持して追加
    local prev_trap
    prev_trap=$(trap -p EXIT 2>/dev/null | sed "s/trap -- '\\(.*\\)' EXIT/\\1/" || echo "")

    # shellcheck disable=SC2064  # 意図的に現在の値でtrapを設定
    if [[ -n "$prev_trap" ]]; then
        trap "rm -f '$tmp_file'; $prev_trap" EXIT
    else
        trap "rm -f '$tmp_file'" EXIT
    fi

    echo "$tmp_file"
}

# ============================================
# 初期化
# ============================================

# スクリプトディレクトリ取得ヘルパー
get_script_dir() {
    local source="${BASH_SOURCE[1]:-$0}"
    local dir
    dir=$(cd "$(dirname "$source")" && pwd)
    echo "$dir"
}
