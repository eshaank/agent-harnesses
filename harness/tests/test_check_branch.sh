#!/usr/bin/env bash
# Test check-branch.sh hook
set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../core/hooks" && pwd)/check-branch.sh"
ERRORS=0

# Create a temporary git repo for testing
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

git -C "$TMPDIR" init -b main --quiet
git -C "$TMPDIR" commit --allow-empty -m "init" --quiet

assert_blocks() {
    local description="$1"
    local command="$2"
    local branch="$3"

    git -C "$TMPDIR" checkout -B "$branch" --quiet 2>/dev/null
    local input="{\"tool_name\": \"Bash\", \"tool_input\": {\"command\": \"$command\"}}"
    # Run hook from within the temp repo so CWD-based branch detection works
    if (cd "$TMPDIR" && echo "$input" | bash "$HOOK") 2>/dev/null; then
        echo "    FAIL: Expected block for: $description" >&2
        ERRORS=$((ERRORS + 1))
    fi
}

assert_allows() {
    local description="$1"
    local command="$2"
    local branch="$3"

    git -C "$TMPDIR" checkout -B "$branch" --quiet 2>/dev/null
    local input="{\"tool_name\": \"Bash\", \"tool_input\": {\"command\": \"$command\"}}"
    if ! (cd "$TMPDIR" && echo "$input" | bash "$HOOK") 2>/dev/null; then
        echo "    FAIL: Expected allow for: $description" >&2
        ERRORS=$((ERRORS + 1))
    fi
}

# Should block commits on main
assert_blocks "commit on main" "git commit -m test" "main"
assert_blocks "commit on master" "git commit -m test" "master"

# Should allow commits on feature branches
assert_allows "commit on feature branch" "git commit -m test" "feat/my-feature"
assert_allows "commit on fix branch" "git commit -m test" "fix/bug"

# Should allow non-commit commands on main
git -C "$TMPDIR" checkout -B main --quiet 2>/dev/null
input='{"tool_name": "Bash", "tool_input": {"command": "git status"}}'
if ! (cd "$TMPDIR" && echo "$input" | bash "$HOOK") 2>/dev/null; then
    echo "    FAIL: Expected allow for git status" >&2
    ERRORS=$((ERRORS + 1))
fi

if [ "$ERRORS" -gt 0 ]; then
    exit 1
fi
