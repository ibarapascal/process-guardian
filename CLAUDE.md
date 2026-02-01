# Process Guardian - Development Guide

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

## Architecture

```
SessionStart Hook
       │
       ▼
scan-orphans.sh (platform detection)
       │
       ├─► platform-darwin.sh (macOS)
       ├─► platform-linux.sh (Linux)
       └─► platform-windows.ps1 (Windows)
              │
              ▼
         patterns.sh (allowlist matching)
              │
              └─► Known → Auto-kill
                  Unknown → Silently ignored
```

---

## Directory Structure

```
process-guardian/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── hooks/
│   └── hooks.json               # SessionStart hook config
├── scripts/
│   ├── scan-orphans.sh          # Main entry (platform detection)
│   └── lib/
│       ├── patterns.sh          # Known process patterns (allowlist)
│       ├── platform-darwin.sh   # macOS implementation
│       ├── platform-linux.sh    # Linux implementation
│       └── platform-windows.ps1 # Windows PowerShell
├── commands/
│   └── check.md                 # /check command definition
├── CLAUDE.md                    # This file
└── README.md                    # User documentation
```

---

## Key Files

### patterns.sh

Central registry of known process patterns. Organized by category:

- `PATTERNS_CLAUDE` - Claude Code processes
- `PATTERNS_MCP_OFFICIAL` - Official @modelcontextprotocol servers
- `PATTERNS_PLAYWRIGHT_MCP` - Playwright MCP variants
- `PATTERNS_CONTEXT7_MCP` - Context7 MCP
- `PATTERNS_PLAYWRIGHT_BROWSER` - Browser processes (Playwright-spawned only)
- `PATTERNS_OTHER_MCP` - Other common MCP servers

### Platform Scripts

| File | Platform | Commands |
|------|----------|----------|
| `platform-darwin.sh` | macOS | `ps`, `lsof`, `kill` |
| `platform-linux.sh` | Linux | `ps`, `ss`/`lsof`, `kill` |
| `platform-windows.ps1` | Windows | PowerShell cmdlets |

---

## Development Workflow

### Quick Testing (No Install)

```bash
claude --plugin-dir /path/to/process-guardian
```

### Full Install Test

```bash
claude plugin uninstall process-guardian@local-dev
claude plugin install process-guardian@local-dev
claude plugin list
```

### Debug Scripts

```bash
# Test scan script directly
./scripts/scan-orphans.sh

# Test pattern matching
source scripts/lib/patterns.sh
is_known_process "node @playwright/mcp"
```

---

## Adding New MCP Support

1. Edit `scripts/lib/patterns.sh`
2. Add pattern to appropriate array
3. Test with `/check` command
4. Update README.md

---

## Release Checklist

- [ ] All platforms tested
- [ ] patterns.sh up to date
- [ ] README.md updated
- [ ] All content in English

---

# Design Decisions

## Allowlist-Only Approach

**This plugin uses an ALLOWLIST-ONLY approach for process management.**

### Why Allowlist?

A blocklist/exclude approach has a fundamental problem: the exclude list grows infinitely. Every new Electron app, Node.js tool, or browser-based application would need to be added to prevent accidental kills.

The allowlist approach solves this:
- **Only processes matching known patterns are killed**
- **Unknown processes are completely ignored** (not reported, not killed)
- **No blocklist needed** - if we don't recognize it, we don't touch it

### Target Processes

We only target two categories of orphan processes:

1. **Claude Code Orphans**
   - `claude --` (subagents with arguments)
   - `claude --resume`
   - `claude --continue`

2. **MCP Server Orphans**
   - Official `@modelcontextprotocol/server-*`
   - Playwright MCP variants (`@playwright/mcp`, etc.)
   - Context7 MCP (`@upstash/context7-mcp`)
   - Browser instances spawned by Playwright/Puppeteer (identified by `--remote-debugging-port`, `ms-playwright`)

---

## CRITICAL: Process Safety Rules

**NEVER kill user's normal processes. This is the #1 priority.**

### Forbidden Patterns (NEVER add these)

```bash
# NEVER match generic browser names - will kill user's browsers!
"Chrome"
"Firefox"
"Safari"
"Chromium"
"msedge"

# NEVER match generic process names
"node"              # Too broad - matches user's dev servers
"python"            # User's scripts
"java"              # User's apps
"claude"            # Without arguments - could match user's Claude app
```

### Safe Patterns (OK to match)

```bash
# Specific MCP packages (safe)
"@playwright/mcp"
"@modelcontextprotocol/server-"
"@upstash/context7-mcp"

# Playwright-specific flags (safe - user browsers don't have these)
"--remote-debugging-port"
"ms-playwright"
"chrome-headless-shell"

# Claude with arguments (safe - distinguishes subagents)
"claude --"
```

### Before Adding Any New Pattern

1. **Ask yourself**: Could this match a normal user process?
2. **Test**: Run `ps aux | grep "pattern"` - what else matches?
3. **Be specific**: Use full package names, not partial matches

---

# Contributing Guidelines

## Language Policy

**All content in this plugin MUST be in English only.**

This includes:
- Code comments
- Documentation (README, CLAUDE.md)
- Command descriptions and instructions
- Hook configurations
- Output messages
- Commit messages

No exceptions. This ensures consistency for potential official marketplace submission.
