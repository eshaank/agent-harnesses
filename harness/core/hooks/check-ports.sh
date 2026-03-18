#!/usr/bin/env bash
# Port Conflict Check Hook — PreToolUse (Bash)
# Blocks starting a server when the target port is already in use.
# Exit code 2 = block operation and tell Claude why.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null)

if [ -z "$COMMAND" ]; then
    exit 0
fi

PORT=""

# 1. Explicit port flags: -p 3000, --port 3000, --port=3000
if echo "$COMMAND" | grep -qoE '(-p|--port[= ])\s*[0-9]+'; then
    PORT=$(echo "$COMMAND" | grep -oE '(-p|--port[= ])\s*[0-9]+' | grep -oE '[0-9]+' | head -1)
fi

# 2. PORT= environment variable prefix
if [ -z "$PORT" ] && echo "$COMMAND" | grep -qE 'PORT=[0-9]+'; then
    PORT=$(echo "$COMMAND" | grep -oE 'PORT=[0-9]+' | head -1 | cut -d'=' -f2)
fi

# 3. Read custom script→port mappings from harness config if available
# Format in harness.config.json: "port_mappings": {"dev:website": 3000, "dev:api": 3001}
if [ -z "$PORT" ]; then
    HARNESS_CONFIG=""
    for cfg in "harness/harness.config.json" "harness.config.json"; do
        if [ -f "$cfg" ]; then
            HARNESS_CONFIG="$cfg"
            break
        fi
    done

    if [ -n "$HARNESS_CONFIG" ]; then
        # Extract port mappings and check if command matches any script name
        PORT=$(python3 -c "
import json, sys
try:
    with open('$HARNESS_CONFIG') as f:
        config = json.load(f)
    mappings = config.get('port_mappings', {})
    cmd = '''$COMMAND'''
    for script_name, port in mappings.items():
        if script_name in cmd:
            print(port)
            sys.exit(0)
except Exception:
    pass
" 2>/dev/null)
    fi
fi

# 4. Common defaults: "npm run dev" or "pnpm dev" without explicit port
if [ -z "$PORT" ]; then
    if echo "$COMMAND" | grep -qE '(npm|pnpm|yarn|bun)\s+run\s+dev$' || \
       echo "$COMMAND" | grep -qE '(npm|pnpm|yarn|bun)\s+dev$'; then
        PORT=3000
    fi
fi

# No port detected — nothing to check
if [ -z "$PORT" ]; then
    exit 0
fi

# Check if lsof is available
if ! command -v lsof &>/dev/null; then
    exit 0
fi

# Check if port is in use
PID=$(lsof -ti:"$PORT" 2>/dev/null | head -1)

if [ -n "$PID" ]; then
    PROC=$(ps -p "$PID" -o comm= 2>/dev/null || echo "unknown")
    echo "BLOCKED: Port $PORT is already in use by $PROC (PID: $PID)." >&2
    echo "Kill it first: lsof -ti:$PORT | xargs kill -9" >&2
    exit 2
fi

exit 0
