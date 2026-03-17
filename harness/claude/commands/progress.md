---
description: Show project progress — what's done, what's pending, what's next
allowed-tools: Read, Bash(find:*), Bash(ls:*), Bash(wc:*), Bash(git log:*)
---

# Project Progress

Check the actual state of all components (frontend and backend) and report status.

## Instructions

1. Read `project-docs/ARCHITECTURE.md` for project context (if it exists)
2. Check **frontend** source: `frontend/src/` (TypeScript/React)
3. Check **backend** source: `backend/app/` (Python/FastAPI)
4. Check test directories: `tests/`, `frontend/` tests, `backend/tests/` (if present)
5. Check recent git activity

## Shell Commands to Run

```bash
echo "=== Frontend Source (TypeScript/React) ==="
find frontend/src/ -name "*.ts" -o -name "*.tsx" 2>/dev/null | head -40 || echo "No frontend/src/"

echo ""
echo "=== Backend Source (Python) ==="
find backend/app/ -name "*.py" 2>/dev/null | head -40 || echo "No backend/app/"

echo ""
echo "=== Test Files ==="
find tests/ -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | head -20
find frontend/ -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | head -20
find backend/ -path "*/tests/*" -name "*.py" 2>/dev/null | head -20

echo ""
echo "=== Recent Activity (Last 7 Days) ==="
git log --oneline --since="7 days ago" 2>/dev/null | head -15 || echo "No recent commits"

echo ""
echo "=== File Counts ==="
find frontend/src/ -name "*.ts" 2>/dev/null | wc -l | xargs -I{} echo "Frontend TS: {} files"
find frontend/src/ -name "*.tsx" 2>/dev/null | wc -l | xargs -I{} echo "Frontend TSX: {} files"
find backend/app/ -name "*.py" 2>/dev/null | wc -l | xargs -I{} echo "Backend Python: {} files"
find tests/ -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | wc -l | xargs -I{} echo "E2E/spec tests: {} files"
find backend/ -path "*/tests/*" -name "test_*.py" 2>/dev/null | wc -l | xargs -I{} echo "Backend pytest: {} files"
```

## Output Format

| Area | Files | Status | Notes |
|------|-------|--------|-------|
| Frontend (frontend/src/) | N TS/TSX | ... | ... |
| Backend (backend/app/) | N Python | ... | ... |
| Tests (E2E / unit / pytest) | N files | ... | ... |
| Documentation | ... | ... | ... |

### Next Actions (Priority Order)
1. ...
2. ...
3. ...
