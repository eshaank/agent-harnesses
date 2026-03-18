#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

HARNESS_DIR="$(cd "$(dirname "$0")" && pwd)"

# If script is at project root (not inside harness/), adjust
if [ -d "$HARNESS_DIR/harness" ]; then
    HARNESS_DIR="$HARNESS_DIR/harness"
fi

# Parse flags and positional args
ACTION="init"
PROJECT_PATH_ARG=""

while [ $# -gt 0 ]; do
    case "$1" in
        --update)
            ACTION="update"
            shift
            ;;
        --eject)
            ACTION="eject"
            shift
            ;;
        --help|-h)
            echo "Usage: setup-harness.sh [OPTIONS] [PROJECT_PATH]"
            echo ""
            echo "Arguments:"
            echo "  PROJECT_PATH        Path to target project (default: parent of harness/)"
            echo ""
            echo "Options:"
            echo "  --update            Rebuild output from existing config"
            echo "  --eject             Copy files instead of symlinking (permanent)"
            echo "  -h, --help          Show this help"
            echo ""
            echo "Examples:"
            echo "  ./harness/setup-harness.sh                    # Install into parent dir"
            echo "  ./harness/setup-harness.sh ~/projects/my-app  # Install into my-app"
            echo "  ./harness/setup-harness.sh --update ~/projects/my-app"
            exit 0
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}" >&2
            echo "Run with --help for usage." >&2
            exit 1
            ;;
        *)
            PROJECT_PATH_ARG="$1"
            shift
            ;;
    esac
done

# Resolve PROJECT_ROOT: explicit arg > parent of harness dir
if [ -n "$PROJECT_PATH_ARG" ]; then
    PROJECT_ROOT="$(cd "$PROJECT_PATH_ARG" 2>/dev/null && pwd)" || {
        echo -e "${RED}ERROR: Directory not found: $PROJECT_PATH_ARG${NC}" >&2
        exit 1
    }
else
    PROJECT_ROOT="$(dirname "$HARNESS_DIR")"
fi

# Show version
VERSION=$(cat "$HARNESS_DIR/VERSION" 2>/dev/null || echo "unknown")
echo -e "${BLUE}=== Agent Harness Setup v${VERSION} ===${NC}"
echo -e "  Harness: ${HARNESS_DIR}"
echo -e "  Target:  ${PROJECT_ROOT}"
echo ""

if [ "$ACTION" = "update" ]; then
    # Check for config in harness dir or project root
    CONFIG_FILE=""
    for candidate in "$HARNESS_DIR/harness.config.json" "$PROJECT_ROOT/harness/harness.config.json"; do
        if [ -f "$candidate" ]; then
            CONFIG_FILE="$candidate"
            break
        fi
    done

    if [ -z "$CONFIG_FILE" ]; then
        echo "No harness.config.json found. Run setup-harness.sh first."
        exit 1
    fi

    CURRENT_VERSION=$(cat "$HARNESS_DIR/VERSION" 2>/dev/null || echo "unknown")
    INSTALLED_VERSION=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('harness_version', 'unknown'))" 2>/dev/null || echo "unknown")

    if [ "$CURRENT_VERSION" != "$INSTALLED_VERSION" ]; then
        echo -e "${YELLOW}Version changed: $INSTALLED_VERSION → $CURRENT_VERSION${NC}"
        echo -e "Check CHANGELOG.md for breaking changes."
        echo ""
    fi

    echo -e "${YELLOW}Rebuilding from existing config...${NC}"
    python3 "$HARNESS_DIR/build.py" "$CONFIG_FILE"
    echo -e "${GREEN}Done.${NC}"
    exit 0
fi

if [ "$ACTION" = "eject" ]; then
    echo -e "${YELLOW}Ejecting: copying output files (symlinks will be replaced with real files)...${NC}"
    OUTPUT_DIR="$HARNESS_DIR/output"
    for link in ".claude" ".cursor" ".opencode" ".rules" "CLAUDE.md" "AGENTS.md" "opencode.json" ".mcp.json"; do
        if [ -L "$PROJECT_ROOT/$link" ]; then
            TARGET=$(readlink "$PROJECT_ROOT/$link")
            rm "$PROJECT_ROOT/$link"
            cp -R "$OUTPUT_DIR/$(basename "$TARGET")" "$PROJECT_ROOT/$link" 2>/dev/null || true
            echo -e "  ${GREEN}COPY${NC}: $link"
        fi
    done
    echo -e "${GREEN}Ejected.${NC} Files are now independent copies."
    exit 0
fi

