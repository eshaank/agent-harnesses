---
name: chat-orchestration
description: "Load this skill before working on the chat domain, LLM integration, tool registry, system prompts, SSE streaming, or widget payload generation. Covers the full chat architecture: Claude API tool use, SSE event protocol, tool registry patterns, conversation state management, widget data contracts, and system prompt structure."
metadata:
  author: eshaank
  version: "1.0.0"
---

# Chat Orchestration — LLM Integration Patterns

> **Load this skill before touching anything in `domains/chat/`.**
> Reference docs: `project-docs/AI-CHAT-TERMINAL.md`, `project-docs/product-plan.md`

---

## Architecture Overview

The chat system sits in `domains/chat/` and orchestrates everything between the user and the LLM. It is the ONLY domain that imports from other domains — all other domains are independent.

```
User message
  → POST /api/v1/chat/message (SSE stream)
    → chat/service.py builds LLM request with tool definitions
      → Claude API (tool_use) processes the request
        → LLM decides which tools to call
          → chat/service.py executes tools by calling domain services directly (Python imports)
            → Results sent back to LLM
              → LLM generates text + widget payloads
                → SSE stream sends events to frontend
```

### File Responsibilities

```
domains/chat/
├── router.py      # Single SSE endpoint: POST /chat/message
├── schemas.py     # All data structures: messages, tool calls, widget payloads, SSE events
├── service.py     # LLM orchestration: build request, execute tool loop, manage state
├── tools.py       # Tool registry: maps tool names → domain service functions
└── prompts.py     # System prompt, skill definitions, expertise adaptation
```

---

## Tool Registry (`tools.py`)

The tool registry is the bridge between the LLM and your data layer. It maps tool names to actual Python functions.

### Structure

```python
from dataclasses import dataclass
from typing import Any, Callable, Awaitable
import httpx

@dataclass
class ToolDefinition:
    name: str
    description: str
    parameters: dict  # JSON Schema for Claude API
    handler: Callable[..., Awaitable[Any]]  # The actual function to call
    requires_http_client: bool = True  # Most handlers need the shared httpx client

TOOLS: list[ToolDefinition] = [
    ToolDefinition(
        name="get_company_profile",
        description=(
            "Get company details: name, description, sector, market cap, "
            "employee count, exchange, and logo URL. Use when the user asks "
            "what a company does, basic company info, or company overview. "
            "Does NOT include financial data — use get_income_statement or "
            "get_balance_sheet for financials."
        ),
        parameters={
            "type": "object",
            "properties": {
                "ticker": {
                    "type": "string",
                    "description": "Stock ticker symbol (e.g. AAPL, MSFT). Always uppercase."
                }
            },
            "required": ["ticker"]
        },
        handler=company_client.fetch_company_details,
    ),
    # ... more tools
]
```

### Tool Description Rules

1. **Say WHEN to use, not just WHAT it does:**
   ```
   BAD:  "Gets income statement data"
   GOOD: "Retrieve quarterly/annual income statements including revenue, gross profit,
          operating income, net income, and EPS. Use for profitability, earnings,
          revenue growth, or margin analysis questions."
   ```

2. **Include negative boundaries to prevent confusion:**
   ```
   "Does NOT include financial data — use get_income_statement for financials."
   "Does NOT include company-specific news — use get_company_news for that."
   ```

3. **Differentiate overlapping tools explicitly:**
   ```
   get_company_news: "...about a SPECIFIC company by ticker"
   get_market_news:  "...general market-wide news, not specific to any company"
   ```

4. **Parameter descriptions should include examples:**
   ```
   "ticker": "Stock ticker symbol (e.g. AAPL, MSFT, TSLA). Always uppercase."
   "timeframe": "Chart period. Use 6M for recent, 5Y for long-term. Options: 1D,1W,1M,6M,12M,5Y,Max"
   ```

### Converting Tools to Claude API Format

The service layer converts `ToolDefinition` objects to the Claude API `tools` parameter:

```python
def tools_to_claude_format(tools: list[ToolDefinition]) -> list[dict]:
    return [
        {
            "name": t.name,
            "description": t.description,
            "input_schema": t.parameters,
        }
        for t in tools
    ]
```

