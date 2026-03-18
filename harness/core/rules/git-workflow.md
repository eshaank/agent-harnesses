# Git Workflow

## Branch FIRST, Work Second

**Auto-branch hook is ON by default.** A hook blocks commits to `main`.

```bash
# MANDATORY first step — do this BEFORE writing or editing anything:
git branch --show-current
# If on main → create a feature branch IMMEDIATELY:
git checkout -b feat/<task-name>
# NOW start working.
```

## Branch Naming

- `feat/*` — New features
- `fix/*` — Bug fixes
- `refactor/*` — Reorganization without behavior change
- `test/*` — Test additions or improvements
- `docs/*` — Documentation changes
- `chore/*` — Build, CI, dependency updates
