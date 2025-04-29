#!/usr/bin/env bash
# Script Name: cert_watch
# Version: 1.1.3
# Author: BytesPulse
# Release Date: 2025-April-28
# Description: Script to check SSL/TLS certificates
# shellcheck disable=SC2317,SC2016,SC2004

set -euo pipefail

# Config
host="$(hostname -f)"
bin="/usr/local/hestia/bin"
hestia_conf="/usr/local/hestia/conf/hestia.conf"
output_file="/home/bpgr/web/sslmonitor.bytespulse.com/private/domains.list"
temp_file="$(mktemp)"
auto_file="$(mktemp)"
manual_file="$(mktemp)"
has_imap=false
has_pop=false
ip_version="${IP_VERSION:-4}"   # Default IPv4 unless overridden

# Functions
function _echoerr() {
    echo "Error: $*" >&2
}

function _checkcommands() {
    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            _echoerr "Missing command: $cmd"
            exit 1
        fi
    done
}

function _iamroot() {
    if [[ $EUID -ne 0 ]]; then
        _echoerr "You must run as root."
        exit 2
    fi
}

# Init checks
_iamroot
_checkcommands lsof grep hostname mktemp diff rm

# IP version info
if [[ "$ip_version" != "4" && "$ip_version" != "6" ]]; then
    _echoerr "Invalid IP_VERSION: must be 4 or 6"
    exit 3
fi

# Backend port
backend_port="$(grep BACKEND_PORT "$hestia_conf" | cut -d '=' -f2 | tr -d "'")"

# Check IMAP/POP services
if lsof -Pn -i${ip_version}:993 -sTCP:LISTEN | grep -q '^dovecot'; then
    has_imap=true
fi
if lsof -Pn -i${ip_version}:995 -sTCP:LISTEN | grep -q '^dovecot'; then
    has_pop=true
fi

# Extract manual (user added) entries from old list if exists
if [[ -f "$output_file" ]]; then
    grep '# AddedByUser' "$output_file" >"$manual_file" || true
fi

# Create fresh auto-generated list
>"$auto_file"

echo "Generating domain list..."
for user in $($bin/v-list-users plain | cut -f1 | sort); do
    for domain_info in $($bin/v-list-web-domains "$user" json | jq -r 'to_entries[] | .key + (if .value.ALIAS != "" then "," + .value.ALIAS else "" end)'); do
        echo "$host;$domain_info;443;" | sed "s/$host;$host;443/$host;$host;$backend_port/" >>"$auto_file"
    done
    for mail_domain in $($bin/v-list-mail-domains "$user" plain | cut -f1); do
        echo "$host;mail.$mail_domain,webmail.$mail_domain;443;" >>"$auto_file"
        echo "$host;mail.$mail_domain;465;" >>"$auto_file"
        if $has_imap; then
            echo "$host;mail.$mail_domain;993;" >>"$auto_file"
        fi
        if $has_pop; then
            echo "$host;mail.$mail_domain;995;" >>"$auto_file"
        fi
    done
done

# Combine auto + manual into temp
cat "$auto_file" "$manual_file" > "$temp_file"

# Compare old vs new
if [[ ! -f "$output_file" ]]; then
    echo "Old domain list not found, creating new one."
    mv "$temp_file" "$output_file"
    echo "Domain list created: $output_file"
else
    if diff -q "$output_file" "$temp_file" >/dev/null; then
        echo "No changes detected in domain list."
        rm "$temp_file"
    else
        echo "Changes detected, updating domain list."
        cp "$output_file" "$output_file.bak"
        mv "$temp_file" "$output_file"
        echo "Domain list updated and backup saved: $output_file.bak"
    fi
fi

# Clean up
del_files=("$auto_file" "$manual_file")
for f in "${del_files[@]}"; do
    [[ -f "$f" ]] && rm -f "$f"
done

sudo chown bpgr:bpgr /home/bpgr/web/sslmonitor.bytespulse.com/private/domains.list
sudo chmod 664 /home/bpgr/web/sslmonitor.bytespulse.com/private/domains.list

# Treats unset variables as an error and causes a pipeline to fail if any command in it fails.
set -uo pipefail

# Initialize seconds
SECONDS=0

# Print error to stderr
function _echoerr() {
    echo "Error: $*" >&2
}

# Check if commands exist
function _checkcommands() {
    for i in "$@"; do
        if ! command -v "$i" &>/dev/null; then
            _echoerr "Command \"$i\" not found."
            _echoerr "Cannot continue, required command $i is missing."
            exit 1
        fi
    done
}

# Define full path for commands
c_awk="/usr/bin/awk"
c_basename="/usr/bin/basename"
c_column="/usr/bin/column"
c_cut="/usr/bin/cut"
c_date="/usr/bin/date"
c_grep="/usr/bin/grep"
c_idn2="/usr/bin/idn2"
c_jq="/usr/bin/jq"
c_mktemp="/usr/bin/mktemp"
c_openssl="/usr/bin/openssl"
c_sed="/usr/bin/sed"
c_sort="/usr/bin/sort"
c_timeout="/usr/bin/timeout"
c_tr="/usr/bin/tr"

