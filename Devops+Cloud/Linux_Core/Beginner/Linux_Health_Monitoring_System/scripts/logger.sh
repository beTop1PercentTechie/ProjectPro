#!/bin/bash
# =============================================================
# logger.sh
# -------------------------------------------------------------
# WHAT THIS SCRIPT DOES:
#   Appends ONE structured, timestamped entry to LOG_FILE every
#   time log_event is called. This is the permanent audit trail
#   of every health check the system has ever run.
#
# WHAT THIS SCRIPT DOES NOT DO:
#   It does not collect metrics and does not decide the STATUS.
#   It only writes down values that health-monitor.sh already
#   collected and that threshold_engine.sh already evaluated.
#
# VARIABLES THIS SCRIPT EXPECTS TO ALREADY EXIST (set by the
# caller before sourcing this file and calling log_event):
#   cpu_usage, ram_usage, disk_usage, swap_usage, load_avg,
#   uptime_info, users_count, STATUS, REASONS
#
# WHO SOURCES THIS SCRIPT:
#   health-monitor.sh, using:  source logger.sh   then   log_event
# =============================================================
 
log_event() {
  {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo ""
    echo "CPU Usage   : ${cpu_usage}%"
    echo "RAM Usage   : ${ram_usage}%"
    echo "Disk Usage  : ${disk_usage}%"
    echo "Swap Usage  : ${swap_usage}%"
    echo "Load Avg    : ${load_avg}"
    echo "Uptime      : ${uptime_info}"
    echo "Users       : ${users_count}"
    echo ""
    echo "STATUS : $STATUS"
    if [ "${#REASONS[@]}" -gt 0 ]; then
      echo "Reasons :"
      for r in "${REASONS[@]}"; do
        echo "  - $r"
      done
    fi
    echo "---------------------------------------------"
  } >> "$LOG_FILE"
  # ">>" APPENDS to the file. Never change this to ">" (that would
  # overwrite/erase all previous history every single run).
}

