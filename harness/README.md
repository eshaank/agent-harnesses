# Harness — AI / Editor Configuration

This directory holds **all AI and editor configuration in one place**. The repo root expects these paths (e.g. `.claude`, `.cursor`, `CLAUDE.md`). The `setup-harness.sh` script at repo root creates **symlinks** from the root into `harness/`, so tools see the same paths while the real files live here.

---

## Quick start

From the **repository root** (not inside `harness/`):

```bash
./setup-harness.sh
```

This creates the symlinks. Run it after cloning or whenever those links are missing.

---

## How the harness is mapped

### Symlink layout

Everything under `harness/` is exposed at the repo root via symlinks. No tool config lives at root; it all points here.

```mermaid
flowchart LR
  subgraph repo_root["Repo root"]
    L_claude[".claude"]
    L_cursor[".cursor"]
    L_opencode[".opencode"]
    L_rules[".rules"]
    L_claude_md["CLAUDE.md"]
    L_agents["AGENTS.md"]
    L_opencode_json["opencode.json"]
    L_mcp[".mcp.json"]
  end

  subgraph harness["harness/"]
    H_claude["claude/"]
    H_cursor["cursor/"]
    H_opencode["opencode/"]
    H_rules["rules/"]
    H_claude_md["claude/CLAUDE.md"]
    H_agents["claude/AGENTS.md"]
    H_opencode_json["opencode/opencode.json"]
    H_mcp["claude/mcp.json"]
  end

  L_claude --> H_claude
  L_cursor --> H_cursor
  L_opencode --> H_opencode
  L_rules --> H_rules
  L_claude_md --> H_claude_md
  L_agents --> H_agents
  L_opencode_json --> H_opencode_json
  L_mcp --> H_mcp
```

| At repo root (symlink) | Points to (in harness/) |
|------------------------|--------------------------|
| `.claude`              | `harness/claude`         |
| `.cursor`             | `harness/cursor`         |
| `.opencode`           | `harness/opencode`       |
| `.rules`              | `harness/rules`          |
| `CLAUDE.md`           | `harness/claude/CLAUDE.md` |
| `AGENTS.md`           | `harness/claude/AGENTS.md` |
| `opencode.json`       | `harness/opencode/opencode.json` |
| `.mcp.json`           | `harness/claude/mcp.json`        |

---

## Directory structure (harness/)

```mermaid
flowchart TB
  subgraph harness["harness/"]
    subgraph claude["claude/"]
      CLAUDE_md["CLAUDE.md"]
      AGENTS_md["AGENTS.md"]
      settings["settings.json"]
      settings_local["settings.local.json"]
      agents["agents/"]
      hooks["hooks/"]
      commands["commands/"]
      skills["skills/"]
      ROADMAP["ROADMAP/"]
    end

    subgraph cursor["cursor/"]
      c_settings["settings.json"]
      c_rules["rules/*.mdc"]
    end

    subgraph opencode["opencode/"]
      o_json["opencode.json"]
      o_agents["agents/"]
    end

    subgraph rules["rules/"]
      base["base.md"]
      arch["architecture.md"]
      git["git-workflow.md"]
      design["design-system.md"]
      rule_agents["agents/"]
    end
  end
```