# Check all commands but jq (it's checked later only if -j option is used)
_checkcommands $c_awk $c_basename $c_column $c_cut $c_date $c_grep $c_idn2 $c_mktemp $c_openssl $c_sed $c_sort $c_timeout $c_tr

# Initialize variables
version="1.1.3"
release_date="2025-April-28"
FILE=""
SINGLE_DOMAIN=""
SINGLE_PORT=""
SINGLE_SERVER=""
EXPIRES_IN_DAYS=29
IP_VERSION="4"
CRON_MODE=false
TABLE=false
TIMEOUT_OPENSSL="10"
SHOW_ISSUER=false
SHOW_COLORS=true
SHOW_TIME=false
SORT_BY_STATUS=false
GENERATE_HTML=false
BE_QUIET=false
JSON=false
# Create temporal directory
TMPDIR="$(mktemp -d)"
SCRIPTNAME="$($c_basename "$0")"
if [[ "$SCRIPTNAME" =~ ^(bash|sh|dash|zsh)$ ]]; then
    SCRIPTNAME="cert_watch"
fi

# Show version
function _showversion() {
    echo -e "$SCRIPTNAME\nVersion: $version\nDate:    $release_date"
    exit 0
}

# Clean the house
function _housekeeping() {
    if [ -d "${TMPDIR}" ]; then
        rm -rf "${TMPDIR}"
    fi
}

# Define colors
function _colors() {
    local type
    type="${1:-fun}"
    if [[ "$type" == "fun" ]]; then
        GREEN=$(tput setaf 2)
        YELLOW=$(tput setaf 226)
        RED=$(tput setaf 196)
        NORMAL=$(tput sgr0)
    else
        GREEN=''
        YELLOW=''
        RED=''
        NORMAL=''
    fi
}

# Generates a sample list of domains and saves it to a file
function _generate_example_domains_list() {
    local fexample
    fexample="cert_watch-example_domains.list"
    # Colors for output
    if [[ -t 1 ]] && $SHOW_COLORS; then
        _colors fun
    else
        _colors bored
    fi
    echo
    echo -e "${GREEN}Generating example domains list in ${YELLOW}$fexample${NORMAL}"
    echo
    tee "$fexample" <<EOF
# Format:
# server;domain1[,domain2,domain3];port;expire_days_alert;IP_protocol
#
# Examples:
# serverA;example.com (it will use defaults; port 443, expire days 29 and IPv4)
# serverA;dev.example.net;;;6 (it will use defaults; port 443, expire days 29. It will use IPv6)
# serverB;example.com,www.example.com;443;;4 (it will use defaults; expire days 29)
# serverC;mail.example.com;465;40;6 (it will use SMTPS to validate the cert, expire days 40 and IPv6) 

hetzner;mail.hetzner.company;465
hetzner;mail.hetzner.company;465;;6
google;google.com;;89
google;google.com;;89;6
google;gmail.com;;45;4
bunny;bunny.net;443
cf;cloudflare.com,www.cloudflare.com
yahoo;mta5.am0.yahoodns.net;25
EOF
    exit
}

# Take care of signals
function _trap_exit() {
    case $1 in
    INT)
        _echoerr "The script has been interrupted by user"
        _housekeeping
        exit 100
        ;;
    TERM)
        _echoerr "Script terminated"
        _housekeeping
        exit 101
        ;;
    *)
        _echoerr "Terminating script on unknown signal"
        _housekeeping
        exit 102
        ;;
    esac
}

# Trap signals
trap "_trap_exit INT" INT
trap "_trap_exit TERM" TERM HUP

# Function to display help
function show_help {
    local rc="${1:-0}"
    echo "Usage: $SCRIPTNAME [OPTIONS]"
    echo "SSL/TLS Certificate Validator"
    echo ""
    echo "Options:"
    echo "  -f FILE       Path to file with domains to check"
    echo "  -d DOMAIN     Single domain to check"
    echo "  -p PORT       Port for single domain (if not used, by default is 443)"
    echo "  -s SERVER     Server identifier for single domain (optional with -d)"
    echo "  -e DAYS       Expiration days threshold for single domain and global (default is 29)"
    echo "  -i IP_VER     IP version to use (4 or 6, default is 4)"
    echo "  -o FILE       Generate results in HTML and save them to file"
    echo "  -g            Generate example domains list"
    echo "  -c            Cron mode (only show alerts)"
    echo "  -a            Show certicate issuer"
    echo "  -k            Disable colors for the status"
    echo "  -m            Show script duration"
    echo "  -x            Sort by status (only works when using -t and/or -o)"
    echo "  -j            Output as json (disables options -t -t and/or -o)"
    echo "  -q            Don't show any output (could be useful when used with -o)"
    echo "  -v            Show version and release date"
    echo "  -h            Show this help"
    echo ""
    echo "Domain file format:"
    echo "server;domain1,domain2,...;port;expiry_days;ip_version"
    echo ""
    echo "Examples:"
    echo "  $SCRIPTNAME -f domains.list"
    echo "  $SCRIPTNAME -f domains.list -t -e 45"
    echo "  $SCRIPTNAME -f domains.list -q -o /var/www/data/cert_status.html"
    echo "  $SCRIPTNAME -d example.com -p 443 -e 15"
    echo "  $SCRIPTNAME -d example.com -p 443 -i 6"
    exit "$rc"
}

