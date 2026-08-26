#!/bin/bash

# ==========================================
# CERTIFICATE RENEWAL FUNCTIONS
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/verification.sh"
source "$SCRIPT_DIR/email.sh"

renew_certificate() {

    echo ""
    echo "Renewal check started..."


    # --------------------------------------
    # No renewal required
    # --------------------------------------

    if [[ "$RENEWAL_REQUIRED" != "true" ]]; then

        echo "Certificate does not require renewal."

        return 0

    fi


    echo "Certificate is within the renewal window."


    # ======================================
    # CERTBOT RENEWAL
    # ======================================

    if [[ "${DEMO_MODE:-false}" == "true" ]]; then

        echo "DEMO MODE: Running Certbot renewal dry-run."
        echo "No real certificate renewal will be performed."

        if ! certbot renew --dry-run; then

            echo "ERROR: Certbot renewal dry-run failed."
            echo "Nginx will NOT be reloaded."

            return 1

        fi

        echo "Certbot renewal dry-run completed successfully."

    else

        echo "REAL MODE: Starting Certbot renewal."

        if ! certbot renew; then

            echo "ERROR: Certbot renewal failed."
            echo "Nginx will NOT be reloaded."
            
	    send_renewal_failure_email	    
           
	    return 1

        fi

        echo "Certbot renewal completed successfully."

    fi


    # ======================================
    # NGINX VALIDATION
    # ======================================

    echo "Testing Nginx configuration..."

    if ! nginx -t; then

        echo "ERROR: Nginx configuration test failed."
        echo "Nginx will NOT be reloaded."
	
	send_renewal_failure_email

        return 1

    fi

    echo "Nginx configuration is valid."


    # ======================================
    # NGINX RELOAD
    # ======================================

    echo "Reloading Nginx..."

    if ! systemctl reload nginx; then

        echo "ERROR: Nginx reload failed."

	send_renewal_failure_email

        return 1

    fi

    echo "Nginx reloaded successfully."


    # ======================================
    # LIVE HTTPS VERIFICATION
    # ======================================

    if ! verify_live_certificate; then

        echo "ERROR: Live HTTPS certificate verification failed."

	send_renewal_failure_email

        return 1

    fi


    echo "Renewal workflow completed successfully."

    if ! send_renewal_success_email; then

       echo "WARNING: Renewal success email could not be sent."

    fi 

    return 0

}
