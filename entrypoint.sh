#!/bin/bash
cp /usr/src/nginx-defaults/wordpress.conf.include /etc/nginx/conf.d/;
cp /usr/src/nginx-defaults/default.conf /etc/nginx/conf.d/;

if [ "$SSL_ENABLED" = "true" ]; then 
    cp /usr/src/nginx-defaults/options-ssl-nginx.conf /var/ssl;
    cp /usr/src/nginx-defaults/default_ssl.conf /etc/nginx/conf.d/;
fi

# Download the latest wordpress
curl https://wordpress.org/latest.zip -o /var/www/wordpress_latest.zip
unzip /var/www/wordpress_latest.zip -d /var/www/
rm -f /var/www/wordpress_latest.zip
cp -r /var/www/wordpress/* /var/www/html/
rm -rf /var/www/wordpress

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
