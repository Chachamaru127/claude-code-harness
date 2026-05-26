#!/usr/bin/env bash
#
# codex-worker-common.sh
# Codex Worker script shared library
#
# Usage: source "$SCRIPT_DIR/lib/codex-worker-common.sh"
#

# Prevent double-loading
if [[ -n "${_CODEX_WORKER_COMMON_LOADED:-}" ]]; then
    return 0
fi
_CODEX_WORKER_COMMON_LOADED=1

# ============================================
# Color definitions
# ============================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# ============================================
# Log functions
# ============================================
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_gate() { echo -e "${BLUE}[GATE]${NC} $1"; }
log_merge() { echo -e "${BLUE}[MERGE]${NC} $1"; }

# ============================================
# Time functions
# ============================================

# ISO8601 UTC current time
now_utc() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

# Convert ISO8601 UTC to epoch seconds (macOS/Linux compatible)
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

    # Fallback
    echo 0
}

# ============================================
# Hash calculation (cross-platform)
# ============================================

# SHA256 hash calculation
# Usage:
#   calculate_sha256 "input string" [chars]   # from argument
#   echo "input" | calculate_sha256 "" [chars] # from stdin
calculate_sha256() {
    local input="${1:-}"
    local chars="${2:-64}"  # Default: all 64 characters

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

    log_error "SHA256 command not found (shasum / sha256sum)"
    return 1
}

# File SHA256 hash calculation (with BOM/CR normalization)
calculate_file_hash() {
    local file="$1"
    local chars="${2:-8}"  # Default: first 8 characters

    if [[ ! -f "$file" ]]; then
        log_error "File does not exist: $file"
        return 1
    fi

    # Remove BOM + remove CR + SHA256 (cross-platform)
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

    log_error "SHA256 command not found"
    return 1
}

# ============================================
# Path validation (security hardening)
# ============================================

# Get repository root
get_repo_root() {
    git rev-parse --show-toplevel 2>/dev/null || {
        log_error "Outside a Git repository"
        return 1
    }
}

