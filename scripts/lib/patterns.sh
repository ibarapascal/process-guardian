#!/bin/bash
# =============================================================================
# Process Guardian - Known Process Patterns (Allowlist Only)
# =============================================================================
# ALLOWLIST APPROACH: Only kill processes that EXACTLY match these patterns.
# If a process doesn't match, it is IGNORED (not reported, not killed).
#
# This eliminates the need for an exclude list - we only kill what we know.
# =============================================================================

# =============================================================================
# Target 1: Claude Code Orphan Processes
# =============================================================================
PATTERNS_CLAUDE=(
    "claude --"                   # Claude with arguments (subagent)
    "claude --resume"             # Claude resume session
    "claude --continue"           # Claude continue
)

# =============================================================================
# Target 2: MCP Server Orphan Processes
# =============================================================================

# Official @modelcontextprotocol servers
# Source: https://github.com/modelcontextprotocol/servers
PATTERNS_MCP_OFFICIAL=(
    "@modelcontextprotocol/server-everything"
    "@modelcontextprotocol/server-fetch"
    "@modelcontextprotocol/server-filesystem"
    "@modelcontextprotocol/server-git"
    "@modelcontextprotocol/server-memory"
    "@modelcontextprotocol/server-sequential-thinking"
    "@modelcontextprotocol/server-time"
    "@modelcontextprotocol/server-postgres"
    "@modelcontextprotocol/server-puppeteer"
    "@modelcontextprotocol/server-slack"
    "@modelcontextprotocol/server-brave-search"
    "@modelcontextprotocol/server-gdrive"
    "@modelcontextprotocol/server-github"
    "@modelcontextprotocol/server-everart"
)

# Playwright MCP
# Source: https://github.com/microsoft/playwright-mcp
PATTERNS_PLAYWRIGHT_MCP=(
    "@playwright/mcp"
    "@executeautomation/playwright-mcp-server"
    "mcp-server-playwright"
    "playwright-mcp"
)

# Context7 MCP
# Source: https://www.npmjs.com/package/@upstash/context7-mcp
PATTERNS_CONTEXT7_MCP=(
    "@upstash/context7-mcp"
    "context7-mcp"
)

# Other common MCP servers
PATTERNS_OTHER_MCP=(
    "@anthropic/claude-mcp"
    "@composio/mcp"
    "apidog-mcp-server"
)

# Browsers spawned by Playwright/Puppeteer (identified by specific flags)
PATTERNS_PLAYWRIGHT_BROWSER=(
    "--remote-debugging-port"     # Playwright/Puppeteer debug flag
    "ms-playwright"               # Playwright cache path
    "chrome-headless-shell"       # Headless Chrome binary
    "headless_shell"              # Headless shell
)

# =============================================================================
# Helper Functions
# =============================================================================

# Build combined regex pattern for all known processes
build_known_pattern() {
    local patterns=()

    # Claude processes
    patterns+=("${PATTERNS_CLAUDE[@]}")

    # MCP servers
    patterns+=("${PATTERNS_MCP_OFFICIAL[@]}")
    patterns+=("${PATTERNS_PLAYWRIGHT_MCP[@]}")
    patterns+=("${PATTERNS_CONTEXT7_MCP[@]}")
    patterns+=("${PATTERNS_OTHER_MCP[@]}")

    # Playwright browsers
    patterns+=("${PATTERNS_PLAYWRIGHT_BROWSER[@]}")

    # Join with | for regex OR
    local IFS='|'
    echo "${patterns[*]}"
}

# Check if a command matches known patterns (allowlist)
is_known_process() {
    local cmd="$1"
    local pattern
    pattern=$(build_known_pattern)
    echo "$cmd" | grep -qE "$pattern"
}

# Get pattern for initial process filtering (used by platform scripts)
get_filter_pattern() {
    # Broad filter for ps output, then refined by is_known_process
    echo "(claude --|@modelcontextprotocol|@playwright/mcp|context7-mcp|mcp-server|remote-debugging-port|ms-playwright|chrome-headless-shell|headless_shell)"
}
