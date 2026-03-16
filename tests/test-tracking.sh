#!/bin/bash
# =============================================================================
# Process Guardian - Session PID Tracking Tests
# =============================================================================
# Run: bash tests/test-tracking.sh
# Requires: macOS or Linux, python3 (for timing)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
TRACK="$SCRIPT_DIR/track-session.sh"
SESSION_DIR="/tmp/claude-guardian-sessions"

PASS=0
FAIL=0
CLEANUP_PIDS=()

cleanup() {
    for pid in "${CLEANUP_PIDS[@]}"; do
        kill -9 "$pid" 2>/dev/null || true
    done
    rm -rf "$SESSION_DIR" /tmp/claude-guardian-baseline_* 2>/dev/null || true
}
trap cleanup EXIT

reset() {
    for pid in "${CLEANUP_PIDS[@]}"; do
        kill -9 "$pid" 2>/dev/null || true
    done
    CLEANUP_PIDS=()
    rm -rf "$SESSION_DIR" /tmp/claude-guardian-baseline_* 2>/dev/null || true
}

pass() { echo "  PASS: $1"; ((PASS++)); }
fail() { echo "  FAIL: $1"; ((FAIL++)); }

# Use here-strings (<<<) to avoid stdin pipe issues in background execution
session_start()  { bash "$TRACK" --session-start <<< '{}'; }
post_tool_bash() { bash "$TRACK" --post-tool <<< '{"tool_name":"Bash","hook_event_name":"PostToolUse"}'; }
post_tool_read() { bash "$TRACK" --post-tool <<< '{"tool_name":"Read","hook_event_name":"PostToolUse"}'; }
session_end()    { bash "$TRACK" --session-end <<< '{}'; }

spawn_orphan() {
    local sleep_id="${1:-999}"
    (sleep "$sleep_id" &)
    sleep 0.5
    local pid
    pid=$(ps -eo pid,ppid,command | awk -v s="sleep $sleep_id" '$2==1 && index($0,s) && !/awk/{print $1}' | tail -1)
    [ -n "$pid" ] && CLEANUP_PIDS+=("$pid")
    echo "$pid"
}

tty_safe() {
    local t
    t=$(tty 2>/dev/null | tr '/' '_')
    [ -n "$t" ] && [ "$t" != "not a tty" ] && echo "$t"
}

# =============================================================================

echo "=== Process Guardian - Session PID Tracking Tests ==="
echo ""

# --- Test 1: Crash exit → orphan killed ---
echo "Test 1: Crash exit kills tracked orphan"
reset
session_start
PID=$(spawn_orphan 991)
post_tool_bash
OUTPUT=$(session_start)
if ! ps -p "$PID" > /dev/null 2>&1; then
    pass "orphan killed"
else
    fail "orphan $PID still alive"
fi
if echo "$OUTPUT" | grep -q "Cleaned 1"; then
    pass "reported 1 kill"
else
    fail "kill not reported"
fi

# --- Test 2: Clean exit → orphan survives ---
echo ""
echo "Test 2: Clean exit preserves tracked orphan"
reset
session_start
PID=$(spawn_orphan 990)
post_tool_bash
session_end
session_start
if ps -p "$PID" > /dev/null 2>&1; then
    pass "orphan survived clean exit"
else
    fail "orphan $PID killed on clean exit"
fi

# --- Test 3: Non-Bash tool → not tracked ---
echo ""
echo "Test 3: Read tool does not trigger tracking"
reset
session_start
spawn_orphan 989 > /dev/null
post_tool_read
TS=$(tty_safe)
if [ -z "$TS" ] || [ ! -f "$SESSION_DIR/$TS" ]; then
    pass "no session file for Read"
else
    fail "session file created for Read"
fi

# --- Test 4: Dead PID → triple verify skips ---
echo ""
echo "Test 4: Dead PID skipped (triple verification)"
reset
session_start
PID=$(spawn_orphan 988)
post_tool_bash
kill -9 "$PID" 2>/dev/null || true
sleep 0.3
OUTPUT=$(session_start)
if echo "$OUTPUT" | grep -q "Cleaned"; then
    fail "killed a dead PID"
else
    pass "dead PID skipped"
fi

