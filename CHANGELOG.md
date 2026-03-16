# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-03-16

### Added
- **Session PID Tracking**: Tracks processes spawned by Bash tool calls via `PostToolUse` hook
- Automatically cleans up orphan processes from crashed sessions on next `SessionStart`
- `SessionEnd` hook marks clean exits to distinguish from crashes
- Triple verification before killing tracked processes (PID + start time + command)
- `/check` command now shows tracked session processes alongside allowlist matches
- Stale tracking file cleanup (>24h) on session start
- Test suite for session tracking (`tests/test-tracking.sh`)
- `/check` command now shows tracked session processes alongside allowlist matches

### Changed
- `get_filter_pattern()` now auto-generated from pattern arrays (no manual dual-maintenance)

### How It Works
- `PostToolUse(Bash)` hook snapshots new PPID=1 processes after each Bash tool call (~50ms overhead)
- Processes are stored in per-session tracking files with full identification (PID, lstart, command)
- On next `SessionStart`: crash exit → auto-kill tracked orphans; clean exit → silently skip
- Complements existing allowlist scanning (allowlist handles known patterns, tracking handles arbitrary scripts)

## [0.1.1] - 2025-02-01

### Added
- `license` and `keywords` fields in plugin.json for marketplace discovery
- JSON output format with `systemMessage` for CLI display to user
- GitHub Actions auto-release workflow

### Fixed
- Release workflow permissions (contents: write)
- JSON escaping for special characters in command output

## [0.1.0] - 2025-01-31

### Added
- Initial release
- Auto-cleanup orphan Claude subagents and MCP servers on session start
- `/check` command for manual process management
- Cross-platform support (macOS, Linux, Windows)
- Allowlist-only approach for safe process termination
- Support for official @modelcontextprotocol servers
- Support for Playwright MCP, Context7 MCP, and other common MCP servers
- Detection of Playwright/Puppeteer-spawned browser instances
