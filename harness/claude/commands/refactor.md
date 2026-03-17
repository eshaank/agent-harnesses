---
description: Refactor a file following all project best practices — split, type, extract, clean
argument-hint: <file-path> [--dry-run]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, AskUserQuestion
---

# Refactor — Best Practices Enforcement

Refactor the target file following every rule in this project's CLAUDE.md and the correct layer (frontend vs backend).

**Target:** $ARGUMENTS

If `--dry-run` is passed, report what WOULD change without modifying any files.

## Step 0 — Detect Layer and Auto-Branch

**Layer detection:** From the target file path, determine which rules apply:
- Path under `frontend/src/` → **Frontend (TypeScript/React)** — apply TypeScript and React checks
- Path under `backend/app/` → **Backend (Python/FastAPI)** — apply Python and FastAPI checks

Report: "Refactoring [Frontend|Backend] file: <path>"

Before making any changes, check the current branch:

```bash
git branch --show-current
```

- If on `main` or `master`: create a feature branch and switch to it:
  ```bash
  git checkout -b refactor/<filename-without-extension>
  ```
  Report: "Created branch `refactor/<name>` — main stays untouched."
- If already on a feature branch: proceed
- If not a git repo: skip this check

## Step 0.5 — Read Before Touching

**NEVER refactor blind.** Read these files first:

1. The target file (fully — every line)
2. `CLAUDE.md` — project rules
3. `project-docs/ARCHITECTURE.md` — where things belong (if it exists)
4. **Frontend:** `frontend/tsconfig.json` (strict mode). **Backend:** `backend/pyproject.toml` (ruff config)

Also check what imports this file (blast radius):
- Frontend: search for the filename in `frontend/src/`
- Backend: search for the module name in `backend/app/`

Report: "This file is imported by X other files. Changes here affect: [list]"

## Step 1 — Audit the File

Run through EVERY check that applies to the detected layer. For each violation, note line number, what's wrong, and the fix.

### 1A. File Size (Quality Gates)

- **> 300 lines = MUST split.** No exceptions.
- Identify logical sections that can become their own files
- Group by: types/schemas, constants, helpers, main logic, exports

### 1B. Function Size (Quality Gates)

- **> 50 lines = MUST extract.** No exceptions.
- Identify functions that do multiple things — each "thing" becomes its own function
- Name extracted functions by what they DO, not where they came from

### Frontend-only (TypeScript / React)

#### 1C. TypeScript Compliance
- If the file is `.js` or `.jsx` → **convert to `.ts` / `.tsx`**
- Find ALL `any` types → replace with proper types or `unknown`
- Check for missing return types on exported functions
- Check for missing parameter types
- Check for `@ts-ignore` or `@ts-expect-error` — remove if possible, document if necessary

#### 1D. Import Hygiene
- No barrel imports (`import * as everything from`)
- No circular imports (A imports B, B imports A)
- Types should use `import type { }` not `import { }`
- Unused imports → remove
- Sort: external packages first, then internal, then types

#### 1E. Error Handling
- No swallowed errors (`catch { return null }`)
- No empty catch blocks
- Errors must be logged with context; user-facing errors must have clear messages

#### 1F. API and Data Flow
- All backend calls go through `frontend/src/lib/api.ts` — no raw fetch to backend elsewhere
- No business logic that belongs in backend (validation, transforms) — keep UI/state only

#### 1G. Independent Awaits
- Sequential `await` calls that don't depend on each other → wrap in `Promise.all`

### Backend-only (Python / FastAPI)

#### 1C. Type Hints
- Every function has type hints for all parameters and return type
- Use `list[...]`, `str | None` (Python 3.10+), not `List`, `Optional`
- Pydantic models for all request/response shapes (in `app/schemas/`)

#### 1D. Async Consistency
- Handlers that do I/O (HTTP to Polygon/Massive) use `async def`
- No blocking calls (e.g. sync `requests`) in async paths — use `httpx` async

#### 1E. Error Handling
- No bare `except:` or empty catch
- Use `HTTPException` for API errors; log and re-raise or return structured error
- Errors logged with context (ticker, endpoint, etc.)

#### 1F. API Routes and Structure
- All endpoints use `/api/` prefix (via router prefix in `app/main.py`)
- Route handlers are thin — external API calls live in `app/services/` (e.g. polygon.py, massive.py)
- Response models from `app/schemas/`; no bare dict returns

#### 1G. Lint (ruff)
- Code must pass `uv run ruff check backend/` (and optionally `ruff format`)

### Cross-cutting

#### 1H. Security
- No hardcoded secrets, API keys, tokens
- Input validation on external/user data

#### 1I. Dead Code
- Unused functions → remove (don't comment out)
- Unused variables → remove
- Commented-out code blocks → remove (use git history)

## Step 2 — Plan the Refactor

Before changing ANYTHING, present the plan to the user. Use concrete line counts and file names. Include:
- File size and whether split is required
- If splitting: list of new files and what goes in each
- Function extractions (name, current line count, split into…)
- Type/lint fixes (per line or per item)
- Other fixes (awaits, errors, dead code)
- Blast radius (importers)

**WAIT for user approval before making any changes.**

Use named steps so the user can say "skip Step 3" or "change Step 2."

## Step 3 — Execute the Refactor

After approval, make changes in this order:

1. **Create new files first** (types/schemas, helpers, utilities)
2. **Move code** from the original file to new files
3. **Update imports** in the original and in all files that imported it
4. **Fix types/lint** (TypeScript or Python)
5. **Fix patterns** (Promise.all, error handling, dead code)

### Frontend splitting rules
- **Types** → `frontend/src/types/<domain>.ts` or colocated `<name>.types.ts`
- **Constants** → colocated `<name>.constants.ts` or `frontend/src/constants/`
- **Helpers** → colocated `<name>.utils.ts` or `frontend/src/lib/`
- **Original file** keeps main logic and imports from the new files

### Backend splitting rules
- **Schemas (Pydantic)** → `backend/app/schemas/` (e.g. `models.py` or per-resource)
- **Constants** → colocated or `backend/app/constants.py`
- **Helpers** → `backend/app/services/` if they call external APIs, else colocated utils
- **Routers** stay in `backend/app/routers/`; keep handlers thin, delegate to services

### Verification commands
- **Frontend:** `cd frontend && npx tsc --noEmit 2>&1 | head -30`
- **Backend:** `cd backend && uv run ruff check app/ 2>&1 | head -30`

## Step 4 — Verify

After all changes:

- **Frontend:** `cd frontend && npx tsc --noEmit` — no TS errors
- **Backend:** `cd backend && uv run ruff check app/` — no ruff violations
- No file exceeds 300 lines
- No function exceeds 50 lines
- **Frontend:** No remaining `any` (unless documented). **Backend:** All functions have type hints.

## Step 5 — Report

Summarize: file(s) created/modified, line counts before/after, fixes applied, and verification result (TypeScript compiles / ruff clean).
