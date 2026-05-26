#!/bin/bash
#
# setup-opencode.sh
#
# Claude Code を使わずに opencode.ai 用の Harness をセットアップ
#
# 使用方法:
#   curl -fsSL https://raw.githubusercontent.com/Chachamaru127/claude-code-harness/main/scripts/setup-opencode.sh | bash
#
# または:
#   ./setup-opencode.sh
#

set -e

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ロゴ
echo -e "${BLUE}"
echo '  ___ _                 _        _  _                              '
echo ' / __| |__ _ _  _ _____|_)___   | || |__ _ _ _ _ _  ___ ________ '
echo '| (__| / _` | || / _` / / -_)  | __ / _` | `_| ` \/ -_|_-<_-<_-<'
echo ' \___|_\__,_|\_,_\__,_/_\___|  |_||_\__,_|_| |_||_\___/__/__/__/'
echo ''
echo '                    for opencode.ai'
echo -e "${NC}"

# 変数
HARNESS_REPO="https://github.com/Chachamaru127/claude-code-harness.git"
HARNESS_BRANCH="main"
TEMP_DIR=$(mktemp -d)
PROJECT_DIR=$(pwd)

# クリーンアップ関数
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# 関数: エラー表示
error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# 関数: 成功表示
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# 関数: 情報表示
info() {
    echo -e "${BLUE}→ $1${NC}"
}

# 関数: 警告表示
warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

