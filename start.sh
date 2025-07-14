#!/bin/sh
set -e

cd /usr/src/app

# Start logging
unbuffer cat /tmp/logpipe &


# Setup dirs/perms
## Copy default files if app is empty
if [ -z "$(ls -A /usr/src/app)" ]; then
  cp -r /usr/src/app.bak/* /usr/src/app
  chmod -R 777 /usr/src/app
fi

## Misc dirs
mkdir -p -m 777 var/cache var/log
mkdir -p -m 777 public/storage

# Install dependencies
composer install --no-dev --no-progress --no-interaction --no-autoloader --no-scripts
composer dump-autoload --optimize --classmap-authoritative
composer dump-env prod
composer run-script auto-scripts
npm install -force
npm run build

chmod +x -R bin

# Run startup commands
/usr/src/app/bin/console doctrine:database:create --if-not-exists --no-interaction
/usr/src/app/bin/console doctrine:migrations:migrate --no-interaction
/usr/src/app/bin/console forumify:plugins:refresh --no-interaction
/usr/src/app/bin/console assets:install --no-interaction
/usr/src/app/bin/console cache:warmup --no-interaction

# Launch services
exec /usr/bin/supervisord -n -c /etc/supervisord.conf
