#!/usr/bin/env bash
# report_engine.sh - Renders the collected findings into TXT, HTML and/or
# JSON reports under REPORT_DIR. Formats are chosen via REPORT_FORMATS
# (comma-separated: txt,html,json).

_unescape_field() {
    printf '%s' "${1//@PIPE@/|}"
}

# _findings_rows <severity> - prints matching rows, one per line.
_findings_rows() {
    local severity="$1"
    [[ -f "$FINDINGS_FILE" ]] || return 0
    awk -F'|' -v s="$severity" '$1 == s' "$FINDINGS_FILE"
}

generate_reports() {
    local score risk_level hostname_val report_date base_name
    score=$(compute_security_score)
    risk_level=$(risk_rating_for_score "$score")
    hostname_val="$(hostname -f 2>/dev/null || hostname)"
    report_date="$(human_date)"
    base_name="lsams_report_${hostname_val}_$(timestamp_now)"

    ensure_dir "$REPORT_DIR"

    IFS=',' read -ra formats <<< "$REPORT_FORMATS"
    for fmt in "${formats[@]}"; do
        fmt="$(trim "$fmt")"
        case "$(to_lower "$fmt")" in
            txt)  _render_txt  "$REPORT_DIR/${base_name}.txt"  "$score" "$risk_level" "$hostname_val" "$report_date" ;;
            html) _render_html "$REPORT_DIR/${base_name}.html" "$score" "$risk_level" "$hostname_val" "$report_date" ;;
            json) _render_json "$REPORT_DIR/${base_name}.json" "$score" "$risk_level" "$hostname_val" "$report_date" ;;
            *) log_warn "Unknown report format requested: '$fmt' (skipped)" ;;
        esac
    done

    LAST_REPORT_BASENAME="$base_name"
    LAST_REPORT_SCORE="$score"
    LAST_REPORT_RISK="$risk_level"
}

_render_txt() {
    local out="$1" score="$2" risk="$3" host="$4" date="$5"
    {
        echo "=============================================================="
        echo " Linux Security Audit & Monitoring Suite (LSAMS) - Report"
        echo "=============================================================="
        echo "Host        : $host"
        echo "Generated   : $date"
        echo "Security Score : $score / 100"
        echo "Risk Rating    : $risk"
        echo "--------------------------------------------------------------"
        echo "Findings summary: CRITICAL=$(count_findings_by_severity CRITICAL) " \
             "HIGH=$(count_findings_by_severity HIGH) " \
             "MEDIUM=$(count_findings_by_severity MEDIUM) " \
             "LOW=$(count_findings_by_severity LOW) " \
             "INFO=$(count_findings_by_severity INFO)"
        echo "=============================================================="

        for sev in CRITICAL HIGH MEDIUM LOW INFO; do
            local rows
            rows="$(_findings_rows "$sev")"
            [[ -z "$rows" ]] && continue
            echo
            echo "[$sev]"
            while IFS='|' read -r severity module title detail recommendation; do
                echo "  - ($module) $(_unescape_field "$title")"
                [[ -n "$detail" ]] && echo "      Detail        : $(_unescape_field "$detail")"
                [[ -n "$recommendation" ]] && echo "      Recommendation: $(_unescape_field "$recommendation")"
            done <<< "$rows"
        done
        echo
        echo "=============================== End of Report ==============================="
    } > "$out"
    log_success "TXT report written: $out"
}

