#!/bin/bash
# =============================================================
# uptime.sh
# -------------------------------------------------------------
# WHAT THIS SCRIPT DOES:
#   Prints a human-friendly uptime string, e.g. "up 3 days, 4 hours".
#
# HOW IT WORKS:
#   "uptime -p" is a built-in flag that formats uptime nicely,
#   so no extra text processing is needed.
#
# WHO CALLS THIS SCRIPT:
#   health-monitor.sh (for the log) and send-report.sh (for the
#   HTML report) — informational only, never threshold-checked.
# =============================================================
uptime -p

