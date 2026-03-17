# agent-harnesses

A collection of AI agent harnesses — configuration bundles for Claude Code, Cursor, and OpenCode that can be dropped into any project via symlinks.

Each harness lives under `harness/` and exposes a consistent directory structure. A `setup-harness.sh` script at the consuming project's root creates symlinks so that tools (`.claude`, `.cursor`, `.rules`, etc.) resolve to the harness without scattering config files across the repo root.

---

## What's in a harness

```
harness/
├── claude/          # Claude Code: CLAUDE.md, AGENTS.md, settings, hooks, commands, skills
├── cursor/          # Cursor IDE: workspace settings + .mdc rule files
├── opencode/        # OpenCode: opencode.json config + agents
└── rules/           # Canonical rule Markdown shared by all three tools
    └── agents/      # Agent prompt sources (AGENTS.md points here)
```

See [`harness/README.md`](harness/README.md) for the full symlink map, hook lifecycle, and agent architecture.

---

## Usage

1. Copy (or submodule) this repo into your project, e.g. as `harness/`.
2. Run `setup-harness.sh` from your project root to create the expected symlinks.
3. Customise the rule files under `harness/rules/` for your project.

---

## Branches

| Branch | Description |
|--------|-------------|
| `main` | Stable, generic harness skeleton |
| `argus` | Argus-specific prompts, skills, and hooks (3Epsilon finance dashboard) |

---

## Contributing

Rules are the source of truth. When updating agent behaviour, edit `harness/rules/agents/*.md` first, then mirror to `harness/claude/agents/` and `harness/opencode/agents/` as needed.
