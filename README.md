# WordPress Web Server
Service combining nginx and php-fpm to host wordpress site, database not included.

## Introduction
This image runs a Debian-based Nginx server with PHP-fpm to serve a website, with configurations specifically for WordPress.

As originally designed to serve an existing WordPress site, this image did not implement a default WordPress site yet. Users need to provide WordPress sources either freshly downloaded or from existing code base to a volume and mount it to /var/www.html.

The default port is 80. If you want to support HTTPS, please set the environment variable SSL_ENABLED to true and provide the cert files in a volume mounted to /var/ssl. We expect lets-encrypt solution, therefore you need to use tools such as certbot to generate SSL in the host, and copy the cert files from /etc/letsencrypt/live/{yourdomain.com} to the volume. Please note the options-ssl-nginx.conf and ssl-dhparams.pem files from /etc/letsencrypt of the host are also needed to be placed in the same volume. The typical content of this ssl volume should contain such files:
```shell
cert.pem  chain.pem  fullchain.pem  options-ssl-nginx.conf  privkey.pem  README  ssl  ssl-dhparams.pem
```

New features might come later. Feel free to visit the repository site on Github: [https://github.com/augwit/wordpress/](https://github.com/augwit/wordpress/)

## Usage
example of docker-compose:
```yml
version: '3'
services:
    db:
        image: mysql/mysql-server:8.0.30
        container_name: mysql
        restart: always
        environment:
            MYSQL_USER: root
            MYSQL_ALLOW_EMPTY_PASSWORD: 'no'
            MYSQL_PASSWORD: password
        ports:
            - 3306:3306
        volumes:
            - ./mysql/data:/var/lib/mysql
    web:
        image: augwit/wordpress:7.4.33
        restart: always
        container_name: wordpress
        ports:
            - 80:80
            - 443:443
        environment:
            - SSL_ENABLED=true
        volumes:
            - ./www:/var/www/html
            - ./nginx/log:/var/log/nginx
            - ./ssl:/var/ssl
```