| Directory   | Purpose |
|------------|---------|
| **harness/claude/** | Claude Code (Claude.dev) config: entrypoints, permissions, hooks, skills, agents, commands, ROADMAP. |
| **harness/cursor/** | Cursor IDE config: workspace settings and rule files (`.mdc`) that reference `.rules/`. |
| **harness/opencode/** | OpenCode config: `opencode.json` instructions and optional agents. |
| **harness/rules/**   | Canonical project rules (Markdown) used by CLAUDE.md, Cursor rules, and OpenCode. |

---

## How tools consume the rules

All three surfaces (Claude, Cursor, OpenCode) use the **same** rule content under `.rules/` (i.e. `harness/rules/`). The flow looks like this:

```mermaid
flowchart TB
  subgraph sources["Rule sources (harness/rules/)"]
    base["base.md"]
    arch["architecture.md"]
    git["git-workflow.md"]
    design["design-system.md"]
    agent_prompts["agents/*.md"]
  end

  subgraph claude_consume["Claude Code"]
    CLAUDE_md["CLAUDE.md"]
    CLAUDE_md -->|"@.rules/base.md\n@.rules/architecture.md\n..."| base
  end

  subgraph cursor_consume["Cursor"]
    mdc[".cursor/rules/*.mdc"]
    mdc -->|"@.rules/base.md\n@.rules/architecture.md\n..."| base
  end

  subgraph opencode_consume["OpenCode"]
    opencode_json["opencode.json"]
    opencode_json -->|"instructions: [.rules/...]"| base
  end
```

- **CLAUDE.md** (repo root → `harness/claude/CLAUDE.md`) includes `@.rules/base.md`, `@.rules/architecture.md`, etc., so Claude loads those files when resolving the `@` refs (and `.rules` is the symlink to `harness/rules`).
- **Cursor** `.mdc` files under `.cursor/rules/` (→ `harness/cursor/rules/`) use the same `@.rules/...` references, so Cursor loads the same Markdown from `harness/rules/`.
- **OpenCode** `opencode.json` lists the same paths in `instructions`; they are resolved relative to repo root, so again they point at `harness/rules/` via the `.rules` symlink.

---

## Claude hooks (when they run)

Claude Code uses `harness/claude/settings.json` (exposed as `.claude/settings.json`). Hooks run at different phases and reference scripts under `.claude/hooks/` (i.e. `harness/claude/hooks/`).

```mermaid
flowchart LR
  subgraph PreToolUse["PreToolUse"]
    P1["Read|Edit|Write"]
    P2["Bash"]
    P1 --> block_secrets["block-secrets.py"]
    P2 --> rybbit["check-rybbit.sh"]
    P2 --> branch["check-branch.sh"]
    P2 --> ports["check-ports.sh"]
    P2 --> e2e["check-e2e.sh"]
  end

  subgraph PostToolUse["PostToolUse"]
    W["Write"]
    W --> lint["lint-on-save.sh"]
  end

  subgraph Stop["Stop (session end)"]
    S1["verify-no-secrets.sh"]
    S2["check-rulecatch.sh"]
    S3["check-env-sync.sh"]
  end
```

| Phase       | Matcher        | Hooks |
|------------|----------------|--------|
| **PreToolUse** | `Read\|Edit\|Write` | `block-secrets.py` (avoid touching secrets) |
| **PreToolUse** | `Bash`         | `check-rybbit.sh`, `check-branch.sh`, `check-ports.sh`, `check-e2e.sh` |
| **PostToolUse** | `Write`      | `lint-on-save.sh` |
| **Stop**   | (all)          | `verify-no-secrets.sh`, `check-rulecatch.sh`, `check-env-sync.sh` |

All hook paths in settings use `.claude/hooks/...`; with `.claude` → `harness/claude`, they resolve to `harness/claude/hooks/`.

---

## Agents (code-reviewer, test-writer)

Agent **prompts** live in multiple places; they are intended to stay in sync:

```mermaid
flowchart LR
  subgraph prompts["Agent prompt content"]
    rules_agents["harness/rules/agents/"]
    claude_agents["harness/claude/agents/"]
    opencode_agents["harness/opencode/agents/"]
  end

  AGENTS_md["AGENTS.md"]
  AGENTS_md -->|"Prompt: .rules/agents/..."| rules_agents
```

- **AGENTS.md** (→ `harness/claude/AGENTS.md`) lists available agents and points to **`.rules/agents/<name>.md`** for the prompt body.
- The same agent names (e.g. `code-reviewer`, `test-writer`) may have parallel files under `harness/claude/agents/` and `harness/opencode/agents/` for tool-specific use; the canonical prompt used by AGENTS.md is under **harness/rules/agents/**.

Keep `harness/rules/agents/*.md` as the source of truth for what the agents do; duplicate agent dirs can mirror or extend that as needed.

---

## Summary

| Concept | Detail |
|--------|--------|
| **Single source of truth** | All AI/editor config lives under `harness/`. |
| **Repo root** | Only symlinks (and `setup-harness.sh`). Run `./setup-harness.sh` to create them. |
| **Rules** | `harness/rules/` is the canonical rules dir; CLAUDE.md, Cursor `.mdc`, and OpenCode all reference it via `.rules/`. |
| **Claude** | Entrypoints and hooks live in `harness/claude/`; hooks use paths like `.claude/hooks/...` (resolved via symlink). |
| **Cursor** | Settings and rule refs in `harness/cursor/`; rules use `@.rules/...` to load `harness/rules/`. |
| **OpenCode** | Config in `harness/opencode/opencode.json`; instructions point at `.rules/...`. |

If a path is documented as `.claude`, `.cursor`, `.rules`, or `CLAUDE.md` / `AGENTS.md` / `opencode.json` at repo root, it is a symlink into this harness.
