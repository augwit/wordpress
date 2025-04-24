# WordPress Web Server
Service combining nginx and php-fpm to host wordpress site, database not included.

## Introduction
This image runs a Debian-based Nginx server with PHP-fpm to serve a website, with configurations specifically for WordPress.

The container will download the latest wordpress to /var/www/html/ when it is created.

New features might come later. 

## Usage
Example of docker-compose, using this image and mysql image:
```yml
version: '3'
services:
    web:
        image: augwit/wordpress:7.4.33-ALPHA.2
        restart: always
        container_name: wordpress
        ports:
            - 80:80
            - 443:443
        environment:
            - SSL_ENABLED=false
        volumes:
            - ./www:/var/www/html
            - ./nginx/log:/var/log/nginx
            - ./ssl:/var/ssl
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
```

The default port is 80. If you want to support HTTPS, please set the environment variable SSL_ENABLED to true and provide the cert files in a volume mounted to /var/ssl.

We highly recommend using lets-encrypt as your SSL solution. You need to use tools such as certbot to generate SSL in the host, then copy the cert files from /etc/letsencrypt/live/{yourdomain.com} to the volume. Please note the options-ssl-nginx.conf and ssl-dhparams.pem files from /etc/letsencrypt of the host are also needed to be placed in the same volume. The typical content of this ssl volume should contain such files:
```shell
cert.pem  chain.pem  fullchain.pem  options-ssl-nginx.conf  privkey.pem  README  ssl  ssl-dhparams.pem
```
Or you can directly mount /etc/letsencrypt/live/{yourdomain.com} to the /var/ssl volume.


## Develop
Feel free to visit the repository site on Github: [https://github.com/augwit/wordpress/](https://github.com/augwit/wordpress/)

Build:
```
docker build . -t augwit/wordpress:${tag}
```

