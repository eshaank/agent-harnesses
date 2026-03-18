#!/usr/bin/env bash
# Test check-env-sync.sh hook
set -euo pipefail

HOOK="$(dirname "$0")/../core/hooks/check-env-sync.sh"
ERRORS=0

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT
cd "$TMPDIR"

# Test 1: Should pass when both files are in sync
cat > .env << 'EOF'
API_KEY=secret
DB_URL=postgres://localhost
EOF
cat > .env.example << 'EOF'
API_KEY=your_api_key
DB_URL=your_db_url
EOF
if ! bash "$HOOK" 2>/dev/null; then
    echo "    FAIL: Expected pass when files are in sync" >&2
    ERRORS=$((ERRORS + 1))
fi

# Test 2: Should warn when .env has keys missing from .env.example
cat >> .env << 'EOF'
NEW_SECRET=value
EOF
OUTPUT=$(bash "$HOOK" 2>&1 || true)
if ! echo "$OUTPUT" | grep -q "NEW_SECRET"; then
    echo "    FAIL: Expected warning about NEW_SECRET" >&2
    ERRORS=$((ERRORS + 1))
fi

# Test 3: Should pass when no .env exists
rm .env
if ! bash "$HOOK" 2>/dev/null; then
    echo "    FAIL: Expected pass when no .env exists" >&2
    ERRORS=$((ERRORS + 1))
fi

if [ "$ERRORS" -gt 0 ]; then
    exit 1
fi
