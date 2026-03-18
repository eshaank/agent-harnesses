#!/usr/bin/env bash
# Test lint-on-save.sh hook — verify it doesn't crash on various file types
set -euo pipefail

HOOK="$(dirname "$0")/../core/hooks/lint-on-save.sh"
ERRORS=0

# Test that the hook exits 0 for various file types (even if linters aren't installed)
for ext in ts tsx js jsx py vue svelte go rs unknown; do
    input="{\"tool_name\": \"Write\", \"tool_input\": {\"file_path\": \"test_file.$ext\"}}"
    if ! echo "$input" | bash "$HOOK" 2>/dev/null; then
        echo "    FAIL: Hook crashed for .$ext file" >&2
        ERRORS=$((ERRORS + 1))
    fi
done

# Test empty file path
input='{"tool_name": "Write", "tool_input": {"file_path": ""}}'
if ! echo "$input" | bash "$HOOK" 2>/dev/null; then
    echo "    FAIL: Hook crashed for empty file path" >&2
    ERRORS=$((ERRORS + 1))
fi

if [ "$ERRORS" -gt 0 ]; then
    exit 1
fi
