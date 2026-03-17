---
description: List all available commands, skills, and agents
allowed-tools: ""
---

# Help — All Available Commands

Display the complete list of commands, skills, and agents available for this project.

**Print this exactly:**

```
=== Finance Dashboard — Command Reference ===

GETTING STARTED
  /help              List all commands, skills, and agents (this screen)
  /setup             Interactive .env configuration — frontend (VITE_API_BASE_URL), backend (MASSIVE_API_KEY, DEBUG)
  /setup --reset     Re-configure everything from scratch

CODE QUALITY
  /review            Code review — TypeScript/React (frontend) and Python/FastAPI (backend) checklist
  /refactor <file>   Audit + refactor a file (frontend or backend) against CLAUDE.md rules
  /security-check    Scan for secrets, .gitignore, dependency audits (npm + Python)
  /commit            Smart commit with conventional commit format

DEVELOPMENT
  /create-api <res>  Scaffold a FastAPI router + Pydantic schemas + service (backend)
  /create-e2e <feat> Generate Playwright E2E test with explicit success criteria (dashboard flows)
  /test-plan         Generate a structured test plan for a feature
  /progress          Check project status — frontend/src, backend/app, tests, git activity

INFRASTRUCTURE
  /diagram <type>    Generate diagrams from code: architecture, api, services, infrastructure, all
  /architecture      Display system architecture and data flow (project-docs/ARCHITECTURE.md)
  /optimize-docker   Audit Dockerfile — multi-stage, FastAPI + Vite templates
  /worktree <name>   Create isolated branch + worktree for a task

=== Skills (activate automatically) ===

  Code Review        Triggers: "review", "audit", "check code"
                     Frontend: TypeScript, React, api.ts. Backend: Pydantic, async, ruff.

  Create Service     Triggers: "create service", "new endpoint", "scaffold router"
                     Backend: FastAPI router, Pydantic schemas, service in app/services/.

Skills activate when Claude detects relevant keywords — no command needed.

=== Custom Agents ===

  Code Reviewer      Read-only security & quality audit (Tools: Read, Grep, Glob)
  Test Writer        Creates tests with explicit assertions (Tools: Read, Write, Grep, Glob, Bash)

=== Tips ===

  For detailed help on any command: ask "How do I use /command-name?"
  Stack: React + Vite (frontend), FastAPI (backend). See project-docs/ARCHITECTURE.md.
  Use /help anytime to see this list again.
```
