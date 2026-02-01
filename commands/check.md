---
description: "Scan and manage orphan Claude/MCP processes using allowlist approach"
---

# /check - Process Guardian

Scan system resources left by Claude Code sessions and provide options to clean them up.

**Safety:** Uses allowlist-only approach - only kills processes matching known patterns.

## Instructions

### Step 1: Detect Platform

Determine the current operating system:
- macOS: Use `ps`, `lsof`, `kill`
- Linux: Use `ps`, `ss` or `lsof`, `kill`
- Windows: Use PowerShell commands

### Step 2: Scan Resources

Run the appropriate commands based on platform:

**macOS/Linux:**
```bash
# Orphan processes (ppid=1) matching allowlist patterns
echo "=== Scanning Orphan Processes ==="
ps -eo pid,ppid,pcpu,pmem,etime,command | awk '$2 == 1' | grep -E "(claude --|@modelcontextprotocol|@playwright/mcp|context7-mcp|mcp-server|--remote-debugging-port|ms-playwright|chrome-headless-shell|headless_shell)" | grep -v grep
```

**Windows (PowerShell):**
```powershell
# Get processes matching allowlist patterns
Get-Process -Name @("node", "claude") -ErrorAction SilentlyContinue |
    ForEach-Object {
        $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($_.Id)" -ErrorAction SilentlyContinue).CommandLine
        if ($cmdLine -match "(claude --|@modelcontextprotocol|@playwright/mcp|context7-mcp|--remote-debugging-port|ms-playwright)") {
            [PSCustomObject]@{
                PID = $_.Id
                Name = $_.ProcessName
                CPU = [math]::Round($_.CPU, 1)
                MemoryMB = [math]::Round($_.WorkingSet64/1MB, 1)
                CommandLine = $cmdLine
            }
        }
    }
```

### Step 3: Format Results

Present the scan results in a clear table format:

```
## Orphan Processes - Allowlist Matches (N)
| # | PID | CPU% | MEM% | Runtime | Command |
|---|-----|------|------|---------|---------|
| 1 | 12345 | 5.2 | 1.3 | 02:30:15 | node @playwright/mcp |
| 2 | 12346 | 85.1 | 2.1 | 01:15:30 | claude --resume abc123 |
```

If no resources found, show "No orphan processes matching allowlist found."

### Step 4: Present Options

After showing results, present these options to the user:

```
**Actions:**
1. Kill specific process - Enter number or PID (e.g., "1" or "kill 12345")
2. Kill all listed processes - Type "kill all"
3. Do nothing - Type "skip" or press Enter
```

### Step 5: Execute User Choice

Based on user selection:

**Kill specific PID:**
```bash
# macOS/Linux - graceful first
kill -TERM <PID>
# If still running after 3 seconds
kill -9 <PID>
```

```powershell
# Windows
Stop-Process -Id <PID> -Force
```

**Kill all listed:**
- Collect all PIDs shown in the table
- Kill each one sequentially
- Report results

### Step 6: Confirm Results

After executing kills, re-scan and confirm:
- Show how many processes were killed
- Show any processes that couldn't be killed (permission issues)
- Show remaining processes if any

## Allowlist Patterns

The following patterns are recognized (ONLY these are targeted):

**Claude Code Orphans:**
- `claude --` (subagents with arguments)
- `claude --resume`, `claude --continue`

**MCP Server Orphans:**
- `@modelcontextprotocol/server-*` (official MCP servers)
- `@playwright/mcp`, `playwright-mcp`, `mcp-server-playwright`
- `@upstash/context7-mcp`, `context7-mcp`
- `@anthropic/claude-mcp`, `@composio/mcp`, `apidog-mcp-server`

**Browser Processes (Playwright/Puppeteer spawned only):**
- `--remote-debugging-port` (Playwright/Puppeteer flag)
- `ms-playwright` (Playwright cache path)
- `chrome-headless-shell`, `headless_shell`

## Safety Notes

- **Allowlist-only**: Unknown processes are NEVER touched
- Always use `kill -TERM` first (graceful shutdown)
- Only use `kill -9` if process doesn't respond within 3 seconds
- User's normal browsers, Electron apps, and dev servers are NOT affected