### Executing Tool Calls

When Claude returns a `tool_use` block, the service looks up the handler and calls it:

```python
async def execute_tool(
    tool_name: str,
    tool_input: dict,
    http_client: httpx.AsyncClient,
) -> Any:
    tool = TOOL_MAP[tool_name]  # dict[str, ToolDefinition]
    if tool.requires_http_client:
        return await tool.handler(http_client, **tool_input)
    return await tool.handler(**tool_input)
```

**CRITICAL:** Tool handlers are called with the shared `httpx.AsyncClient` from `app.state.http_client`. This is the same client used by all domain routers — retry logic, connection pooling, and timeout config are inherited automatically.

---

## SSE Streaming Protocol (`router.py`)

The chat endpoint returns a `text/event-stream` response. The frontend processes multiple event types from the same stream.

### Event Types

```
event: text
data: {"content": "Apple's revenue grew..."}

event: tool_call
data: {"tool_name": "get_income_statement", "tool_input": {"ticker": "AAPL"}, "status": "calling"}

event: tool_result
data: {"tool_name": "get_income_statement", "status": "done"}

event: widget
data: {"id": "w1", "widget_type": "metrics_card", "title": "AAPL Key Metrics", "data": {...}, "config": {...}}

event: error
data: {"message": "Failed to fetch income statement", "tool_name": "get_income_statement"}

event: done
data: {}
```

### SSE Endpoint Pattern

```python
from fastapi import APIRouter, Depends, Request
from fastapi.responses import StreamingResponse
from app.core.security import get_current_user

router = APIRouter(prefix="/chat")

@router.post("/message")
async def chat_message(
    request: Request,
    body: ChatMessageRequest,
    _user: dict = Depends(get_current_user),
) -> StreamingResponse:
    return StreamingResponse(
        chat_stream(
            messages=body.messages,
            conversation_id=body.conversation_id,
            http_client=request.app.state.http_client,
            user=_user,
        ),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",  # Disable nginx buffering
        },
    )
```

### Streaming Generator Pattern

```python
async def chat_stream(
    messages: list[ChatMessage],
    conversation_id: str | None,
    http_client: httpx.AsyncClient,
    user: dict,
) -> AsyncGenerator[str, None]:
    # Build Claude API request
    claude_messages = build_claude_messages(messages)
    tools = tools_to_claude_format(TOOLS)
    system_prompt = build_system_prompt(user)

    # Call Claude API with streaming
    async with anthropic_client.messages.stream(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system=system_prompt,
        messages=claude_messages,
        tools=tools,
    ) as stream:
        async for event in stream:
            if event.type == "content_block_delta":
                if event.delta.type == "text_delta":
                    yield sse_event("text", {"content": event.delta.text})

            elif event.type == "content_block_start":
                if event.content_block.type == "tool_use":
                    yield sse_event("tool_call", {
                        "tool_name": event.content_block.name,
                        "status": "calling",
                    })

    # After initial response, handle tool use loop
    # (Claude may request tools, which need execution and re-submission)
    # See Tool Use Loop below

    yield sse_event("done", {})


def sse_event(event_type: str, data: dict) -> str:
    """Format a server-sent event."""
    import json
    return f"event: {event_type}\ndata: {json.dumps(data)}\n\n"
```

---

## Tool Use Loop (`service.py`)

Claude's tool use works in a loop: Claude requests tools → you execute them → you send results back → Claude continues (possibly requesting more tools).

