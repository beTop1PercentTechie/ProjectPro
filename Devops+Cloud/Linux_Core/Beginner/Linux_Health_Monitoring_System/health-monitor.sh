#!/bin/bash
# =============================================================
# health-monitor.sh
# -------------------------------------------------------------
# A simple, beginner-friendly Linux Health Monitor.
#
# WHAT THIS SCRIPT DOES, STEP BY STEP:
#   1. Collects 7 basic health metrics: CPU, RAM, Disk, Swap,
#      Load Average, Uptime, and logged-in/SSH users.
#   2. Writes one timestamped entry with all of the above into
#      logs/health.log (in the same folder as this script).
#
# HOW TO RUN IT:
#   1. Make it executable (only needed once):
#        chmod +x health-monitor.sh
#   2. Run it:
#        ./health-monitor.sh
#   3. Open logs/health.log to see the result.
#
#   (There is no automatic scheduling here - just run the
#   script whenever you want a fresh health check.)
# =============================================================

# -------------------------------------------------------------
# 0. Setup - find this script's own folder and the logs folder
# -------------------------------------------------------------
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$DIR/logs"
LOG_FILE="$LOG_DIR/health.log"

# Create the logs folder automatically if it doesn't exist yet.
mkdir -p "$LOG_DIR"

# -------------------------------------------------------------
# 1. Collect metrics
# -------------------------------------------------------------

# --- CPU Usage (%) ---
# Read CPU idle % from "top" and subtract from 100.
cpu_idle=$(top -bn1 | awk -F',' '/Cpu\(s\)/ {print $4}' | awk '{print $1}')
cpu_usage=$(printf "%.0f" "$(echo "100 - $cpu_idle" | bc)")

# --- RAM Usage (%) ---
# "free" shows total and used memory on the "Mem:" row.
ram_usage=$(free | awk '/Mem:/ {printf "%.0f", ($3/$2) * 100}')

# --- Disk Usage (%) ---
# "df /" shows how full the root filesystem is (Use% column).
disk_usage=$(df / | awk 'NR==2 {print $5}' | tr -d '%')

# --- Swap Usage (%) ---
# "free" shows total and used swap on the "Swap:" row.
# If a machine has no swap (total = 0), print 0 instead of
# dividing by zero.
swap_usage=$(free | awk '/Swap:/ {
  if ($2 == 0) { print 0 }
  else { printf "%.0f", ($3/$2) * 100 }
}')

# --- Load Average (1-minute) ---
# "uptime" ends with "load average: 0.42, 0.30, 0.25".
# We only need the 1-minute value.
load_avg=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | xargs)

# --- System Uptime (human-readable) ---
uptime_info=$(uptime -p)

# --- Connected Users ---
# Count active SSH connections and list connected usernames.
# (Using ss/ps instead of "who"/"users" because utmp is often
# not populated correctly on cloud VMs.)
ssh_connections=$(ss -tn state established '( sport = :22 )' | tail -n +2 | wc -l)
connected_users=$(ps -ef | grep "[s]shd-session:.*@pts/" | awk '{print $1}' | sort -u)
if [ -z "$connected_users" ]; then
  connected_users="(none)"
fi

# -------------------------------------------------------------
# 2. Write one entry to logs/health.log
# -------------------------------------------------------------
{
  echo "[$(date '+%Y-%m-%d %H:%M:%S')]"
  echo ""
  echo "CPU Usage        : ${cpu_usage}%"
  echo "RAM Usage        : ${ram_usage}%"
  echo "Disk Usage       : ${disk_usage}%"
  echo "Swap Usage       : ${swap_usage}%"
  echo "Load Avg (1 min) : ${load_avg}"
  echo "Uptime           : ${uptime_info}"
  echo "SSH Connections  : ${ssh_connections}"
  echo "Connected Users  : ${connected_users}"
  echo "---------------------------------------------"
} >> "$LOG_FILE"
# ">>" APPENDS to the file, so every run adds a new entry below
# the previous ones instead of erasing the history.

# -------------------------------------------------------------
# 3. Also show the result on screen
# -------------------------------------------------------------
echo "Health check complete."
echo "Full details logged to: $LOG_FILE"
