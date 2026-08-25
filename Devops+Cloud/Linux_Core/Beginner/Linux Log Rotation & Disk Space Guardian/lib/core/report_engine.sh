#!/usr/bin/env bash
# report_engine.sh - Renders this run's events and remediation actions into
# TXT, HTML and/or JSON reports under REPORT_DIR. Formats are chosen via
# REPORT_FORMATS (comma-separated: txt,html,json).

generate_reports() {
    local status hostname_val report_date base_name freed_human
    status=$(overall_status)
    hostname_val="$(hostname -f 2>/dev/null || hostname)"
    report_date="$(human_date)"
    base_name="guardian_report_${hostname_val}_$(timestamp_now)"
    freed_human="$(bytes_to_human "$(total_bytes_freed_this_run)")"

    ensure_dir "$REPORT_DIR"

    IFS=',' read -ra formats <<< "$REPORT_FORMATS"
    for fmt in "${formats[@]}"; do
        fmt="$(trim "$fmt")"
        case "$(to_lower "$fmt")" in
            txt)  _render_txt  "$REPORT_DIR/${base_name}.txt"  "$status" "$hostname_val" "$report_date" "$freed_human" ;;
            html) _render_html "$REPORT_DIR/${base_name}.html" "$status" "$hostname_val" "$report_date" "$freed_human" ;;
            json) _render_json "$REPORT_DIR/${base_name}.json" "$status" "$hostname_val" "$report_date" "$freed_human" ;;
            *) log_warn "Unknown report format requested: '$fmt' (skipped)" ;;
        esac
    done

    LAST_REPORT_BASENAME="$base_name"
    LAST_REPORT_STATUS="$status"
}

_render_txt() {
    local out="$1" status="$2" host="$3" date="$4" freed_human="$5"
    {
        echo "================================================================"
        echo " Linux Log Rotation & Disk Space Guardian - Report"
        echo "================================================================"
        echo "Host          : $host"
        echo "Generated     : $date"
        echo "Overall Status: $status"
        echo "Space freed this run: $freed_human"
        echo "----------------------------------------------------------------"
        echo "Events: CRITICAL=$(count_events_by_severity CRITICAL) " \
             "WARNING=$(count_events_by_severity WARNING) " \
             "INFO=$(count_events_by_severity INFO)"
        echo "================================================================"

        for sev in CRITICAL WARNING INFO; do
            local rows
            rows="$(events_rows "$sev")"
            [[ -z "$rows" ]] && continue
            echo
            echo "[$sev]"
            while IFS='|' read -r severity category title detail; do
                echo "  - ($(_ev_unescape "$category")) $(_ev_unescape "$title")"
                [[ -n "$detail" ]] && echo "      Detail: $(_ev_unescape "$detail")"
            done <<< "$rows"
        done

        echo
        echo "[Remediation Actions This Run]"
        local action_rows
        action_rows="$(run_actions_rows)"
        if [[ -z "$action_rows" ]]; then
            echo "  (none)"
        else
            while IFS='|' read -r epoch ts action_type target bytes_before bytes_after bytes_freed detail; do
                echo "  - $ts | $action_type | $(_ev_unescape "$target") | freed: $(bytes_to_human "$bytes_freed") | $(_ev_unescape "$detail")"
            done <<< "$action_rows"
        fi
        echo
        echo "=============================== End of Report ==============================="
    } > "$out"
    log_success "TXT report written: $out"
}