# -------------------------------------------------------------------
# Step 1: Detect stack
# -------------------------------------------------------------------
echo -e "${YELLOW}Detecting project stack...${NC}"

DETECTED_STACK=()

[ -f "$PROJECT_ROOT/package.json" ] && DETECTED_STACK+=("node")
[ -f "$PROJECT_ROOT/tsconfig.json" ] && DETECTED_STACK+=("typescript")
([ -f "$PROJECT_ROOT/pyproject.toml" ] || [ -f "$PROJECT_ROOT/requirements.txt" ]) && DETECTED_STACK+=("python")
[ -f "$PROJECT_ROOT/Cargo.toml" ] && DETECTED_STACK+=("rust")
[ -f "$PROJECT_ROOT/go.mod" ] && DETECTED_STACK+=("go")
[ -f "$PROJECT_ROOT/Gemfile" ] && DETECTED_STACK+=("ruby")

# Detect frameworks
if [ -f "$PROJECT_ROOT/next.config.js" ] || [ -f "$PROJECT_ROOT/next.config.ts" ] || [ -f "$PROJECT_ROOT/next.config.mjs" ]; then
    DETECTED_STACK+=("nextjs")
fi
if grep -rq "fastapi" "$PROJECT_ROOT/pyproject.toml" 2>/dev/null || \
   grep -rq "fastapi" "$PROJECT_ROOT/requirements.txt" 2>/dev/null; then
    DETECTED_STACK+=("fastapi")
fi
if grep -rq "\"react\"" "$PROJECT_ROOT/package.json" 2>/dev/null; then
    DETECTED_STACK+=("react")
fi
if grep -rq "\"vue\"" "$PROJECT_ROOT/package.json" 2>/dev/null; then
    DETECTED_STACK+=("vue")
fi
if grep -rq "\"svelte\"" "$PROJECT_ROOT/package.json" 2>/dev/null; then
    DETECTED_STACK+=("svelte")
fi

