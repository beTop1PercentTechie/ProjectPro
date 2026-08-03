#!/bin/bash
# =============================================================
# load.sh
# -------------------------------------------------------------
# WHAT THIS SCRIPT DOES:
#   Prints the server's 1-minute load average, e.g. "0.42".
#
# HOW IT WORKS:
#   "uptime" ends with text like:
#     load average: 0.42, 0.30, 0.25
#   These are the 1, 5, and 15-minute averages. We only need the
#   1-minute value (the most sensitive to sudden spikes), so we
#   cut everything after the first comma.
#
# WHO CALLS THIS SCRIPT:
#   health-monitor.sh and send-report.sh.
# =============================================================
uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | xargs

