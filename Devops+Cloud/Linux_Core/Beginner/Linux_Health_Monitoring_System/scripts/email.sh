#!/bin/bash
# =============================================================
# email.sh
# -------------------------------------------------------------
# WHAT THIS SCRIPT DOES:
#   Defines TWO functions for sending emails. It does not send
#   anything by itself just by being sourced - something else
#   must call one of these functions.
#
#   1) send_critical_alert
#        Sends a short PLAIN-TEXT emergency email immediately,
#        used only when STATUS="CRITICAL". Uses the "mail"
#        command, which is fine for plain text.
#
#   2) send_html_email "<subject>" "<path-to-html-file>"
#        Sends an HTML file (already built by html_report.sh) as
#        a properly formatted HTML email, using "sendmail"
#        directly (not "mail") because we need to set the
#        "Content-Type: text/html" header ourselves - the plain
#        "mail" command strips this header, which would make the
#        email show raw <html> tags as text instead of rendering.
#
# VARIABLES send_critical_alert EXPECTS TO ALREADY EXIST:
#   cpu_usage, ram_usage, disk_usage, swap_usage, load_avg,
#   REASONS (array), EMAIL (from config.conf)
#
# WHO USES THIS SCRIPT:
#   health-monitor.sh calls send_critical_alert() when CRITICAL.
#   send-report.sh calls send_html_email() every hour.
# =============================================================
 
send_critical_alert() {
  local subject="CRITICAL ALERT: $(hostname) - ${cpu_usage}% CPU"
 
  # Build a readable list of reasons, one per line
  local reasons_text=""
  for r in "${REASONS[@]}"; do
    reasons_text="$reasons_text
  - $r"
  done
 
  local msg="Immediate attention required.
 
Server : $(hostname) (AWS EC2 Ubuntu)
Time   : $(date '+%Y-%m-%d %H:%M:%S')
 
CPU Usage  : ${cpu_usage}%
RAM Usage  : ${ram_usage}%
Disk Usage : ${disk_usage}%
Swap Usage : ${swap_usage}%
Load Avg   : ${load_avg}
 
Reasons:$reasons_text"
 
  echo "$msg" | mail -s "$subject" "$EMAIL"
}
 
send_html_email() {
  # $1 = email subject line
  # $2 = path to an already-generated HTML file (see html_report.sh)
  local subject="$1"
  local html_file="$2"
  (
    echo "Subject: $subject"
    echo "To: $EMAIL"
    echo "MIME-Version: 1.0"
    echo "Content-Type: text/html"
    echo ""
    cat "$html_file"
  ) | sendmail -t
}

