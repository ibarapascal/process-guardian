# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