# Parse arguments
while getopts ":f:d:p:s:e:i:o:gcakmqvhtxj" OPT; do
    case $OPT in
    f) FILE="$OPTARG" ;;
    d) SINGLE_DOMAIN="$OPTARG" ;;
    p) SINGLE_PORT="$OPTARG" ;;
    s) SINGLE_SERVER="$OPTARG" ;;
    e) EXPIRES_IN_DAYS="$OPTARG" ;;
    i) IP_VERSION="$OPTARG" ;;
    o)
        HTML_FILE="$OPTARG"
        GENERATE_HTML=true
        ;;
    g) _generate_example_domains_list ;;
    c) CRON_MODE=true ;;
    a) SHOW_ISSUER=true ;;
    k) SHOW_COLORS=false ;;
    m) SHOW_TIME=true ;;
    q) BE_QUIET=true ;;
    v) _showversion ;;
    t) TABLE=true ;;
    x) SORT_BY_STATUS=true ;;
    j) JSON=true ;;
    h) show_help ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        _housekeeping
        exit 1
        ;;
    esac
done

# Colors for output
if [[ -t 1 ]] && $SHOW_COLORS; then
    _colors fun
else
    _colors bored
fi

# Validate arguments

# Error if no file or domain provided
if [[ -z "$FILE" && -z "$SINGLE_DOMAIN" ]]; then
    _echoerr "You must specify either a file (-f) or a single domain (-d)"
    show_help 1
fi

# Error if file doesn't exist
if [[ -n "$FILE" && ! -f "$FILE" ]]; then
    _echoerr "File $FILE does not exist"
    show_help 1
fi

# Default port 443 if none specified
if [[ -n "$SINGLE_DOMAIN" && -z "$SINGLE_PORT" ]]; then
    SINGLE_PORT="443"
fi

if [[ -n "$SINGLE_DOMAIN" && -z "$SINGLE_PORT" ]]; then
    SINGLE_PORT="443"
fi

# Validate IP version
if [[ "$IP_VERSION" != "4" && "$IP_VERSION" != "6" ]]; then
    _echoerr "IP version must be either 4 or 6"
    show_help 1
fi

# If show issuer is true, set column name and the number of columns
if $SHOW_ISSUER; then
    col_issuer="Issuer,"
    ncolumns=7
else
    col_issuer=""
    ncolumns=6
fi

# If JSON is true, disable colors, be quiet, show duration and table
if $JSON; then
    _checkcommands $c_jq
    TABLE=false
    SHOW_COLORS=false
    SHOW_TIME=false
    BE_QUIET=false
fi

