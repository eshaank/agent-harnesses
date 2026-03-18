#!/usr/bin/env bash
# Test block-secrets.py hook
set -euo pipefail

HOOK="$(dirname "$0")/../core/hooks/block-secrets.py"
ERRORS=0

assert_blocks() {
    local description="$1"
    local tool_name="$2"
    local file_path="$3"

    local input="{\"tool_name\": \"$tool_name\", \"tool_input\": {\"file_path\": \"$file_path\"}}"
    if echo "$input" | python3 "$HOOK" 2>/dev/null; then
        echo "    FAIL: Expected block for: $description (tool=$tool_name, path=$file_path)" >&2
        ERRORS=$((ERRORS + 1))
    fi
}

assert_allows() {
    local description="$1"
    local tool_name="$2"
    local file_path="$3"

    local input="{\"tool_name\": \"$tool_name\", \"tool_input\": {\"file_path\": \"$file_path\"}}"
    if ! echo "$input" | python3 "$HOOK" 2>/dev/null; then
        echo "    FAIL: Expected allow for: $description (tool=$tool_name, path=$file_path)" >&2
        ERRORS=$((ERRORS + 1))
    fi
}

# Should block
assert_blocks "Read .env" "Read" ".env"
assert_blocks "Edit .env" "Edit" ".env"
assert_blocks "Read .env.local" "Read" ".env.local"
assert_blocks "Read .env.production" "Read" ".env.production"
assert_blocks "Read id_rsa" "Read" "~/.ssh/id_rsa"
assert_blocks "Read credentials.json" "Read" "credentials.json"
assert_blocks "Read .npmrc" "Read" ".npmrc"
assert_blocks "Edit secrets.json" "Edit" "secrets.json"
assert_blocks "Read aws credentials" "Read" "/home/user/.aws/credentials"
assert_blocks "Read ssh dir" "Read" "/home/user/.ssh/config"
assert_blocks "Read private_key file" "Read" "certs/private_key.pem"

# Should allow
assert_allows "Write .env (scaffolding)" "Write" ".env"
assert_allows "Write .env.example" "Write" ".env.example"
assert_allows "Read normal file" "Read" "src/index.ts"
assert_allows "Edit normal file" "Edit" "src/main.py"
assert_allows "Read package.json" "Read" "package.json"
assert_allows "No file path" "Read" ""

if [ "$ERRORS" -gt 0 ]; then
    exit 1
fi
