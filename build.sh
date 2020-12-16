# Set up swap space
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
echo "/swapfile swap swap defaults 0 0" >> /etc/fstab 2>&1
/sbin/swapon -a /swapfile
/bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=1024
/sbin/mkswap /var/swap.1
/sbin/swapon /var/swap.1


# Set up timezone
rm -f /etc/localtime
ln -s /usr/share/zoneinfo/US/Eastern /etc/localtime


# Install dependency packages
apt update
apt -y upgrade
apt install -y \
  unzip \
  apache2 \
  php7.4 \
  php-dev \
  php-gd \
  php-soap \
  php-mbstring \
  php-zip \
  php-curl \
  php-mysql \
  mysql-server \


# Configure Apache
echo "AddHandler php5-script .php" >> /etc/apache2/apache2.conf
echo "AddType text/html .php" >> /etc/apache2/apache2.conf
sed -i -e 's/AllowOverride\ None/AllowOverride\ All/g' /etc/apache2/apache2.conf
sed -i -e 's/\/var\/www\/html/\/var\/www\/html\/drupal\/web/g' /etc/apache2/sites-available/000-default.conf
a2enmod rewrite
service apache2 restart


# Configure MySQL
mysql --execute "create database drupal;"
mysql --execute "create user 'drupal'@'%' identified by 'drupal';"
mysql --execute "grant all privileges on drupal.* to 'drupal'@'%';"
mysql --execute "flush privileges;"
service mysql restart


# Install Composer
cd /root
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --filename=composer --install-dir=/usr/local/bin
php -r "unlink('composer-setup.php');"
chmod +x /usr/local/bin/composer


# Install Drupal
cd /var/www/html
composer -n global require zaporylie/composer-drupal-optimizations
composer -n create-project drupal-composer/drupal-project:9.x-dev drupal --stability dev --no-interaction
echo '$settings["trusted_host_patterns"] = ["^localhost$"];' >> /var/www/html/drupal/web/sites/default/settings.php
cd drupal
mkdir -p config/sync
chmod -R 777 /var/www/html/drupal/config
mkdir private
chmod -R 777 /var/www/html/drupal/private
echo '$settings["file_private_path"] = "/var/www/html/drupal/private";' >> /var/www/html/drupal/web/sites/default/settings.php
cp .env.example .env 
vendor/bin/drush site:install \
  --yes \
  --db-url=mysql://drupal:drupal@localhost:3306/drupal \
  --site-name="Drupal 9 VM" \
  --site-mail=admin@example.com \
  --account-name=admin \
  --account-pass=admin \
  --account-mail=admin@example.com \
  --locale=en \
  standard \
  install_configure_form.enable_update_status_emails=NULL
vendor/bin/drush core:cron
vendor/bin/drush cache:rebuild
