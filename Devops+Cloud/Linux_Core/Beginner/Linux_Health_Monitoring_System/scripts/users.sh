#!/bin/bash
# =============================================================
# users.sh
# -------------------------------------------------------------
# WHAT THIS SCRIPT DOES:
#   Displays the number of active SSH connections and the
#   usernames of users currently connected via SSH.
#
# WHY THIS METHOD?
#   Traditional commands like "who" or "users" rely on the
#   utmp database, which may not be populated correctly on
#   modern cloud environments (AWS EC2, Azure, GCP, etc.).
#
#   Therefore, we:
#     1. Count active SSH TCP connections.
#     2. Extract usernames from active SSH session processes.
#
# HOW IT WORKS:
#
#   Connection Count:
#     ss -tn state established '( sport = :22 )'
#       -> Shows all active SSH TCP connections.
#
#     tail -n +2
#       -> Removes the header line.
#
#     wc -l
#       -> Counts the remaining SSH connections.
#
#   Connected Users:
#     ps -ef
#       -> Lists all running processes.
#
#     grep "[s]shhd-session:.*@pts/"
#       -> Keeps only active SSH login sessions.
#
#     awk '{print $1}'
#       -> Prints the username column.
#
#     sort -u
#       -> Removes duplicate usernames.
#
# ALTERNATIVE:
#   On traditional Linux servers where utmp is maintained,
#   the following command can be used instead:
#
#       w -h | wc -l
#
# WHO CALLS THIS SCRIPT:
#   health-monitor.sh and send-report.sh.
# =============================================================

echo "Active SSH Connections : $(ss -tn state established '( sport = :22 )' | tail -n +2 | wc -l)"

echo
echo "Connected Users:"

ps -ef \
| grep "[s]shd-session:.*@pts/" \
| awk '{print $1}' \
| sort -u

# -----------------------------------------------------------------
# Alternative (Traditional Linux Servers)
# -----------------------------------------------------------------
# Count logged-in interactive sessions.
# This works only if the system maintains the utmp database.
#
# w -h | wc -l
