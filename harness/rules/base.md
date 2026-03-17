# Argus — Base Rules

> **Argus** — A conversational financial research terminal.
> Chat-first interface where users ask questions in plain English and get data-driven answers with interactive visualizations.

---

## Critical Rules

### 0. NEVER Publish Sensitive Data

- NEVER commit passwords, API keys, tokens, or secrets to git/npm/docker
- NEVER commit `.env` files — ALWAYS verify `.env` is in `.gitignore`
- Before ANY commit: verify no secrets are included
- NEVER output secrets in suggestions, logs, or responses

### 1. NEVER Hardcode Credentials

- ALWAYS use environment variables for secrets
- NEVER put API keys, passwords, or tokens directly in code
- NEVER hardcode connection strings — use environment variables from .env

### 2. ALWAYS Ask Before Deploying

- NEVER auto-deploy, even if the fix seems simple
- NEVER assume approval — wait for explicit "yes, deploy"
- ALWAYS ask before deploying to production

---

## Domain Naming Convention

Domain names are chosen so an LLM can unambiguously select the right tool from the name alone. Each domain maps to a clear analytical concept:

| Domain | What It Answers | Tool Name Pattern |
|--------|----------------|-------------------|
| `company` | "What does this company do?" | `get_company_profile` |
| `financials` | "How profitable is this company?" | `get_income_statement`, `get_balance_sheet`, `get_cash_flow`, `get_ratios` |
| `pricing` | "What's the stock price / chart?" | `get_price_chart`, `get_quote` |
| `short_interest` | "Is this stock heavily shorted?" | `get_short_interest`, `get_short_volume`, `get_float` |
| `corporate_actions` | "Does it pay dividends? Any splits?" | `get_dividends`, `get_splits`, `get_ipos` |
| `news` | "What's in the news?" | `get_company_news`, `get_market_news` |
| `economics` | "How's the economy?" | `get_economic_indicators`, `get_upcoming_events` |
| `scanner` | "Find stocks matching a pattern" | `scan_inside_days` |
| `filings` | "Show me SEC filings" | `get_sec_filings` |

**NEVER create a domain named something vague like "research" or "data".** Domain names must be specific enough that a tool description writes itself.

---

## Project Documentation

| Document | Purpose | When to Read |
|----------|---------|--------------|
| `project-docs/ARCHITECTURE.md` | System overview, data flow, DDD structure | Before architectural changes |
| `project-docs/AI-CHAT-TERMINAL.md` | Chat feature plan, widget types, template system | Before chat/canvas/template work |
| `project-docs/DECISIONS.md` | ADRs — the "why" behind each choice | Before proposing alternatives |
| `project-docs/INFRASTRUCTURE.md` | Env vars, deployment, tech stack | Before environment changes |
| `project-docs/argus-style-guide.md` | Complete visual design system | Before any frontend work |
| `project-docs/product-plan.md` | Full product roadmap, phases, future plans | For strategic context |
| `project-docs/backend-refactor-plan.md` | Domain reorg details, migration plan | Before backend restructuring |

**ALWAYS read relevant docs before making cross-service changes.**

---

## When Something Seems Wrong

Before jumping to conclusions:

- Widget not rendering? → Check the widget_type matches a registered renderer BEFORE assuming broken
- LLM picking wrong tool? → Check tool descriptions in `chat/tools.py` BEFORE blaming the model
- SSE stream breaking? → Check event type parsing BEFORE assuming backend issue
- Empty data? → Check if external API services are running BEFORE assuming broken
- Auth failing? → Check which auth system (Supabase JWT) BEFORE debugging
- Test failing? → Read the error message fully BEFORE changing code

---

## Environment Variables

| Variable | Required | Service | Description |
|----------|----------|---------|-------------|
| `MASSIVE_API_KEY` | Yes | Backend | API key for Polygon.io + Massive APIs |
| `FRED_API_KEY` | Yes | Backend | API key for FRED economic data |
| `TOGETHER_API_KEY` | Yes | Backend | API key for Together AI LLM (chat) |
| `VITE_API_BASE_URL` | Yes | Frontend | Backend URL (e.g. `http://localhost:8000`) |
| `VITE_SUPABASE_URL` | Yes | Frontend | Supabase project URL |
| `VITE_SUPABASE_ANON_KEY` | Yes | Frontend | Supabase anon key |
| `SUPABASE_URL` | Yes | Backend | Supabase URL for JWKS verification |
| `DEBUG` | No | Backend | FastAPI debug mode |

---

## Workflow Preferences

- Quality over speed — if unsure, ask before executing
- One task, one chat — `/clear` between unrelated tasks
- When testing: queue observations, fix in batch (not one at a time)
- When building widgets: always test with real API data, not mocks
- When writing tool descriptions: test with ambiguous user queries to verify the LLM picks correctly

---

## Naming — NEVER Rename Mid-Project

If you must rename packages, modules, or key variables:

1. Create a checklist of ALL files and references first
2. Use IDE semantic rename (not search-and-replace)
3. Full project search for old name after renaming
4. Check: .md files, .txt files, .env files, comments, strings, paths
5. Update tool registry if any domain was renamed
6. Start a FRESH session after renaming
