#!/bin/bash

# === CONFIGURATION ===
SSL_MONITOR="/home/YOURUSER/web/YOURDOMAIN/private/ssl_monitor"
DOMAINS_LIST="/home/YOURUSER/web/YOURDOMAIN/private/domains.list"
EMAIL="info@domain.com"

# === Prevent cron from sending emails on standard output or errors
exec > /dev/null 2>&1

# === Run ssl_monitor with JSON output
OUTPUT=$(sudo "$SSL_MONITOR" -f "$DOMAINS_LIST" -j)

# === Extract only the JSON portion (remove log headers)
CLEAN_OUTPUT=$(echo "$OUTPUT" | awk '/^\[/{flag=1} flag')

# === Find domains with expired, error, or connection issues
ALERTS=$(echo "$CLEAN_OUTPUT" | jq -r '.[] | select(.status | test("expired|error|connect"; "i")) | "\(.domain) => \(.status)"')

# === Send email only if issues were found
if [[ -n "$ALERTS" ]]; then
    echo -e "⚠️ The following domains are expired or have issues:\n\n$ALERTS" | mail -s "SSL Monitor Alert" "$EMAIL"
fi
