# A web server to host wordpress
This image runs a Debian-based Nginx server with PHP-fpm to serve a website, configured specifically for WordPress.

## About database server
The database server is not included in this image. You can use a local database sever or a dockerized database server such as mysql. You may need to manually create a database for wordpress if you don't already have one.

## Quickstart

Suppose your database is running on localhost, already with a database named "wordpress". User "wordpress" has the permission to access it with password "password"

You can execute below command to run a HTTP wordpress container right away:

```shell
docker run -d \
  -p 80:80 \
  -e WP_DB_HOST=host.docker.internal \
  -e WP_DB_USER=wordpress \
  -e WP_DB_PASSWORD=password \
  -e WP_DB_NAME=wordpress \
  augwit/wordpress:7.4.33
```

Open browser to visit http://localhost, you will see the wordpress language selection page.

Note the "host.docker.internal" stands for the host machine where the docker container runs on. The commonly used "localhost" or "127.0.0.1" only points to the container, not to the parent level host. You can try to use the "host" network mode by adding "--network host". However on MacOS and Windows this doesn't always work well, therefore using "host.docker.internal" is always a safe play.

Reference: https://docs.docker.com/engine/network/

### About wordpress installation

The web folder is "/var/www/html" in the container. It is recommended to always amount a volume to the web folder, because it is common that users need to directly access wordpress files from the host.

If the web folder is empty, the container will automatically download the latest wordpress into it.

If you already have a wordpress installation, you can mount the existing wordpress folder to the web folder, the container will not overwrite it.

### About wordpress configuration
There are several environment variables available for user to inject the database configs into the wordpress configuration file (wp-config.php) on installation or on wp-config.php missing. The variables are:  WP_DB_HOST, WP_DB_USER, WP_DB_PASSWORD, WP_DB_NAME

Note that these variables will not apply to existing wp-config.php files. This means once the wordpress is installed, you will need to manually edit the wp-config.php file if you want to change to connect to other databases.

When setting up wordpress against a dockerized database server, bear in mind to use the correct host name or IP address because in docker environment the network mode is a bit tricky.

For example in below docker-compose.yml, we should use host name "db" to access the database from wordpress, the default "localhost" will not work because the wordpress and the database are in two different containers.

## Docker compose example
Example of docker-compose, using this image and mysql image:

```yml
services:
    web:
        image: augwit/wordpress:7.4.33
        restart: always
        ports:
            - 80:80
        environment:
            - WP_DB_HOST=db
            - WP_DB_USER=wordpress
            - WP_DB_PASSWORD=password
            - WP_DB_NAME=wordpress
        volumes:
            - ./www:/var/www/html
            - ./nginx/log:/var/log/nginx
    db:
        image: mysql/mysql-server:8.0.32
        restart: always
        environment:
            MYSQL_ROOT_PASSWORD: password
            MYSQL_USER: wordpress
            MYSQL_PASSWORD: password
            MYSQL_DATABASE: wordpress
        ports:
            - 3306:3306
        volumes:
            - ./mysql/data:/var/lib/mysql
```

The default port is 80. If you want to support HTTPS, you can set the environment variable SERVER_NAME, SSL_ENABLED to true, and publish the 443 port.

Below is the example, to set HTTPS for domain name "example.com", so you can visit https://example.com.

```yml
services:
    web:
        image: augwit/wordpress:7.4.33
        restart: always
        ports:
            - 80:80
            - 443:443
        environment:
            - SERVER_NAME=example.com
            - SSL_ENABLED=true
            - CERTBOT_ENABLED=true
            - WP_DB_HOST=db
            - WP_DB_USER=wordpress
            - WP_DB_PASSWORD=password
            - WP_DB_NAME=wordpress
        volumes:
            - ./www:/var/www/html
            - ./nginx/log:/var/log/nginx
    db:
        image: mysql/mysql-server:8.0.32
        restart: always
        environment:
            MYSQL_ROOT_PASSWORD: password
            MYSQL_USER: wordpress
            MYSQL_PASSWORD: password
            MYSQL_DATABASE: wordpress
        ports:
            - 3306:3306
        volumes:
            - ./mysql/data:/var/lib/mysql
```

Note that we use letsencrypt's certbot to generate SSL certificates for you, you need to prove the domain is controlled by you, in most case your domain name should already resolved to the host you run this container, otherwise the certbot will fail, and the container will not be able to serve.

However, if you want to use your own certificate or if your environment does not support certbot to automatically generate certificate, you can set CERTBOT_ENABLED to false, and mount a volumn to /var/ssl, then put your own fullchain.pem and privkey.pem to this folder.

## Develop
Feel free to visit the repository site on Github: [https://github.com/augwit/wordpress/](https://github.com/augwit/wordpress/)

Build:
```
docker build . -t augwit/wordpress:${tag}
```

