# Agent Harnesses

A composable AI agent configuration framework for Claude Code, Cursor, and OpenCode.

## Quick Start

```bash
# From your project root:
./harness/setup-harness.sh
```

The setup wizard will:
1. Detect your project stack (Python, TypeScript, React, etc.)
2. Ask which presets to apply
3. Generate merged configuration
4. Create symlinks

## Architecture

```
harness/
├── core/          # Universal — security hooks, branch protection, linting, code review
├── presets/       # Project-specific bundles (argus, etc.)
├── output/        # Generated at setup (core + selected presets merged)
├── tests/         # Hook test suite
├── build.py       # Merge engine
└── setup-harness.sh
```

### Core Layer

Always included. Provides:
- **Rules**: Security, workflow, naming conventions (`core/rules/`)
- **Hooks**: Secret blocking, branch protection, port detection, linting, env sync (`core/hooks/`)
- **Commands**: `/help`, `/commit`, `/review`, `/worktree`, `/security-check`, `/refactor`, `/test-plan`, `/progress`, `/optimize-docker`, `/doctor`, `/skills`, `/test-harness` (`core/commands/`)
- **Agents**: Code reviewer, test writer (`core/agents/`)
- **Skills**: Code review (`core/skills/`)

### Preset Layer

Project-specific bundles that add rules, hooks, commands, skills, and agents on top of core.

Each preset has a `preset.json` that declares:
- Variables (project name, paths, port mappings)
- Additional rules, hooks, commands, skills, agents
- MCP server configurations
- Cursor/OpenCode settings

## Commands

| Command | Description |
|---------|-------------|
| `setup-harness.sh` | Interactive setup |
| `setup-harness.sh --update` | Rebuild output from existing config |
| `setup-harness.sh --eject` | Replace symlinks with copies |
| `/doctor` | Validate installation |
| `/test-harness` | Run hook tests |
| `/skills` | List available skills |

## Creating a Preset

1. Create `harness/presets/<name>/preset.json`
2. Add rules, hooks, commands, skills, agents as needed
3. Run `setup-harness.sh` and select your preset

See `presets/argus/` for a complete example.

## Feature Support

| Feature | Claude Code | Cursor | OpenCode |
|---------|:-----------:|:------:|:--------:|
| Rules   | Full        | Full   | Full     |
| Hooks   | Full        | —      | —        |
| Commands | Full       | —      | —        |
| Skills  | Full        | —      | —        |
| Agents  | Full        | —      | Partial  |
| MCP     | Full        | Full   | Full     |

## How It Works

The `build.py` script merges `core/` + selected presets into `output/`. Symlinks from the project root point into `output/`, so tools find their configs in standard locations.

```
project-root/
├── .claude     → harness/output/claude/
├── .cursor     → harness/output/cursor/
├── .rules      → harness/output/rules/
├── CLAUDE.md   → harness/output/claude/CLAUDE.md
├── AGENTS.md   → harness/output/claude/AGENTS.md
└── harness/
    ├── core/
    ├── presets/
    └── output/   (generated)
```

## Requirements

- Python 3.8+
- Bash
- Git
