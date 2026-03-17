# Argus — Architecture

This is a two-tier application: **React + Vite** frontend and **FastAPI** backend. The backend proxies external market-data APIs (Polygon.io, Massive, FRED) and orchestrates LLM-powered chat via Claude API. Supabase handles auth and data persistence.

## The Core Loop

```
User message → Chat endpoint (SSE) → LLM with tool definitions
→ LLM selects tools → Backend calls domain services directly (no HTTP)
→ Data returned to LLM → LLM generates text + widget payloads
→ Streamed to frontend → Text renders in chat, widgets render on canvas
```

## Backend — Domain-Driven Design

Each business domain is a self-contained module. The chat service calls domain services **directly via Python imports** — not through HTTP endpoints.

```
backend/app/
├── api/v1/router.py              # Aggregates all domain routers
├── core/                          # Config, security, exceptions, middleware, rate limiting
├── shared/                        # Async HTTP client, shared schemas
├── domains/
│   ├── company/                   # Company profile, search (Polygon reference API)
│   ├── financials/                # Income statement, balance sheet, cash flow, ratios (Massive)
│   ├── pricing/                   # OHLC charts, quotes, snapshots (Polygon candles)
│   ├── short_interest/            # Short interest, short volume, float (Massive)
│   ├── corporate_actions/         # Dividends, splits, IPOs (Polygon reference)
│   ├── news/                      # Company news + market news (Polygon)
│   ├── economics/                 # Macro indicators, upcoming events (FRED + Massive)
│   ├── fred/                      # Internal — consumed by economics only
│   ├── scanner/                   # Inside-day pattern detection
│   ├── filings/                   # SEC filings
│   ├── polymarket/                # Prediction markets
│   ├── imf/                       # International macro data
│   └── chat/                      # LLM orchestration, tool registry, SSE streaming
```

### Adding a New Domain

1. Create `backend/app/domains/<name>/` with `__init__.py`, `router.py`, `schemas.py`, `service.py`, `client.py`
2. Add router import in `backend/app/api/v1/router.py`
3. Add tool entry in `backend/app/domains/chat/tools.py`
4. Zero changes to existing domains

## Frontend — Chat + Canvas

```
frontend/src/
├── components/
│   ├── chat/                      # Chat panel: messages, input, tool indicators, suggestions
│   ├── canvas/                    # Widget canvas: grid layout, widget container
│   ├── widgets/                   # Widget types: chart, table, metrics card, comparison
│   ├── sidebar/                   # Templates, conversation history, search
│   ├── layout/                    # App shell, icon rail, split-view
│   └── ui/                        # Shared primitives: badge, skeleton, button, input
├── hooks/                         # useChat, useCanvas, useTemplates, useConversation
├── lib/                           # API client, SSE handler, SWR config, Supabase client
├── types/                         # Shared TypeScript interfaces
└── App.tsx
```

---

## Chat System Rules

### Tool Registry (`domains/chat/tools.py`)

- Every tool has a `name`, `description`, `parameters`, and `handler`
- The `description` is what the LLM reads — it must be precise and unambiguous
- The `handler` points to an existing client/service function via Python import
- Tool descriptions should specify WHEN to use the tool, not just what it does
- Example: "Retrieve income statement data including revenue, operating income, net income. **Use for profitability and earnings questions.**"

### Widget Payloads

- The LLM emits structured widget payloads alongside text in its response
- Each widget payload specifies: `widget_type`, `title`, `data`, `config`, `interactions`
- The frontend widget renderer maps `widget_type` → React component
- Supported types: `line_chart`, `bar_chart`, `data_table`, `metrics_card`, `comparison_table`
- Widget data must always come from tool results — NEVER fabricated by the LLM

### Streaming (SSE)

- Chat endpoint is `POST /api/v1/chat/message` returning `text/event-stream`
- Event types: `text` (chat prose), `tool_call` (tool invocation), `tool_result` (data back), `widget` (canvas payload), `done` (stream end)
- Frontend processes all event types from the same stream

### Conversation Context

- Full conversation history is sent with each LLM call (up to context limit)
- A state object tracks: active entities (tickers), active timeframe, user expertise level
- Follow-up references like "compare that to MSFT" must resolve correctly
