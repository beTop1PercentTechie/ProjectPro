#!/bin/bash
# =============================================================
# ram.sh
# -------------------------------------------------------------
# WHAT THIS SCRIPT DOES:
#   Measures current RAM (memory) usage and prints it as a whole
#   number percentage, e.g. "34" meaning 34% of RAM is in use.
#
# HOW IT WORKS:
#   The "free" command prints a table where the "Mem:" row has:
#     column 2 = total memory (KB)
#     column 3 = used memory (KB)
#   Usage % = (used / total) * 100.
#
# WHO CALLS THIS SCRIPT:
#   health-monitor.sh and send-report.sh.
# =============================================================
free | awk '/Mem:/ {printf "%.0f\n", ($3/$2) * 100}'

