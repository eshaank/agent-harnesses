#!/usr/bin/env python3
"""
Build script for agent-harnesses.
Reads harness.config.json, merges core/ + selected presets/ → output/.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import sys
from pathlib import Path


# Built-in defaults for template variables
DEFAULTS = {
    "PROJECT_NAME": "Project",
    "PROJECT_DESCRIPTION": "",
    "TEAM_NAME": "",
    "DEFAULT_BRANCH": "main",
    "FRONTEND_DIR": "frontend",
    "BACKEND_DIR": "backend",
}


def load_config(config_path: str) -> dict:
    with open(config_path) as f:
        return json.load(f)


def load_preset(presets_dir: Path, preset_name: str) -> dict:
    preset_file = presets_dir / preset_name / "preset.json"
    if preset_file.exists():
        with open(preset_file) as f:
            return json.load(f)
    return {}


def clean_output(output_dir: Path) -> None:
    """Remove old output directory."""
    if output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True)


def resolve_variables(config: dict, presets_dir: Path, selected_presets: list) -> dict:
    """Build the final variable dict from defaults + presets + user config."""
    variables = dict(DEFAULTS)

    # Layer in preset variables
    for preset_name in selected_presets:
        preset = load_preset(presets_dir, preset_name)
        for key, value in preset.get("variables", {}).items():
            # Skip complex types (lists, dicts) — those are handled separately
            if isinstance(value, str):
                variables[key] = value

    # Layer in user config variables (highest priority)
    for key, value in config.get("variables", {}).items():
        if isinstance(value, str):
            variables[key] = value

    return variables


def render_template(content: str, variables: dict) -> str:
    """Replace {{VARIABLE_NAME}} patterns in content."""
    def replacer(match):
        var_name = match.group(1).strip()
        return variables.get(var_name, match.group(0))

    return re.sub(r'\{\{(\s*[A-Z_][A-Z0-9_]*\s*)\}\}', replacer, content)


def copy_tree(src: Path, dst: Path, variables: dict | None = None) -> None:
    """Copy directory tree, merging into existing destination.
    If variables is provided, render templates in text files.
    """
    if not src.exists():
        return
    for item in src.rglob("*"):
        if item.is_file():
            rel = item.relative_to(src)
            # Remove .tmpl extension
            if rel.suffix == ".tmpl":
                rel = rel.with_suffix("")
            dest_file = dst / rel
            dest_file.parent.mkdir(parents=True, exist_ok=True)

            # Render templates for text files if variables provided
            if variables and item.suffix in (".md", ".json", ".tmpl", ".sh", ".py", ".mdc"):
                try:
                    content = item.read_text()
                    content = render_template(content, variables)
                    dest_file.write_text(content)
                except UnicodeDecodeError:
                    shutil.copy2(item, dest_file)
            else:
                shutil.copy2(item, dest_file)


def merge_hooks(core_hooks: dict, preset_hooks: dict) -> dict:
    """Merge hook configurations from core and preset.

    Both are dicts with keys like "PreToolUse", "PostToolUse", "Stop".
    Each value is a list of {matcher, hooks} objects.
    Same-matcher entries get their hooks lists concatenated.
    Different-matcher entries are appended.
    """
    merged = {}
    for phase in set(list(core_hooks.keys()) + list(preset_hooks.keys())):
        core_entries = core_hooks.get(phase, [])
        preset_entries = preset_hooks.get(phase, [])

        # Index core entries by matcher
        by_matcher = {}
        for entry in core_entries:
            matcher = entry.get("matcher", "__stop__")
            by_matcher[matcher] = {
                "matcher": matcher,
                "hooks": list(entry.get("hooks", []))
            }

        # Merge preset entries
        for entry in preset_entries:
            matcher = entry.get("matcher", "__stop__")
            if matcher in by_matcher:
                by_matcher[matcher]["hooks"].extend(entry.get("hooks", []))
            else:
                by_matcher[matcher] = {
                    "matcher": matcher,
                    "hooks": list(entry.get("hooks", []))
                }

        result = []
        for matcher, data in by_matcher.items():
            if matcher == "__stop__":
                result.append({"hooks": data["hooks"]})
            else:
                result.append({"matcher": data["matcher"], "hooks": data["hooks"]})
        merged[phase] = result

    return merged


def build_claude_md(config: dict, core_dir: Path, presets_dir: Path, selected_presets: list) -> str:
    """Build the final CLAUDE.md content."""
    lines = [f"# CLAUDE.md — {config.get('project_name', 'Project')}", ""]

    # Always include core rules
    lines.append("@.rules/base.md")
    lines.append("@.rules/git-workflow.md")

    # Include preset rules
    for preset_name in selected_presets:
        preset = load_preset(presets_dir, preset_name)
        for rule_file in preset.get("rules", []):
            # Strip "rules/" prefix since they're flattened into .rules/
            rule_name = rule_file.replace("rules/", "")
            lines.append(f"@.rules/{rule_name}")

    lines.append("")
    lines.append("---")
    lines.append("")

    # Skill loading instructions from presets
    skill_instructions = []
    for preset_name in selected_presets:
        preset = load_preset(presets_dir, preset_name)
        skills = preset.get("skills", [])
        if skills:
            skill_instructions.append(f"## Skills (from {preset_name} preset)")
            skill_instructions.append("")
            skill_instructions.append("Before starting a task, check available skills and load the most relevant one:")
            skill_instructions.append("")
            for skill in skills:
                skill_instructions.append(f"- `{skill}`")
            skill_instructions.append("")

    if skill_instructions:
        lines.append("## Claude Code: Load Skills Before Working")
        lines.append("")
        lines.extend(skill_instructions)

    return "\n".join(lines) + "\n"


def build_agents_md(core_dir: Path, presets_dir: Path, selected_presets: list) -> str:
    """Build the final AGENTS.md content."""
    lines = [
        "# Agents",
        "",
        "Project rules are in `.rules/`. Agent prompt bodies are in `.rules/agents/`.",
        "",
        "## Available Agents",
        "",
    ]

    # Core agents
    agents_dir = core_dir / "agents" / "rules"
    if agents_dir.exists():
        for agent_file in sorted(agents_dir.glob("*.md")):
            name = agent_file.stem
            lines.append(f"### {name}")
            # Read first line for description
            first_line = agent_file.read_text().strip().split("\n")[0]
            lines.append(first_line)
            lines.append(f"- Prompt: `.rules/agents/{name}.md`")
            lines.append("")

    # Preset agents
    for preset_name in selected_presets:
        preset_agents_dir = presets_dir / preset_name / "agents" / "rules"
        if preset_agents_dir.exists():
            for agent_file in sorted(preset_agents_dir.glob("*.md")):
                name = agent_file.stem
                lines.append(f"### {name}")
                first_line = agent_file.read_text().strip().split("\n")[0]
                lines.append(first_line)
                lines.append(f"- Prompt: `.rules/agents/{name}.md`")
                lines.append("")

    return "\n".join(lines) + "\n"


def build_settings_json(config: dict, core_dir: Path, presets_dir: Path, selected_presets: list) -> dict:
    """Build the final settings.json for Claude Code."""

    # Core hooks
    core_hooks = {
        "PreToolUse": [
            {
                "matcher": "Read|Edit|Write",
                "hooks": [
                    {"type": "command", "command": "python3 .claude/hooks/block-secrets.py"}
                ]
            },
            {
                "matcher": "Bash",
                "hooks": [
                    {"type": "command", "command": "bash .claude/hooks/check-branch.sh"},
                    {"type": "command", "command": "bash .claude/hooks/check-ports.sh"}
                ]
            }
        ],
        "PostToolUse": [
            {
                "matcher": "Write",
                "hooks": [
                    {"type": "command", "command": "bash .claude/hooks/lint-on-save.sh"}
                ]
            }
        ],
        "Stop": [
            {
                "hooks": [
                    {"type": "command", "command": "bash .claude/hooks/verify-no-secrets.sh"},
                    {"type": "command", "command": "bash .claude/hooks/check-rulecatch.sh"},
                    {"type": "command", "command": "bash .claude/hooks/check-env-sync.sh"}
                ]
            }
        ]
    }

    # Merge preset hooks
    for preset_name in selected_presets:
        preset = load_preset(presets_dir, preset_name)
        preset_hooks = preset.get("hooks", {})
        if preset_hooks:
            core_hooks = merge_hooks(core_hooks, preset_hooks)

    return {
        "permissions": {
            "allow": [
                "Bash(*)",
                "Write(*)",
                "Edit(*)",
                "Read(*)"
            ]
        },
        "hooks": core_hooks
    }


def build_mcp_json(presets_dir: Path, selected_presets: list) -> dict | None:
    """Build mcp.json from preset MCP server configs."""
    servers = {}
    for preset_name in selected_presets:
        preset = load_preset(presets_dir, preset_name)
        for name, server_config in preset.get("mcp_servers", {}).items():
            servers[name] = server_config

    if servers:
        return {"mcpServers": servers}
    return None


def build_cursor_settings(config: dict, presets_dir: Path, selected_presets: list) -> dict:
    """Build cursor/settings.json."""
    settings: dict = {}

    for preset_name in selected_presets:
        preset = load_preset(presets_dir, preset_name)
        cursor_config = preset.get("cursor", {})

        if "plugins" in cursor_config:
            settings.setdefault("plugins", {}).update(cursor_config["plugins"])
        if "recommendations" in cursor_config:
            existing = settings.get("recommendations", [])
            for rec in cursor_config["recommendations"]:
                if rec not in existing:
                    existing.append(rec)
            settings["recommendations"] = existing

        # MCP servers
        for name, server_config in preset.get("mcp_servers", {}).items():
            settings.setdefault("mcpServers", {})[name] = {"url": server_config.get("url", "")}

    # Python interpreter from preset variables
    for preset_name in selected_presets:
        preset = load_preset(presets_dir, preset_name)
        interp = preset.get("variables", {}).get("PYTHON_INTERPRETER")
        if interp:
            settings["python.defaultInterpreterPath"] = interp

    return settings


def build_opencode_json(config: dict, presets_dir: Path, selected_presets: list) -> dict:
    """Build opencode.json."""
    instructions = [
        ".rules/base.md",
        ".rules/git-workflow.md"
    ]

    # Add preset rules
    for preset_name in selected_presets:
        preset = load_preset(presets_dir, preset_name)
        for rule_file in preset.get("rules", []):
            rule_name = rule_file.replace("rules/", "")
            instructions.append(f".rules/{rule_name}")

    result: dict = {
        "$schema": "https://opencode.ai/config.json",
        "instructions": instructions
    }

    # MCP servers
    mcp = {}
    for preset_name in selected_presets:
        preset = load_preset(presets_dir, preset_name)
        for name, server_config in preset.get("mcp_servers", {}).items():
            mcp[name.replace("-", "_")] = {
                "type": "remote",
                "url": server_config.get("url", ""),
                "enabled": True
            }
    if mcp:
        result["mcp"] = mcp

    return result


def generate_cursor_rules(rules_out: Path, cursor_rules_out: Path,
                          presets_dir: Path, selected_presets: list) -> None:
    """Generate .mdc files for each rule in the output rules directory."""
    cursor_rules_out.mkdir(parents=True, exist_ok=True)

    for rule_file in sorted(rules_out.glob("*.md")):
        if rule_file.name.startswith("agents"):
            continue
        name = rule_file.stem
        mdc_name = f"{name}.mdc"

        # Determine if this rule should always apply or use globs
        always_apply = name in ("base", "git-workflow")

        # Check presets for custom .mdc files
        for preset_name in selected_presets:
            preset_cursor_dir = presets_dir / preset_name / "cursor" / "rules"
            preset_mdc = preset_cursor_dir / mdc_name
            if preset_mdc.exists():
                # Preset has a custom .mdc — use it directly
                shutil.copy2(preset_mdc, cursor_rules_out / mdc_name)
                break
        else:
            # Generate a default .mdc
            content = f"---\ndescription: {name.replace('-', ' ').title()} rules\n"
            if always_apply:
                content += "alwaysApply: true\n"
            else:
                content += "alwaysApply: false\n"
            content += f"---\n\n@.rules/{rule_file.name}\n"
            (cursor_rules_out / mdc_name).write_text(content)


def main():
    if len(sys.argv) < 2:
        print("Usage: build.py <harness.config.json>")
        sys.exit(1)

    config_path = sys.argv[1]
    config = load_config(config_path)

    harness_dir = Path(config_path).parent
    core_dir = harness_dir / "core"
    presets_dir = harness_dir / "presets"
    output_dir = harness_dir / "output"

    selected_presets = config.get("presets", [])

    # Validate presets exist
    for preset_name in selected_presets:
        if not (presets_dir / preset_name / "preset.json").exists():
            print(f"ERROR: Preset '{preset_name}' not found at {presets_dir / preset_name}")
            sys.exit(1)

    print(f"  Building: core + {selected_presets}")

    # Resolve template variables
    variables = resolve_variables(config, presets_dir, selected_presets)

    # Clean output
    clean_output(output_dir)

    # ---- Build output/rules/ ----
    rules_out = output_dir / "rules"
    rules_out.mkdir(parents=True, exist_ok=True)

    # Copy core rules
    copy_tree(core_dir / "rules", rules_out, variables)

    # Copy preset rules (they go into rules/ alongside core rules)
    for preset_name in selected_presets:
        preset_rules = presets_dir / preset_name / "rules"
        if preset_rules.exists():
            copy_tree(preset_rules, rules_out, variables)

    # Copy agent prompt bodies into rules/agents/
    agents_rules_out = rules_out / "agents"
    agents_rules_out.mkdir(parents=True, exist_ok=True)
    copy_tree(core_dir / "agents" / "rules", agents_rules_out, variables)
    for preset_name in selected_presets:
        copy_tree(presets_dir / preset_name / "agents" / "rules", agents_rules_out, variables)

    # ---- Build output/claude/ ----
    claude_out = output_dir / "claude"
    claude_out.mkdir(parents=True, exist_ok=True)

    # CLAUDE.md
    (claude_out / "CLAUDE.md").write_text(
        build_claude_md(config, core_dir, presets_dir, selected_presets)
    )

    # AGENTS.md
    (claude_out / "AGENTS.md").write_text(
        build_agents_md(core_dir, presets_dir, selected_presets)
    )

    # settings.json
    settings = build_settings_json(config, core_dir, presets_dir, selected_presets)
    with open(claude_out / "settings.json", "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")

    # mcp.json
    mcp = build_mcp_json(presets_dir, selected_presets)
    if mcp:
        with open(claude_out / "mcp.json", "w") as f:
            json.dump(mcp, f, indent=2)
            f.write("\n")

    # Copy hooks (core + preset)
    hooks_out = claude_out / "hooks"
    hooks_out.mkdir(parents=True, exist_ok=True)
    copy_tree(core_dir / "hooks", hooks_out)
    for preset_name in selected_presets:
        copy_tree(presets_dir / preset_name / "hooks", hooks_out)
    # Make hooks executable
    for hook_file in hooks_out.iterdir():
        if hook_file.is_file():
            hook_file.chmod(0o755)

    # Copy agent metadata (Claude format)
    agents_out = claude_out / "agents"
    agents_out.mkdir(parents=True, exist_ok=True)
    copy_tree(core_dir / "agents" / "claude", agents_out, variables)
    for preset_name in selected_presets:
        copy_tree(presets_dir / preset_name / "agents" / "claude", agents_out, variables)

    # Copy commands (core + preset)
    commands_out = claude_out / "commands"
    commands_out.mkdir(parents=True, exist_ok=True)
    copy_tree(core_dir / "commands", commands_out, variables)
    for preset_name in selected_presets:
        copy_tree(presets_dir / preset_name / "commands", commands_out, variables)

    # Copy skills (core + preset)
    skills_out = claude_out / "skills"
    skills_out.mkdir(parents=True, exist_ok=True)
    copy_tree(core_dir / "skills", skills_out, variables)
    for preset_name in selected_presets:
        copy_tree(presets_dir / preset_name / "skills", skills_out, variables)

    # Merge skill manifests for reference
    merged_manifest = {"skills": {}}

    core_manifest = core_dir / "skills" / "manifest.json"
    if core_manifest.exists():
        with open(core_manifest) as f:
            data = json.load(f)
        merged_manifest["skills"].update(data.get("skills", {}))

    for preset_name in selected_presets:
        preset_manifest = presets_dir / preset_name / "skills" / "manifest.json"
        if preset_manifest.exists():
            with open(preset_manifest) as f:
                data = json.load(f)
            for skill_name, skill_data in data.get("skills", {}).items():
                skill_data["source_preset"] = preset_name
                merged_manifest["skills"][skill_name] = skill_data

    if merged_manifest["skills"]:
        with open(skills_out / "manifest.json", "w") as f:
            json.dump(merged_manifest, f, indent=2)
            f.write("\n")

    # ---- Build output/cursor/ ----
    cursor_out = output_dir / "cursor"
    cursor_out.mkdir(parents=True, exist_ok=True)

    cursor_settings = build_cursor_settings(config, presets_dir, selected_presets)
    if cursor_settings:
        with open(cursor_out / "settings.json", "w") as f:
            json.dump(cursor_settings, f, indent=2)
            f.write("\n")

    # Cursor rules — auto-generate + preset overrides
    cursor_rules_out = cursor_out / "rules"
    generate_cursor_rules(rules_out, cursor_rules_out, presets_dir, selected_presets)

    # ---- Build output/opencode/ ----
    opencode_out = output_dir / "opencode"
    opencode_out.mkdir(parents=True, exist_ok=True)

    opencode_config = build_opencode_json(config, presets_dir, selected_presets)
    with open(opencode_out / "opencode.json", "w") as f:
        json.dump(opencode_config, f, indent=2)
        f.write("\n")

    # OpenCode agents
    opencode_agents_out = opencode_out / "agents"
    opencode_agents_out.mkdir(parents=True, exist_ok=True)
    copy_tree(core_dir / "agents" / "opencode", opencode_agents_out, variables)
    for preset_name in selected_presets:
        copy_tree(presets_dir / preset_name / "agents" / "opencode", opencode_agents_out, variables)

    print(f"  Output written to: {output_dir}")
    print(f"  Files: {sum(1 for _ in output_dir.rglob('*') if _.is_file())}")


if __name__ == "__main__":
    main()
