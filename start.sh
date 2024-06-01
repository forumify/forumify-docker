# Setup dirs/perms
## Copy default files if app is empty
if [ -z "$(ls -A /usr/src/app)" ]; then
  cp -r /usr/src/app.bak/* /usr/src/app
  chmod -R 777 /usr/src/app
fi

## Misc dirs
mkdir -p /var/log/supervisor
mkdir -p var/cache
mkdir -p var/log
chmod -R 777 var
mkdir -p public/storage
chmod -R 777 public
chown -R nginx:nginx .

# Install dependencies
su nginx -c "composer install --no-dev --no-progress"
su nginx -c "composer dump-autoload --no-dev --classmap-authoritative"
su nginx -c "composer dump-env prod"

su nginx -c "npm install -force"
su nginx -c "npm run build"

chmod +x -R bin

# Run startup commands
su nginx -c "/usr/src/app/bin/console doctrine:migrations:migrate --no-interaction"
su nginx -c "/usr/src/app/bin/console forumify:plugins:refresh --no-interaction"
su nginx -c "/usr/src/app/bin/console assets:install --no-interaction"
su nginx -c "/usr/src/app/bin/console cache:warmup --no-interaction"

# Launch services
exec /usr/bin/supervisord -n -c /etc/supervisord.conf
