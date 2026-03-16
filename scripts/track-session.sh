#!/bin/bash
# =============================================================================
# Process Guardian - Session PID Tracking
# =============================================================================
# Tracks processes spawned by Bash tool calls and cleans up orphans from
# crashed sessions. Complements allowlist scanning with per-session tracking.
#
# Modes:
#   --session-start  Create baseline, clean up previous session orphans
#   --post-tool      Track new PPID=1 processes after Bash tool calls
#   --session-end    Mark clean exit
#
# File layout:
#   /tmp/claude-guardian-sessions/{tty_safe}        Tracked PIDs (PID|lstart|command)
#   /tmp/claude-guardian-sessions/{tty_safe}.clean   Clean exit marker
#   /tmp/claude-guardian-baseline_{tty_safe}         PPID=1 PID list (one PID per line)
# =============================================================================

set -uo pipefail

# Fail-open safety net: uncaught errors → silent exit (never block Claude)
trap 'exit 0' ERR

SESSION_DIR="/tmp/claude-guardian-sessions"
BASELINE_PREFIX="/tmp/claude-guardian-baseline"

# =============================================================================
# TTY Detection (walk process tree upward to find controlling terminal)
# =============================================================================

get_tty() {
    local pid=$$
    while [ "$pid" != "1" ] && [ "$pid" != "0" ] && [ -n "$pid" ]; do
        local t
        t=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
        if [ -n "$t" ] && [ "$t" != "??" ]; then
            echo "/dev/$t"
            return
        fi
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    done
}

# =============================================================================
# Process Helpers
# =============================================================================

# Get all PPID=1 PIDs for current user (fast: single ps call)
get_orphan_pids() {
    ps -eo pid=,ppid= -U "$(whoami)" 2>/dev/null | awk '$2 == 1 {print $1}'
}

