#!/bin/bash

json_file="/home/YOURUSER/web/YOURDOMAIN/private/cert_status.json"
recipient="info@yourdomain.com"

# Βρες domains με status != "Valid"
expired=$(jq -r '.[] | select(.status != "Valid") | "\(.domain) - Status: \(.status) (expires in \(.days_left) days)"' "$json_file")

if [ -n "$expired" ]; then
    echo -e "The following domains have issues:\n\n$expired" | mail -s "SSL Certificate Alert" "$recipient"
fi
