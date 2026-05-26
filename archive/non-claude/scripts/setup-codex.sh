#!/bin/bash
#
# setup-codex.sh
#
# Setup Harness for Codex CLI.
#
# Usage:
#   ./scripts/setup-codex.sh [--user|--project]
#

set -euo pipefail
IFS=$'\n\t'

HARNESS_REPO="https://github.com/Chachamaru127/claude-code-harness.git"
HARNESS_BRANCH="main"
TEMP_DIR=$(mktemp -d)
PROJECT_DIR=$(pwd)
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
TARGET_MODE="user"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

log_info() { echo "[INFO] $1"; }
log_warn() { echo "[WARN] $1"; }
log_ok() { echo "[OK]   $1"; }
log_err() { echo "[ERR]  $1" >&2; }

usage() {
    cat <<USAGE
Usage: $0 [--user|--project]

Modes:
  --user      Install to CODEX_HOME (default: $CODEX_HOME_DIR)
  --project   Install to current project (.codex/ + AGENTS.md)
USAGE
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --user)
                TARGET_MODE="user"
                ;;
            --project)
                TARGET_MODE="project"
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_err "Unknown argument: $1"
                usage
                exit 1
                ;;
        esac
        shift
    done
}

check_requirements() {
    log_info "Checking requirements..."
    if ! command -v git >/dev/null 2>&1; then
        log_err "git is required but not installed"
        exit 1
    fi
    log_ok "All requirements met"
}

clone_harness() {
    log_info "Downloading Harness..."
    git clone --depth 1 --branch "$HARNESS_BRANCH" "$HARNESS_REPO" "$TEMP_DIR/harness" 2>/dev/null || {
        log_err "Failed to clone Harness repository"
        exit 1
    }
    log_ok "Harness downloaded"
}

backup_path() {
    local target="$1"
    local backup_root="$2"
    if [ -e "$target" ]; then
        local ts
        local base
        local dst
        ts=$(date +%Y%m%d%H%M%S)
        base="$(basename "$target")"
        mkdir -p "$backup_root"
        dst="$backup_root/${base}.${ts}.$$"
        mv "$target" "$dst"
        log_warn "Backed up $target to $dst"
    fi
}

should_skip_sync_entry() {
    local name="$1"
    case "$name" in
        _archived|*.backup.*)
            return 0
            ;;
    esac
    return 1
}

is_legacy_harness_skill_name() {
    local name="$1"
    case "$name" in
        plan-with-agent|planning|plans-management|sync-status|work|execute|impl|parallel-workflows|verify|setup|harness-init|release-har|codex-review|codex-worker|remember)
            return 0
            ;;
    esac
    return 1
}

is_harness_managed_skill_entry() {
    local skill_file="$1"
    [ -f "$skill_file" ] || return 1

    if grep -Eq 'Claude Code Harness|Harness v3|claude-code-harness|/harness-|Plans\.md' "$skill_file"; then
        return 0
    fi
    return 1
}

cleanup_legacy_skill_entries() {
    local dst_dir="$1"
    local backup_root="$2"
    [ -d "$dst_dir" ] || return 0

    local legacy_path
    for legacy_path in "$dst_dir"/_archived "$dst_dir"/*.backup.*; do
        [ -e "$legacy_path" ] || continue
        backup_path "$legacy_path" "$backup_root"
    done
}

extract_skill_frontmatter_name() {
    local skill_file="$1"
    [ -f "$skill_file" ] || return 1

    awk '
        BEGIN { in_frontmatter = 0 }
        /^---[[:space:]]*$/ {
            if (in_frontmatter == 0) {
                in_frontmatter = 1
                next
            }
            exit
        }
        in_frontmatter == 1 && /^[[:space:]]*name:[[:space:]]*/ {
            sub(/^[[:space:]]*name:[[:space:]]*/, "", $0)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
            gsub(/^"|"$/, "", $0)
            print $0
            exit
        }
    ' "$skill_file"
}

