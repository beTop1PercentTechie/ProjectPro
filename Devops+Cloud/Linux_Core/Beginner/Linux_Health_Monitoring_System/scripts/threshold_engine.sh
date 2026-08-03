#!/bin/bash
# =============================================================
# threshold_engine.sh
# -------------------------------------------------------------
# WHAT THIS SCRIPT DOES:
#   Compares metric values that have ALREADY been collected
#   (cpu_usage, ram_usage, disk_usage, swap_usage, load_avg)
#   against the thresholds set in config.conf, and decides an
#   overall STATUS: "OK", "WARNING", or "CRITICAL".
#
# WHAT THIS SCRIPT DOES NOT DO:
#   It does NOT run cpu.sh/ram.sh/etc itself. The caller
#   (health-monitor.sh or send-report.sh) must already have set
#   the variables below before sourcing this file. This keeps
#   metric-collection logic in exactly one place per caller and
#   avoids a separate "collector" file that would just duplicate
#   what the callers already do in a few lines.
#
# HOW THE LOGIC WORKS (per metric):
#   1. If value >= threshold + CRITICAL_MARGIN  -> CRITICAL
#   2. Else if value >= threshold                -> WARNING
#   3. Else                                       -> no alert
#   The overall STATUS becomes the WORST status seen across all
#   metrics (CRITICAL beats WARNING beats OK).
#
# VARIABLES THIS SCRIPT SETS FOR THE CALLER TO USE:
#   STATUS   -> "OK" | "WARNING" | "CRITICAL"
#   REASONS  -> a Bash array of human-readable reason strings
#
# WHO SOURCES THIS SCRIPT:
#   health-monitor.sh and send-report.sh, using:
#     source threshold_engine.sh
# =============================================================
 
STATUS="OK"
REASONS=()
 
check_threshold() {
  # $1 = metric name (e.g. "CPU")
  # $2 = the value we measured (e.g. 92)
  # $3 = the WARNING threshold from config.conf (e.g. 80)
  local name="$1" value="$2" threshold="$3"
  local critical_at=$((threshold + CRITICAL_MARGIN))
 
  if [ "$value" -ge "$critical_at" ]; then
    STATUS="CRITICAL"
    REASONS+=("$name CRITICAL - $value% >= $critical_at%")
  elif [ "$value" -ge "$threshold" ]; then
    # Don't downgrade an already-CRITICAL overall status to WARNING
    if [ "$STATUS" != "CRITICAL" ]; then STATUS="WARNING"; fi
    REASONS+=("$name WARNING - $value% >= $threshold%")
  fi
}
 
# Run the check for every metric. "${load_avg%.*}" strips the
# decimal part of load_avg (e.g. "1.42" -> "1") because Bash's
# "-ge" comparison only works with whole numbers.
check_threshold "CPU"  "$cpu_usage"  "$CPU_THRESHOLD"
check_threshold "RAM"  "$ram_usage"  "$RAM_THRESHOLD"
check_threshold "DISK" "$disk_usage" "$DISK_THRESHOLD"
check_threshold "SWAP" "$swap_usage" "$SWAP_THRESHOLD"
check_threshold "LOAD" "${load_avg%.*}" "$LOAD_THRESHOLD"

