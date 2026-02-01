<div align="center">

# Process Guardian

**Auto-cleanup orphan processes from Claude Code sessions**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blueviolet)](https://docs.anthropic.com/en/docs/claude-code)
[![Platform](https://img.shields.io/badge/platform-macOS%20|%20Linux%20|%20Windows-lightgrey)](https://github.com/ibarapascal/process-guardian)
[![MCP Compatible](https://img.shields.io/badge/MCP-Compatible-green)](https://modelcontextprotocol.io/)

</div>

---

## Overview

Claude Code plugin for auto-cleanup of orphan processes from AI coding sessions.

**The problem:**
- When running multiple agents or MCP servers, unexpected exits happen—OOM kills, session crashes, failed startups
- These leave orphan processes behind, some silently consume 100% CPU in the background
- Others go unnoticed until your machine freezes—manual cleanup gets old fast

**What it does:**
- Automatically cleans up orphan Claude subagents and MCP servers on session start
- Provides `/check` command for manual process management
- Supports macOS, Linux, and Windows

**Key principle:**
- Allowlist-only approach—only kills processes matching known patterns
- Unknown processes are completely ignored

---

## Installation

```bash
claude plugin install process-guardian@local-dev
```

That's it. The plugin runs automatically on every session start.

---

## Usage

### Automatic (Default)

Just start a new Claude session. Process Guardian will:
1. Scan for orphan processes (ppid=1)
2. Kill processes matching the allowlist
3. Report what was cleaned (or a friendly status message)

### Manual

```bash
/check
```

Scans and displays orphan processes with options to kill specific ones.

---

## Safety: Allowlist-Only

**Your normal processes are never touched.**

| Approach | Unknown Process | Risk |
|----------|-----------------|------|
| Blocklist | Might get killed | High |
| **Allowlist** | **Ignored** | **None** |

### What Gets Killed

Only these specific patterns:

- `claude --*` (subagents with arguments)
- `@modelcontextprotocol/server-*`
- `@playwright/mcp`, `playwright-mcp`
- `@upstash/context7-mcp`
- Browsers with `--remote-debugging-port` or `ms-playwright`

### What's Safe

- Your browsers (Chrome, Firefox, Safari)
- Your Electron apps (VS Code, Slack, Discord)
- Your dev servers (webpack, vite, next)
- **Everything not in the allowlist**

---

## Platform Support

| Platform | Status |
|----------|--------|
| macOS | ✅ |
| Linux | ✅ |
| Windows | ✅ |

---

## Supported MCP Servers

| Category | Examples |
|----------|----------|
| Official | `@modelcontextprotocol/server-filesystem`, `server-memory`, `server-git`, `server-puppeteer`, [more...](https://github.com/modelcontextprotocol/servers) |
| Playwright | `@playwright/mcp`, `playwright-mcp`, `mcp-server-playwright` |
| Context7 | `@upstash/context7-mcp` |
| Other | `@anthropic/claude-mcp`, `@composio/mcp`, `apidog-mcp-server` |

---

## Testing

To verify the plugin works:

**Step 1: Create orphan processes**
```bash
# Method: Use a subshell that exits immediately, orphaning the child process
(npx @playwright/mcp &)

# Verify it's orphaned (ppid = 1)
ps -eo pid,ppid,command | awk '$2 == 1' | grep -E "playwright|mcp"
```

**Step 2: Test cleanup**
```bash
# Start a new Claude Code session
claude

# You should see:
# [Process Guardian] Cleaned 1 orphan process(es):
#   PID=xxxxx node .../npx/.../mcp...
```

Or run `/check` manually to scan and manage orphan processes.

**Alternative: Real-world scenario**
```bash
# Start Claude with MCP server, then force-kill the terminal
claude  # with Playwright MCP configured
# Force close terminal (Cmd+Q / kill -9 terminal PID)
# Reopen terminal, start new claude session - orphans should be cleaned
```

---

## Contributing

1. Fork the repository
2. Add patterns to `scripts/lib/patterns.sh`
3. Test on your platform
4. Submit a pull request

All contributions must be in English.

---

## Learn More

- [Model Context Protocol](https://modelcontextprotocol.io/)
- [MCP Servers Repository](https://github.com/modelcontextprotocol/servers)
- [Claude Code Plugins](https://docs.anthropic.com/en/docs/claude-code)

---

## License

MIT

---

<div align="center">

**Made for the Claude Code community**

[Report Bug](https://github.com/ibarapascal/process-guardian/issues) · [Request Feature](https://github.com/ibarapascal/process-guardian/issues)

</div>
