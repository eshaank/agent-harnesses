---
name: argus-design-system
description: "MANDATORY for all frontend work. The Argus design system for a conversational financial research terminal: dark-mode layered surfaces, DM Sans + JetBrains Mono + Fraunces typography, accent blue, rounded geometry, stroke-only icons. Load this skill BEFORE writing or modifying any frontend component. Covers CSS variables, color tokens, type scale, spacing, component patterns, widget cards, charts, and anti-patterns."
metadata:
  author: eshaank
  version: "2.0.0"
---

# Argus Design System

> **This is the single source of truth for all UI decisions.**
> Every component you build MUST follow these patterns exactly.
> Full reference: `project-docs/argus-style-guide.md`
> POC reference: `project-docs/argus-poc.html`

---

## CRITICAL: Read This First

Argus is NOT the old Bloomberg-terminal style dashboard. It is a **modern, softened** dark UI with rounded corners, generous (but not wasteful) spacing, and three distinct font families. If you're used to the old `ui-design-system` skill, reset your assumptions. Key differences:

- Corners are **rounded** (8–12px), not sharp
- Spacing is **comfortable** (20px card padding), not ultra-compact
- Fonts are **DM Sans / JetBrains Mono / Fraunces**, not system fonts
- There are **no shadows** — depth comes from surface color tiers
- Icons are **stroke-only** (stroke-width 1.8), never filled
- The accent color is **blue** (#5b8cff), not burgundy

---

## CSS Variables — The Complete Token Set

Every value in the UI comes from these variables. NEVER use hardcoded hex values.

```css
:root {
  /* Surfaces (4 tiers — each one step lighter) */
  --bg-primary: #0a0b0e;      /* App background, canvas */
  --bg-secondary: #111318;    /* Sidebar, chat panel, widget cards */
  --bg-tertiary: #181b22;     /* Inputs, toggles, nested containers */
  --bg-hover: #1e2230;        /* Hover state on any surface */

  /* Borders (2 tiers) */
  --border: #252a36;          /* Interactive elements — buttons, inputs */
  --border-subtle: #1c2028;   /* Structural dividers — panel edges */

  /* Text (3 tiers) */
  --text-primary: #e8eaf0;    /* Headings, primary content */
  --text-secondary: #8b90a0;  /* Body text, descriptions */
  --text-muted: #555b6e;      /* Labels, metadata, placeholders */

  /* Accent */
  --accent: #5b8cff;          /* Active states, focused borders, CTAs */
  --accent-dim: #3d6ae0;      /* Hover on accent elements */
  --accent-glow: rgba(91, 140, 255, 0.08);  /* Selected/active backgrounds */

  /* Semantic */
  --green: #34d399;
  --green-dim: rgba(52, 211, 153, 0.12);
  --red: #f87171;
  --red-dim: rgba(248, 113, 113, 0.12);
  --amber: #fbbf24;

  /* Charts (use in order) */
  --chart-1: #5b8cff;         /* Primary series */
  --chart-2: #a78bfa;         /* Secondary series */
  --chart-3: #34d399;         /* Tertiary series */
  --chart-4: #fbbf24;         /* Quaternary series */
}
```

### Surface Layering Rule

Each element sits on a surface **one tier lighter** than its parent:

```
--bg-primary (app shell)
  └── --bg-secondary (sidebar, chat panel, widget card)
        └── --bg-tertiary (input fields, toggles inside panels)
              └── --bg-hover (hover states inside tertiary containers)
```

NEVER skip tiers for containers. Small elements (badges, pills) can sit on any tier.

---

## Typography

### Three Font Families

| Role | Family | Weights | When To Use |
|------|--------|---------|-------------|
| **Body / UI** | `DM Sans` | 400, 500, 600, 700 | All interface text, labels, buttons, chat messages |
| **Data / Numbers** | `JetBrains Mono` | 400, 500 | Any number the user might scan or compare: prices, percentages, metrics, tickers, dates in data contexts |
| **Display** | `Fraunces` | 300, 600 | Canvas titles, empty state headings — serif for warmth. Used sparingly. |

### Type Scale (complete)

| Element | Size | Weight | Family | Color |
|---------|------|--------|--------|-------|
| Canvas title | 18px | 600 | Fraunces | `--text-primary` |
| Chat header | 14px | 600 | DM Sans | `--text-primary` |
| Section label | 10–11px | 600 | DM Sans | `--text-muted` |
| Body / chat | 13.5px | 400 | DM Sans | `--text-secondary` |
| Sidebar item | 13px | 500 | DM Sans | `--text-primary` |
| Sidebar meta | 11px | 400 | DM Sans | `--text-muted` |
| Button label | 11–12px | 500 | DM Sans | `--text-secondary` |
| Table header | 11px | 600 | DM Sans | `--text-muted` |
| Table data | 13px | 400 | DM Sans | `--text-secondary` |
| Metric value | 20px | 500 | JetBrains Mono | `--text-primary` |
| Change badge | 11px | 500 | JetBrains Mono | Semantic color |
| Inline metric | 12px | 400 | JetBrains Mono | `--accent` |
| Ticker badge | 10px | 600 | JetBrains Mono | `--text-secondary` |
| Chart label | 10px | 400 | JetBrains Mono | `--text-muted` |
| Tool call | 11px | 400 | JetBrains Mono | `--text-secondary` |
| Footer | 10px | 400 | DM Sans | `--text-muted` |

### Section Labels

ALL section/category labels use this pattern — it's the primary "this is a label" signal:

```css
font-size: 10–11px;
font-weight: 600;
letter-spacing: 0.06–0.08em;
text-transform: uppercase;
color: var(--text-muted);
```

---

## Layout

### Four-Column Grid

```css
.app {
  display: grid;
  grid-template-columns: 56px 280px 1fr 420px;
  height: 100vh;
}
```

| Column | Width | Content |
|--------|-------|---------|
| Icon rail | 56px | Nav icons, logo |
| Sidebar | 280px | Templates, history |
| Widget canvas | `1fr` | Charts, tables, metrics |
| Chat panel | 420px | Conversation, input |

Full-viewport height, no outer scroll. Each column scrolls independently.

### Widget Canvas Sub-Grid

```css
.widget-canvas {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
  padding: 24px;
  align-content: start;
}
.widget.wide { grid-column: 1 / -1; }
```

### Spacing Scale (4px base)

| Token | Pixels | Usage |
|-------|--------|-------|
| xs | 4px | Icon-label gap, badge padding |
| sm | 8px | Small component padding, compact gaps |
| md | 12px | Input padding, list items |
| lg | 16px | Panel padding, widget gap |
| xl | 20px | Chat area padding |
| 2xl | 24px | Canvas padding |

---

## Border Radius

| Size | Radius | Usage |
|------|--------|-------|
| xs | 2–3px | Chart bar tops, legend dots |
| sm | 4px | Badges, toggle buttons, small pills |
| md | 6px | Icon backgrounds, small action buttons |
| lg | 8px | Inputs, sidebar items, rail buttons |
| xl | 10–12px | Widget cards, chat input wrapper |
| pill | 20px | Suggestion chips |
| circle | 50% | Status dot only |

**Rule:** Outer container radius ≥ inner element radius. A widget card (12px) contains toggles (4px).

---

## Icons

- **Style:** Stroke-only SVGs, NEVER filled
- **Stroke width:** 1.8 (standard), 2.0 (inside small containers)
- **Viewbox:** `0 0 24 24`
- **Line cap/join:** round
- **Sizes:** 18px in rail, 13–14px in sidebar, 14px in buttons, 10px in tool calls
- **Colors:** `--text-muted` default → `--text-secondary` hover → `--accent` active

---

## Component Patterns

### Widget Card

```css
background: var(--bg-secondary);
border: 1px solid var(--border-subtle);
border-radius: 12px;
padding: 20px;
/* Hover: border → var(--border) over 0.2s */
```

Every widget has: header (label + optional controls) → data area → optional legend.

### Buttons

**Ghost:** `bg: none | --bg-tertiary`, `border: 1px solid --border`, `radius: 6–8px`
**Primary (send):** `bg: --accent`, `border: none`, `radius: 8px`, `color: white`
**Toggle group:** Container `--bg-tertiary` / `radius: 6px`, buttons `radius: 4px`, active `--bg-hover` or `--accent`
**Suggestion chip:** `bg: --bg-tertiary`, `border: 1px solid --border`, `radius: 20px` → hover: accent border/text

### Inputs

```css
background: var(--bg-tertiary);
border: 1px solid var(--border);
border-radius: 8px;
padding: 8–10px 12px;
color: var(--text-primary);
font-size: 13–13.5px;
/* Focus: border-color → var(--accent) */
```

### Data Tables

```css
/* Headers: 11px uppercase --text-muted, border-bottom --border */
/* Cells: 13px --text-secondary, border-bottom --border-subtle */
/* First column: --text-primary, font-weight 500 */
/* Numeric columns: right-aligned, JetBrains Mono */
/* Last row: no bottom border */
```

### Metric Cards

Vertical stack: label (11px `--text-muted`) → value (20px JetBrains Mono) → change badge (11px, semantic color on dim background, `radius: 4px`, `padding: 1px 6px`, arrow character ▲/▼).

### Chat Messages

- User: sender "YOU" uppercase `--text-muted`, body `--text-secondary`
- AI: sender "ARGUS" uppercase `--accent`, optional tool calls, body with `<strong>` in `--text-primary`, optional suggestion chips
- Animation: `0.3s ease-out` slide-up (translateY 8px → 0, opacity 0 → 1)

### Inline Metrics (Chat)

```css
font-family: JetBrains Mono;
font-size: 12px;
color: var(--accent);
background: var(--accent-glow);
padding: 1px 6px;
border-radius: 4px;
```

Green variant: `--green` text on `--green-dim` background.

### Tool Call Indicator

```css
background: var(--bg-tertiary);
border: 1px solid var(--border-subtle);
border-radius: 8px;
padding: 8px 12px;
/* Contains: icon (20px, --accent-glow bg) → name (JetBrains Mono 11px) → params (11px --text-muted) → status ✓ (--green) */
```

---

## Charts

### Bar Charts
- Colors: chart palette in order
- Rounded tops (3px), flat bottoms
- 3px gap within group, 1px between groups
- Hover: opacity 0.8
- Legend below, 14px margin-top

### Line Charts
- SVG polyline, stroke-width 2px, round caps/joins
- Area fill: line color gradient at 10–15% opacity → transparent
- Grid lines: 0.5px `--border-subtle`
- End dots: 3px radius, filled with line color

### Legend
- Flex row, 16px gap
- Colored dot: 8px square, border-radius 2px
- Label: 12px `--text-secondary`

---

## Motion

| Duration | Usage |
|----------|-------|
| 0.12s | Micro-interactions: hover bg, toggle |
| 0.15s | Standard: border-color, text-color |
| 0.2s | Widget card hover border |
| 0.3s | Chat message entrance |

Timing: `ease` or `ease-out` only. NEVER `linear`, `bounce`, `elastic`, or `spring`.

Chat messages animate in. Widgets appear instantly. No page-load animations.

---

## Scrollbars

```css
::-webkit-scrollbar { width: 5–6px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: var(--border); border-radius: 3px; }
```

---

## Anti-Patterns Checklist

Before submitting ANY component, verify NONE of these exist:

- [ ] Hardcoded hex color instead of CSS variable
- [ ] `box-shadow` used for elevation (only allowed on status dot glow)
- [ ] Filled icon instead of stroke-only
- [ ] Border thicker than 1px
- [ ] Sharp corners (0px radius) on any container
- [ ] Fully circular container (except 8px status dot)
- [ ] `font-family: Inter`, `Arial`, `Roboto`, or system fonts
- [ ] Number displayed without JetBrains Mono in a data context
- [ ] Logo gradient used on anything other than the logo
- [ ] Accent color as large background fill
- [ ] `bounce`, `spring`, or `elastic` animation
- [ ] New color not in the token set
- [ ] DM Sans number next to JetBrains Mono number in same table
- [ ] Missing hover state on interactive element
- [ ] Section label without uppercase + letter-spacing