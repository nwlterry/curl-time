#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 [-a] [url] [attempts]"
    echo "  -a: Prompt for authentication (username and password)"
    exit 1
}

# Parse options
AUTH=false
while getopts "a" opt; do
    case $opt in
        a) AUTH=true ;;
        *) usage ;;
    esac
done

# Shift past options to get positional arguments
shift $((OPTIND-1))

# Check if URL is provided
if [ -z "$1" ]; then
    usage
fi

URL="$1"
ATTEMPTS=${2:-1} # Default to 1 attempt if not specified

# Validate attempts is a positive integer
if ! [[ "$ATTEMPTS" =~ ^[0-9]+$ ]] || [ "$ATTEMPTS" -lt 1 ]; then
    echo "Error: Attempts must be a positive integer"
    exit 1
fi

# Prompt for authentication if -a flag is used
CURL_AUTH=""
if [ "$AUTH" = true ]; then
    read -p "Enter username: " username
    read -s -p "Enter password: " password
    echo
    CURL_AUTH="-u $username:$password"
fi

# Initialize variables for summary calculations
total_connect=0
total_starttransfer=0
total_total=0
http_codes=()
content_types=()

# Print table header
echo -e "\n Url:\t${URL}\n"
printf "+---------------------------------------------------------------------------------------------------------+\n"
printf "| %-7s |                           Time (seconds)                                | Server Response       |\n"
printf "+---------------------------------------------------------------------------------------------------------+\n"
printf "| %-7s | %-7s | %-14s | %-8s | %-10s | %-11s | %-6s | %-11s | %-20s |\n" \
       "Attempt" "Connect" "Start transfer" "Redirect" "Namelookup" "Pretransfer" "Total" "HTTP Status" "Content Type"
printf "+---------------------------------------------------------------------------------------------------------+\n"

# Perform cURL requests
for ((i=1; i<=ATTEMPTS; i++)); do
    # Execute cURL with optional authentication and capture timing and response data
    response=$(curl -s -o /dev/null $CURL_AUTH -w "%{time_connect},%{time_starttransfer},%{time_redirect},%{time_namelookup},%{time_pretransfer},%{time_total},%{http_code},%{content_type}" "$URL")
    
    # Check if cURL command failed
    if [ $? -ne 0 ]; then
        echo "Error: cURL request failed for attempt $i"
        continue
    fi

    # Split response into variables
    IFS=',' read -r time_connect time_starttransfer time_redirect time_namelookup time_pretransfer time_total http_code content_type <<< "$response"
    
    # Convert HTTP status code to human-readable format
    case $http_code in
        200) http_status="200 OK" ;;
        301) http_status="301 Moved" ;;
        401) http_status="401 Unauthorized" ;;
        404) http_status="404 Not Found" ;;
        500) http_status="500 Error" ;;
        *) http_status="$http_code" ;;
    esac
    
    # Store for summary
    total_connect=$(echo "$total_connect + $time_connect" | bc)
    total_starttransfer=$(echo "$total_starttransfer + $time_starttransfer" | bc)
    total_total=$(echo "$total_total + $time_total" | bc)
    http_codes+=("$http_status")
    content_types+=("$content_type")
    
    # Print attempt row
    printf "| %-7s | %7.3f | %14.3f | %8.3f | %10.3f | %11.3f | %6.3f | %-11s | %-20s |\n" \
           "$i." "$time_connect" "$time_starttransfer" "$time_redirect" "$time_namelookup" "$time_pretransfer" "$time_total" "$http_status" "$content_type"
done

# Calculate averages for summary
if [ $ATTEMPTS -gt 0 ]; then
    avg_connect=$(echo "scale=3; $total_connect / $ATTEMPTS" | bc)
    avg_starttransfer=$(echo "scale=3; $total_starttransfer / $ATTEMPTS" | bc)
    avg_total=$(echo "scale=3; $total_total / $ATTEMPTS" | bc)
    
    # Determine most common HTTP status and content type
    http_status_summary=$(printf "%s\n" "${http_codes[@]}" | sort | uniq -c | sort -nr | head -n1 | awk '{print $2}')
    content_type_summary=$(printf "%s\n" "${content_types[@]}" | sort | uniq -c | sort -nr | head -n1 | awk '{print $2}')
    
    # Print summary row
    printf "+---------------------------------------------------------------------------------------------------------+\n"
    printf "| %-7s | %7.3f | %14.3f | %-8s | %-10s | %-11s | %6.3f | %-11s | %-20s |\n" \
           "summary" "$avg_connect" "$avg_starttransfer" "-" "-" "-" "$avg_total" "$http_status_summary" "$content_type_summary"
    printf "+---------------------------------------------------------------------------------------------------------+\n"
fi

echo
