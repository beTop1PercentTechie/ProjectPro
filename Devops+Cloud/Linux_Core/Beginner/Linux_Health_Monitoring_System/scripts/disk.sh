#!/bin/bash
# =============================================================
# disk.sh
# -------------------------------------------------------------
# WHAT THIS SCRIPT DOES:
#   Measures how full the root ("/") filesystem is and prints it
#   as a whole number percentage, e.g. "41" meaning 41% full.
#
# HOW IT WORKS:
#   "df /" prints a two-line report for the root filesystem.
#   The 2nd line's 5th column is the "Use%" value, e.g. "41%".
#   "tr -d '%'" strips the percent sign so it's a plain number.
#
# WHO CALLS THIS SCRIPT:
#   health-monitor.sh and send-report.sh.
# =============================================================
df / | awk 'NR==2 {print $5}' | tr -d '%'

