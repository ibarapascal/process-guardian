#!/bin/bash
# =============================================================================
# Process Guardian - macOS (Darwin) Implementation
# =============================================================================
# ALLOWLIST ONLY: Only kills processes that match known patterns.
# Unknown processes are completely ignored (not reported, not killed).
# =============================================================================

# =============================================================================
# Scan and Clean (Allowlist Approach)
# =============================================================================

scan_and_clean_darwin() {
    local filter_pattern
    filter_pattern=$(get_filter_pattern)

    local killed_count=0
    local killed_list=()

    # Find orphan processes (ppid=1) that match our filter pattern
    while IFS= read -r line; do
        [ -z "$line" ] && continue

        local pid cmd
        pid=$(echo "$line" | awk '{print $1}')
        cmd=$(echo "$line" | cut -d' ' -f6-)

        # Only kill if it matches known patterns (allowlist)
        if is_known_process "$cmd"; then
            # Force kill orphan processes immediately (no graceful wait to avoid blocking startup)
            kill -9 "$pid" 2>/dev/null || true
            ((killed_count++)) || true

            # Truncate command for display
            local short_cmd="${cmd:0:50}"
            [ ${#cmd} -gt 50 ] && short_cmd="${short_cmd}..."
            killed_list+=("PID=$pid $short_cmd")
        fi
        # Unknown processes are silently ignored

    done < <(ps -eo pid,ppid,pcpu,pmem,etime,command | awk '$2 == 1' | grep -E "$filter_pattern" 2>/dev/null || true)

    # Output results
    if [ $killed_count -gt 0 ]; then
        echo "[Process Guardian] Cleaned $killed_count orphan process(es):"
        printf '  %s\n' "${killed_list[@]}"
    else
        # Random geek message when nothing to clean
        local messages=(
            "The process table is at peace."
            "All children have parents."
            "Systems nominal."
            "All clear."
            "All systems green."
        )
        local idx=$((RANDOM % ${#messages[@]}))
        echo "[Process Guardian] No orphan processes. ${messages[$idx]}"
    fi
}
