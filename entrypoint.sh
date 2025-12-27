#!/bin/bash

if [ ! -f /etc/nginx/conf.d/default.conf ]; then
    cp /usr/src/nginx-defaults/default.conf /etc/nginx/conf.d/;
    cp /usr/src/nginx-defaults/wordpress.conf.include /etc/nginx/conf.d/wordpress.conf.include

    # Update entrypoint to configure Nginx and configure SSL certificates
    sed -i "s/server_name localhost;/server_name $DOMAIN_NAME;/" /etc/nginx/conf.d/default.conf

    # If SSL is enabled and Certbot is not enabled, copy the default SSL configuration
    if [ "$HTTPS_ENABLED" = "true" ] && [ "$LETSENCRYPT_ENABLED" = "false" ]; then 
        cp /usr/src/nginx-defaults/default_ssl.conf /etc/nginx/conf.d/;
    fi

    # If SSL is enabled and Certbot is enabled, run Certbot to obtain SSL certificates
    if [ "$HTTPS_ENABLED" = "true" ] && [ "$LETSENCRYPT_ENABLED" = "true" ]; then
        certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos --register-unsafely-without-email -m admin@$DOMAIN_NAME
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
