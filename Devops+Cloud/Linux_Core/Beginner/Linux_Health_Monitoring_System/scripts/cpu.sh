#!/bin/bash

# =====================================================
# CPU Monitoring Script
# Method 1 (Active): Using top command
# Best for beginners to understand Linux commands.
# =====================================================

# Extract CPU Idle Percentage
cpu_idle=$(top -bn1 | awk -F',' '/Cpu\(s\)/ {print $4}' | awk '{print $1}')

# Calculate CPU Usage
cpu_usage=$(echo "100 - $cpu_idle" | bc)

# Print rounded CPU Usage
printf "%.0f\n" "$cpu_usage"



# =====================================================
# Method 2 (Commented): Using /proc/stat
# Production-grade approach used by monitoring tools.
# Uncomment this section if you want to use it.
# =====================================================

# # Read CPU statistics (Snapshot 1)
# read cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
#
# # Calculate Total CPU Time
# total1=$((user + nice + system + idle + iowait + irq + softirq + steal))
#
# # Calculate Total Idle Time
# idle1=$((idle + iowait))
#
# # Wait for 1 second
# sleep 1
#
# # Read CPU statistics again (Snapshot 2)
# read cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
#
# # Calculate Total CPU Time
# total2=$((user + nice + system + idle + iowait + irq + softirq + steal))
#
# # Calculate Total Idle Time
# idle2=$((idle + iowait))
#
# # Calculate Differences
# total_diff=$((total2 - total1))
# idle_diff=$((idle2 - idle1))
#
# # Avoid division by zero
# if [ "$total_diff" -eq 0 ]; then
#     echo "0"
#     exit 0
# fi
#
# # Calculate CPU Usage Percentage
# cpu_usage=$(echo "scale=2; 100 * ($total_diff - $idle_diff) / $total_diff" | bc)
#
# # Print Rounded CPU Usage
# printf "%.0f\n" "$cpu_usage"
