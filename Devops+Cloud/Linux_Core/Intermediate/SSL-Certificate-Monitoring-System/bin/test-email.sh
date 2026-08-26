#!/bin/bash

set -euo pipefail

# ==========================================
# SSL MONITOR EMAIL TEST SCRIPT
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIG_FILE="$PROJECT_DIR/config/ssl-monitor.conf"

# ------------------------------------------
# Validate configuration
# ------------------------------------------

if [[ ! -f "$CONFIG_FILE" ]]; then

    echo "ERROR: Configuration file not found:"
    echo "$CONFIG_FILE"

    exit 1

fi

# ------------------------------------------
# Load SSL monitor configuration
# ------------------------------------------

source "$CONFIG_FILE"

# ------------------------------------------
# Load email functions
# ------------------------------------------

source "$SCRIPT_DIR/email.sh"

# ------------------------------------------
# Validate argument
# ------------------------------------------

if [[ $# -ne 1 ]]; then

    echo "Usage:"
    echo "./test-email.sh healthy"
    echo "./test-email.sh warning"
    echo "./test-email.sh critical"
    echo "./test-email.sh expired"
    echo "./test-email.sh renewal-success"
    echo "./test-email.sh renewal-failure"

    exit 1

fi

TEST_TYPE="$1"

# ------------------------------------------
# Get real certificate expiry
# ------------------------------------------

EXPIRY_DATE=$(openssl x509 \
    -in "$CERTIFICATE" \
    -noout \
    -enddate \
    | cut -d= -f2)

# ------------------------------------------
# Select test
# ------------------------------------------

case "$TEST_TYPE" in

    healthy)

        STATUS="HEALTHY"
        REMAINING_DAYS=89

        echo "Testing HEALTHY email..."

        send_healthy_email

        ;;

    warning)

        STATUS="WARNING"
        REMAINING_DAYS=10

        echo "Testing WARNING email..."

        send_warning_email

        ;;

    critical)

        STATUS="CRITICAL"
        REMAINING_DAYS=5

        echo "Testing CRITICAL email..."

        send_critical_email

        ;;

    expired)

        STATUS="EXPIRED"
        REMAINING_DAYS=0

        echo "Testing EXPIRED email..."

        send_expired_email

        ;;

    renewal-success)

        STATUS="HEALTHY"
        REMAINING_DAYS=89

	DEMO_MODE=false

        echo "Testing REAL RENEWAL SUCCESS email..."

        send_renewal_success_email

        ;;

    renewal-simulation)

    STATUS="HEALTHY"
    REMAINING_DAYS=10

    DEMO_MODE=true

    echo "Testing RENEWAL SIMULATION SUCCESS email..."

    send_renewal_success_email

    ;;

    renewal-failure)

        STATUS="CRITICAL"
        REMAINING_DAYS=5

        echo "Testing RENEWAL FAILURE email..."

        send_renewal_failure_email

        ;;

    *)

        echo "ERROR: Unknown test type:"
        echo "$TEST_TYPE"

        exit 1

        ;;

esac

echo ""
echo "Email test completed successfully."
