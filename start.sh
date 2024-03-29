mkdir -p /var/log/supervisor
mkdir -p var/cache
mkdir -p var/log
chmod -R 755 var
mkdir -p public/storage
chmod -R 755 public
chmod +x -R bin

chown -R nginx:nginx .

su nginx -c "/usr/src/app/bin/console doctrine:migrations:migrate --no-interaction"
su nginx -c "/usr/src/app/bin/console assets:install --no-interaction"
su nginx -c "/usr/src/app/bin/console cache:warmup --no-interaction"

exec /usr/bin/supervisord -n -c /etc/supervisord.conf
