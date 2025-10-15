# A Web Server to Host Wordpress
[![Docker Pulls](https://img.shields.io/docker/pulls/augwit/wordpress.svg)](https://hub.docker.com/r/augwit/wordpress)
[![Docker Image Version](https://img.shields.io/docker/v/augwit/wordpress?sort=semver)](https://hub.docker.com/r/augwit/wordpress/tags)
[![GitHub stars](https://img.shields.io/github/stars/augwit/wordpress.svg?style=social&label=Star)](https://github.com/augwit/wordpress)
[![GitHub license](https://img.shields.io/github/license/augwit/wordpress)](https://github.com/augwit/wordpress/blob/main/LICENSE)
[![Docs](https://img.shields.io/badge/docs-deepwiki.com-blue)](https://deepwiki.com/augwit/wordpress)

## Introduction

This image runs a Debian-based Nginx server with PHP-fpm to serve a website, configured specifically for WordPress.

### About Database Server

The database server is not included in this image. You can use a local database sever or a dockerized database server such as mysql. You may need to manually create a database for Wordpress if you don't already have one.

## Quickstart

### Run with an external MySQL server

Suppose your database is running on localhost, already with a database named "wordpress". User "wordpress" has the permission to access it with password "password".

You can execute below command to run a HTTP Wordpress container right away:

```shell
docker run -d \
  -p 80:80 \
  -e WP_DB_HOST=host.docker.internal \
  -e WP_DB_USER=wordpress \
  -e WP_DB_PASSWORD=password \
  -e WP_DB_NAME=wordpress \
  augwit/wordpress:latest
```

Open browser to visit http://localhost, you will see the Wordpress language selection page as the first configuration step of the new installation.

Note the "host.docker.internal" stands for the host machine where the docker container runs on. The commonly used "localhost" or "127.0.0.1" only points to the container, not to the parent level host. You can try to use the "host" network mode by adding "--network host". However on MacOS and Windows this doesn't always work well, therefore using "host.docker.internal" is always a safe play.

Reference: https://docs.docker.com/engine/network/

## How Wordpress Works

### Wordpress installation

On the container's startup, a web folder (the home directory of the Wordpress website) will be automatically created or mounted. The container then determine how to install the Wordpress:

- If the web folder is empty, the container will automatically download the latest Wordpress into it.
- If the web folder is not empty, the container will do nothing to avoid overwrite anything in the web folder.

The web folder is "/var/www/html" inside the container. It is recommended to mount a dedicated volume to the web folder. It is very common that users need to directly access Wordpress files from the host at some point, therefore mounting a managed folder to it is always a good practice. You should be familiar with docker commands or docker compose scripts to mount volumes.

If you already have a Wordpress website, you can mount the existing Wordpress folder to the web folder, this way the container will save the installation process and avoid overwriting the existing Wordpress.

### Wordpress upgrade

The container by itself does not provide automatic Wordpress upgrade feature. You should use the Wordpress admin panel to upgrade it or set the automatic upgrade on. The file permissions were already taken care of by the container so there should be no worries about upgrading fail due to file permission errors.

### Wordpress initial configuration

On container's startup, after the eligible Wordpress installation, the container will check if the Wordpress's config file wp-config.php exists in the web folder.

- If the wp-config.php does not exist(for a new installation this is true), the container will create one according to the sample config file, and inject a set of docker envrionment variables into it.

- If the wp-config.php already exists, the container will leave it as is.


The supported docker environment variables are:  

```
WP_DB_HOST, WP_DB_USER, WP_DB_PASSWORD, WP_DB_NAME
```

***Note that these environment variables will only apply to new wp-config.php file creation, it will not apply to an existing wp-config.php file.***

This means once the Wordpress creation is completed, you cannot change the config through change environment variables. You will need to manually edit the wp-config.php file. For example, if you want to change to connect to other databases, you should manually edit these variables in the wp-config.php file.

## Advanced Usages

### Docker compose example
An example of docker-compose configuration, using this image with a MySQL database image:

```yml
services:
    web:
        image: augwit/wordpress:latest
        restart: always
        ports:
            - 80:80
        environment:
            - WP_DB_HOST=db
            - WP_DB_USER=wordpress
            - WP_DB_PASSWORD=password
            - WP_DB_NAME=Wordpress
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

### Connect to a dockerized MySQL server

When setting up Wordpress to connect to a dockerized database server as in above example, remember to use the correct host name or IP address of the the database server, the reason is that in docker environment the network mode is a bit tricky which will affect the name resolve.

For example, in the above docker-compose.yml example, we should use host name "db" to access the database from Wordpress, the default "localhost" will not work because the Wordpress and the database are in two different containers, the "localhost" of them only refers to each of their own container.

### HTTPS & SSL support

The default port of the web server is 80. If you want to support HTTPS, you can set the environment variable DOMAIN_NAME, HTTPS_ENABLED to true, and publish the 443 port.

HTTPS is already a industrial standard of web security, so it is always encouraged to support HTTPS and redirect HTTP into HTTPS (or turn off HTTP if you want).

Below is an example, by setting up HTTPS for domain name "example.com", you can visit https://example.com for the website.

```yml
services:
    web:
        image: augwit/wordpress:latest
        restart: always
        ports:
            - 80:80
            - 443:443
        environment:
            - DOMAIN_NAME=example.com
            - HTTPS_ENABLED=true
            - LETSENCRYPT_ENABLED=true
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

Note that by default we use ***Letsencrypt*** to automatically generate SSL certificates for the website, you need to make sure that your domain name is already resolved to the host server you run this container. If the DNS is not correc the certbot will fail the challenge phase, causing no certificate generated and the website will fallback to only serve on HTTP 80 port.

***How to use your own certificates:***
If you want to use your own certificate or if your environment is not friendly to the Letsencrypt, you can follow below steps:

1. Set LETSENCRYPT_ENABLED to false
2. Mount a volumn to /var/ssl
3. Put your own cert files such as fullchain.pem and privkey.pem to this folder.
   
The website will only serve when the two cert files are properly placed when LETSENCRYPT_ENABLED=false.

## Develop This Image

Feel free to visit the repository site on Github: [https://github.com/augwit/wordpress/](https://github.com/augwit/wordpress/)

Build with specific Debian & PHP version:

```shell
docker build --build-arg DEBIAN_VERSION=trixie --build-arg PHP_VERSION=8.4.13 -t augwit/wordpress:8.4.13 .
```

Build with the default:

```shell
docker build . -t augwit/wordpress:${tagName}
```

The current default build args are:

```shell
DEBIAN_VERSION=bookworm
PHP_VERSION=8.3.26
```

