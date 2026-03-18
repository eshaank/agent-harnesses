# Agent Harnesses

A composable AI agent configuration framework for **Claude Code**, **Cursor**, and **OpenCode**. Drop it into any project, run the setup wizard, and get working hooks, rules, commands, agents, and skills — with zero project-specific content unless you opt into a preset.

---

## Quick Start

```bash
# Option 1: Run from inside your project (harness/ is a subdirectory)
./harness/setup-harness.sh

# Option 2: Point at any project from the harness repo
./harness/setup-harness.sh ~/projects/my-app
```

The wizard will:

1. **Detect** your stack (Python, TypeScript, React, Go, Rust, etc.)
2. **List** available presets — pick the ones that match your project
3. **Merge** core + selected presets into `harness/output/`
4. **Symlink** from project root so every tool finds its config

```bash
# Rebuild after editing core/ or presets/:
./harness/setup-harness.sh --update ~/projects/my-app

# Replace symlinks with standalone copies:
./harness/setup-harness.sh --eject ~/projects/my-app
```

---

## Architecture

```mermaid
flowchart TB
    subgraph harness["harness/"]
        direction TB
        subgraph core["core/ — universal"]
            rules_c["rules/"]
            hooks_c["hooks/"]
            commands_c["commands/"]
            agents_c["agents/"]
            skills_c["skills/"]
        end

        subgraph presets["presets/ — project-specific"]
            argus["argus/"]
            other["your-project/"]
        end

        build["build.py"]
        setup["setup-harness.sh"]
        config["harness.config.json"]

        subgraph output["output/ — generated"]
            out_claude["claude/"]
            out_cursor["cursor/"]
            out_opencode["opencode/"]
            out_rules["rules/"]
        end
    end

    core --> build
    presets --> build
    config --> build
    setup --> config
    setup --> build
    build --> output
```

### How the build works

`build.py` reads `harness.config.json` and merges everything:

```mermaid
flowchart LR
    subgraph inputs["Inputs"]
        CR["core/rules/*.md"]
        CH["core/hooks/*.sh"]
        CC["core/commands/*.md"]
        CA["core/agents/"]
        CS["core/skills/"]
        PR["preset/rules/*.md"]
        PH["preset/hooks/*.sh"]
        PC["preset/commands/*.md"]
        PA["preset/agents/"]
        PS["preset/skills/"]
    end

    subgraph merge["build.py"]
        MR["Merge rules"]
        MH["Merge hooks"]
        MC["Merge commands"]
        MA["Merge agents"]
        MS["Merge skills"]
        TV["Resolve {{variables}}"]
    end

    subgraph output["output/"]
        CLAUDE["claude/CLAUDE.md"]
        SETTINGS["claude/settings.json"]
        HOOKS["claude/hooks/"]
        CMDS["claude/commands/"]
        RULES["rules/*.md"]
        CURSOR["cursor/rules/*.mdc"]
        OC["opencode/opencode.json"]
    end

    CR & PR --> MR --> RULES
    CH & PH --> MH --> HOOKS
    CC & PC --> MC --> CMDS
    CA & PA --> MA
    CS & PS --> MS
    MR --> CLAUDE
    MH --> SETTINGS
    TV --> CLAUDE
    MR --> CURSOR
    MR --> OC
```

**Key behavior**: When core and a preset both declare hooks for the same matcher (e.g. `Bash`), their hook lists are **concatenated** — nothing is overwritten.

---

## Symlink Layout

After setup, symlinks at the project root point into `harness/output/`, so tools see their standard config locations:

```mermaid
flowchart LR
    subgraph root["project root (symlinks)"]
        L1[".claude"]
        L2[".cursor"]
        L3[".rules"]
        L4["CLAUDE.md"]
        L5["AGENTS.md"]
        L6[".mcp.json"]
    end

    subgraph output["harness/output/"]
        O1["claude/"]
        O2["cursor/"]
        O3["rules/"]
        O4["claude/CLAUDE.md"]
        O5["claude/AGENTS.md"]
        O6["claude/mcp.json"]
    end

    L1 --> O1
    L2 --> O2
    L3 --> O3
    L4 --> O4
    L5 --> O5
    L6 --> O6
```

All three tools (Claude Code, Cursor, OpenCode) consume the **same rules** from `output/rules/` — single source of truth:

```mermaid
flowchart TB
    subgraph rules["output/rules/"]
        base["base.md"]
        git["git-workflow.md"]
        extra["preset rules..."]
    end

    subgraph consumers["Tool configs"]
        claude["CLAUDE.md\n@.rules/base.md\n@.rules/git-workflow.md"]
        cursor[".cursor/rules/*.mdc\n@.rules/base.md"]
        opencode["opencode.json\ninstructions: [.rules/...]"]
    end

    rules --> claude
    rules --> cursor
    rules --> opencode
```

