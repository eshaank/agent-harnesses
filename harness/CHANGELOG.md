# Changelog

All notable changes to the agent-harnesses framework are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-03-17

### Added
- Core/preset architecture — universal harness with optional project-specific presets
- Interactive `setup-harness.sh` with stack detection
- `build.py` — merges core + presets into output/
- Template variable system (`{{PROJECT_NAME}}`, etc.)
- Hook test suite with 5 test files
- Skill manifest system (`manifest.json`)
- `/doctor` health check command
- `/skills` command to list available skills
- `/test-harness` command to run hook tests
- `VERSION` file and `CHANGELOG.md`

### Changed
- Moved Argus-specific content from core to `presets/argus/`
- `check-ports.sh` now reads port mappings from `harness.config.json`
- `review.md` command is now stack-agnostic with auto-detection
- `help.md` command now dynamically discovers commands

### Removed
- Hardcoded Argus references from all core files
