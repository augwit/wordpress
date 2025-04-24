#!/bin/bash
cp /usr/src/nginx-defaults/wordpress.conf.include /etc/nginx/conf.d/;
cp /usr/src/nginx-defaults/default.conf /etc/nginx/conf.d/;

# if [ "$SSL_ENABLED" = "true" ]; then 
#     cp /usr/src/nginx-defaults/options-ssl-nginx.conf /var/ssl;
#     cp /usr/src/nginx-defaults/default_ssl.conf /etc/nginx/conf.d/;
# fi

# Update entrypoint to configure Nginx and acquire SSL certificates
sed -i "s/server_name localhost;/server_name $SERVER_NAME;/" /etc/nginx/conf.d/default.conf

if [ "$SSL_ENABLED" = "true" ]; then
    certbot --nginx -d $SERVER_NAME --non-interactive --agree-tos --register-unsafely-without-email -m admin@$SERVER_NAME
    service nginx stop
fi

# Download the latest wordpress
if [ ! -f /var/www/html/index.php ]; then
    curl https://wordpress.org/latest.zip -o /var/www/wordpress_latest.zip
    unzip /var/www/wordpress_latest.zip -d /var/www/
    rm -f /var/www/wordpress_latest.zip
    cp -r /var/www/wordpress/* /var/www/html/
    rm -rf /var/www/wordpress
fi

# Copy wp-config-sample.php to wp-config.php and update database configuration
cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
sed -i "s/database_name_here/${WP_DB_NAME}/" /var/www/html/wp-config.php
sed -i "s/username_here/${WP_DB_USER}/" /var/www/html/wp-config.php
sed -i "s/password_here/${WP_DB_PASSWORD}/" /var/www/html/wp-config.php
sed -i "s/localhost/${WP_DB_HOST}/" /var/www/html/wp-config.php

# Change owner of the web folder
chown -R www-data /var/www/html

# Start PHP-FPM in the background
php-fpm &

# Start Nginx in the foreground
nginx -g 'daemon off;'

if [ "$?" = "0" ]; then
    exec echo "Nginx started to serve.";
else
    exec echo "Nginx failed to start.";
fi
