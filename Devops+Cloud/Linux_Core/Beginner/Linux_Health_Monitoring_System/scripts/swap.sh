#!/bin/bash
# =============================================================
# swap.sh
# -------------------------------------------------------------
# WHAT THIS SCRIPT DOES:
#   Measures current swap usage and prints it as a whole number
#   percentage.
#
# HOW IT WORKS:
#   The "free" command's "Swap:" row has:
#     column 2 = total swap (KB)
#     column 3 = used swap (KB)
#   If total swap is 0 (some EC2 instance types have no swap),
#   we print 0 instead of dividing by zero, which would crash
#   the script.
#
# WHO CALLS THIS SCRIPT:
#   health-monitor.sh and send-report.sh.
# =============================================================
free | awk '/Swap:/ {
  if ($2 == 0) { print 0 }
  else { printf "%.0f\n", ($3/$2) * 100 }
}'

