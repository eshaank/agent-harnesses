#!/usr/bin/env bash
# Test verify-no-secrets.sh hook
set -euo pipefail

HOOK="$(dirname "$0")/../core/hooks/verify-no-secrets.sh"
ERRORS=0

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Create a git repo
cd "$TMPDIR"
git init -b main --quiet
git commit --allow-empty -m "init" --quiet

# Test 1: Should pass with clean staged files
echo "const x = 1;" > clean.js
git add clean.js
if ! bash "$HOOK" 2>/dev/null; then
    echo "    FAIL: Expected pass for clean file" >&2
    ERRORS=$((ERRORS + 1))
fi
git reset HEAD clean.js --quiet

# Test 2: Should block staged .env file
echo "API_KEY=secret123" > .env
git add .env
if bash "$HOOK" 2>/dev/null; then
    echo "    FAIL: Expected block for staged .env" >&2
    ERRORS=$((ERRORS + 1))
fi
git reset HEAD .env --quiet

# Test 3: Should block file with AWS key pattern
echo 'aws_key = "AKIAIOSFODNN7EXAMPLE"' > config.py
git add config.py
if bash "$HOOK" 2>/dev/null; then
    echo "    FAIL: Expected block for AWS key in staged file" >&2
    ERRORS=$((ERRORS + 1))
fi
git reset HEAD config.py --quiet

# Test 4: Should pass with no staged files
if ! bash "$HOOK" 2>/dev/null; then
    echo "    FAIL: Expected pass with no staged files" >&2
    ERRORS=$((ERRORS + 1))
fi

if [ "$ERRORS" -gt 0 ]; then
    exit 1
fi
