#!/bin/bash
# =============================================================================
# Process Guardian - Orphan Process Scanner (Main Entry)
# =============================================================================
# Scans and cleans up orphan processes from Claude Code sessions.
# Automatically detects platform and uses appropriate implementation.
#
# Supported platforms:
#   - macOS (Darwin)
#   - Linux
#   - Windows (via Git Bash/MSYS2/Cygwin)
#
# Exit codes:
#   0 - Success (cleaned or nothing to clean)
#   1 - Error
# =============================================================================

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source patterns
source "${SCRIPT_DIR}/lib/patterns.sh"

# =============================================================================
# Platform Detection
# =============================================================================

detect_platform() {
    case "$(uname -s)" in
        Darwin)
            echo "darwin"
            ;;
        Linux)
            echo "linux"
            ;;
        MINGW*|CYGWIN*|MSYS*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# =============================================================================
# Main Logic
# =============================================================================

main() {
    local platform
    platform=$(detect_platform)

    case "$platform" in
        darwin)
            source "${SCRIPT_DIR}/lib/platform-darwin.sh"
            scan_and_clean_darwin
            ;;
        linux)
            source "${SCRIPT_DIR}/lib/platform-linux.sh"
            scan_and_clean_linux
            ;;
        windows)
            # Windows uses PowerShell script
            if command -v pwsh &> /dev/null; then
                pwsh -ExecutionPolicy Bypass -File "${SCRIPT_DIR}/lib/platform-windows.ps1"
            elif command -v powershell &> /dev/null; then
                powershell -ExecutionPolicy Bypass -File "${SCRIPT_DIR}/lib/platform-windows.ps1"
            else
                echo "[Process Guardian] Warning: PowerShell not found, skipping Windows cleanup"
            fi
            ;;
        *)
            echo "[Process Guardian] Warning: Unsupported platform '$(uname -s)', skipping cleanup"
            ;;
    esac
}

main "$@"