# Validate that a path is inside the repository
# Security: prevents symlink attacks
# Note: validation is possible even if the file does not exist, as long as the parent directory does
# Note: for paths outside the repo such as worktrees, use validate_worktree_path()
validate_repo_path() {
    local path="$1"
    local repo_root

    repo_root=$(get_repo_root) || return 1

    # Empty path check
    if [[ -z "$path" ]]; then
        log_error "Path is empty"
        return 1
    fi

    # Resolve path to real path
    local real_path
    local target_path

    if [[ "$path" == /* ]]; then
        target_path="$path"
    else
        target_path="$repo_root/$path"
    fi

    # Resolve directly when file/directory exists
    if [[ -e "$target_path" ]]; then
        real_path=$(realpath "$target_path" 2>/dev/null) || {
            log_error "Cannot resolve path: $path"
            return 1
        }
    else
        # Resolve parent directory and append basename when path does not exist
        local parent_dir
        local base_name
        parent_dir=$(dirname "$target_path")
        base_name=$(basename "$target_path")

        # Check whether parent directory exists
        if [[ -d "$parent_dir" ]]; then
            local real_parent
            real_parent=$(realpath "$parent_dir" 2>/dev/null) || {
                log_error "Cannot resolve parent directory: $parent_dir"
                return 1
            }
            real_path="$real_parent/$base_name"
        else
            # Parent also absent: logical path validation only
            # Convert to absolute path and verify position relative to repo_root
            real_path=$(cd "$repo_root" && realpath -m "$path" 2>/dev/null) || {
                # Fallback for environments without realpath -m (some BSD systems)
                real_path="$repo_root/$path"
            }
        fi
    fi

    # Resolve repository root as well
    local real_repo_root
    real_repo_root=$(realpath "$repo_root" 2>/dev/null) || real_repo_root="$repo_root"

    # Verify that the real path is inside the repository (Security: include / to distinguish /repo from /repo2)
    if [[ "$real_path" != "$real_repo_root" && "$real_path" != "$real_repo_root/"* ]]; then
        log_error "Path is outside the repository: $path (resolved: $real_path)"
        return 1
    fi

    return 0
}

# Validate a worktree path
# Note: worktrees are often outside the repo (e.g. ../worktrees), so no in-repo restriction is applied.
# Instead, verify via git worktree list that it belongs to the same repository.
validate_worktree_path() {
    local worktree="$1"

    # Empty path check
    if [[ -z "$worktree" ]]; then
        log_error "Worktree path is empty"
        return 1
    fi

    # Directory existence check
    if [[ ! -d "$worktree" ]]; then
        log_error "Worktree directory does not exist: $worktree"
        return 1
    fi

    # Check whether it is a Git repository
    if ! (cd "$worktree" && git rev-parse --show-toplevel >/dev/null 2>&1); then
        log_error "Worktree is not a Git repository: $worktree"
        return 1
    fi

    # Verify it is a worktree of the same repository (exact match)
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
        log_error "The specified path is not a worktree of this repository: $worktree"
        log_error "Please verify with: git worktree list"
        return 1
    fi

    return 0
}

# Path normalization (strip ./, convert \ to /)
normalize_path() {
    local path="$1"
    path="${path#./}"
    path="${path//\\//}"
    printf '%s' "$path"
}

# ============================================
# Configuration file management
# ============================================

# Config file path
readonly CONFIG_FILE="${CONFIG_FILE:-.claude/state/codex-worker-config.json}"

# Default configuration (Security: fail-closed defaults)
declare -A CONFIG_DEFAULTS=(
    [ttl_minutes]="30"
    [heartbeat_minutes]="10"
    [max_retries]="3"
    [approval_policy]="never"
    [sandbox]="workspace-write"
    [base_branch]=""
    [require_gate_pass_for_merge]="true"  # Security: defaults to true
    [gate_skip_allowlist]="[]"
)

# Retrieve a configuration value
get_config() {
    local key="$1"
    local default="${CONFIG_DEFAULTS[$key]:-}"

    # Use default when config file does not exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "$default"
        return 0
    fi

    # Get value via jq; fall back to default if absent
    local value
    value=$(jq -r --arg key "$key" '.[$key] // empty' "$CONFIG_FILE" 2>/dev/null)

    if [[ -n "$value" && "$value" != "null" ]]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# Load the entire config file
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        cat "$CONFIG_FILE"
    else
        echo '{}'
    fi
}

# Validate config file (schema-based)
# Returns: 0 if valid, 1 if invalid
validate_config() {
    local config_file="${1:-$CONFIG_FILE}"

    if [[ ! -f "$config_file" ]]; then
        # No config file means defaults will be used, which is valid
        return 0
    fi

    # JSON syntax check
    if ! jq empty "$config_file" 2>/dev/null; then
        log_error "Config file contains invalid JSON: $config_file"
        return 1
    fi

    # Type check for required fields (basic validation)
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
        log_error "Config file validation errors:"
        for err in "${validation_errors[@]}"; do
            log_error "  - $err"
        done
        return 1
    fi

    return 0
}

# ============================================
# Dependency command check
# ============================================

# Verify that required commands exist
# When called with no arguments, checks the default dependencies
check_dependencies() {
    local commands=("$@")
    local missing=()

    # Set default dependencies when called with no arguments
    if [[ ${#commands[@]} -eq 0 ]]; then
        commands=("git" "jq")
        # Either shasum or sha256sum is sufficient for SHA256
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
        log_error "Required commands not found: ${missing[*]}"
        return 1
    fi

    return 0
}

# ============================================
# Package manager detection
# ============================================

# Detect the project's package manager
detect_package_manager() {
    local project_dir="${1:-.}"
    local pkg_json="$project_dir/package.json"

    # 1. packageManager field in package.json
    if [[ -f "$pkg_json" ]]; then
        local pm
        pm=$(jq -r '.packageManager // empty' "$pkg_json" 2>/dev/null | cut -d@ -f1)
        if [[ -n "$pm" ]]; then
            echo "$pm"
            return 0
        fi
    fi

    # 2. Determine from lock file
    if [[ -f "$project_dir/pnpm-lock.yaml" ]]; then
        echo "pnpm"
    elif [[ -f "$project_dir/yarn.lock" ]]; then
        echo "yarn"
    elif [[ -f "$project_dir/bun.lockb" ]]; then
        echo "bun"
    elif [[ -f "$project_dir/package-lock.json" ]]; then
        echo "npm"
    else
        # Default
        echo "npm"
    fi
}

# Run command for the package manager
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
# Base branch retrieval
# ============================================

# Get default branch
get_default_branch() {
    local config_branch
    config_branch=$(get_config "base_branch")

    # 1. Specified in the config file
    if [[ -n "$config_branch" ]]; then
        echo "$config_branch"
        return 0
    fi

    # 2. Retrieve from Git symbolic-ref
    local remote_head
    remote_head=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')

    if [[ -n "$remote_head" ]]; then
        echo "$remote_head"
        return 0
    fi

    # 3. Fallback
    echo "main"
}

# ============================================
# Worktree metadata management
# ============================================

readonly WORKTREE_META_FILE=".codex-worker-meta.json"

# Save metadata
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

    # Set permissions (Security)
    chmod 600 "$meta_file"
}

# Load metadata
load_worktree_meta() {
    local worktree="$1"
    local meta_file="$worktree/$WORKTREE_META_FILE"

    if [[ -f "$meta_file" ]]; then
        cat "$meta_file"
    else
        echo '{}'
    fi
}

# Update metadata
update_worktree_meta() {
    local worktree="$1"
    local key="$2"
    local value="$3"

    local meta_file="$worktree/$WORKTREE_META_FILE"

    if [[ ! -f "$meta_file" ]]; then
        log_error "Metadata file does not exist: $meta_file"
        return 1
    fi

    local tmp_file
    tmp_file=$(mktemp)

    jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$meta_file" > "$tmp_file"
    mv "$tmp_file" "$meta_file"
    chmod 600 "$meta_file"
}

# ============================================
# Gate result management (Security: centrally managed outside the worktree)
# ============================================

readonly GATE_RESULTS_DIR=".claude/state/gates"

# Save gate result (stored outside worktree to prevent Worker tampering)
# Usage: save_gate_result "$worktree" "$status" "$details"
# Note: resolves central repository from worktree without depending on CWD
save_gate_result() {
    local worktree="$1"
    local status="$2"
    local details="${3:-}"

    # Resolve central repository root from worktree (no CWD dependency)
    local repo_root
    repo_root=$(cd "$worktree" && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/.git$||') || {
        # Fallback: use current repo root
        repo_root=$(get_repo_root) || return 1
    }

    # Retrieve HEAD commit hash of the worktree
    local head_commit
    head_commit=$(cd "$worktree" && git rev-parse HEAD 2>/dev/null) || {
        log_error "Cannot retrieve HEAD of worktree: $worktree"
        return 1
    }

    # Create gate result directory
    local gate_dir="$repo_root/$GATE_RESULTS_DIR"
    mkdir -p "$gate_dir"
    chmod 700 "$gate_dir"

    # Result file (identified by commit hash)
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
    log_info "Gate result saved: $result_file (status=$status)"
}

# Verify gate result (used at merge time)
# Usage: verify_gate_result "$worktree"
# Returns: 0 if passed, 1 if not passed or not found
# Note: resolves central repository from worktree without depending on CWD
verify_gate_result() {
    local worktree="$1"

    # Resolve central repository root from worktree (no CWD dependency)
    local repo_root
    repo_root=$(cd "$worktree" && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/.git$||') || {
        # Fallback: use current repo root
        repo_root=$(get_repo_root) || return 1
    }

    # Retrieve HEAD commit hash of the worktree
    local head_commit
    head_commit=$(cd "$worktree" && git rev-parse HEAD 2>/dev/null) || {
        log_error "Cannot retrieve HEAD of worktree: $worktree"
        return 1
    }

    # Gate result file
    local result_file="$repo_root/$GATE_RESULTS_DIR/${head_commit}.json"

    if [[ ! -f "$result_file" ]]; then
        log_error "Gate result not found: $result_file"
        log_error "Please run the quality gate: ./scripts/codex-worker-quality-gate.sh --worktree $worktree"
        return 1
    fi

    # Check status
    local status
    status=$(jq -r '.status' "$result_file" 2>/dev/null)

    if [[ "$status" == "passed" ]]; then
        log_info "Gate result verification OK: commit=$head_commit, status=$status"
        return 0
    else
        log_error "Gate not passed: commit=$head_commit, status=$status"
        return 1
    fi
}

# ============================================
# File permission management (Security)
# ============================================

# Create a secure file
create_secure_file() {
    local file="$1"
    local content="${2:-}"

    # Create directory
    mkdir -p "$(dirname "$file")"

    # Create with umask 077 (owner read/write only)
    (
        umask 077
        if [[ -n "$content" ]]; then
            printf '%s' "$content" > "$file"
        else
            touch "$file"
        fi
    )
}

# Create a temp file (auto-deleted via trap, preserving existing traps)
create_temp_file() {
    local prefix="${1:-codex-worker}"
    local tmp_file

    tmp_file=$(mktemp "/tmp/${prefix}.XXXXXX")

    # Preserve existing EXIT trap and append
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
# Initialization
# ============================================

# Helper to get the script directory
get_script_dir() {
    local source="${BASH_SOURCE[1]:-$0}"
    local dir
    dir=$(cd "$(dirname "$source")" && pwd)
    echo "$dir"
}
