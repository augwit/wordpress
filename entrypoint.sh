#!/bin/bash

deploy_self_signed_certificates() {
    domain="$1"

    if [ -z "$domain" ]; then
        echo "[ERROR] domain is empty" >&2
        return 1
    fi

    mkdir -p /var/ssl

    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /var/ssl/privkey.pem \
        -out /var/ssl/fullchain.pem \
        -subj "/CN=$domain" \
        -addext "subjectAltName=DNS:$domain,IP:127.0.0.1"

    cp -p /usr/src/nginx-defaults/default_ssl.conf /etc/nginx/conf.d/default.conf
    sed -i "s/server_name localhost;/server_name $domain;/" /etc/nginx/conf.d/default.conf
}

if [ -f /etc/nginx/conf.d/default.conf ] && ! grep -q "wordpress.conf.include" /etc/nginx/conf.d/default.conf; then
    # Custom config detected - warn but don't overwrite
    echo "INFO: Custom Nginx config detected - not overwriting"
    echo "To update to default configs, manually delete the custom configs under /etc/nginx/conf.d/, then restart the container"
else
    if [ ! -f /etc/nginx/conf.d/default.conf ]; then
        echo "Setting up default WordPress Nginx configuration"
    else
        echo "Override existing WordPress Nginx configurations"
    fi

    cp -p /usr/src/nginx-defaults/default.conf /etc/nginx/conf.d/;
    cp -p /usr/src/nginx-defaults/wordpress.conf.include /etc/nginx/conf.d/wordpress.conf.include
    if [ ! -f /etc/nginx/conf.d/custom.conf.include ]; then
        cp /usr/src/nginx-defaults/custom.conf.include /etc/nginx/conf.d/custom.conf.include
    fi

    # Update server_name in Nginx configuration
    sed -i "s/server_name localhost;/server_name $DOMAIN_NAME;/" /etc/nginx/conf.d/default.conf

    # If SSL is enabled and Certbot is not enabled, copy the default SSL configuration
    if [ "$HTTPS_ENABLED" = "true" ] && [ "$LETSENCRYPT_ENABLED" = "false" ]; then
        # Generate self-signed certificates
        deploy_self_signed_certificates $DOMAIN_NAME
    fi

    if [ "$HTTPS_ENABLED" = "true" ]; then
        # Ensure proper SSL handling for reverse proxy
        sed -i "s/ssl_certificate \/var\/ssl\/fullchain.pem;/ssl_certificate \/var\/ssl\/fullchain.pem;\n    proxy_headers_hash_max_size 512;\n    proxy_headers_hash_bucket_size 128;/" /etc/nginx/conf.d/default.conf
    fi

    # If SSL is enabled and Certbot is enabled, run Certbot to obtain SSL certificates
    if [ "$HTTPS_ENABLED" = "true" ] && [ "$LETSENCRYPT_ENABLED" = "true" ]; then
        if [ $DOMAIN_NAME = "localhost" ]; then
            # Always use self-signed certificates for localhost
            deploy_self_signed_certificates $DOMAIN_NAME
        fi
        # Try Certbot - handle failure appropriately
        echo "Using Let's Encrypt for domain $DOMAIN_NAME"
        certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos --register-unsafely-without-email -m admin@$DOMAIN_NAME
        service nginx stop
    fi
fi

# Download the latest wordpress if necessary
if [ ! -f /var/www/html/index.php ]; then
    curl https://wordpress.org/latest.zip -o /var/www/wordpress_latest.zip
    unzip /var/www/wordpress_latest.zip -d /var/www/
    rm -f /var/www/wordpress_latest.zip
    cp -r /var/www/wordpress/* /var/www/html/
    rm -rf /var/www/wordpress
fi

# If wp-config.php does not exist and wp-config-sample.php exists, copy wp-config-sample.php to wp-config.php
if [ ! -f /var/www/html/wp-config.php ] && [ -f /var/www/html/wp-config-sample.php ]; then
    cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

    # Generate random keys for authentication salts only on first setup
    for key in AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT; do
        rand=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 64)
        sed -i "s/put your unique phrase here/${rand}/" /var/www/html/wp-config.php
    done
fi

# Always update database configuration from environment variables on boot
if [ -f /var/www/html/wp-config.php ]; then
    # Update DB_NAME
    sed -i "s/define( *['\"]DB_NAME['\"] *, *['\"].*['\"] *);/define( 'DB_NAME', '${WP_DB_NAME}' );/" /var/www/html/wp-config.php
    
    # Update DB_USER
    sed -i "s/define( *['\"]DB_USER['\"] *, *['\"].*['\"] *);/define( 'DB_USER', '${WP_DB_USER}' );/" /var/www/html/wp-config.php
    
    # Update DB_PASSWORD
    sed -i "s/define( *['\"]DB_PASSWORD['\"] *, *['\"].*['\"] *);/define( 'DB_PASSWORD', '${WP_DB_PASSWORD}' );/" /var/www/html/wp-config.php
    
    # Update DB_HOST
    sed -i "s/define( *['\"]DB_HOST['\"] *, *['\"].*['\"] *);/define( 'DB_HOST', '${WP_DB_HOST}' );/" /var/www/html/wp-config.php

    # Add WORDPRESS_CONFIG_EXTRA to wp-config.php
    if [ ! -z "$WORDPRESS_CONFIG_EXTRA" ]; then
        echo "Adding WORDPRESS_CONFIG_EXTRA to wp-config.php"
        # Check if WORDPRESS_CONFIG_EXTRA is already in wp-config.php to avoid duplication
        if ! grep -q "WORDPRESS_CONFIG_EXTRA" /var/www/html/wp-config.php; then
             # Use awk to insert the content before the "stop editing" line
             awk -v content="$WORDPRESS_CONFIG_EXTRA" '
             /That.s all, stop editing/ {
                 print "// WORDPRESS_CONFIG_EXTRA"
                 print content
                 print ""
             }
             { print }
             ' /var/www/html/wp-config.php > /var/www/html/wp-config.php.tmp && mv /var/www/html/wp-config.php.tmp /var/www/html/wp-config.php
        fi
    fi

    # Add proxy headers support to wp-config.php
    if ! grep -q "HTTP_X_FORWARDED_PROTO" /var/www/html/wp-config.php; then
        echo "Adding proxy header support to wp-config.php"
        cat <<EOF >> /var/www/html/wp-config.php

// Handle Reverse Proxy (HTTPS)
if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    \$_SERVER['HTTPS'] = 'on';
}
EOF
    fi

    # Change owner of the web folder to make sure proper permissions for nginx
    chown -R www-data /var/www/html
fi

# Start PHP-FPM in the background
php-fpm &

# Start Nginx in the foreground
nginx -g 'daemon off;'

if [ "$?" = "0" ]; then
    exec echo "Nginx started to serve.";
else
    exec echo "Nginx failed to start.";
fi