copy_dir_contents() {
    local src="$1"
    local dest="$2"
    local label="$3"
    local required="${4:-required}"

    if [ ! -d "$src" ]; then
        if [ "$required" = "required" ]; then
            error "$label not found in Harness"
        fi
        warn "$label not found in Harness (optional)"
        return
    fi

    if [ -z "$(find "$src" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
        if [ "$required" = "required" ]; then
            error "$label is empty in Harness"
        fi
        warn "$label is empty in Harness (optional)"
        return
    fi

    mkdir -p "$dest"
    cp -R "$src/." "$dest/"
    success "$label copied to ${dest#$PROJECT_DIR/}"
}

backup_dir_if_nonempty() {
    local dir="$1"
    local label="$2"

    if [ -d "$dir" ] && [ -n "$(find "$dir" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
        local backup_dir="${dir}.backup.$(date +%Y%m%d%H%M%S)"
        warn "$label already has content, creating backup"
        mv "$dir" "$backup_dir"
        mkdir -p "$dir"
    fi
}

copy_file_with_backup() {
    local src="$1"
    local dest="$2"
    local label="$3"

    if [ ! -f "$src" ]; then
        error "$label not found in Harness"
    fi

    mkdir -p "$(dirname "$dest")"
    if [ -f "$dest" ]; then
        local backup_file="${dest}.backup.$(date +%Y%m%d%H%M%S)"
        warn "$label already exists, creating backup"
        mv "$dest" "$backup_file"
    fi
    cp "$src" "$dest"
    success "$label copied to ${dest#$PROJECT_DIR/}"
}

# 前提条件チェック
check_requirements() {
    info "Checking requirements..."

    if ! command -v git &> /dev/null; then
        error "git is required but not installed"
    fi

    success "All requirements met"
}

# Harness をクローン
clone_harness() {
    info "Downloading Harness..."

    git clone --depth 1 --branch "$HARNESS_BRANCH" "$HARNESS_REPO" "$TEMP_DIR/harness" 2>/dev/null || \
        error "Failed to clone Harness repository"

    success "Harness downloaded"
}

# opencode ディレクトリをコピー
copy_opencode_files() {
    info "Setting up opencode files..."

    # .opencode/skills/ is the OpenCode-native primary surface.
    mkdir -p "$PROJECT_DIR/.opencode/skills"
    backup_dir_if_nonempty "$PROJECT_DIR/.opencode/skills" ".opencode/skills/"
    copy_dir_contents "$TEMP_DIR/harness/opencode/skills" "$PROJECT_DIR/.opencode/skills" "OpenCode skills"

    # .opencode/commands/ is compatibility-only for older slash-command flows.
    copy_dir_contents "$TEMP_DIR/harness/opencode/commands" "$PROJECT_DIR/.opencode/commands" "OpenCode compatibility commands" "optional"

    # .opencode/plugins/ provides bootstrap context without replacing user plugins.
    copy_file_with_backup \
        "$TEMP_DIR/harness/opencode/plugins/harness-bootstrap.mjs" \
        "$PROJECT_DIR/.opencode/plugins/harness-bootstrap.mjs" \
        "OpenCode bootstrap plugin"

    # AGENTS.md をコピー（既存の場合はバックアップ）
    if [ -f "$PROJECT_DIR/AGENTS.md" ]; then
        warn "AGENTS.md already exists, creating backup"
        mv "$PROJECT_DIR/AGENTS.md" "$PROJECT_DIR/AGENTS.md.backup.$(date +%Y%m%d%H%M%S)"
    fi

    if [ -f "$TEMP_DIR/harness/opencode/AGENTS.md" ]; then
        cp "$TEMP_DIR/harness/opencode/AGENTS.md" "$PROJECT_DIR/AGENTS.md"
        success "AGENTS.md created (from CLAUDE.md)"
    else
        error "opencode/AGENTS.md not found in Harness"
    fi
}

# opencode.json をセットアップ
setup_opencode_config() {
    if [ -f "$PROJECT_DIR/opencode.json" ]; then
        warn "opencode.json already exists, skipping"
        return
    fi

    if [ -f "$TEMP_DIR/harness/opencode/opencode.json" ]; then
        cp "$TEMP_DIR/harness/opencode/opencode.json" "$PROJECT_DIR/opencode.json"
        success "opencode.json created"
    else
        error "opencode/opencode.json not found in Harness"
    fi
}

verify_installation() {
    local first_skill
    first_skill="$(find "$PROJECT_DIR/.opencode/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -print -quit 2>/dev/null || true)"

    [ -n "$first_skill" ] || error "No OpenCode skills installed under .opencode/skills/"
    [ -f "$PROJECT_DIR/AGENTS.md" ] || error "AGENTS.md was not created"
    [ -f "$PROJECT_DIR/opencode.json" ] || error "opencode.json was not created"
    [ -f "$PROJECT_DIR/.opencode/plugins/harness-bootstrap.mjs" ] || error "OpenCode bootstrap plugin was not created"

    if command -v node >/dev/null 2>&1; then
        node -e "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'))" "$PROJECT_DIR/opencode.json" \
            || error "opencode.json is not valid JSON"
    fi

    success "OpenCode-native skills, AGENTS.md, and opencode.json verified"
}

# 完了メッセージ
print_success() {
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✅ Harness for OpenCode setup complete!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Created files:"
    echo "  📁 .opencode/skills/    - Harness skills for OpenCode's native skill tool"
    [ -d "$PROJECT_DIR/.opencode/commands" ] && echo "  📁 .opencode/commands/  - Optional compatibility commands"
    echo "  📄 .opencode/plugins/harness-bootstrap.mjs - Harness bootstrap plugin"
    echo "  📄 AGENTS.md            - Rules file (from CLAUDE.md)"
    echo "  📄 opencode.json        - OpenCode skill/instruction configuration"
    echo ""
    echo "Primary skills:"
    echo "  • harness-plan    - Evidence-backed implementation planning"
    echo "  • harness-work    - Execute Plans.md tasks"
    echo "  • breezing        - Team execution mode"
    echo "  • harness-review  - Code review"
    echo "  • harness-sync    - Sync progress and plans"
    echo ""
    echo "Next steps:"
    echo "  1. Start opencode: ${BLUE}opencode${NC}"
    echo "  2. Ask it to use the installed skills, for example: ${BLUE}Use harness-plan to create a plan${NC}"
    echo ""
    echo "MCP note: mcp-server/ is development-only and distribution-excluded."
    echo "Documentation: https://github.com/Chachamaru127/claude-code-harness"
    echo ""
}

# メイン処理
main() {
    echo ""
    info "Setting up Harness for OpenCode in: $PROJECT_DIR"
    echo ""

    check_requirements
    clone_harness
    copy_opencode_files
    setup_opencode_config
    verify_installation
    print_success
}

main "$@"
