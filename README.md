# Forumify Docker Image

Official forumify docker image.

## Usage

This docker image comes without any files or dependencies, you are expected to copy those yourself in a multi-stage build.

Example:
```dockerfile
FROM composer as backend-builder

WORKDIR /usr/src/app

COPY composer.* .

RUN composer install --no-dev --optimize-autoloader --ignore-platform-reqs --no-scripts --no-progress

FROM node:lts as frontend-builder

WORKDIR /usr/src/app

COPY package*.json .
COPY --from=backend-builder /usr/src/app/vendor ./vendor
RUN npm install

COPY assets assets
COPY webpack.config.js webpack.config.js
RUN npm run build

FROM forumify:forumify

WORKDIR /usr/src/app

COPY . .
COPY --from=backend-builder /usr/src/app/vendor ./vendor
COPY --from=frontend-builder /usr/src/app/public/build ./public/build
```
