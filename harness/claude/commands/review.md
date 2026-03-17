---
description: Review code for bugs, security issues, and best practices
allowed-tools: Read, Grep, Glob, Bash(git diff:*)
---

# Code Review

Review the current changes for:

## Branch Check

Verify the current branch context:

```bash
git branch --show-current
```

- If on `main` or `master`: warn — "You're reviewing changes directly on main. Next time, start work on a feature branch."
- Report which branch is being reviewed in the output header
- Review is read-only so no auto-branch is created

## Context
- Current diff: !`git diff HEAD`
- Staged changes: !`git diff --cached`

## Review Checklist

### Cross-cutting
1. **Security** — OWASP Top 10, no secrets in code, proper input validation
2. **Error Handling** — No swallowed errors, proper logging, user-friendly messages
3. **Testing** — New code has tests where appropriate, tests have explicit assertions
4. **API** — All backend endpoints use `/api/` prefix (see [project-docs/ARCHITECTURE.md](project-docs/ARCHITECTURE.md))

### Frontend (TypeScript / React in `frontend/src/`)
- **Types** — No `any`, proper null handling, explicit return types on exported functions
- **React** — Hook dependency arrays correct, no missing deps in useEffect/useCallback/useMemo
- **Style** — No inline styles for layout; use Tailwind or CSS modules
- **API client** — All backend calls go through `src/lib/api.ts`; no raw fetch to backend URLs elsewhere

### Backend (Python / FastAPI in `backend/app/`)
- **Types** — Type hints on every function (params and return); use `list[...]`, `str | None` (Python 3.10+)
- **Pydantic** — All response/request bodies use Pydantic models in `app/schemas/`; no bare dict returns
- **Async** — Handlers that do I/O (HTTP to Polygon/Massive) use `async def`; no blocking calls in async paths
- **Errors** — No bare `except:`; use `except Exception` with logging or re-raise; HTTPException for API errors
- **Routers** — Route handlers are thin; external API calls live in `app/services/` (e.g. polygon.py, massive.py)
- **Lint** — Code is ruff-clean (`uv run ruff check backend/`)

## Output Format

For each issue found:
- **File**: path/to/file:line
- **Severity**: Critical | Warning | Info
- **Issue**: Description
- **Fix**: Suggested change

Group findings by layer (Frontend vs Backend) when changes span both.
