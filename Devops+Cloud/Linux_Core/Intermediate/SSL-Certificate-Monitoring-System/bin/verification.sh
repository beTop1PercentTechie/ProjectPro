#!/bin/bash

# ==========================================
# HTTPS CERTIFICATE VERIFICATION FUNCTIONS
# ==========================================

verify_live_certificate() {

    echo ""
    echo "Verifying live HTTPS certificate..."

    # --------------------------------------
    # Get live certificate expiry
    # --------------------------------------

    LIVE_EXPIRY_DATE=$(echo | openssl s_client \
        -connect "${DOMAIN}:443" \
        -servername "${DOMAIN}" 2>/dev/null \
        | openssl x509 -noout -enddate \
        | cut -d= -f2)

    if [[ -z "$LIVE_EXPIRY_DATE" ]]; then

        echo "ERROR: Unable to retrieve live HTTPS certificate."

        return 1

    fi

    echo "Live certificate expiry: $LIVE_EXPIRY_DATE"

    # --------------------------------------
    # Get live certificate subject
    # --------------------------------------

    LIVE_SUBJECT=$(echo | openssl s_client \
        -connect "${DOMAIN}:443" \
        -servername "${DOMAIN}" 2>/dev/null \
        | openssl x509 -noout -subject)

    if [[ -z "$LIVE_SUBJECT" ]]; then

        echo "ERROR: Unable to retrieve live certificate subject."

        return 1

    fi

    echo "Live certificate: $LIVE_SUBJECT"

    echo "Live HTTPS certificate verified successfully."

    return 0
}