# Function to check if domain matches a wildcard certificate
function domain_matches_wildcard {
    local domain
    local wildcard
    domain=$1
    wildcard=$2

    # Remove the wildcard character and leading dot
    local wildcard_base
    wildcard_base=${wildcard#\*.}

    # Get the domain without the first subdomain
    local domain_base
    domain_base=${domain#*.}

    # Check if domain_base matches wildcard_base exactly
    if [[ "$domain_base" == "$wildcard_base" ]]; then
        return 0 # True, it matches
    else
        return 1 # False, no match
    fi
}

# Function to validate certificate
function validate_certificate {
    local server_id
    local domain
    local port
    local expires_in
    local ip_ver
    local protocol
    server_id=$1
    domain=$(${c_idn2} <<<"$2")
    port="${3:-443}"
    expires_in=${4:-$EXPIRES_IN_DAYS}
    ip_ver=${5:-4}
    protocol="s_client"

    # Determine protocol and extra arguments based on port
    case "$port" in
    25 | 587) protocol="s_client -starttls smtp" ;;
    143) protocol="s_client -starttls imap" ;;
    110) protocol="s_client -starttls pop3" ;;
    esac

    # Set IP version flag
    local ip_flag=""
    if [[ "$ip_ver" == "4" ]]; then
        ip_flag="-4"
    elif [[ "$ip_ver" == "6" ]]; then
        ip_flag="-6"
    fi

    # Connect using the domain (not the server_id)
    local issuer
    issuer=""
    local cert_info
    #shellcheck disable=SC2086
    cert_info=$($c_timeout $TIMEOUT_OPENSSL $c_openssl $protocol "$ip_flag" -servername "$domain" -connect "$domain:$port" <<<: 2>/dev/null | $c_openssl x509 -noout -text 2>/dev/null)
    if [[ -z "$cert_info" ]]; then
        if $SHOW_ISSUER; then
            echo -e "$server_id|$domain|$port|$ip_ver|$expires_in|$issuer|${RED}Error: Could not get certificate information${NORMAL}"
            return 1
        else
            echo -e "$server_id|$domain|$port|$ip_ver|$expires_in|${RED}Error: Could not get certificate information${NORMAL}"
            return 1
        fi
    fi

    # Get Issuer
    issuer_org="$($c_grep 'Issuer: ' <<<"$cert_info" | $c_tr ',' '\n' | $c_grep -E '^\s*O\s=' | $c_sed 's/=\s/=/' | cut -d '=' -f2-)"
    issuer_cn="$($c_grep 'Issuer: ' <<<"$cert_info" | $c_tr ',' '\n' | $c_grep -E '^\s*CN\s=' | $c_sed 's/=\s/=/' | cut -d '=' -f2-)"
    issuer="$issuer_org → $issuer_cn"

    # Get expiration date in seconds since epoch
    local expiry_date
    expiry_date=$($c_awk '/Not After/ {print substr($0, index($0,$4))}' <<<"$cert_info")

    # Convert the expiry_date string to seconds since epoch
    # Extract components from date string (format: MMM DD HH:MM:SS YYYY GMT)
    local month
    local day
    local time
    local year
    month=$($c_awk '{print $1}' <<<"$expiry_date")
    day=$($c_awk '{print $2}' <<<"$expiry_date")
    time=$($c_awk '{print $3}' <<<"$expiry_date")
    year=$($c_awk '{print $4}' <<<"$expiry_date")

    # Create a date string in a format that date command can parse
    local formatted_date
    local expiry_epoch
    formatted_date="$month $day $time $year"
    expiry_epoch=$($c_date -d "$formatted_date" +%s 2>/dev/null)

    # Get current time in seconds since epoch
    local current_epoch
    local seconds_remaining
    local days_remaining
    current_epoch=$($c_date +%s)
    seconds_remaining=$((expiry_epoch - current_epoch))
    days_remaining=$((seconds_remaining / 86400))

    # Check domain against certificate
    local domain_valid
    domain_valid=false

    # Extract common name (CN)
    local common_name
    common_name=$($c_grep "Subject:" <<<"$cert_info" | $c_grep -o "CN = [^,]*" | $c_cut -d= -f2 | $c_tr -d ' ')

    # Extract subject alternative names
    local subject_alt_names
    subject_alt_names=$($c_grep -A1 "Subject Alternative Name" <<<"$cert_info" | $c_grep "DNS:" | $c_sed 's/DNS://g' | $c_tr ',' '\n' | $c_tr -d ' ')

    # First check for exact match
    subject_alt_names="$(echo "$subject_alt_names" | $c_tr '\n' ' ' | $c_sed -E -e 's/ $//' -e 's/\s{2,}/ /g')"

    if echo "$subject_alt_names" | $c_grep -Eq "^${domain}$|\s${domain}" || [[ "$common_name" == "$domain" ]]; then
        domain_valid=true
    else
        # Check for wildcard certificates
        if $c_grep -qF '*.' <<<"$subject_alt_names"; then
            # Look through all wildcard entries
            IFS=' ' read -ra DOMAINS <<<"$subject_alt_names"
            for cert_domain in "${DOMAINS[@]}"; do
                if echo "$cert_domain" | $c_grep -Eq '^\*\.'; then
                    if domain_matches_wildcard "$domain" "$cert_domain"; then
                        domain_valid=true
                        break
                    fi
                fi
            done
        fi
    fi

    # Determine status and color
    local status
    local color

    if ! $domain_valid; then
        status="Domain not covered by certificate"
        color=$RED
    elif [[ $days_remaining -lt 0 ]]; then
        status="Expired ($((days_remaining * -1)) days ago)"
        color=$RED
    elif [[ $days_remaining -le $expires_in ]]; then
        status="Expires in $days_remaining days"
        color=$YELLOW
    else
        status="Valid (expires in $days_remaining days)"
        color=$GREEN
    fi

    # Determine if we should show output based on mode and conditions
    local should_show
    should_show=false
    if ! $CRON_MODE; then
        # In normal mode, always show output
        should_show=true
    else
        # In cron mode, only show if there's an issue
        if ! $domain_valid || [[ $days_remaining -le $expires_in || $days_remaining -lt 0 ]]; then
            should_show=true
            touch "$TMPDIR/show_output"
        fi
    fi

    # Show result if needed
    if $should_show; then
        if $SHOW_ISSUER; then
            echo -e "$server_id|$domain|$port|$ip_ver|$expires_in|$issuer|${color}$status${NORMAL}"
        else
            echo -e "$server_id|$domain|$port|$ip_ver|$expires_in|${color}$status${NORMAL}"
        fi
    fi

    # Return status for scripts that call this function
    if ! $domain_valid || [[ $days_remaining -lt 0 ]]; then
        return 1
    elif [[ $days_remaining -le $expires_in ]]; then
        return 2
    else
        return 0
    fi
}

# Process single domain if specified
if [[ -n "$SINGLE_DOMAIN" ]]; then
    if $TABLE; then
        validate_certificate "${SINGLE_SERVER:-$SINGLE_DOMAIN}" "$SINGLE_DOMAIN" "$SINGLE_PORT" "$EXPIRES_IN_DAYS" "$IP_VERSION" | $c_column -t -s '|' -N Server,Domain,Port,IPv,Warning_Days,"$col_issuer"Status -R 4,5
        _housekeeping
        exit $?
    else
        validate_certificate "${SINGLE_SERVER:-$SINGLE_DOMAIN}" "$SINGLE_DOMAIN" "$SINGLE_PORT" "$EXPIRES_IN_DAYS" "$IP_VERSION"
        _housekeeping
        exit $?
    fi
fi