# --- Test 5: Multiple orphans ---
echo ""
echo "Test 5: Multiple orphans tracked and killed"
reset
session_start
P1=$(spawn_orphan 987)
post_tool_bash
P2=$(spawn_orphan 986)
post_tool_bash
OUTPUT=$(session_start)
KILLED=0
ps -p "$P1" > /dev/null 2>&1 || ((KILLED++))
ps -p "$P2" > /dev/null 2>&1 || ((KILLED++))
if [ "$KILLED" -eq 2 ]; then
    pass "both orphans killed ($P1, $P2)"
else
    fail "only $KILLED/2 killed"
fi

# --- Test 6: Pre-existing orphans in baseline ---
echo ""
echo "Test 6: Pre-existing orphans not tracked"
reset
PREEXIST=$(spawn_orphan 985)
session_start  # baseline includes PREEXIST
post_tool_bash
TS=$(tty_safe)
if [ -n "$TS" ] && [ -f "$SESSION_DIR/$TS" ] && grep -q "^${PREEXIST}|" "$SESSION_DIR/$TS" 2>/dev/null; then
    fail "pre-existing orphan tracked"
else
    pass "pre-existing orphan in baseline, not tracked"
fi

# --- Test 7: .clean marker lifecycle ---
echo ""
echo "Test 7: .clean marker created and cleaned up"
reset
session_start
spawn_orphan 984 > /dev/null
post_tool_bash
TS=$(tty_safe)
if [ -n "$TS" ] && [ -f "$SESSION_DIR/$TS" ]; then
    pass "session file exists"
else
    fail "session file missing"
fi
session_end
if [ -n "$TS" ] && [ -f "$SESSION_DIR/$TS.clean" ]; then
    pass ".clean marker exists"
else
    fail ".clean marker missing"
fi
session_start
if [ -z "$TS" ] || { [ ! -f "$SESSION_DIR/$TS" ] && [ ! -f "$SESSION_DIR/$TS.clean" ]; }; then
    pass "files cleaned after processing"
else
    fail "files not cleaned"
fi

# --- Test 8: No orphan processes from scripts ---
echo ""
echo "Test 8: Scripts create no orphan processes"
reset
BEFORE=$(ps -eo pid,ppid -U "$(whoami)" | awk '$2==1' | wc -l | tr -d ' ')
session_start
post_tool_bash
post_tool_bash
post_tool_bash
session_end
AFTER=$(ps -eo pid,ppid -U "$(whoami)" | awk '$2==1' | wc -l | tr -d ' ')
if [ "$BEFORE" = "$AFTER" ]; then
    pass "no orphan processes ($BEFORE → $AFTER)"
else
    fail "orphan count changed ($BEFORE → $AFTER)"
fi

# --- Test 9: Cross-TTY pickup (resume scenario) ---
echo ""
echo "Test 9: Resume picks up other TTY's session files"
reset
session_start
PID=$(spawn_orphan 983)
post_tool_bash
TS=$(tty_safe)
# Move to fake TTY to simulate another terminal's crashed session
mkdir -p "$SESSION_DIR"
if [ -n "$TS" ] && [ -f "$SESSION_DIR/$TS" ]; then
    mv "$SESSION_DIR/$TS" "$SESSION_DIR/_dev_ttys999"
fi
OUTPUT=$(session_start)
if ! ps -p "$PID" > /dev/null 2>&1; then
    pass "orphan from other TTY killed"
else
    fail "orphan from other TTY survived"
fi

# --- Test 10: Performance ---
echo ""
echo "Test 10: PostToolUse(Bash) performance"
reset
session_start
START=$(python3 -c 'import time;print(int(time.time()*1000))')
for i in {1..5}; do post_tool_bash; done
END=$(python3 -c 'import time;print(int(time.time()*1000))')
AVG=$(( (END - START) / 5 ))
if [ "$AVG" -lt 200 ]; then
    pass "avg ${AVG}ms per call"
else
    fail "avg ${AVG}ms per call (>200ms threshold)"
fi

# --- Test 11: Empty session dir ---
echo ""
echo "Test 11: Empty session dir handled gracefully"
reset
mkdir -p "$SESSION_DIR"
session_start > /dev/null 2>&1
if [ $? -eq 0 ]; then
    pass "no error on empty dir"
else
    fail "error on empty dir"
fi

# =============================================================================
echo ""
echo "==========================================="
echo "Results: $PASS passed, $FAIL failed"
echo "==========================================="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