if [ ${#DETECTED_STACK[@]} -gt 0 ]; then
    echo -e "  Detected: ${GREEN}${DETECTED_STACK[*]}${NC}"
else
    echo -e "  ${YELLOW}No specific stack detected. Core harness will be installed.${NC}"
fi

echo ""

# -------------------------------------------------------------------
# Step 2: List available presets
# -------------------------------------------------------------------
echo -e "${YELLOW}Available presets:${NC}"
echo -e "  ${GREEN}[core]${NC} — Always included. Security hooks, branch protection, linting, generic commands."

PRESETS_DIR="$HARNESS_DIR/presets"
AVAILABLE_PRESETS=()
if [ -d "$PRESETS_DIR" ]; then
    for preset_dir in "$PRESETS_DIR"/*/; do
        if [ -f "${preset_dir}preset.json" ]; then
            PRESET_NAME=$(basename "$preset_dir")
            PRESET_DESC=$(python3 -c "import json; print(json.load(open('${preset_dir}preset.json'))['description'])" 2>/dev/null || echo "No description")
            echo -e "  ${GREEN}[$PRESET_NAME]${NC} — $PRESET_DESC"
            AVAILABLE_PRESETS+=("$PRESET_NAME")
        fi
    done
fi

echo ""

# -------------------------------------------------------------------
# Step 3: Choose presets
# -------------------------------------------------------------------
SELECTED_PRESETS=()

if [ ${#AVAILABLE_PRESETS[@]} -gt 0 ]; then
    echo -e "${YELLOW}Which presets do you want to apply? (comma-separated, or 'none' for core only)${NC}"
    echo -n "> "
    read -r PRESET_INPUT

    if [ "$PRESET_INPUT" != "none" ] && [ -n "$PRESET_INPUT" ]; then
        IFS=',' read -ra SELECTED_PRESETS <<< "$PRESET_INPUT"
        # Trim whitespace
        SELECTED_PRESETS=("${SELECTED_PRESETS[@]// /}")
    fi
fi

echo ""
echo -e "${BLUE}Configuration:${NC}"
echo -e "  Core: ${GREEN}yes${NC}"
for p in "${SELECTED_PRESETS[@]}"; do
    echo -e "  Preset: ${GREEN}$p${NC}"
done

echo ""

# -------------------------------------------------------------------
# Step 4: Ask for project variables
# -------------------------------------------------------------------
echo -e "${YELLOW}Project configuration:${NC}"

echo -n "  Project name [$(basename "$PROJECT_ROOT")]: "
read -r PROJECT_NAME
PROJECT_NAME="${PROJECT_NAME:-$(basename "$PROJECT_ROOT")}"

echo -n "  Default branch [main]: "
read -r DEFAULT_BRANCH
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"

echo ""

# -------------------------------------------------------------------
# Step 5: Generate harness.config.json
# -------------------------------------------------------------------
CONFIG_FILE="$HARNESS_DIR/harness.config.json"

python3 -c "
import json

detected = []
$(for s in "${DETECTED_STACK[@]:-}"; do echo "detected.append('$s')"; done)

selected = []
$(for s in "${SELECTED_PRESETS[@]:-}"; do echo "selected.append('$s')"; done)

harness_version = 'unknown'
try:
    with open('$HARNESS_DIR/VERSION') as f:
        harness_version = f.read().strip()
except FileNotFoundError:
    pass

config = {
    'harness_version': harness_version,
    'project_name': '$PROJECT_NAME',
    'default_branch': '$DEFAULT_BRANCH',
    'detected_stack': detected,
    'presets': selected,
    'variables': {
        'PROJECT_NAME': '$PROJECT_NAME',
        'DEFAULT_BRANCH': '$DEFAULT_BRANCH'
    },
    'port_mappings': {}
}

# Merge variables from selected presets
for preset_name in config['presets']:
    preset_path = '$PRESETS_DIR/' + preset_name + '/preset.json'
    try:
        with open(preset_path) as f:
            preset = json.load(f)
        preset_vars = preset.get('variables', {})
        # Merge port mappings
        if 'PORT_MAPPINGS' in preset_vars:
            config['port_mappings'].update(preset_vars['PORT_MAPPINGS'])
    except FileNotFoundError:
        pass

with open('$CONFIG_FILE', 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')

print('  Config saved to: $CONFIG_FILE')
" 2>/dev/null

echo ""

# -------------------------------------------------------------------
# Step 6: Build (merge core + presets → output/)
# -------------------------------------------------------------------
echo -e "${YELLOW}Building harness...${NC}"

python3 "$HARNESS_DIR/build.py" "$CONFIG_FILE"

echo ""

# -------------------------------------------------------------------
# Step 7: Create symlinks
# -------------------------------------------------------------------
echo -e "${YELLOW}Creating symlinks...${NC}"

OUTPUT_DIR="$HARNESS_DIR/output"

create_symlink() {
    local target="$1"
    local link="$2"

    if [ -L "$link" ]; then
        rm "$link"
    elif [ -e "$link" ]; then
        echo -e "  ${YELLOW}SKIP${NC}: $link already exists (not a symlink). Back up or remove it."
        return
    fi

    # Make target relative to link location
    local link_dir=$(dirname "$link")
    local rel_target=$(python3 -c "import os.path; print(os.path.relpath('$target', '$link_dir'))")

    ln -s "$rel_target" "$link"
    echo -e "  ${GREEN}LINK${NC}: $(basename "$link") → $rel_target"
}

create_symlink "$OUTPUT_DIR/claude" "$PROJECT_ROOT/.claude"
create_symlink "$OUTPUT_DIR/rules" "$PROJECT_ROOT/.rules"
create_symlink "$OUTPUT_DIR/claude/CLAUDE.md" "$PROJECT_ROOT/CLAUDE.md"
create_symlink "$OUTPUT_DIR/claude/AGENTS.md" "$PROJECT_ROOT/AGENTS.md"

# Only create if output exists
[ -d "$OUTPUT_DIR/cursor" ] && create_symlink "$OUTPUT_DIR/cursor" "$PROJECT_ROOT/.cursor"
[ -d "$OUTPUT_DIR/opencode" ] && create_symlink "$OUTPUT_DIR/opencode" "$PROJECT_ROOT/.opencode"
[ -f "$OUTPUT_DIR/opencode/opencode.json" ] && create_symlink "$OUTPUT_DIR/opencode/opencode.json" "$PROJECT_ROOT/opencode.json"
[ -f "$OUTPUT_DIR/claude/mcp.json" ] && create_symlink "$OUTPUT_DIR/claude/mcp.json" "$PROJECT_ROOT/.mcp.json"

echo ""
echo -e "${GREEN}Done!${NC} Harness installed with $(echo "${SELECTED_PRESETS[@]:-}" | wc -w | tr -d ' ') preset(s)."
echo -e "  Config:  $CONFIG_FILE"
echo -e "  Output:  $OUTPUT_DIR/"
echo -e "  Project: $PROJECT_ROOT"
echo ""
if [ -n "$PROJECT_PATH_ARG" ]; then
    echo -e "Run ${BLUE}$HARNESS_DIR/setup-harness.sh $PROJECT_ROOT${NC} again to reconfigure."
else
    echo -e "Run ${BLUE}./harness/setup-harness.sh${NC} again to reconfigure."
fi
