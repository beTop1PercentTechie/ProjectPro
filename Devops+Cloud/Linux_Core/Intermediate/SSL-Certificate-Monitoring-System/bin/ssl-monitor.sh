#!/bin/bash

set -euo pipefail

# ==========================================
# SSL CERTIFICATE MONITOR
# Main Controller
# ==========================================

# ------------------------------------------
# Determine script directory
# ------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ------------------------------------------
# Load functions
# ------------------------------------------

source "$SCRIPT_DIR/certificate.sh"
source "$SCRIPT_DIR/verification.sh"
source "$SCRIPT_DIR/email.sh"
source "$SCRIPT_DIR/renewal.sh"

# ==========================================
# CONFIGURATION
# ==========================================

CONFIG_FILE="/home/ubuntu/ssl-monitor/config/ssl-monitor.conf"

# ------------------------------------------
# Load configuration
# ------------------------------------------

if [[ ! -f "$CONFIG_FILE" ]]; then

    echo "ERROR: Configuration file not found:"
    echo "$CONFIG_FILE"

    exit 4

fi

source "$CONFIG_FILE"

# ==========================================
# VALIDATION
# ==========================================

# ------------------------------------------
# Validate required configuration
# ------------------------------------------

if [[ -z "${DOMAIN:-}" ]]; then

    echo "ERROR: DOMAIN is not configured."

    exit 4

fi


if [[ -z "${CERTIFICATE:-}" ]]; then

    echo "ERROR: CERTIFICATE is not configured."

    exit 4

fi


if [[ ! -f "$CERTIFICATE" ]]; then

    echo "ERROR: Certificate file does not exist:"
    echo "$CERTIFICATE"

    exit 4

fi

# ------------------------------------------
# Check required commands
# ------------------------------------------

if ! command -v openssl >/dev/null 2>&1; then

    echo "ERROR: OpenSSL is not installed."

    exit 4

fi


if ! command -v certbot >/dev/null 2>&1; then

    echo "ERROR: Certbot is not installed."

    exit 4

fi


if ! command -v nginx >/dev/null 2>&1; then

    echo "ERROR: Nginx is not installed."

    exit 4

fi

# ==========================================
# CERTIFICATE CHECK
# ==========================================

check_certificate_status

# ==========================================
# PREPARE MONITORING OUTPUT
# ==========================================

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

OUTPUT="
==========================================
       SSL CERTIFICATE MONITOR
==========================================

Timestamp       : $TIMESTAMP
Domain          : $DOMAIN
Certificate     : $CERTIFICATE

Expiry Date     : $EXPIRY_DATE
Days Remaining  : $REMAINING_DAYS

Warning Threshold  : $WARNING_DAYS days
Critical Threshold : $CRITICAL_DAYS days
Renewal Threshold  : $RENEWAL_DAYS days

Status          : $STATUS
Renewal Required: $RENEWAL_REQUIRED

==========================================
"

# ==========================================
# DISPLAY RESULT
# ==========================================

echo "$OUTPUT"

# ==========================================
# WRITE RESULT TO LOG
# ==========================================

echo "$OUTPUT" >> "$LOG_FILE"

# ==========================================
# EMAIL NOTIFICATION
# ==========================================

if ! send_status_email; then

    echo "WARNING: Status email could not be sent."

fi

# ==========================================
# RENEWAL
# ==========================================

renew_certificate

# ==========================================
# RETURN MONITORING STATUS
# ==========================================

case "$STATUS" in

    HEALTHY)

        exit 0

        ;;

    WARNING)

        exit 1

        ;;

    CRITICAL)

        exit 2

        ;;

    EXPIRED)

        exit 3

        ;;

    *)

        exit 4

        ;;

esac
