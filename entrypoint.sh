#!/bin/bash

if [ -z "$(ls -A /etc/nginx/conf.d)" ]; then
    cp /usr/src/nginx-defaults/default.conf /etc/nginx/conf.d/;
    cp /usr/src/nginx-defaults/wordpress.conf.include /etc/nginx/conf.d/wordpress.conf.include

    # Update entrypoint to configure Nginx and configure SSL certificates
    sed -i "s/server_name localhost;/server_name $SERVER_NAME;/" /etc/nginx/conf.d/default.conf

    # If SSL is enabled and Certbot is not enabled, copy the default SSL configuration
    if [ "$SSL_ENABLED" = "true" ] && [ "$CERTBOT_ENABLED" = "false" ]; then 
        cp /usr/src/nginx-defaults/default_ssl.conf /etc/nginx/conf.d/;
    fi

    # If SSL is enabled and Certbot is enabled, run Certbot to obtain SSL certificates
    if [ "$SSL_ENABLED" = "true" ] && [ "$CERTBOT_ENABLED" = "true" ]; then
        certbot --nginx -d $SERVER_NAME --non-interactive --agree-tos --register-unsafely-without-email -m admin@$SERVER_NAME
        # cerrtbot started nginx but we need to stop it for now. Later we will start it in the foreground.
        service nginx stop
    fi
fi

# Download the latest wordpress
if [ ! -f /var/www/html/index.php ]; then
    curl https://wordpress.org/latest.zip -o /var/www/wordpress_latest.zip
    unzip /var/www/wordpress_latest.zip -d /var/www/
    rm -f /var/www/wordpress_latest.zip
    cp -r /var/www/wordpress/* /var/www/html/
    rm -rf /var/www/wordpress
fi

# If wp-config.php does not exist and wp-config-sample.php exists, copy wp-config-sample.php to wp-config.php and update database configuration
if [ ! -f /var/www/html/wp-config.php ] && [ -f /var/www/html/wp-config-sample.php ]; then
    cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
    sed -i "s/database_name_here/${WP_DB_NAME}/" /var/www/html/wp-config.php
    sed -i "s/username_here/${WP_DB_USER}/" /var/www/html/wp-config.php
    sed -i "s/password_here/${WP_DB_PASSWORD}/" /var/www/html/wp-config.php
    sed -i "s/localhost/${WP_DB_HOST}/" /var/www/html/wp-config.php

    # Generate random keys for authentication salts
    for key in AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT; do
        rand=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 64)
        sed -i "s/put your unique phrase here/${rand}/" /var/www/html/wp-config.php
    done

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
