#!/bin/bash
# =============================================================
# html_report.sh
# -------------------------------------------------------------
# WHAT THIS SCRIPT DOES:
#   PRINTS a complete, colour-coded HTML page (as text) that
#   summarizes the server's current health. It does NOT save a
#   file and does NOT send an email itself - it only prints.
#
#   The caller (send-report.sh) is responsible for:
#     a) redirecting this script's output into a saved .html file
#     b) emailing that file using email.sh's send_html_email()
#
# HOW THE COLOUR LOGIC WORKS (status_colour function):
#   - value >= threshold           -> RED    (#e74c3c) - breached
#   - value >= threshold - 15      -> AMBER  (#f39c12) - getting close
#   - otherwise                    -> GREEN  (#27ae60) - healthy
#
# VARIABLES THIS SCRIPT EXPECTS TO ALREADY EXIST:
#   cpu_usage, ram_usage, disk_usage, swap_usage, load_avg,
#   uptime_info, users_count, and the *_THRESHOLD variables
#   from config.conf.
#
# WHO CALLS THIS SCRIPT:
#   send-report.sh, using:
#     ./html_report.sh > report_file.html
# =============================================================
 
status_colour() {
  local value="$1" threshold="$2"
  local warn_at=$((threshold - 15))
  if   [ "$value" -ge "$threshold" ]; then echo "#e74c3c"        # red = breached
  elif [ "$value" -ge "$warn_at" ]; then echo "#f39c12"          # amber = getting close
  else echo "#27ae60"; fi                                        # green = healthy
}
 
cat <<EOF
<html>
<body style="font-family:Arial, sans-serif; background:#f7f7f7; padding:20px;">
  <h2 style="color:#1F3864;">Linux Health Report - $(hostname)</h2>
  <p style="color:#555;">Generated: $(date '+%Y-%m-%d %H:%M:%S')  |  Uptime: ${uptime_info}</p>
  <table style="border-collapse:collapse;width:100%;max-width:500px;">
    <tr style="background:#1F3864;color:#fff;">
      <th style="padding:8px;text-align:left;">Metric</th>
      <th style="padding:8px;text-align:left;">Value</th>
    </tr>
    <tr><td style="padding:8px;">CPU</td>
        <td style="padding:8px;color:$(status_colour "$cpu_usage" "$CPU_THRESHOLD");font-weight:bold;">${cpu_usage}%</td></tr>
    <tr><td style="padding:8px;">RAM</td>
        <td style="padding:8px;color:$(status_colour "$ram_usage" "$RAM_THRESHOLD");font-weight:bold;">${ram_usage}%</td></tr>
    <tr><td style="padding:8px;">Disk</td>
        <td style="padding:8px;color:$(status_colour "$disk_usage" "$DISK_THRESHOLD");font-weight:bold;">${disk_usage}%</td></tr>
    <tr><td style="padding:8px;">Swap</td>
        <td style="padding:8px;color:$(status_colour "$swap_usage" "$SWAP_THRESHOLD");font-weight:bold;">${swap_usage}%</td></tr>
    <tr><td style="padding:8px;">Load Avg</td>
        <td style="padding:8px;color:$(status_colour "${load_avg%.*}" "$LOAD_THRESHOLD");font-weight:bold;">${load_avg}</td></tr>
    <tr><td style="padding:8px;">Logged-in Users</td>
        <td style="padding:8px;">${users_count}</td></tr>
  </table>
</body>
</html>
EOF

