ARG DEBIAN_VERSION=bullseye
ARG PHP_VERSION=7.4.33

FROM php:$PHP_VERSION-fpm-$DEBIAN_VERSION

# Add environment variables for domain and port
ENV DOMAIN_NAME="localhost"
ENV HTTPS_ENABLED="false"
ENV LETSENCRYPT_ENABLED="true"

ENV WP_DB_HOST="hub.docker.internal"
ENV WP_DB_USER="wordpress"
ENV WP_DB_PASSWORD="password"
ENV WP_DB_NAME="wordpress"

# Add Debian Bookworm repositories and install necessary tools
# persistent dependencies
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		lsb-release \
	; \
	echo "deb http://security.debian.org/debian-security $(lsb_release -cs)-security main" >> /etc/apt/sources.list \
	; \
	echo "deb-src http://security.debian.org/debian-security $(lsb_release -cs)-security main" >> /etc/apt/sources.list \
	; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
	# Ghostscript is required for rendering PDF previews
		ghostscript \
		vim curl unzip gnupg2 ca-certificates

RUN set -eux; \
# install the PHP extensions we need (https://make.wordpress.org/hosting/handbook/handbook/server-environment/#php-extensions)
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libfreetype6-dev \
		libjpeg-dev \
		libmagickwand-dev \
		libpng-dev \
		libzip-dev \
	; \
	\
	docker-php-ext-configure gd \
		--with-freetype \
		--with-jpeg \
	; \
	docker-php-ext-install -j "$(nproc)" \
		bcmath \
		exif \
		gd \
		intl \
		mysqli \
		zip \
	; \
	pecl install imagick-3.8.0; \
	docker-php-ext-enable imagick; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { print $3 }' \
		| sort -u \
		| xargs -r dpkg-query -S \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN set -eux; \
	docker-php-ext-enable opcache; \
	{ \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini
# https://wordpress.org/support/article/editing-wp-config-php/#configure-error-logging
RUN { \
# https://www.php.net/manual/en/errorfunc.constants.php
# https://github.com/docker-library/wordpress/issues/420#issuecomment-517839670
		echo 'error_reporting = E_ERROR | E_WARNING | E_PARSE | E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_COMPILE_WARNING | E_RECOVERABLE_ERROR'; \
		echo 'display_errors = Off'; \
		echo 'display_startup_errors = Off'; \
		echo 'log_errors = On'; \
		echo 'error_log = /dev/stderr'; \
		echo 'log_errors_max_len = 1024'; \
		echo 'ignore_repeated_errors = On'; \
		echo 'ignore_repeated_source = Off'; \
		echo 'html_errors = Off'; \
	} > /usr/local/etc/php/conf.d/error-logging.ini


#RUN mv "/usr/src/php//php.ini-production" "$PHP_INI_DIR/php.ini"

# Install nginx
RUN curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add - \
	; \
RUN set -ex; \
	echo "deb http://nginx.org/packages/debian/ $(lsb_release -cs) nginx" | tee /etc/apt/sources.list.d/nginx.list \
	; \
	apt-get update; \
	\
	apt-get install -y --no-install-recommends \
		nginx \
	; \
        rm -rf /var/lib/apt/lists/*

# Install Certbot using the package manager
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends certbot python3-certbot-nginx cron

# Add a cron job for Certbot auto-renewal
RUN echo "0 0,12 * * * certbot renew --quiet" | crontab -

# Update Nginx to run as www-data
RUN sed -i 's/user  nginx;/user  www-data;/' /etc/nginx/nginx.conf
RUN usermod -a -G nginx www-data
# Change owner of the web folder
RUN chown -R www-data /var/www/html

# Copy default configuration files of nginx
RUN mkdir /usr/src/nginx-defaults
COPY ./nginx/default.conf /usr/src/nginx-defaults/default.conf
COPY ./nginx/default_ssl.conf /usr/src/nginx-defaults/default_ssl.conf
COPY ./nginx/wordpress.conf.include /usr/src/nginx-defaults/wordpress.conf.include
RUN mkdir -p /etc/nginx/ssl
COPY ./nginx/options-ssl-nginx.conf /etc/nginx/ssl/options-ssl-nginx.conf
# Generate the Diffie-Hellman certificate
RUN openssl dhparam -out /etc/nginx/ssl/ssl-dhparams.pem 2048
# Create a directory for SSL certificates when certbot is disabled
RUN mkdir "/var/ssl";
# Remove the default Nginx configuration file, later we will generate new one
RUN rm -f /etc/nginx/conf.d/default.conf

# Expose the default Nginx ports
EXPOSE 80
EXPOSE 443

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]


