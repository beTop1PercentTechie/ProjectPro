#!/bin/bash
# =============================================================
# send-report.sh   <-- runs once an hour by cron
# -------------------------------------------------------------
# WHAT THIS SCRIPT DOES, STEP BY STEP:
#   1. Loads config.conf
#   2. Collects all 7 metrics (same short collection step as
#      health-monitor.sh - this script does not need the
#      threshold engine or the logger, only fresh metric values
#      to build the HTML report with)
#   3. Runs html_report.sh and SAVES its printed HTML output into
#      a dated file inside reports/
#   4. Calls email.sh's send_html_email function to email that
#      saved file to the administrator
#
# WHO RUNS THIS SCRIPT:
#   Cron, once every hour, on the hour (see Step 17).
# =============================================================
 
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$DIR")"
 
# 1. Load configuration
source "$BASE_DIR/config.conf"
 
# 2. Collect all 7 metrics fresh, right now
cpu_usage=$("$DIR/cpu.sh")
ram_usage=$("$DIR/ram.sh")
disk_usage=$("$DIR/disk.sh")
swap_usage=$("$DIR/swap.sh")
load_avg=$("$DIR/load.sh")
uptime_info=$("$DIR/uptime.sh")
users_count=$("$DIR/users.sh")
 
# 3. Build the HTML report and save it with a dated filename
source "$DIR/email.sh"
mkdir -p "$REPORT_DIR"
report_file="$REPORT_DIR/health-$(date '+%Y-%m-%d-%H').html"
"$DIR/html_report.sh" > "$report_file"
 
# 4. Email the saved HTML file to the administrator
send_html_email "Hourly Health Report - $(hostname)" "$report_file"

