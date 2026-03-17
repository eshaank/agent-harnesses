# CLAUDE.md — Argus

@.rules/base.md
@.rules/architecture.md
@.rules/git-workflow.md
@.rules/design-system.md

---

## Claude Code: Load Skills Before Working
We are 3Epsilon working on project Argus. 

Before starting ANY task, check the available skills list and load the most relevant one:

- **Frontend UI work** (chat interface, widgets, canvas): Load `argus-design-system` skill — this is **MANDATORY** before writing or modifying any frontend component
- **Backend API work** (domains, routers, services): Load `fastapi-templates` skill
- **Chat/LLM work** (tool registry, prompts, orchestration): Load `chat-orchestration` skill
- **Database work**: Load `supabase-postgres-best-practices` skill
- **API integrations** (Polygon, Massive, FRED): Load `massive-api` skill
- **React performance**: Load `vercel-react-best-practices` skill
- **Code review**: Load `code-review` skill

If multiple skills apply, load the most specific one first.

**MANDATORY: Load the `argus-design-system` skill before any frontend work.** The style guide has the full token list, component patterns, and do's/don'ts.
