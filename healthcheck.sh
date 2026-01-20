#!/bin/bash

# 1. Database Connectivity Check
# Returns exit code 2 if database connection fails
php -r '
if (file_exists("/var/www/html/wp-config.php")) {
    include "/var/www/html/wp-config.php";
    $conn = @new mysqli(DB_HOST, DB_USER, DB_PASSWORD, DB_NAME);
    if ($conn->connect_error) {
        exit(2);
    }
    exit(0);
}
# If wp-config.php doesn\'t exist yet, we consider it "not ready" (generic failure 1) rather than DB failure (2).
exit(1);
'
PHP_EXIT=$?
if [ $PHP_EXIT -eq 2 ]; then
    exit 2
elif [ $PHP_EXIT -ne 0 ]; then
    exit 1
fi

# 2. HTTP/HTTPS Status Check
# Returns exit code 1 if the web server is not reachable or returns an error status
HOST=${DOMAIN_NAME:-localhost}
URL="http://127.0.0.1/wp-login.php"
CURL_OPTS="-f -L -o /dev/null -H \"Host: $HOST\""

if [ "$HTTPS_ENABLED" = "true" ]; then
    URL="https://127.0.0.1/wp-login.php"
    # -k to allow self-signed certificates (common in internal/testing setups)
    CURL_OPTS="$CURL_OPTS -k"
fi

# We use eval to correctly parse the quoted arguments in CURL_OPTS
eval curl $CURL_OPTS "$URL" || exit 1

exit 0