# Function to process domains file
process_domains_file() {
    local file
    file="$1"

    while IFS=';' read -r server domains port expires_in ip_ver; do
        # Skip empty lines or comments
        [[ -z "$server" || "$server" =~ ^# ]] && continue

	# Clean up expires_in if it contains '#'
        expires_in="${expires_in%%#*}"   # Remove anything after #
        expires_in="$(echo "$expires_in" | xargs)" # Trim spaces

        # Use default values if not specified
        expires_in=${expires_in:-$EXPIRES_IN_DAYS}
        ip_ver=${ip_ver:-4}

        # Validate IP version
        if [[ -n "$ip_ver" && "$ip_ver" != "4" && "$ip_ver" != "6" ]]; then
            echo "Warning: Invalid IP version '$ip_ver' for server '$server', using IPv4" >&2
            ip_ver="4"
        fi

        # Process each domain in the list (comma-separated)
        IFS=',' read -ra DOMAINS_ARRAY <<<"$domains"
        for domain in "${DOMAINS_ARRAY[@]}"; do
            validate_certificate "$server" "$domain" "$port" "$expires_in" "$ip_ver"
        done
    done < <($c_sort "$file")
}

# Function to calculate script execution time
function duration() {
    secs="$SECONDS"
    DURACION="$(printf '%02dm %02ds' $((secs % 3600 / 60)) $((secs % 60)))"
    echo
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Check last $DURACION"
    echo
}

# Generate HTML page
function generate_certificate_status_html_fill() {
    # Check if output file argument is provided
    if [ $# -ne 1 ]; then
        echo "Usage: generate_certificate_status_html output_file < input_data"
        return 1
    fi

    # Declare all local variables first
    local OUTPUT_FILE dir INPUT_DATA LAST_UPDATED COLUMNS HEADER
    local HEADER6 HEADER7 FIRST_LINE STATUS COLOR_CLASS line
    local HAS_RED HAS_YELLOW FOOTER_COLOR

    OUTPUT_FILE="$1"
    INPUT_DATA=$(cat)

    # Create directory if needed
    dir=$(dirname "$OUTPUT_FILE")
    if [ -n "$dir" ] && [ ! -d "$dir" ]; then
        mkdir -p "$dir" || {
            echo "Error: Failed to create directory $dir"
            return 1
        }
    fi

    # Get current date and time
    LAST_UPDATED=$(date '+%Y-%m-%d %H:%M:%S')

    # Determine columns based on input or use default
    if [ -z "$INPUT_DATA" ]; then
        # Default to 7 columns when no input
        COLUMNS=7
        HEADER="Server|Domain|Port|IPv|Warning Days|Certificate Issuer|Status"
    else
        # Detect number of columns from input
        HEADER6="Server|Domain|Port|IPv|Warning Days|Status"
        HEADER7="Server|Domain|Port|IPv|Warning Days|Certificate Issuer|Status"

        FIRST_LINE=$(echo "$INPUT_DATA" | head -n 1)
        COLUMNS=$(echo "$FIRST_LINE" | $c_awk -F '|' '{print NF}')

        if [[ "$COLUMNS" -eq 6 ]]; then
            HEADER="$HEADER6"
        elif [[ "$COLUMNS" -eq 7 ]]; then
            HEADER="$HEADER7"
        else
            echo "Invalid data format"
            return 1
        fi
    fi

    # Initialize status flags
    HAS_RED=0
    HAS_YELLOW=0

    # Check status colors if we have data
    if [ -n "$INPUT_DATA" ]; then
        while IFS='|' read -r line; do
            STATUS=$(echo "$line" | $c_awk -F '|' '{print $NF}')
            if [[ "$STATUS" != "Valid"* ]] && [[ "$STATUS" != "Expires in"* ]]; then
                HAS_RED=1
            elif [[ "$STATUS" == "Expires in"* ]]; then
                HAS_YELLOW=1
            fi
        done <<<"$INPUT_DATA"
    fi

    # Determine footer color
    if [ $HAS_RED -eq 1 ]; then
        FOOTER_COLOR="background: #f8d7da; color: #721c24;"
    elif [ $HAS_YELLOW -eq 1 ]; then
        FOOTER_COLOR="background: #fff3cd; color: #856404;"
    else
        FOOTER_COLOR="background: #d4edda; color: #155724;"
    fi

    # Start HTML (grouped redirections)
    {
        cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Certificate Status</title>
    <link rel="icon" type="image/png" href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABoAAAAaCAYAAACpSkzOAAAACXBIWXMAAAsTAAALEwEAmpwYAAACKklEQVR4nK2VzWsTURDA11bQ/geibdJ5m4DgTah4E09ePHrRk9bSGvGmZ3PdnbeBRjx58qRYK4IIFdqLIj14riAVFJPMrD0pmFqr4pP31iQ1+3aT3WZgDrv7Zn7z9WYdZ0gp1TcPCeSKQHoTKVeK1Y+HnVGKCOgiILeEZNWnJJAu7R/gN8sC+YUFoP5TpJeuF57IDCji1hFArgPSz4EQGSlI3gXkRW2b6twNWlMQ0Bwg3ReSt4cFiLhuax/al/YZAwHS2304V/YsaSPeD6QPIwchv49nJHk9n0OSIPmmQGpb+vbaUjp+mgP0yqmqsShQumoJYjleOkl3M0GQ2iXcco2xUgcAec1SukXL1PF8NhBXemWnG/ZzrSu2Hs0kNPSB64dnzRbovV/VWZgAa42SrT9aXZ9OxkCTtcaEvnR9h985S2q8uyUMjL4KjwrGqKrGdMMTAvyh92MMFPWJV/umZnc6oHPd736zDJIvdJ6nkW+l3KEVKySp1ma1+OH5/rPFgI4L5O8pfbyWCNIrQyD9thjt7M3sTFUdNL+K5Gx+TfmfjiaCovLRcoKDLkxIvj1g9B+lQkxJap9Pp0VqNgjSnzQQeOGpgSATMdLzHFtC/btfz4aCGJBHBUD6lh1C7YIMwckiIPl6jmwWMkFy7r97Tl7RYwxIT4Yo2ePOBskvS2ocJN9JnDDkeudXMRIBvzVr9lyvH18EhpdHBtgrJa85CcgPtZZrjWNZjP8CAfrbGMpORAUAAAAASUVORK5CYII=">
    <style>
        body { font-family: Arial, sans-serif; background-color: #f4f4f4; margin: 20px; }
        table { width: 100%; border-collapse: collapse; background: white; border-radius: 10px; overflow: hidden; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #2c3e50; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .green-bg { background-color: #d4edda; color: #155724; font-weight: bold; }
        .yellow-bg { background-color: #fff3cd; color: #856404; font-weight: bold; }
        .red-bg { background-color: #f8d7da; color: #721c24; font-weight: bold; }
        .footer { margin-bottom: 20px; text-align: left; font-size: 14px; color: #555; }
        .footer span { padding: 5px 10px; border-radius: 5px; font-weight: bold; }
    </style>
</head>
<body>
    <h2>Certificate Status</h2>
    <div class='footer'>Last updated: <span style="$FOOTER_COLOR">$LAST_UPDATED</span></div>
    <table>
        <tr>
EOF

        # Add headers
        echo "$HEADER" | $c_awk -F '|' '{for(i=1;i<=NF;i++) printf "<th>%s</th>", $i}'
        echo "</tr>"

        # Process data or add empty row
        if [ -z "$INPUT_DATA" ]; then
            # Add empty row with dashes
            echo "<tr>"
            for ((i = 1; i <= COLUMNS; i++)); do
                echo "<td>-</td>"
            done
            echo "</tr>"
        else
            # Process input data
            echo "$INPUT_DATA" | while IFS='|' read -r line; do
                STATUS=$(echo "$line" | $c_awk -F '|' '{print $NF}')
                COLOR_CLASS="red-bg"
                [[ "$STATUS" == "Valid"* ]] && COLOR_CLASS="green-bg"
                [[ "$STATUS" == "Expires in"* ]] && COLOR_CLASS="yellow-bg"

                echo "<tr>"
                echo "$line" | $c_awk -F '|' -v class="$COLOR_CLASS" '{
                    for(i=1;i<NF;i++) {
                        if (i == 3 || i == 4 || i == 5)
                            printf "<td style=\"text-align: right;\">%s</td>", $i
                        else
                            printf "<td>%s</td>", $i
                    }
                    printf "<td class=\"%s\"><b>%s</b></td>", class, $NF
                }'
                echo "</tr>"
            done
        fi

        # Close HTML
        echo "    </table>"
        echo "</body></html>"
    } >"$OUTPUT_FILE"
    if [[ -t 1 ]]; then
        if ! $BE_QUIET; then
            if ! $JSON; then
                echo
                echo "HTML file generated: $OUTPUT_FILE"
            fi
        fi
    fi
}

# Generate HTML page (not color filling the status)
function generate_certificate_status_html_simple() {
    # Check if output file argument is provided
    if [ $# -ne 1 ]; then
        echo "Usage: generate_certificate_status_html output_file < input_data"
        return 1
    fi

    # Declare all local variables first
    local OUTPUT_FILE dir INPUT_DATA LAST_UPDATED COLUMNS HEADER
    local HEADER6 HEADER7 FIRST_LINE STATUS COLOR_CLASS line
    local HAS_RED HAS_YELLOW FOOTER_COLOR

    OUTPUT_FILE="$1"
    INPUT_DATA=$(cat)

    # Create directory if needed
    dir=$(dirname "$OUTPUT_FILE")
    if [ -n "$dir" ] && [ ! -d "$dir" ]; then
        mkdir -p "$dir" || {
            echo "Error: Failed to create directory $dir"
            return 1
        }
    fi

    # Get current date and time
    LAST_UPDATED=$(date '+%Y-%m-%d %H:%M:%S')

    # Determine columns based on input or use default
    if [ -z "$INPUT_DATA" ]; then
        # Default to 7 columns when no input
        COLUMNS=7
        HEADER="Server|Domain|Port|IPv|Warning Days|Certificate Issuer|Status"
    else
        # Detect number of columns from input
        HEADER6="Server|Domain|Port|IPv|Warning Days|Status"
        HEADER7="Server|Domain|Port|IPv|Warning Days|Certificate Issuer|Status"

        FIRST_LINE=$(echo "$INPUT_DATA" | head -n 1)
        COLUMNS=$(echo "$FIRST_LINE" | $c_awk -F '|' '{print NF}')

        if [[ "$COLUMNS" -eq 6 ]]; then
            HEADER="$HEADER6"
        elif [[ "$COLUMNS" -eq 7 ]]; then
            HEADER="$HEADER7"
        else
            echo "Invalid data format"
            return 1
        fi
    fi

    # Initialize status flags
    HAS_RED=false
    HAS_YELLOW=false

    # Check status colors if we have data
    if [ -n "$INPUT_DATA" ]; then
        while IFS='|' read -r line; do
            STATUS=$(echo "$line" | $c_awk -F '|' '{print $NF}')
            if [[ "$STATUS" != "Valid"* ]] && [[ "$STATUS" != "Expires in"* ]]; then
                HAS_RED=true
            elif [[ "$STATUS" == "Expires in"* ]]; then
                HAS_YELLOW=true
            fi
        done <<<"$INPUT_DATA"
    fi

    # Determine footer color
    if $HAS_RED; then
        FOOTER_COLOR="background: #f8d7da; color: #721c24;"
    elif $HAS_YELLOW; then
        FOOTER_COLOR="background: #fff3cd; color: #856404;"
    else
        FOOTER_COLOR="background: #d4edda; color: #155724;"
    fi

    # Start HTML (grouped redirections)
    {
        cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Certificate Status</title>
    <link rel="icon" type="image/png" href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABoAAAAaCAYAAACpSkzOAAAACXBIWXMAAAsTAAALEwEAmpwYAAACKklEQVR4nK2VzWsTURDA11bQ/geibdJ5m4DgTah4E09ePHrRk9bSGvGmZ3PdnbeBRjx58qRYK4IIFdqLIj14riAVFJPMrD0pmFqr4pP31iQ1+3aT3WZgDrv7Zn7z9WYdZ0gp1TcPCeSKQHoTKVeK1Y+HnVGKCOgiILeEZNWnJJAu7R/gN8sC+YUFoP5TpJeuF57IDCji1hFArgPSz4EQGSlI3gXkRW2b6twNWlMQ0Bwg3ReSt4cFiLhuax/al/YZAwHS2304V/YsaSPeD6QPIwchv49nJHk9n0OSIPmmQGpb+vbaUjp+mgP0yqmqsShQumoJYjleOkl3M0GQ2iXcco2xUgcAec1SukXL1PF8NhBXemWnG/ZzrSu2Hs0kNPSB64dnzRbovV/VWZgAa42SrT9aXZ9OxkCTtcaEvnR9h985S2q8uyUMjL4KjwrGqKrGdMMTAvyh92MMFPWJV/umZnc6oHPd736zDJIvdJ6nkW+l3KEVKySp1ma1+OH5/rPFgI4L5O8pfbyWCNIrQyD9thjt7M3sTFUdNL+K5Gx+TfmfjiaCovLRcoKDLkxIvj1g9B+lQkxJap9Pp0VqNgjSnzQQeOGpgSATMdLzHFtC/btfz4aCGJBHBUD6lh1C7YIMwckiIPl6jmwWMkFy7r97Tl7RYwxIT4Yo2ePOBskvS2ocJN9JnDDkeudXMRIBvzVr9lyvH18EhpdHBtgrJa85CcgPtZZrjWNZjP8CAfrbGMpORAUAAAAASUVORK5CYII=">
    <style>
        body { font-family: Arial, sans-serif; background-color: #f4f4f4; margin: 20px; }
        table { width: 100%; border-collapse: collapse; background: white; border-radius: 10px; overflow: hidden; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #2c3e50; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .green { color: #155724; font-weight: bold; }
        .yellow { color: #856404; font-weight: bold; }
        .red { color: #721c24; font-weight: bold; }
        .footer { margin-bottom: 20px; text-align: left; font-size: 14px; color: #555; }
        .footer span { padding: 5px 10px; border-radius: 5px; font-weight: bold; }
    </style>
</head>
<body>
    <h2>Certificate Status</h2>
    <div class='footer'>Last updated: <span style="$FOOTER_COLOR">$LAST_UPDATED</span></div>
    <table>
        <tr>
EOF

        # Add headers
        echo "$HEADER" | $c_awk -F '|' '{for(i=1;i<=NF;i++) printf "<th>%s</th>", $i}'
        echo "</tr>"

        # Process data or add empty row
        if [ -z "$INPUT_DATA" ]; then
            # Add empty row with dashes
            echo "<tr>"
            for ((i = 1; i <= COLUMNS; i++)); do
                echo "<td>-</td>"
            done
            echo "</tr>"
        else
            # Process input data
            echo "$INPUT_DATA" | while IFS='|' read -r line; do
                STATUS=$(echo "$line" | $c_awk -F '|' '{print $NF}')
                COLOR_CLASS="red"
                [[ "$STATUS" == "Valid"* ]] && COLOR_CLASS="green"
                [[ "$STATUS" == "Expires in"* ]] && COLOR_CLASS="yellow"

                echo "<tr>"
                echo "$line" | $c_awk -F '|' -v class="$COLOR_CLASS" '{
                    for(i=1;i<NF;i++) {
                        if (i == 3 || i == 4 || i == 5)
                            printf "<td style=\"text-align: right;\">%s</td>", $i
                        else
                            printf "<td>%s</td>", $i
                    }
                    printf "<td><span class=\"%s\"><b>%s</b></span></td>", class, $NF
                }'
                echo "</tr>"
            done
        fi

        # Close HTML
        echo "    </table>"
        echo "</body></html>"
    } >"$OUTPUT_FILE"
    if [[ -t 1 ]]; then
        if ! $BE_QUIET; then
            echo
            echo "HTML file generated: $OUTPUT_FILE"
        fi
    fi
}

# Sort status text from more to less critical
function sort_status() {
    local output1 output2 output3 sorted columns
    columns="$2"
    output1="$(echo "$1" | grep -Ev 'Valid \(|Expires in' | sort -t '|' -k"$columns")"
    output2="$(echo "$1" | grep -E 'Expires in' | sort -t '|' -k"$columns".12V)"
    output3="$(echo "$1" | grep -E 'Valid \(' | sort -t '|' -k"$columns".19V)"
    sorted=""
    if [ -n "$output1" ]; then
        sorted="$output1"
    fi

    if [ -n "$output2" ]; then
        if [ -n "$sorted" ]; then
            sorted+=$'\n'
        fi
        sorted+="$output2"
    fi

    if [ -n "$output3" ]; then
        if [ -n "$sorted" ]; then
            sorted+=$'\n'
        fi
        sorted+="$output3"
    fi
    echo "$sorted"
}

# Remove blanks
trim() {
    local var
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}" # Eliminar espacios al inicio
    var="${var%"${var##*[![:space:]]}"}" # Eliminar espacios al final
    echo -n "$var"
}

# Remove color characters in cases where -k option is not taking care
remove_color() {
    $c_sed -E 's/\x1B\[[0-9;]*[mGK]|\x1B\(B//g'
}

# Convert output to json format
convert_to_json() {
    # Leer la entrada
    local input_text
    input_text=$(cat)
    if [[ -z "$input_text" ]]; then
        return
    fi
    # Procesar cada línea
    while IFS='|' read -r -a fields; do
        # Limpiar espacios en cada campo
        for i in "${!fields[@]}"; do
            fields[$i]=$(trim "${fields[$i]}")
            fields[$i]=$(remove_color <<<"${fields[$i]}")
        done

        # Determinar estructura según número de campos
        if [[ ${#fields[@]} -eq 7 ]]; then
            # 7 fields: server|domain|port|ip_version|warning_days|certificate_issuer|status
            jq -n \
                --arg server "${fields[0]}" \
                --arg domain "${fields[1]}" \
                --argjson port "${fields[2]}" \
                --argjson ip_version "${fields[3]}" \
                --argjson warning_days "${fields[4]}" \
                --arg certificate_issuer "${fields[5]}" \
                --arg status "${fields[6]}" \
                '{
                    server: $server,
                    domain: $domain,
                    port: $port,
                    ip_version: $ip_version,
                    warning_days: $warning_days,
                    certificate_issuer: $certificate_issuer,
                    status: $status
                }'
        elif [[ ${#fields[@]} -eq 6 ]]; then
            # 6 fields: server|domain|port|ip_version|warning_days|status
            jq -n \
                --arg server "${fields[0]}" \
                --arg domain "${fields[1]}" \
                --argjson port "${fields[2]}" \
                --argjson ip_version "${fields[3]}" \
                --argjson warning_days "${fields[4]}" \
                --arg status "${fields[5]}" \
                '{
                    server: $server,
                    domain: $domain,
                    port: $port,
                    ip_version: $ip_version,
                    warning_days: $warning_days,
                    status: $status
                }'
        else
            echo "Error: Línea con formato incorrecto -> ${fields[*]}" >&2
        fi
    done <<<"$input_text" | jq -s . # Agrupa en array JSON
}

# Process domain file
# Determine output format and process domains only once
if [ -t 1 ] && ! $BE_QUIET && ! $JSON && ! $TABLE; then
    # Special case: interactive terminal, show output in real-time
    output=$(process_domains_file "$FILE" | tee /dev/tty)
else
    # All other cases: process just once
    output="$(process_domains_file "$FILE")"
fi

# Apply formatting to the output based on parameters
if $TABLE && ! $BE_QUIET; then
    # Apply status sorting if needed
    if $SORT_BY_STATUS; then
        output="$(sort_status "$output" "$ncolumns")"
    fi

    # Display the formatted table
    echo "$output" | $c_column -t -s '|' -N Server,Domain,Port,IPv,Warning_Days,"$col_issuer"Status -R 4,5
elif ! $BE_QUIET; then
    # We already have processed data, just need to display in the correct format
    if $JSON; then
        echo "$output" | convert_to_json
    elif [ ! -t 1 ]; then
        # If not in interactive terminal, show normal output
        echo "$output"
    fi
    # In case of interactive terminal without JSON or TABLE, output was already shown with tee
fi

# Generate HTML output (sorted or unsorted)
if $GENERATE_HTML; then
    if $SORT_BY_STATUS; then
        sort_status "$output" "$ncolumns" | remove_color | generate_certificate_status_html_fill "$HTML_FILE"
    else
        echo "$output" | remove_color | generate_certificate_status_html_fill "$HTML_FILE"
    fi
fi

# Show execution time if not in cron mode or there is something to show (errors or warnings)
if ! $CRON_MODE || [[ -f "$TMPDIR/show_output" ]]; then
    if $SHOW_TIME; then
        duration
    fi
fi

_housekeeping

exit 0
