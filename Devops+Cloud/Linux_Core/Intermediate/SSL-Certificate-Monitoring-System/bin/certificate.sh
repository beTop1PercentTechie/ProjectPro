#!/bin/bash

# ==========================================
# CERTIFICATE FUNCTIONS
# ==========================================

# ------------------------------------------
# Get certificate expiry date
# ------------------------------------------

get_expiry_date() {

    openssl x509 \
        -in "$CERTIFICATE" \
        -noout \
        -enddate \
        | cut -d= -f2

}


# ------------------------------------------
# Calculate certificate status
# ------------------------------------------

check_certificate_status() {

    # --------------------------------------
    # Get real certificate expiry
    # --------------------------------------

    EXPIRY_DATE=$(get_expiry_date)

    EXPIRY_TIMESTAMP=$(date -d "$EXPIRY_DATE" +%s)

    CURRENT_TIMESTAMP=$(date +%s)

    REMAINING_SECONDS=$((EXPIRY_TIMESTAMP - CURRENT_TIMESTAMP))

    REMAINING_DAYS=$((REMAINING_SECONDS / 86400))


    # --------------------------------------
    # Demonstration mode
    # --------------------------------------

    if [[ "${DEMO_MODE:-false}" == "true" ]]; then

        echo "DEMO MODE: Simulating certificate expiry."

        REMAINING_DAYS="$DEMO_REMAINING_DAYS"

        REMAINING_SECONDS=$((REMAINING_DAYS * 86400))

    fi


    # --------------------------------------
    # Determine certificate status
    # --------------------------------------

    if (( REMAINING_SECONDS <= 0 )); then

        STATUS="EXPIRED"

    elif (( REMAINING_DAYS <= CRITICAL_DAYS )); then

        STATUS="CRITICAL"

    elif (( REMAINING_DAYS <= WARNING_DAYS )); then

        STATUS="WARNING"

    else

        STATUS="HEALTHY"

    fi


    # --------------------------------------
    # Determine renewal requirement
    # --------------------------------------

    RENEWAL_REQUIRED=false

    if (( REMAINING_DAYS <= RENEWAL_DAYS )); then

        RENEWAL_REQUIRED=true

    fi

}
