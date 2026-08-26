#!/bin/bash

# ==========================================
# SSL MONITOR EMAIL FUNCTIONS
# ==========================================

set -u

# ------------------------------------------
# Determine directories
# ------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ------------------------------------------
# Configuration
# ------------------------------------------

EMAIL_CONFIG="$PROJECT_DIR/config/email.conf"
TEMPLATE_DIR="$PROJECT_DIR/templates"

# ------------------------------------------
# Load email configuration
# ------------------------------------------

if [[ ! -f "$EMAIL_CONFIG" ]]; then

    echo "ERROR: Email configuration not found:"
    echo "$EMAIL_CONFIG"

    return 1 2>/dev/null || exit 1

fi

source "$EMAIL_CONFIG"

# ------------------------------------------
# Validate email configuration
# ------------------------------------------

if [[ -z "${EMAIL_FROM:-}" ]]; then

    echo "ERROR: EMAIL_FROM is not configured."

    return 1 2>/dev/null || exit 1

fi

if [[ -z "${EMAIL_FROM_NAME:-}" ]]; then

    echo "ERROR: EMAIL_FROM_NAME is not configured."

    return 1 2>/dev/null || exit 1

fi

if [[ -z "${ALERT_EMAIL:-}" ]]; then

    echo "ERROR: ALERT_EMAIL is not configured."

    return 1 2>/dev/null || exit 1

fi

# ------------------------------------------
# Check sendmail
# ------------------------------------------

SENDMAIL="/usr/sbin/sendmail"

if [[ ! -x "$SENDMAIL" ]]; then

    echo "ERROR: sendmail was not found:"
    echo "$SENDMAIL"

    return 1 2>/dev/null || exit 1

fi


# ==========================================
# Render HTML Template
# ==========================================

render_template() {

    local TEMPLATE_FILE="$1"

    if [[ ! -f "$TEMPLATE_FILE" ]]; then

        echo "ERROR: Email template not found:"
        echo "$TEMPLATE_FILE"

        return 1

    fi

    sed \
        -e "s|{{DOMAIN}}|${DOMAIN}|g" \
        -e "s|{{REMAINING_DAYS}}|${REMAINING_DAYS}|g" \
        -e "s|{{EXPIRY_DATE}}|${EXPIRY_DATE}|g" \
        -e "s|{{CERTIFICATE}}|${CERTIFICATE}|g" \
        -e "s|{{STATUS}}|${STATUS}|g" \
        "$TEMPLATE_FILE"
}


# ==========================================
# Send HTML Email
# ==========================================

send_html_email() {

    local SUBJECT="$1"
    local TEMPLATE_FILE="$2"

    local HTML_BODY

    HTML_BODY=$(render_template "$TEMPLATE_FILE") || return 1

    echo "Sending email:"
    echo "  From    : $EMAIL_FROM_NAME <$EMAIL_FROM>"
    echo "  To      : $ALERT_EMAIL"
    echo "  Subject : $SUBJECT"

    if ! {

        printf 'From: %s <%s>\n' \
            "$EMAIL_FROM_NAME" \
            "$EMAIL_FROM"

        printf 'To: %s\n' \
            "$ALERT_EMAIL"

        printf 'Subject: %s\n' \
            "$SUBJECT"

        printf 'MIME-Version: 1.0\n'

        printf 'Content-Type: text/html; charset=UTF-8\n'

        printf 'Content-Transfer-Encoding: 8bit\n'

        printf 'X-Mailer: SSL Certificate Monitor\n'

        printf '\n'

        printf '%s\n' "$HTML_BODY"

    } | "$SENDMAIL" -t -oi; then

        echo "ERROR: Failed to send email."

        return 1

    fi

    echo "Email sent successfully."

    return 0
}


# ==========================================
# HEALTHY EMAIL
# ==========================================

send_healthy_email() {

    local SUBJECT

    SUBJECT="SSL Certificate Healthy - ${DOMAIN}"

    send_html_email \
        "$SUBJECT" \
        "$TEMPLATE_DIR/healthy.html"
}


# ==========================================
# WARNING EMAIL
# ==========================================

send_warning_email() {

    local SUBJECT

    SUBJECT="SSL Certificate Warning - ${DOMAIN}"

    send_html_email \
        "$SUBJECT" \
        "$TEMPLATE_DIR/warning.html"
}


# ==========================================
# CRITICAL EMAIL
# ==========================================

send_critical_email() {

    local SUBJECT

    SUBJECT="URGENT: SSL Certificate Critical - ${DOMAIN}"

    send_html_email \
        "$SUBJECT" \
        "$TEMPLATE_DIR/critical.html"
}


# ==========================================
# EXPIRED EMAIL
# ==========================================

send_expired_email() {

    local SUBJECT

    SUBJECT="URGENT: SSL Certificate Expired - ${DOMAIN}"

    send_html_email \
        "$SUBJECT" \
        "$TEMPLATE_DIR/expired.html"
}


# ==========================================
# RENEWAL SUCCESS / SIMULATION EMAIL
# ==========================================

send_renewal_success_email() {

    local SUBJECT
    local TEMPLATE

    # --------------------------------------
    # DEMO MODE
    # --------------------------------------

    if [[ "${DEMO_MODE:-false}" == "true" ]]; then

        SUBJECT="SSL Renewal Simulation Successful - ${DOMAIN}"

        TEMPLATE="$TEMPLATE_DIR/renewal-simulation-success.html"

    # --------------------------------------
    # PRODUCTION MODE
    # --------------------------------------

    else

        SUBJECT="SSL Certificate Renewal Successful - ${DOMAIN}"

        TEMPLATE="$TEMPLATE_DIR/renewal-success.html"

    fi

    send_html_email \
        "$SUBJECT" \
        "$TEMPLATE"
}


# ==========================================
# RENEWAL FAILURE EMAIL
# ==========================================

send_renewal_failure_email() {

    local SUBJECT

    SUBJECT="URGENT: SSL Certificate Renewal Failed - ${DOMAIN}"

    send_html_email \
        "$SUBJECT" \
        "$TEMPLATE_DIR/renewal-failure.html"
}


# ==========================================
# Send Email According To Status
# ==========================================

send_status_email() {

    case "$STATUS" in

        HEALTHY)

            if [[ "${EMAIL_ON_HEALTHY:-false}" == "true" ]]; then

                send_healthy_email

            else

                echo "Healthy email notifications are disabled."

            fi

            ;;

        WARNING)

            send_warning_email

            ;;

        CRITICAL)

            send_critical_email

            ;;

        EXPIRED)

            send_expired_email

            ;;

        *)

            echo "ERROR: Unknown certificate status:"
            echo "$STATUS"

            return 1

            ;;

    esac
}
