# syntax=docker/dockerfile:1.4
FROM node:22 AS node
FROM php:8.4-fpm

WORKDIR /usr/src/app


# Configure OS
RUN apt-get update && apt-get install -y --no-install-recommends \
        acl \
        expect \
        file \
        gettext \
        git \
        nginx \
        supervisor \
    && rm -rf /var/lib/apt/lists/*

# Install PHP Extensions
RUN curl -sSLf -o \
        /usr/local/bin/install-php-extensions \
        https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions \
    && chmod +x /usr/local/bin/install-php-extensions

RUN install-php-extensions \
        @composer \
        pdo_mysql \
        intl \
        opcache \
        zip

ENV COMPOSER_ALLOW_SUPERUSER=1

# Install NodeJS
COPY --link --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --link --from=node /usr/local/bin/node /usr/local/bin/node
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm

# Configuration files
COPY --link conf/php-fpm.conf /usr/local/etc/php-fpm.conf
COPY --link conf/php.ini /usr/local/etc/php/conf.d/production.ini
COPY --link conf/nginx.conf /etc/nginx/nginx.conf
COPY --link conf/supervisord.conf /etc/supervisord.conf
COPY --link composer.json /usr/src/app.bak/composer.json

RUN mkfifo -m 666 /tmp/logpipe

# Start forumify
WORKDIR /usr/src/app

COPY --link --chmod=755 start.sh /start.sh
ENTRYPOINT ["/start.sh"]