cleanup_legacy_skill_name_duplicates() {
    local src_dir="$1"
    local dst_dir="$2"
    local backup_root="$3"
    [ -d "$src_dir" ] || return 0
    [ -d "$dst_dir" ] || return 0

    local src_skill_names=""
    local src_entry
    for src_entry in "$src_dir"/*; do
        [ -d "$src_entry" ] || continue
        local src_name
        src_name="$(basename "$src_entry")"
        if should_skip_sync_entry "$src_name"; then
            continue
        fi
        local src_skill_name
        src_skill_name="$(extract_skill_frontmatter_name "$src_entry/SKILL.md" || true)"
        [ -n "$src_skill_name" ] || continue
        src_skill_names+=$'\n'"$src_skill_name"
    done

    [ -n "$src_skill_names" ] || return 0

    local deduped=0
    local dst_entry
    for dst_entry in "$dst_dir"/*; do
        [ -d "$dst_entry" ] || continue
        local dst_name
        dst_name="$(basename "$dst_entry")"
        if should_skip_sync_entry "$dst_name"; then
            continue
        fi
        [ -e "$src_dir/$dst_name" ] && continue

        local dst_skill_name
        dst_skill_name="$(extract_skill_frontmatter_name "$dst_entry/SKILL.md" || true)"
        [ -n "$dst_skill_name" ] || continue

        if printf '%s\n' "$src_skill_names" | grep -Fxq "$dst_skill_name"; then
            backup_path "$dst_entry" "$backup_root"
            deduped=$((deduped + 1))
        fi
    done

    if [ "$deduped" -gt 0 ]; then
        log_warn "Moved $deduped legacy skill alias(es) with duplicate frontmatter name"
    fi
}

cleanup_removed_harness_skill_entries() {
    local src_dir="$1"
    local dst_dir="$2"
    local backup_root="$3"
    [ -d "$src_dir" ] || return 0
    [ -d "$dst_dir" ] || return 0

    local removed=0
    local dst_entry
    for dst_entry in "$dst_dir"/*; do
        [ -d "$dst_entry" ] || continue
        local dst_name
        dst_name="$(basename "$dst_entry")"
        if should_skip_sync_entry "$dst_name"; then
            continue
        fi
        [ -e "$src_dir/$dst_name" ] && continue

        local dst_skill_file="$dst_entry/SKILL.md"
        local dst_skill_name
        dst_skill_name="$(extract_skill_frontmatter_name "$dst_skill_file" || true)"

        if ! is_harness_managed_skill_entry "$dst_skill_file"; then
            continue
        fi

        if is_legacy_harness_skill_name "$dst_name" || { [ -n "$dst_skill_name" ] && is_legacy_harness_skill_name "$dst_skill_name"; }; then
            backup_path "$dst_entry" "$backup_root"
            removed=$((removed + 1))
        fi
    done

    if [ "$removed" -gt 0 ]; then
        log_warn "Moved $removed removed legacy Harness skill(s) that are no longer shipped"
    fi
}

merge_dir_recursive() {
    local src_dir="$1"
    local dst_dir="$2"
    local backup_root="$3"
    local _copied_ref="$4"
    local _updated_ref="$5"

    mkdir -p "$dst_dir"

    local entry
    for entry in "$src_dir"/*; do
        [ -e "$entry" ] || continue
        local name
        name="$(basename "$entry")"
        local dst_path="$dst_dir/$name"

        if [ ! -e "$dst_path" ]; then
            cp -R -L "$entry" "$dst_dir/"
            eval "$_copied_ref=\$((\$$_copied_ref + 1))"
        elif [ -d "$entry" ] && [ -d "$dst_path" ]; then
            merge_dir_recursive "$entry" "$dst_path" "$backup_root" "$_copied_ref" "$_updated_ref"
        else
            backup_path "$dst_path" "$backup_root"
            cp -R -L "$entry" "$dst_dir/"
            eval "$_updated_ref=\$((\$$_updated_ref + 1))"
        fi
    done
}

sync_named_children() {
    local src_dir="$1"
    local dst_dir="$2"
    local label="$3"
    local backup_root="$4"

    [ -d "$src_dir" ] || {
        log_err "$label source not found: $src_dir"
        exit 1
    }

    mkdir -p "$dst_dir"

    local copied=0
    local updated=0
    local skipped=0
    local preserved=0
    local entry
    for entry in "$src_dir"/*; do
        [ -e "$entry" ] || continue

        local name
        name="$(basename "$entry")"
        if should_skip_sync_entry "$name"; then
            skipped=$((skipped + 1))
            continue
        fi
        local dst_path="$dst_dir/$name"

        if [ ! -e "$dst_path" ]; then
            cp -R -L "$entry" "$dst_dir/"
            copied=$((copied + 1))
        elif [ -d "$entry" ] && [ -d "$dst_path" ]; then
            merge_dir_recursive "$entry" "$dst_path" "$backup_root" "copied" "updated"
        else
            backup_path "$dst_path" "$backup_root"
            cp -R -L "$entry" "$dst_dir/"
            updated=$((updated + 1))
        fi
    done

    for entry in "$dst_dir"/*; do
        [ -e "$entry" ] || continue
        local name
        name="$(basename "$entry")"
        if should_skip_sync_entry "$name"; then
            continue
        fi
        [ -e "$src_dir/$name" ] || preserved=$((preserved + 1))
    done

    log_ok "$label merged to $dst_dir ($copied new, $updated updated, $preserved preserved, $skipped skipped)"
}

copy_project_agents() {
    local backup_root="$1"
    local src="$TEMP_DIR/harness/codex/AGENTS.md"
    local dst="$PROJECT_DIR/AGENTS.md"

    if [ ! -f "$src" ]; then
        log_err "codex/AGENTS.md not found in Harness"
        exit 1
    fi

    if [ -f "$dst" ]; then
        backup_path "$dst" "$backup_root"
    fi

    cp "$src" "$dst"
    log_ok "AGENTS.md copied to project root"
}

resolve_target_root() {
    if [ "$TARGET_MODE" = "user" ]; then
        echo "$CODEX_HOME_DIR"
    else
        echo "$PROJECT_DIR/.codex"
    fi
}

resolve_backup_root() {
    local target_root="$1"
    if [ "$TARGET_MODE" = "user" ]; then
        echo "$CODEX_HOME_DIR/backups/setup-codex"
    else
        echo "$target_root/backups/setup-codex"
    fi
}

ensure_multi_agent_defaults() {
    local target_root="$1"
    local cfg="$target_root/config.toml"

    mkdir -p "$target_root"

    if [ ! -f "$cfg" ]; then
        cat > "$cfg" <<'CFG'
# Codex Team Config (Codex CLI 0.110.0+)

[features]
multi_agent = true

[agents]
max_threads = 8

[agents.implementer]
description = "Codex implementation worker for harness task execution"

[agents.reviewer]
description = "Codex reviewer worker for harness review and retake loops"
sandbox = "workspace-read-only"

[agents.task_worker]
description = "Standard Breezing implementer (impl_mode: standard). Implements tasks, runs self-review, build, and tests."

[agents.code_reviewer]
description = "Breezing reviewer. Performs independent code review with harness-review 5-point assessment including AI Residuals. Issues APPROVE / REQUEST_CHANGES / REJECT / STOP. Read-only."
sandbox = "workspace-read-only"

[agents.codex_implementer]
description = "Codex Breezing implementer (impl_mode: codex, used with --codex flag). Invokes Codex CLI, verifies AGENTS_SUMMARY, enforces Quality Gates."

[agents.claude_implementer]
description = "Claude CLI delegated implementation worker (used when --claude)"

[agents.claude_reviewer]
description = "Claude CLI delegated reviewer worker (used when --claude)"
sandbox = "workspace-read-only"

[agents.plan_analyst]
description = "Phase 0 planning analyst: analyzes task granularity, estimates owns files, proposes dependencies, and evaluates risk. Read-only access to codebase."
sandbox = "workspace-read-only"

[agents.plan_critic]
description = "Phase 0 plan critic: red-teaming review of task decomposition. Checks goal coverage, granularity, dependency accuracy, parallelism, and risk. Read-only access."
sandbox = "workspace-read-only"

[memories]
no_memories_if_mcp_or_web_search = false
CFG
        log_ok "Created $cfg with multi_agent + harness role defaults"
        return
    fi

    if ! grep -q '^[[:space:]]*multi_agent[[:space:]]*=' "$cfg"; then
        cat >> "$cfg" <<'CFG'

[features]
multi_agent = true
CFG
        log_ok "Enabled features.multi_agent in $cfg"
    fi

    if ! grep -q '^\[agents\]' "$cfg"; then
        cat >> "$cfg" <<'CFG'

[agents]
max_threads = 8
CFG
        log_ok "Added [agents] defaults to $cfg"
    fi

    if ! grep -q '^\[agents\.implementer\]' "$cfg"; then
        cat >> "$cfg" <<'CFG'

[agents.implementer]
description = "Codex implementation worker for harness task execution"
CFG
    fi

    if ! grep -q '^\[agents\.reviewer\]' "$cfg"; then
        cat >> "$cfg" <<'CFG'

[agents.reviewer]
description = "Codex reviewer worker for harness review and retake loops"
sandbox = "workspace-read-only"
CFG
    fi

    if ! grep -q '^\[agents\.claude_implementer\]' "$cfg"; then
        cat >> "$cfg" <<'CFG'

[agents.claude_implementer]
description = "Claude CLI delegated implementation worker (used when --claude)"
CFG
    fi

    if ! grep -q '^\[agents\.claude_reviewer\]' "$cfg"; then
        cat >> "$cfg" <<'CFG'

[agents.claude_reviewer]
description = "Claude CLI delegated reviewer worker (used when --claude)"
sandbox = "workspace-read-only"
CFG
    fi

    if ! grep -q '^\[agents\.task_worker\]' "$cfg"; then
        cat >> "$cfg" <<'CFG'

[agents.task_worker]
description = "Standard Breezing implementer (impl_mode: standard). Implements tasks, runs self-review, build, and tests."
CFG
    fi

    if ! grep -q '^\[agents\.code_reviewer\]' "$cfg"; then
        cat >> "$cfg" <<'CFG'

[agents.code_reviewer]
description = "Breezing reviewer. Performs independent code review with harness-review 5-point assessment including AI Residuals. Issues APPROVE / REQUEST_CHANGES / REJECT / STOP. Read-only."
sandbox = "workspace-read-only"
CFG
    fi

    if ! grep -q '^\[agents\.codex_implementer\]' "$cfg"; then
        cat >> "$cfg" <<'CFG'

[agents.codex_implementer]
description = "Codex Breezing implementer (impl_mode: codex, used with --codex flag). Invokes Codex CLI, verifies AGENTS_SUMMARY, enforces Quality Gates."
CFG
    fi

    if ! grep -q '^\[agents\.plan_analyst\]' "$cfg"; then
        cat >> "$cfg" <<'CFG'

[agents.plan_analyst]
description = "Phase 0 planning analyst: analyzes task granularity, estimates owns files, proposes dependencies, and evaluates risk. Read-only access to codebase."
sandbox = "workspace-read-only"
CFG
    fi

    if ! grep -q '^\[agents\.plan_critic\]' "$cfg"; then
        cat >> "$cfg" <<'CFG'

[agents.plan_critic]
description = "Phase 0 plan critic: red-teaming review of task decomposition. Checks goal coverage, granularity, dependency accuracy, parallelism, and risk. Read-only access."
sandbox = "workspace-read-only"
CFG
    fi

    # [memories] section (0.110.0+)
    if ! grep -q '^\[memories\]' "$cfg"; then
        cat >> "$cfg" <<'CFG'

[memories]
no_memories_if_mcp_or_web_search = false
CFG
        log_ok "Added [memories] defaults to $cfg"
    fi

}

print_success() {
    local target_root="$1"
    local backup_root="$2"

    echo ""
    echo "============================================"
    echo "Harness for Codex CLI setup complete."
    echo "============================================"
    echo ""
    echo "Mode: $TARGET_MODE"
    echo "Target: $target_root"
    echo ""
    echo "Created/updated:"
    echo "  $target_root/skills/  - Harness skills"
    echo "  $target_root/rules/   - Guardrails"
    echo "  $backup_root/ - Setup backups (outside skill scan path)"
    if [ "$TARGET_MODE" = "project" ]; then
        echo "  $PROJECT_DIR/AGENTS.md - Project instructions"
    else
        echo "  (project AGENTS.md unchanged in user mode)"
    fi

    echo ""
    echo "Next steps:"
    echo "  1. Restart Codex"
    echo "  2. Use \$harness-plan / \$harness-work / \$breezing / \$harness-loop to invoke Harness workflows"
    echo ""
}

main() {
    parse_args "$@"

    echo ""
    log_info "Setting up Harness for Codex CLI"
    log_info "Mode: $TARGET_MODE"
    if [ "$TARGET_MODE" = "user" ]; then
        log_info "Target: $CODEX_HOME_DIR"
    else
        log_info "Target: $PROJECT_DIR/.codex"
    fi
    echo ""

    check_requirements
    clone_harness

    local target_root
    target_root="$(resolve_target_root)"
    local backup_root
    backup_root="$(resolve_backup_root "$target_root")"

    cleanup_legacy_skill_entries "$target_root/skills" "$backup_root"
    cleanup_legacy_skill_name_duplicates "$TEMP_DIR/harness/codex/.codex/skills" "$target_root/skills" "$backup_root"
    cleanup_removed_harness_skill_entries "$TEMP_DIR/harness/codex/.codex/skills" "$target_root/skills" "$backup_root"
    sync_named_children "$TEMP_DIR/harness/codex/.codex/skills" "$target_root/skills" "Skills" "$backup_root"
    sync_named_children "$TEMP_DIR/harness/codex/.codex/rules" "$target_root/rules" "Rules" "$backup_root"

    if [ "$TARGET_MODE" = "project" ]; then
        copy_project_agents "$backup_root"
    else
        log_info "User mode: project AGENTS.md is unchanged"
    fi

    ensure_multi_agent_defaults "$target_root"
    print_success "$target_root" "$backup_root"
}

main "$@"
