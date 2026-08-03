#!/bin/bash
# =============================================================
# health-monitor.sh   <-- MASTER SCRIPT, run every 5 minutes by cron
# -------------------------------------------------------------
# WHAT THIS SCRIPT DOES, STEP BY STEP:
#   1. Loads config.conf (thresholds, email, paths)
#   2. Calls each of the 7 check scripts directly and stores the
#      results in variables (this IS the metric collection step -
#      there is no separate collect_metrics.sh; it would just be
#      these same 7 lines living in a second file for no benefit)
#   3. Sources threshold_engine.sh, which reads those variables
#      and decides STATUS ("OK"/"WARNING"/"CRITICAL") + REASONS
#   4. Sources logger.sh and calls log_event to write one
#      timestamped entry to health.log
#   5. If STATUS is CRITICAL, sources email.sh and calls
#      send_critical_alert to email the administrator immediately
#
# WHO RUNS THIS SCRIPT:
#   Cron, every 5 minutes (see Step 17).
# =============================================================
 
# Find this script's own folder, so paths work no matter where
# cron or you run this script FROM.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$DIR")"
 
# 1. Load configuration
source "$BASE_DIR/config.conf"
 
# 2. Collect all 7 metrics (this is the only place this happens
#    for the 5-minute cycle - simple enough to not need its own file)
cpu_usage=$("$DIR/cpu.sh")
ram_usage=$("$DIR/ram.sh")
disk_usage=$("$DIR/disk.sh")
swap_usage=$("$DIR/swap.sh")
load_avg=$("$DIR/load.sh")
uptime_info=$("$DIR/uptime.sh")
users_count=$("$DIR/users.sh")
 
# 3. Decide STATUS and REASONS
source "$DIR/threshold_engine.sh"
 
# 4. Write the log entry (always happens, every run)
source "$DIR/logger.sh"
log_event
 
# 5. Send an instant email ONLY if something is critical
source "$DIR/email.sh"
if [ "$STATUS" = "CRITICAL" ]; then
  send_critical_alert
fi

