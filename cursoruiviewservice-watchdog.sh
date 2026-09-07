#!/bin/bash
# Watchdog for the CursorUIViewService XPC helper (TextInputUIMacHelper). Runs periodically via a LaunchAgent. Detects hang signatures and kills the process so launchd respawns it fresh on next use:
#   1) Confirmed deadlock: a 1-second `sample` of the process's main thread shows it stuck (>=DEADLOCK_RATIO of samples) inside -[HIRunLoopSemaphore wait], nested under a window-layout/CATransaction flush. This is a real, verified hang signature: main thread was stuck in that exact frame for 1739/1739 samples (100%) while Activity Monitor showed the process "Not Responding". Apple's own code names the enclosing frame __CONSIDER_WHO_REQUESTED_THIS_WAIT_BEFORE_SENDING_BUG_TO_HISERVICES__, which is effectively their own internal marker for this deadlock. This check requires /usr/bin/sample (ships with Xcode Command Line Tools) and is the primary, reliable detector.
#   2) Busy-spin hang: %CPU stays above CPU_THRESHOLD for CPU_SUSTAIN_CHECKS consecutive checks in a row. Fallback for a different failure mode.
#   3) Stuck-idle hang: process has been alive longer than MAX_AGE_SECONDS. A conservative safety net for anything neither check above catches. Tune or disable MAX_AGE_SECONDS below if it proves too aggressive now that (1) exists.

SERVICE_MATCH="XPCServices/CursorUIViewService.xpc/Contents/MacOS/CursorUIViewService"
LOG="/tmp/cursoruiviewservice-watchdog.log"
STATE_FILE="/tmp/cursoruiviewservice-watchdog.state"
SAMPLE_TMP="/tmp/cursoruiviewservice-watchdog.sample.tmp"

SAMPLE_DURATION=1         # seconds spent sampling the main thread each check
DEADLOCK_FRAME="HIRunLoopSemaphore wait\]"
DEADLOCK_RATIO=50         # percent of main-thread samples that must show the frame

CPU_THRESHOLD=50          # percent
CPU_SUSTAIN_CHECKS=3      # consecutive high-CPU samples before killing
MAX_AGE_SECONDS=$((6 * 3600))   # 6 hours; set to 0 to disable this check

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"
}

etime_to_seconds() {
  local et="$1" days=0 rest="$1" a b c
  if [[ "$et" == *-* ]]; then
    days="${et%%-*}"
    rest="${et#*-}"
  fi
  IFS=: read -r a b c <<< "$rest"
  if [ -z "$c" ]; then
    echo $(( days*86400 + 10#$a*60 + 10#$b ))
  else
    echo $(( days*86400 + 10#$a*3600 + 10#$b*60 + 10#$c ))
  fi
}

trim_log() {
  # Keep the log from growing unbounded: cap at ~2000 lines
  if [ -f "$LOG" ] && [ "$(wc -l < "$LOG")" -gt 2000 ]; then
    tail -n 1000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
  fi
}

trim_log
pid=$(pgrep -f "$SERVICE_MATCH" | head -n1)

if [ -z "$pid" ]; then
  log "not running; nothing to check"
  rm -f "$STATE_FILE"
  exit 0
fi

read -r cpu etime <<< "$(ps -o %cpu=,etime= -p "$pid" | tr -s ' ')"
cpu_int=${cpu%.*}
age=$(etime_to_seconds "$etime")
prev_streak=0
[ -f "$STATE_FILE" ] && prev_streak=$(cat "$STATE_FILE" 2>/dev/null || echo 0)

kill_it() {
  local reason="$1"
  log "KILLING pid=$pid reason=\"$reason\" cpu=${cpu}% etime=${etime} (age=${age}s)"
  kill -9 "$pid" 2>>"$LOG"
  rm -f "$STATE_FILE" "$SAMPLE_TMP"
}

# Check 1: confirmed deadlock via thread sample (see header comment).
check_deadlock() {
  command -v /usr/bin/sample >/dev/null 2>&1 || return 1
  /usr/bin/sample "$pid" "$SAMPLE_DURATION" -mayDie -file "$SAMPLE_TMP" >/dev/null 2>&1
  [ -f "$SAMPLE_TMP" ] || return 1

  local total stuck
  total=$(awk '/com\.apple\.main-thread/ {for(i=1;i<=NF;i++) if ($i ~ /^[0-9]+$/) {print $i; exit}}' "$SAMPLE_TMP")
  stuck=$(awk "/${DEADLOCK_FRAME}/"' {for(i=1;i<=NF;i++) if ($i ~ /^[0-9]+$/) {print $i; exit}}' "$SAMPLE_TMP")
  rm -f "$SAMPLE_TMP"

  [ -n "$total" ] && [ -n "$stuck" ] && [ "$total" -gt 0 ] || return 1
  # stuck/total >= DEADLOCK_RATIO% , integer math: stuck*100 >= total*DEADLOCK_RATIO
  if [ $((stuck * 100)) -ge $((total * DEADLOCK_RATIO)) ]; then
    log "check pid=$pid DEADLOCK sample: main-thread stuck ${stuck}/${total} samples in [HIRunLoopSemaphore wait]"
    return 0
  fi
  return 1
}

if check_deadlock; then
  kill_it "confirmed deadlock: main thread stuck in HIRunLoopSemaphore wait (HIServices), verified via sample"
  exit 0
fi

if [ "$cpu_int" -ge "$CPU_THRESHOLD" ] 2>/dev/null; then
  streak=$((prev_streak + 1))
  echo "$streak" > "$STATE_FILE"
  log "check pid=$pid cpu=${cpu}% etime=${etime} high-cpu-streak=$streak"
  if [ "$streak" -ge "$CPU_SUSTAIN_CHECKS" ]; then
    kill_it "sustained high CPU (${streak} consecutive checks >= ${CPU_THRESHOLD}%)"
  fi
else
  [ -f "$STATE_FILE" ] && rm -f "$STATE_FILE"
  log "check pid=$pid cpu=${cpu}% etime=${etime} age=${age}s ok"
  if [ "$MAX_AGE_SECONDS" -gt 0 ] && [ "$age" -ge "$MAX_AGE_SECONDS" ]; then
    kill_it "exceeded max age (${age}s >= ${MAX_AGE_SECONDS}s) while idle"
  fi
fi