```python
async def run_tool_loop(
    client: anthropic.AsyncAnthropic,
    messages: list[dict],
    system: str,
    tools: list[dict],
    http_client: httpx.AsyncClient,
    on_event: Callable,  # SSE yield function
) -> str:
    """Run the Claude tool-use loop until no more tools are requested."""

    while True:
        response = await client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=4096,
            system=system,
            messages=messages,
            tools=tools,
        )

        # Collect text and tool_use blocks
        text_parts = []
        tool_calls = []

        for block in response.content:
            if block.type == "text":
                text_parts.append(block.text)
                await on_event("text", {"content": block.text})
            elif block.type == "tool_use":
                tool_calls.append(block)
                await on_event("tool_call", {
                    "tool_name": block.name,
                    "tool_input": block.input,
                    "status": "calling",
                })

        # If no tool calls, we're done
        if response.stop_reason == "end_turn" or not tool_calls:
            return "".join(text_parts)

        # Execute tools and build tool_result messages
        tool_results = []
        for tc in tool_calls:
            try:
                result = await execute_tool(tc.name, tc.input, http_client)
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": tc.id,
                    "content": json.dumps(result, default=str),
                })
                await on_event("tool_result", {"tool_name": tc.name, "status": "done"})

                # Check if the LLM should emit a widget for this data
                widget = maybe_generate_widget(tc.name, tc.input, result)
                if widget:
                    await on_event("widget", widget)

            except Exception as e:
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": tc.id,
                    "content": json.dumps({"error": str(e)}),
                    "is_error": True,
                })
                await on_event("error", {"tool_name": tc.name, "message": str(e)})

        # Append assistant response + tool results to conversation
        messages.append({"role": "assistant", "content": response.content})
        messages.append({"role": "user", "content": tool_results})

        # Loop continues — Claude will process tool results and may request more tools
```

---

## Widget Data Contract (`schemas.py`)

Widgets are structured payloads that the frontend renders on the canvas.

```python
from pydantic import BaseModel
from typing import Any

class WidgetPayload(BaseModel):
    id: str                          # Unique ID (uuid4)
    widget_type: str                 # Maps to frontend React component
    title: str                       # Widget header text
    source_message_id: str | None    # Chat message that created this
    data: dict[str, Any]             # The actual data to render
    config: WidgetConfig
    interactions: WidgetInteractions

class WidgetConfig(BaseModel):
    x_axis: str | None = None
    y_axis: str | None = None
    series: list[str] | None = None
    format: str | None = None        # "currency", "percent", "number", "currency_billions"

class WidgetInteractions(BaseModel):
    hover: bool = True
    drill_down: str | None = None
    timeframe_toggle: list[str] | None = None
    sort: bool = False
    export: bool = False
```

### Supported Widget Types

| `widget_type` | Frontend Component | Data Shape |
|---------------|-------------------|------------|
| `line_chart` | `LineChartWidget` | `{series: [{name, data: [{x, y}]}]}` |
| `bar_chart` | `BarChartWidget` | `{groups: [{label, values: [{series, value}]}]}` |
| `data_table` | `DataTableWidget` | `{columns: [{key, label, align}], rows: [{...}]}` |
| `metrics_card` | `MetricsCardWidget` | `{metrics: [{label, value, change, direction}]}` |
| `comparison_table` | `ComparisonWidget` | `{entities: [...], metrics: [...], data: {...}}` |

### Widget Generation

Widgets can be generated in two ways:

1. **Auto-generated from tool results:** The `maybe_generate_widget` function in the tool loop checks if a tool call's data maps naturally to a widget type (e.g., `get_income_statement` → `data_table`).

2. **LLM-directed:** The system prompt instructs the LLM to emit widget payloads as structured JSON blocks within its response. The service layer parses these and sends them as `widget` SSE events.

Approach 1 is simpler and more reliable to start with. Approach 2 gives the LLM more control over presentation.

---

## Conversation State (`service.py`)

Each conversation maintains state that's sent with every LLM request:

```python
class ConversationState(BaseModel):
    active_tickers: list[str] = []     # Companies discussed so far
    active_timeframe: str | None = None # Current time range in scope
    expertise_level: str = "standard"   # "beginner" or "standard"
    canvas_widgets: list[str] = []      # Widget IDs currently on canvas
```

This state is injected into the system prompt so the LLM can resolve references like "compare that to MSFT" (knows "that" = the last active ticker).

---

## System Prompt Structure (`prompts.py`)

