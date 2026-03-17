# Argus — Git Workflow

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

- `feat/chat-*` — Chat interface work
- `feat/canvas-*` — Widget canvas work
- `feat/widget-*` — New widget types
- `feat/domain-*` — Backend domain changes
- `feat/tool-*` — Chat tool registry changes
- `feat/template-*` — Template system
- `fix/*` — Bug fixes
- `refactor/*` — Reorganization without behavior change