---

## Hook Lifecycle

Claude Code hooks run at three phases. Each hook receives the tool call as JSON on stdin and can **block** an operation by exiting with code 2.

```mermaid
flowchart LR
    subgraph pre["PreToolUse"]
        direction TB
        P1["Read | Edit | Write"]
        P2["Bash"]
        P1 --> block_secrets["block-secrets.py\n(block .env, credentials)"]
        P2 --> check_branch["check-branch.sh\n(block commits to main)"]
        P2 --> check_ports["check-ports.sh\n(block if port in use)"]
    end

    subgraph post["PostToolUse"]
        W["Write"] --> lint["lint-on-save.sh\n(auto-lint written files)"]
    end

    subgraph stop["Stop"]
        S1["verify-no-secrets.sh\n(scan staged files)"]
        S2["check-rulecatch.sh"]
        S3["check-env-sync.sh\n(.env ↔ .env.example)"]
    end
```

Presets can **add** hooks to any phase/matcher. For example, the Argus preset adds `check-rybbit.sh` and `check-e2e.sh` to the `Bash` matcher — they run alongside the core hooks.

---

## What's Included

### Core (always installed)

| Category | Contents |
|----------|----------|
| **Rules** | `base.md` (security, workflow, naming), `git-workflow.md` (branch-first) |
| **Hooks** | `block-secrets.py`, `check-branch.sh`, `check-ports.sh`, `lint-on-save.sh`, `verify-no-secrets.sh`, `check-env-sync.sh`, `check-rulecatch.sh` |
| **Commands** | `/help`, `/commit`, `/review`, `/worktree`, `/security-check`, `/refactor`, `/test-plan`, `/progress`, `/optimize-docker`, `/doctor`, `/skills`, `/test-harness` |
| **Agents** | Code reviewer (read-only audit), Test writer (creates tests with assertions) |
| **Skills** | Code review (triggered by "review", "audit", "check code") |

### Presets

Project-specific bundles that layer on top of core. Each has a `preset.json` declaring variables, rules, hooks, commands, skills, and agents.

| Preset | Description | Stack |
|--------|-------------|-------|
| `argus` | Financial research terminal — 13 DDD domains, LLM chat, widget canvas | React, FastAPI, Supabase |

---

## Template Variables

Core files can reference `{{VARIABLE_NAME}}` placeholders that resolve at build time:

| Variable | Default | Description |
|----------|---------|-------------|
| `{{PROJECT_NAME}}` | Directory name | Used in `/help` header, CLAUDE.md title |
| `{{DEFAULT_BRANCH}}` | `main` | Protected branch name |
| `{{FRONTEND_DIR}}` | `frontend` | Frontend source directory |
| `{{BACKEND_DIR}}` | `backend` | Backend source directory |

Variables are resolved in priority order: user config > preset defaults > built-in defaults.

---

## Creating a Preset

1. Create `harness/presets/<name>/preset.json`:

```json
{
  "name": "my-project",
  "description": "My project description",
  "version": "1.0.0",
  "stack": ["python", "react"],
  "variables": {
    "PROJECT_NAME": "My Project",
    "PORT_MAPPINGS": { "dev": 3000 }
  },
  "rules": ["rules/my-rules.md"],
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{ "type": "command", "command": "bash .claude/hooks/my-hook.sh" }]
    }]
  },
  "commands": ["my-command.md"],
  "skills": ["my-skill"],
  "agents": ["my-agent"]
}
```

2. Add your rules, hooks, commands, skills, agents in the preset directory
3. Run `./harness/setup-harness.sh` and select your preset

See [`harness/presets/argus/`](harness/presets/argus/) for a complete example.

---

## CLI Reference

```
Usage: setup-harness.sh [OPTIONS] [PROJECT_PATH]
```

| Command | Description |
|---------|-------------|
| `setup-harness.sh [path]` | Interactive setup wizard (path defaults to parent of harness/) |
| `setup-harness.sh --update [path]` | Rebuild `output/` from existing `harness.config.json` |
| `setup-harness.sh --eject [path]` | Replace symlinks with standalone file copies |
| `setup-harness.sh --help` | Show usage |

---

## Feature Support by Tool

| Feature | Claude Code | Cursor | OpenCode |
|---------|:-----------:|:------:|:--------:|
| Rules   | Full        | Full   | Full     |
| Hooks   | Full        | --     | --       |
| Commands | Full       | --     | --       |
| Skills  | Full        | --     | --       |
| Agents  | Full        | --     | Partial  |
| MCP     | Full        | Full   | Full     |

---

## Requirements

- Python 3.8+
- Bash
- Git