# Get full info for a specific PID: PID|lstart|command
get_process_info() {
    local pid="$1"
    local lstart cmd
    lstart=$(LC_ALL=C ps -o lstart= -p "$pid" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') || return 1
    cmd=$(LC_ALL=C ps -o command= -p "$pid" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') || return 1
    [ -n "$lstart" ] && [ -n "$cmd" ] && echo "${pid}|${lstart}|${cmd}"
}

# =============================================================================
# PostToolUse Handler
# =============================================================================

handle_post_tool() {
    local input
    input=$(cat)

    # Only track Bash tool calls
    local tool_name=""
    [[ "$input" =~ \"tool_name\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]] && tool_name="${BASH_REMATCH[1]}"
    [ "$tool_name" != "Bash" ] && exit 0

    local my_tty
    my_tty=$(get_tty)
    [ -z "$my_tty" ] && exit 0
    local tty_safe
    tty_safe=$(echo "$my_tty" | tr '/' '_')

    local baseline_file="${BASELINE_PREFIX}_${tty_safe}"
    local session_file="${SESSION_DIR}/${tty_safe}"

    mkdir -p "$SESSION_DIR"

    # Get current orphan PIDs (single ps call, fast)
    local current_pids
    current_pids=$(get_orphan_pids) || true

    # No baseline yet → create one and exit
    if [ ! -f "$baseline_file" ]; then
        echo "$current_pids" > "$baseline_file"
        exit 0
    fi

    [ -z "$current_pids" ] && exit 0

    # Diff: find PIDs in current but not in baseline (no sort dependency)
    local new_pids
    new_pids=$(grep -vxFf "$baseline_file" <(echo "$current_pids")) || true
    [ -z "$new_pids" ] && exit 0

    # For each new PID: get full info and track it (only a few PIDs typically)
    while read -r pid; do
        [ -z "$pid" ] && continue

        # Skip if already tracked
        grep -q "^${pid}|" "$session_file" 2>/dev/null && continue

        # Get full process info and append to session file
        local info
        info=$(get_process_info "$pid") || continue
        echo "$info" >> "$session_file"
    done <<< "$new_pids"
}

# =============================================================================
# SessionStart Handler
# =============================================================================

handle_session_start() {
    cat > /dev/null  # drain stdin

    local my_tty
    my_tty=$(get_tty)
    [ -z "$my_tty" ] && exit 0
    local tty_safe
    tty_safe=$(echo "$my_tty" | tr '/' '_')

    mkdir -p "$SESSION_DIR"

    # 1. Scan all session tracking files for orphans from previous sessions
    scan_tracked_orphans

    # 2. Create baseline for this session (PIDs only, fast)
    local baseline_file="${BASELINE_PREFIX}_${tty_safe}"
    get_orphan_pids > "$baseline_file"

    # 3. Clean up stale files (>24h)
    find "$SESSION_DIR" -maxdepth 1 -type f -mmin +1440 -delete 2>/dev/null || true
    find /tmp -maxdepth 1 -name "claude-guardian-baseline_*" -mmin +1440 -delete 2>/dev/null || true
}

# =============================================================================
# SessionEnd Handler
# =============================================================================

handle_session_end() {
    cat > /dev/null  # drain stdin

    local my_tty
    my_tty=$(get_tty)
    [ -z "$my_tty" ] && exit 0
    local tty_safe
    tty_safe=$(echo "$my_tty" | tr '/' '_')

    # Mark clean exit (only if session file exists)
    if [ -f "${SESSION_DIR}/${tty_safe}" ]; then
        touch "${SESSION_DIR}/${tty_safe}.clean"
    fi

    # Clean up baseline
    rm -f "${BASELINE_PREFIX}_${tty_safe}"
}

# =============================================================================
# Tracked Orphan Scanner (called during SessionStart)
# =============================================================================

scan_tracked_orphans() {
    [ ! -d "$SESSION_DIR" ] && return

    local killed_count=0
    local killed_list=()

    shopt -s nullglob
    for session_file in "$SESSION_DIR"/*; do
        [ ! -f "$session_file" ] && continue
        [[ "$session_file" == *.clean ]] && continue

        local clean_marker="${session_file}.clean"
        local is_crash=true
        [ -f "$clean_marker" ] && is_crash=false

        while IFS='|' read -r pid lstart cmd; do
            [ -z "$pid" ] && continue

            # Triple verify: PID exists + lstart matches + command matches
            local cur_lstart cur_cmd
            cur_lstart=$(LC_ALL=C ps -o lstart= -p "$pid" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') || continue
            cur_cmd=$(LC_ALL=C ps -o command= -p "$pid" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') || continue

            [ "$cur_lstart" != "$lstart" ] && continue
            [ "$cur_cmd" != "$cmd" ] && continue

            # Verified: process is still alive and matches tracked record
            if [ "$is_crash" = true ]; then
                kill -9 "$pid" 2>/dev/null || true
                ((killed_count++)) || true
                local short_cmd="${cmd:0:50}"
                [ ${#cmd} -gt 50 ] && short_cmd="${short_cmd}..."
                short_cmd="${short_cmd//\\/\\\\}"
                short_cmd="${short_cmd//\"/\\\"}"
                killed_list+=("PID=$pid $short_cmd")
            fi
            # Clean exit: silently skip (user may have intended these)
        done < "$session_file"

        # Clean up processed files
        rm -f "$session_file" "$clean_marker"
    done

    # Output JSON only if we killed something
    if [ $killed_count -gt 0 ]; then
        local details=""
        for item in "${killed_list[@]}"; do
            details="${details}\\n  ${item}"
        done
        echo "{\"systemMessage\": \"[Process Guardian] Cleaned $killed_count tracked orphan(s) from crashed session:${details}\"}"
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    local mode="${1:-}"
    case "$mode" in
        --post-tool)     handle_post_tool ;;
        --session-start) handle_session_start ;;
        --session-end)   handle_session_end ;;
        *)               exit 0 ;;
    esac
}

main "$@"
