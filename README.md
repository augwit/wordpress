## A web server to host wordpress
This image runs a Debian-based Nginx server with PHP-fpm to serve a website, configured specifically for WordPress.

The container will download the latest wordpress when it is created.

## About database server
The database is not included in this image. You can use a locally installed or a dockerized database server such as mysql.

## Usage
Example of docker-compose, using this image and mysql image:

```yml
services:
    web:
        image: augwit/wordpress:7.4.33-BETA.2
        restart: always
        container_name: wordpress
        ports:
            - 80:80
        environment:
            - SERVER_NAME=localhost
            - SSL_ENABLED=false
            - WP_DB_HOST=db
            - WP_DB_USER=root
            - WP_DB_PASSWORD=password
            - WP_DB_NAME=wordpress
        volumes:
            - ./www:/var/www/html
            - ./nginx/log:/var/log/nginx
    db:
        image: mysql/mysql-server:8.0.32
        restart: always
        environment:
            MYSQL_USER: root
            MYSQL_ALLOW_EMPTY_PASSWORD: 'no'
            MYSQL_PASSWORD: password
            MYSQL_DATABASE: wordpress
        ports:
            - 3306:3306
        volumes:
            - ./mysql/data:/var/lib/mysql
```

When setting up wordpress, bear in mind the database name should be "db" or "mysql", not the default "localhost", because the wordpress and the database are in two different containers.

The default port is 80. If you want to support HTTPS, please set the environment variable SSL_ENABLED to true publish the 443 port.

We use letsencrypt to generate SSL certificates for you, therefore you don't need to put files by yourself any more.

~~We highly recommend using lets-encrypt as your SSL solution. You need to use tools such as certbot to generate SSL in the host, then copy the cert files from /etc/letsencrypt/live/{yourdomain.com} to the volume. Please note the options-ssl-nginx.conf and ssl-dhparams.pem files from /etc/letsencrypt of the host are also needed to be placed in the same volume. The typical content of this ssl volume should contain such files:~~

~~cert.pem  chain.pem  fullchain.pem  options-ssl-nginx.conf  privkey.pem  README  ssl  ssl-dhparams.pem~~

~~Or you can directly mount /etc/letsencrypt/live/{yourdomain.com} to the /var/ssl volume.~~


## Develop
Feel free to visit the repository site on Github: [https://github.com/augwit/wordpress/](https://github.com/augwit/wordpress/)

Build:
```
docker build . -t augwit/wordpress:${tag}
```

