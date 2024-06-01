FROM php:8.3-fpm-alpine

WORKDIR /usr/src/app

# Configure OS
RUN apk add --no-cache \
    busybox-suid \
    icu-dev \
    libzip-dev \
    nodejs \
    npm \
    shadow \
    supervisor \
    tzdata \
    xmlstarlet && \
    docker-php-ext-install -j$(nproc) pdo_mysql intl opcache zip && \
    mkdir -p /var/log/supervisor && \
    curl -o /usr/local/bin/composer https://getcomposer.org/download/latest-stable/composer.phar && \
    chmod +x /usr/local/bin/composer

# Install nginx
RUN addgroup -S nginx && \
    adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx && \
    usermod -u 1000 nginx && \
    groupmod -g 1000 nginx && \
    usermod --shell /bin/ash nginx && \
    apk add nginx && \
    apk del shadow

# Configuration files
COPY php/php-fpm.conf /usr/local/etc/php-fpm.conf
COPY php/www.conf /usr/local/etc/php-fpm.d/www.conf
COPY php/php.ini /usr/local/etc/php/conf.d/production.ini

COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/http.d/default.conf /etc/nginx/http.d/default.conf

COPY supervisor/supervisord.conf /etc/supervisord.conf
COPY supervisor/conf.d /etc/supervisor/conf.d

COPY composer.json /usr/src/app.bak/composer.json

# Start forumify
COPY start.sh /start.sh
RUN chmod 755 /start.sh

CMD ["/start.sh"]
