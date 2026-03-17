---
description: Scan project for security issues — exposed secrets, missing .gitignore entries, unsafe patterns
allowed-tools: Read, Grep, Glob, Bash(git:*), Bash(grep:*), Bash(find:*)
---

# Security Check

Scan this project for security vulnerabilities. This stack has a **frontend** (npm) and **backend** (Python/uv); run checks for both where applicable.

## Checks to Perform

### 1. Secrets in Code
```bash
# Search for common secret patterns in tracked files (exclude lockfiles and node_modules)
git grep -n -E '(api[_-]?key|secret[_-]?key|password|token)\s*[:=]\s*["\x27][A-Za-z0-9+/=_-]{8,}' -- ':!*.lock' ':!node_modules' ':!frontend/node_modules' 2>/dev/null || echo "No secrets found in code"

# Search for AWS keys
git grep -n 'AKIA[0-9A-Z]\{16\}' 2>/dev/null || echo "No AWS keys found"

# Search for hardcoded URLs with credentials
git grep -n -E '(https?://[^:]+:[^@]+@)' 2>/dev/null || echo "No credential URLs found"
```

### 2. .gitignore Coverage
Verify these entries exist in .gitignore:
- [ ] `.env`
- [ ] `.env.*`
- [ ] `.env.local`
- [ ] `node_modules/`
- [ ] `frontend/node_modules/` (or `node_modules/` at repo root if used)
- [ ] `.venv/` (Python virtual environment)
- [ ] `dist/`
- [ ] `CLAUDE.local.md`
- [ ] `*.log`

### 3. Sensitive Files Check
```bash
# Check if any sensitive files are tracked by git
for f in .env .env.local .env.production secrets.json credentials.json id_rsa .npmrc; do
  git ls-files --error-unmatch "$f" 2>/dev/null && echo "WARNING: $f is tracked by git!"
done
echo "Sensitive file check complete."
```

### 4. .env File Verification
- [ ] `.env` exists but is NOT in git
- [ ] `.env.example` exists and IS in git
- [ ] `.env.example` has NO real values (only placeholders)

### 5. Dependency Audit

**Frontend (npm):**
```bash
# Check for known vulnerabilities (if npm project)
[ -f "package.json" ] && npm audit --production 2>/dev/null | head -20 || echo "Not an npm project"
```

**Backend (Python):**
```bash
# Prefer pip-audit if available (install with: uv add --dev pip-audit)
[ -d "backend" ] && (cd backend && uv run pip-audit 2>/dev/null | head -25) || echo "No backend or pip-audit not installed"
# Fallback: list deps so user can check manually
[ -d "backend" ] && (cd backend && uv pip list 2>/dev/null) || true
```

If `pip-audit` is not in the backend, suggest: `cd backend && uv add --dev pip-audit` then re-run.

### 6. Python .venv Not Committed
- [ ] `backend/.venv/` (or project `.venv/`) is in .gitignore and not tracked

## Output Format

| Check | Status | Details |
|-------|--------|---------|
| Secrets in code | Pass/Fail | ... |
| .gitignore coverage | Pass/Fail | ... |
| Sensitive files tracked | Pass/Fail | ... |
| .env handling | Pass/Fail | ... |
| Dependencies (frontend) | Pass/Fail | ... |
| Dependencies (backend) | Pass/Fail | ... |
| .venv not committed | Pass/Fail | ... |

**Overall: PASS / FAIL**

List any specific remediation steps needed.