_html_escape() {
    printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

_render_html() {
    local out="$1" status="$2" host="$3" date="$4" freed_human="$5"
    local status_color
    case "$status" in
        OK) status_color="#2e7d32" ;;
        WARNING) status_color="#f9a825" ;;
        *) status_color="#c62828" ;;
    esac

    {
        cat <<HEADER
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Guardian Report - ${host}</title>
<style>
  body { font-family: 'Segoe UI', Arial, sans-serif; background:#f4f6f8; color:#1a1a1a; margin:0; padding:2rem; }
  .container { max-width: 960px; margin: 0 auto; }
  header { background:#12263a; color:#fff; padding:1.5rem 2rem; border-radius:8px 8px 0 0; }
  header h1 { margin:0; font-size:1.4rem; }
  header p { margin:.25rem 0 0; color:#b7c5d3; font-size:.9rem; }
  .summary { display:flex; gap:1rem; background:#fff; padding:1.5rem 2rem; flex-wrap:wrap; border-bottom:1px solid #e2e6ea; }
  .stat { flex:1; min-width:140px; text-align:center; }
  .stat .value { font-size:1.6rem; font-weight:700; }
  .stat .label { font-size:.8rem; color:#667; text-transform:uppercase; letter-spacing:.05em; }
  .status-badge { display:inline-block; padding:.35rem .9rem; border-radius:999px; color:#fff; font-weight:600; background:${status_color}; }
  section.block { background:#fff; padding:1.5rem 2rem; }
  .sev-block { margin-bottom:1.5rem; }
  .sev-title { font-size:1rem; font-weight:700; margin-bottom:.5rem; padding-bottom:.25rem; border-bottom:2px solid #e2e6ea; }
  .item { border-left:4px solid #ccc; background:#fafbfc; padding:.6rem .9rem; margin-bottom:.5rem; border-radius:0 4px 4px 0; }
  .item .title { font-weight:600; }
  .item .meta { font-size:.85rem; color:#555; margin-top:.2rem; }
  .CRITICAL { border-color:#c62828; } .WARNING { border-color:#f9a825; } .INFO { border-color:#1565c0; }
  table { width:100%; border-collapse:collapse; font-size:.9rem; }
  th, td { text-align:left; padding:.5rem; border-bottom:1px solid #e2e6ea; }
  footer { text-align:center; color:#8a97a3; font-size:.8rem; padding:1.5rem; }
</style>
</head>
<body>
<div class="container">
  <header>
    <h1>Linux Log Rotation &amp; Disk Space Guardian</h1>
    <p>Host: ${host} &nbsp;|&nbsp; Generated: ${date}</p>
  </header>
  <div class="summary">
    <div class="stat"><div class="status-badge">${status}</div><div class="label">Overall Status</div></div>
    <div class="stat"><div class="value">${freed_human}</div><div class="label">Space Freed This Run</div></div>
    <div class="stat"><div class="value">$(count_events_by_severity CRITICAL)</div><div class="label">Critical</div></div>
    <div class="stat"><div class="value">$(count_events_by_severity WARNING)</div><div class="label">Warning</div></div>
    <div class="stat"><div class="value">$(count_events_by_severity INFO)</div><div class="label">Info</div></div>
  </div>
  <section class="block">
HEADER

        for sev in CRITICAL WARNING INFO; do
            local rows
            rows="$(events_rows "$sev")"
            [[ -z "$rows" ]] && continue
            echo "    <div class=\"sev-block\"><div class=\"sev-title\">${sev}</div>"
            while IFS='|' read -r severity category title detail; do
                echo "      <div class=\"item ${sev}\">"
                echo "        <div class=\"title\">[$(_html_escape "$(_ev_unescape "$category")")] $(_html_escape "$(_ev_unescape "$title")")</div>"
                [[ -n "$detail" ]] && echo "        <div class=\"meta\">$(_html_escape "$(_ev_unescape "$detail")")</div>"
                echo "      </div>"
            done <<< "$rows"
            echo "    </div>"
        done

        echo "    <div class=\"sev-block\"><div class=\"sev-title\">Remediation Actions This Run</div>"
        local action_rows
        action_rows="$(run_actions_rows)"
        if [[ -z "$action_rows" ]]; then
            echo "      <p>No remediation actions were needed this run.</p>"
        else
            echo "      <table><tr><th>Time</th><th>Action</th><th>Target</th><th>Freed</th><th>Detail</th></tr>"
            while IFS='|' read -r epoch ts action_type target bytes_before bytes_after bytes_freed detail; do
                echo "        <tr><td>$(_html_escape "$ts")</td><td>$(_html_escape "$action_type")</td>" \
                     "<td>$(_html_escape "$(_ev_unescape "$target")")</td><td>$(bytes_to_human "$bytes_freed")</td>" \
                     "<td>$(_html_escape "$(_ev_unescape "$detail")")</td></tr>"
            done <<< "$action_rows"
            echo "      </table>"
        fi
        echo "    </div>"

        cat <<FOOTER
  </section>
  <footer>Generated by Guardian &middot; ${date}</footer>
</div>
</body>
</html>
FOOTER
    } > "$out"
    log_success "HTML report written: $out"
}

_json_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

_render_json() {
    local out="$1" status="$2" host="$3" date="$4" freed_human="$5"
    {
        printf '{\n'
        printf '  "host": "%s",\n' "$(_json_escape "$host")"
        printf '  "generated_at": "%s",\n' "$(_json_escape "$date")"
        printf '  "overall_status": "%s",\n' "$status"
        printf '  "bytes_freed_this_run": %s,\n' "$(total_bytes_freed_this_run)"
        printf '  "summary": {\n'
        printf '    "critical": %s,\n' "$(count_events_by_severity CRITICAL)"
        printf '    "warning": %s,\n' "$(count_events_by_severity WARNING)"
        printf '    "info": %s\n' "$(count_events_by_severity INFO)"
        printf '  },\n'

        printf '  "events": [\n'
        local first=true
        if [[ -f "$EVENTS_FILE" ]]; then
            while IFS='|' read -r severity category title detail; do
                [[ -z "$severity" ]] && continue
                $first || printf ',\n'
                first=false
                printf '    {"severity": "%s", "category": "%s", "title": "%s", "detail": "%s"}' \
                    "$(_json_escape "$severity")" \
                    "$(_json_escape "$(_ev_unescape "$category")")" \
                    "$(_json_escape "$(_ev_unescape "$title")")" \
                    "$(_json_escape "$(_ev_unescape "$detail")")"
            done < "$EVENTS_FILE"
        fi
        printf '\n  ],\n'

        printf '  "actions": [\n'
        first=true
        local action_rows
        action_rows="$(run_actions_rows)"
        if [[ -n "$action_rows" ]]; then
            while IFS='|' read -r epoch ts action_type target bytes_before bytes_after bytes_freed detail; do
                $first || printf ',\n'
                first=false
                printf '    {"time": "%s", "action": "%s", "target": "%s", "bytes_before": %s, "bytes_after": %s, "bytes_freed": %s, "detail": "%s"}' \
                    "$(_json_escape "$ts")" "$(_json_escape "$action_type")" \
                    "$(_json_escape "$(_ev_unescape "$target")")" \
                    "$bytes_before" "$bytes_after" "$bytes_freed" \
                    "$(_json_escape "$(_ev_unescape "$detail")")"
            done <<< "$action_rows"
        fi
        printf '\n  ]\n'
        printf '}\n'
    } > "$out"
    log_success "JSON report written: $out"
}
