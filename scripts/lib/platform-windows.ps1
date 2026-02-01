# =============================================================================
# Process Guardian - Windows (PowerShell) Implementation
# =============================================================================
# ALLOWLIST ONLY: Only kills processes that match known patterns.
# Unknown processes are completely ignored (not reported, not killed).
# =============================================================================

# =============================================================================
# Known Patterns (Allowlist)
# =============================================================================

$KnownPatterns = @(
    # Claude Code - specific patterns only
    "claude --"
    "claude.exe --"

    # Official @modelcontextprotocol
    "@modelcontextprotocol/server-"
    "modelcontextprotocol"

    # Playwright MCP
    "@playwright/mcp"
    "playwright-mcp"
    "mcp-server-playwright"

    # Context7 MCP
    "@upstash/context7-mcp"
    "context7-mcp"

    # Browsers - ONLY Playwright/Puppeteer spawned (safe patterns)
    # Do NOT add generic browser names - will kill user browsers!
    "chrome-headless-shell"
    "headless_shell"
    "--remote-debugging-port"
    "ms-playwright"

    # Other MCP
    "@anthropic/claude-mcp"
    "@composio/mcp"
    "apidog-mcp-server"
)

# =============================================================================
# Functions
# =============================================================================

function Test-KnownProcess {
    param([string]$CommandLine)

    foreach ($pattern in $KnownPatterns) {
        if ($CommandLine -match [regex]::Escape($pattern)) {
            return $true
        }
    }
    return $false
}

# =============================================================================
# Main (Allowlist Approach)
# =============================================================================

$killedCount = 0
$killedList = @()

# Get node and claude processes only
$processes = Get-Process -Name @("node", "claude") -ErrorAction SilentlyContinue

foreach ($proc in $processes) {
    try {
        # Get command line
        $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction SilentlyContinue).CommandLine

        if ($cmdLine -and (Test-KnownProcess $cmdLine)) {
            # Only kill if it matches known patterns (allowlist)
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            $killedCount++

            # Truncate command for display
            $shortCmd = $cmdLine
            if ($shortCmd.Length -gt 50) {
                $shortCmd = $shortCmd.Substring(0, 50) + "..."
            }
            $killedList += "PID=$($proc.Id) $shortCmd"
        }
        # Unknown processes are silently ignored
    } catch {
        # Skip processes we can't access
    }
}

# Output results
if ($killedCount -gt 0) {
    Write-Host "[Process Guardian] Cleaned $killedCount orphan process(es):"
    foreach ($item in $killedList) {
        Write-Host "  $item"
    }
} else {
    # Random geek message when nothing to clean
    $messages = @(
        "The process table is at peace."
        "All children have parents."
        "Systems nominal."
        "All clear."
        "All systems green."
    )
    $idx = Get-Random -Maximum $messages.Count
    Write-Host "[Process Guardian] No orphan processes. $($messages[$idx])"
}