```python
def build_system_prompt(user: dict, state: ConversationState) -> str:
    return f"""You are Argus, a financial research assistant. You help users
analyze companies, economic data, and market trends by fetching real data
and presenting it with clear explanations and interactive visualizations.

## Your Capabilities
- You have access to tools that fetch real financial data (not training data)
- You can create interactive charts, tables, and metric cards on the user's canvas
- You can compare multiple companies, analyze trends, and explain financial concepts

## Tool Use Rules
- ALWAYS use tools to fetch data — never cite financial numbers from memory
- Call the most specific tool for the question (prefer get_income_statement over get_company_profile for earnings questions)
- You can call multiple tools in one turn for comparison queries
- If a tool fails, explain what happened and suggest alternatives

## Widget Rules
- Create widgets for any data that benefits from visual presentation
- Use data_table for detailed breakdowns, line_chart for trends, bar_chart for comparisons, metrics_card for key stats
- Reference widgets in your text: "As shown in the chart above..."

## Expertise Adaptation
Current mode: {state.expertise_level}
{"- Use plain language. Define technical terms in parentheses. Explain WHY data matters, not just WHAT it shows. Add context like 'this means the company is taking longer to collect payments.'" if state.expertise_level == "beginner" else "- Use standard financial terminology. Be concise. Focus on the data and analysis."}

## Current Context
Active tickers: {', '.join(state.active_tickers) or 'None'}
Active timeframe: {state.active_timeframe or 'Not set'}
Widgets on canvas: {len(state.canvas_widgets)} items
"""
```

---

## Request/Response Schemas (`schemas.py`)

```python
class ChatMessage(BaseModel):
    role: str          # "user" or "assistant"
    content: str

class ChatMessageRequest(BaseModel):
    messages: list[ChatMessage]
    conversation_id: str | None = None
    expertise_level: str = "standard"  # "beginner" or "standard"

class ToolCallEvent(BaseModel):
    tool_name: str
    tool_input: dict | None = None
    status: str        # "calling" or "done"

class ChatMessageResponse(BaseModel):
    """Used for non-streaming responses or conversation persistence."""
    conversation_id: str
    message: ChatMessage
    tool_calls: list[ToolCallEvent] = []
    widgets: list[WidgetPayload] = []
```

---

## Error Handling

### Tool Execution Errors

When a tool call fails (bad ticker, API timeout, etc.):

1. Send an `error` SSE event so the frontend can show the failure
2. Return the error to Claude as a `tool_result` with `is_error: True`
3. Claude will typically acknowledge the failure and suggest alternatives
4. NEVER let a tool error crash the entire stream

### LLM API Errors

- Wrap the Claude API call in try/except
- On rate limit (429): yield an error event and close the stream
- On context too long: truncate older messages and retry once
- On other errors: yield a generic error event

### Timeout

- Set a maximum stream duration (e.g., 120 seconds)
- If the tool loop exceeds 5 iterations, force-stop and ask Claude to summarize with available data

---

## Testing the Chat System

### Tool Registry Tests

For each tool, verify with at least these query types:
- Direct: "Show me Apple's income statement" → `get_income_statement(AAPL)`
- Indirect: "How profitable is Apple?" → `get_income_statement(AAPL)`
- Ambiguous: "Tell me about Apple" → `get_company_profile(AAPL)` (NOT financials)
- Multi-tool: "Compare Apple and Microsoft margins" → 2× `get_income_statement`
- Negative: "What's the weather?" → no tools

### SSE Stream Tests

- Verify all event types parse correctly on the frontend
- Test with slow tool calls (add artificial delay) to verify streaming UX
- Test tool errors (bad ticker) to verify graceful degradation
- Test context length limits by sending very long conversation histories

### Integration Tests

```python
# Test that the full loop works end-to-end
async def test_chat_basic():
    response = client.post("/api/v1/chat/message", json={
        "messages": [{"role": "user", "content": "What does Apple do?"}],
    }, headers=auth_headers)
    assert response.status_code == 200
    events = parse_sse(response.text)
    assert any(e["type"] == "tool_call" and e["data"]["tool_name"] == "get_company_profile" for e in events)
    assert any(e["type"] == "text" for e in events)
    assert events[-1]["type"] == "done"
```