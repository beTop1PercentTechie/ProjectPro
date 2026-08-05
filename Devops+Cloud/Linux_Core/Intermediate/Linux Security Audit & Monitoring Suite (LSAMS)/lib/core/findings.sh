#!/usr/bin/env bash
# findings.sh - Central store for audit findings and the security score.
#
# Every module reports through add_finding() instead of building its own
# report fragments. Findings are appended to a pipe-delimited data file
# (rather than a bash array) so state survives across sourced modules and
# any subshells they spawn via pipelines.
#
# Line format: SEVERITY|MODULE|TITLE|DETAIL|RECOMMENDATION
# Pipe characters inside fields are replaced with the @PIPE@ placeholder by
# _escape_field so they never collide with the column delimiter. Plain bash
# substitution is used deliberately - GNU tr has no \xHH hex-escape support,
# so 'tr "|" "\x7c"' silently maps to the literal 4-char string instead.

init_findings_store() {
    FINDINGS_FILE="$(mktemp "${LSAMS_TMP_DIR:-/tmp}/lsams_findings.XXXXXX")"
    : > "$FINDINGS_FILE"
}

_escape_field() {
    local s="$1"
    s="${s//|/@PIPE@}"
    s="${s//$'\n'/ }"
    printf '%s' "$s"
}

# add_finding <SEVERITY> <MODULE> <TITLE> <DETAIL> <RECOMMENDATION>
# SEVERITY one of: CRITICAL HIGH MEDIUM LOW INFO
add_finding() {
    local severity="$1" module="$2" title="$3" detail="$4" recommendation="$5"

    printf '%s|%s|%s|%s|%s\n' \
        "$severity" \
        "$(_escape_field "$module")" \
        "$(_escape_field "$title")" \
        "$(_escape_field "$detail")" \
        "$(_escape_field "$recommendation")" >> "$FINDINGS_FILE"

    case "$severity" in
        CRITICAL) log_critical "[$module] $title" ;;
        HIGH)     log_error    "[$module] $title" ;;
        MEDIUM)   log_warn     "[$module] $title" ;;
        LOW)      log_info     "[$module] $title" ;;
        *)        log_info     "[$module] $title" ;;
    esac
}

count_findings_by_severity() {
    local severity="$1"
    [[ -f "$FINDINGS_FILE" ]] || { echo 0; return; }
    awk -F'|' -v s="$severity" '$1 == s { c++ } END { print c+0 }' "$FINDINGS_FILE"
}

# compute_security_score - 100 minus weighted deductions, floored at 0.
compute_security_score() {
    local crit high med low score
    crit=$(count_findings_by_severity CRITICAL)
    high=$(count_findings_by_severity HIGH)
    med=$(count_findings_by_severity MEDIUM)
    low=$(count_findings_by_severity LOW)

    score=$(( 100 - (crit * SCORE_CRITICAL) - (high * SCORE_HIGH) - (med * SCORE_MEDIUM) - (low * SCORE_LOW) ))
    (( score < 0 )) && score=0
    echo "$score"
}

# risk_rating_for_score <score> - maps a numeric score to a risk label.
risk_rating_for_score() {
    local score="$1"
    if   (( score >= 90 )); then echo "LOW"
    elif (( score >= 70 )); then echo "MEDIUM"
    elif (( score >= 40 )); then echo "HIGH"
    else                          echo "CRITICAL"
    fi
}

cleanup_findings_store() {
    [[ -n "${FINDINGS_FILE:-}" && -f "$FINDINGS_FILE" ]] && rm -f "$FINDINGS_FILE"
}
