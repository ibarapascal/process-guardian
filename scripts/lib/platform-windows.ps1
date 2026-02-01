# =============================================================================
# Process Guardian - Windows (PowerShell) Implementation
# =============================================================================
# ALLOWLIST ONLY: Only kills processes that match known patterns.
# Unknown processes are completely ignored (not reported, not killed).
#
# ORPHAN DETECTION: Only kills processes whose parent process no longer exists.
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
    "@executeautomation/playwright-mcp-server"
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

function Test-IsOrphan {
    param([int]$ProcessId)

    try {
        $process = Get-CimInstance Win32_Process -Filter "ProcessId = $ProcessId" -ErrorAction SilentlyContinue
        if (-not $process) {
            return $false
        }

        $parentPid = $process.ParentProcessId
        if ($parentPid -eq 0) {
            # System process, not an orphan
            return $false
        }

        # Check if parent process still exists
        $parentProcess = Get-Process -Id $parentPid -ErrorAction SilentlyContinue
        if (-not $parentProcess) {
            # Parent process no longer exists - this is an orphan
            return $true
        }

        return $false
    } catch {
        return $false
    }
}

# =============================================================================
# Main (Allowlist + Orphan Detection)
# =============================================================================

$killedCount = 0
$killedList = @()

# Get node and claude processes only
$processes = Get-Process -Name @("node", "claude") -ErrorAction SilentlyContinue

foreach ($proc in $processes) {
    try {
        # First check if it's an orphan process
        if (-not (Test-IsOrphan $proc.Id)) {
            continue
        }

        # Get command line
        $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction SilentlyContinue).CommandLine

        if ($cmdLine -and (Test-KnownProcess $cmdLine)) {
            # Only kill if it's orphan AND matches known patterns (allowlist)
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            $killedCount++

            # Truncate command for display and escape for JSON
            $shortCmd = $cmdLine
            if ($shortCmd.Length -gt 50) {
                $shortCmd = $shortCmd.Substring(0, 50) + "..."
            }
            # Escape backslashes and double quotes for JSON
            $shortCmd = $shortCmd.Replace('\', '\\').Replace('"', '\"')
            $killedList += "PID=$($proc.Id) $shortCmd"
        }
        # Unknown processes are silently ignored
    } catch {
        # Skip processes we can't access
    }
}

# Output results as JSON for CLI display
if ($killedCount -gt 0) {
    $details = ""
    foreach ($item in $killedList) {
        $details += "\n  $item"
    }
    Write-Output "{`"systemMessage`": `"[Process Guardian] Cleaned $killedCount orphan process(es):$details`"}"
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
    Write-Output "{`"systemMessage`": `"[Process Guardian] No orphan processes. $($messages[$idx])`"}"
}