_html_escape() {
    printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

_render_html() {
    local out="$1" score="$2" risk="$3" host="$4" date="$5"
    local risk_color
    case "$risk" in
        LOW) risk_color="#2e7d32" ;;
        MEDIUM) risk_color="#f9a825" ;;
        HIGH) risk_color="#ef6c00" ;;
        *) risk_color="#c62828" ;;
    esac

    {
        cat <<HEADER
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>LSAMS Report - ${host}</title>
<style>
  body { font-family: 'Segoe UI', Arial, sans-serif; background:#f4f6f8; color:#1a1a1a; margin:0; padding:2rem; }
  .container { max-width: 960px; margin: 0 auto; }
  header { background:#12263a; color:#fff; padding:1.5rem 2rem; border-radius:8px 8px 0 0; }
  header h1 { margin:0; font-size:1.4rem; }
  header p { margin:.25rem 0 0; color:#b7c5d3; font-size:.9rem; }
  .summary { display:flex; gap:1rem; background:#fff; padding:1.5rem 2rem; flex-wrap:wrap; border-bottom:1px solid #e2e6ea; }
  .stat { flex:1; min-width:140px; text-align:center; }
  .stat .value { font-size:2rem; font-weight:700; }
  .stat .label { font-size:.8rem; color:#667; text-transform:uppercase; letter-spacing:.05em; }
  .risk-badge { display:inline-block; padding:.35rem .9rem; border-radius:999px; color:#fff; font-weight:600; background:${risk_color}; }
  section.findings { background:#fff; padding:1.5rem 2rem; }
  .sev-block { margin-bottom:1.5rem; }
  .sev-title { font-size:1rem; font-weight:700; margin-bottom:.5rem; padding-bottom:.25rem; border-bottom:2px solid #e2e6ea; }
  .finding { border-left:4px solid #ccc; background:#fafbfc; padding:.6rem .9rem; margin-bottom:.5rem; border-radius:0 4px 4px 0; }
  .finding .title { font-weight:600; }
  .finding .meta { font-size:.85rem; color:#555; margin-top:.2rem; }
  .CRITICAL { border-color:#c62828; } .HIGH { border-color:#ef6c00; }
  .MEDIUM { border-color:#f9a825; } .LOW { border-color:#1565c0; } .INFO { border-color:#546e7a; }
  footer { text-align:center; color:#8a97a3; font-size:.8rem; padding:1.5rem; }
</style>
</head>
<body>
<div class="container">
  <header>
    <h1>Linux Security Audit &amp; Monitoring Suite</h1>
    <p>Host: ${host} &nbsp;|&nbsp; Generated: ${date}</p>
  </header>
  <div class="summary">
    <div class="stat"><div class="value">${score}/100</div><div class="label">Security Score</div></div>
    <div class="stat"><div class="risk-badge">${risk}</div><div class="label">Risk Rating</div></div>
    <div class="stat"><div class="value">$(count_findings_by_severity CRITICAL)</div><div class="label">Critical</div></div>
    <div class="stat"><div class="value">$(count_findings_by_severity HIGH)</div><div class="label">High</div></div>
    <div class="stat"><div class="value">$(count_findings_by_severity MEDIUM)</div><div class="label">Medium</div></div>
    <div class="stat"><div class="value">$(count_findings_by_severity LOW)</div><div class="label">Low</div></div>
  </div>
  <section class="findings">
HEADER

        for sev in CRITICAL HIGH MEDIUM LOW INFO; do
            local rows
            rows="$(_findings_rows "$sev")"
            [[ -z "$rows" ]] && continue
            echo "    <div class=\"sev-block\"><div class=\"sev-title\">${sev}</div>"
            while IFS='|' read -r severity module title detail recommendation; do
                echo "      <div class=\"finding ${sev}\">"
                echo "        <div class=\"title\">[$(_html_escape "$module")] $(_html_escape "$(_unescape_field "$title")")</div>"
                [[ -n "$detail" ]] && echo "        <div class=\"meta\">Detail: $(_html_escape "$(_unescape_field "$detail")")</div>"
                [[ -n "$recommendation" ]] && echo "        <div class=\"meta\">Recommendation: $(_html_escape "$(_unescape_field "$recommendation")")</div>"
                echo "      </div>"
            done <<< "$rows"
            echo "    </div>"
        done

        cat <<FOOTER
  </section>
  <footer>Generated by LSAMS &middot; ${date}</footer>
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
    local out="$1" score="$2" risk="$3" host="$4" date="$5"
    {
        printf '{\n'
        printf '  "host": "%s",\n' "$(_json_escape "$host")"
        printf '  "generated_at": "%s",\n' "$(_json_escape "$date")"
        printf '  "security_score": %s,\n' "$score"
        printf '  "risk_rating": "%s",\n' "$risk"
        printf '  "summary": {\n'
        printf '    "critical": %s,\n' "$(count_findings_by_severity CRITICAL)"
        printf '    "high": %s,\n' "$(count_findings_by_severity HIGH)"
        printf '    "medium": %s,\n' "$(count_findings_by_severity MEDIUM)"
        printf '    "low": %s,\n' "$(count_findings_by_severity LOW)"
        printf '    "info": %s\n' "$(count_findings_by_severity INFO)"
        printf '  },\n'
        printf '  "findings": [\n'

        local first=true
        if [[ -f "$FINDINGS_FILE" ]]; then
            while IFS='|' read -r severity module title detail recommendation; do
                [[ -z "$severity" ]] && continue
                $first || printf ',\n'
                first=false
                printf '    {"severity": "%s", "module": "%s", "title": "%s", "detail": "%s", "recommendation": "%s"}' \
                    "$(_json_escape "$severity")" \
                    "$(_json_escape "$(_unescape_field "$module")")" \
                    "$(_json_escape "$(_unescape_field "$title")")" \
                    "$(_json_escape "$(_unescape_field "$detail")")" \
                    "$(_json_escape "$(_unescape_field "$recommendation")")"
            done < "$FINDINGS_FILE"
        fi
        printf '\n  ]\n'
        printf '}\n'
    } > "$out"
    log_success "JSON report written: $out"
}
