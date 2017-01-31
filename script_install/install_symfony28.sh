#! /bin/bash
#
# Script Instalacion Ambiente desarrollo Symfony28
# @author Juan.Mardones@grupogtd.com
# date 19/01/2017

# Instalacion Inicial 
yum install vim epel-release
yum update
yum install wget vim gcc acl git

# Instalacion PHP56
#rpm -Uvh https://mirror.webtatic.com/yum/el6/latest.rpm
#yum install -y php56w php56w-opcache php56w-cli php56w-common php56w-gd php56w-pgsql php56w-pdo php56w-mysql php56w-mbstring php56w-xml
wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm && rpm -Uvh epel-release-latest-6.noarch.rpm
wget http://rpms.famillecollet.com/enterprise/remi-release-6.rpm && rpm -Uvh remi-release-6*.rpm
sed -i '/\[remi\]/,/^ *\[/ s/enabled=0/enabled=1/' /etc/yum.repos.d/remi.repo
sed -i '/\[remi-php56\]/,/^ *\[/ s/enabled=0/enabled=1/' /etc/yum.repos.d/remi.repo

yum -y install php php-cli php-common php-gd php-pgsql php-pdo php-mbstring php-xml php-cli php-pear php-devel

# Instalacion Mongo
pecl install mongo

# Instalacion Apache
yum -y install httpd


# Configuracion PHP

PHP_TIMEZONE="America/Santiago"
sed -i "s/expose_php =.*/expose_php = Off/" /etc/php.ini
sed -i "s/;date.timezone =.*/date.timezone = ${PHP_TIMEZONE/\//\\/}/" /etc/php.ini

# Instalacion Symfony
curl -LsS https://symfony.com/installer -o /usr/local/bin/symfony
chmod a+x /usr/local/bin/symfony

# Instalacion Composer
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod a+x /usr/local/bin/composer

# Instalacion Demo Symfony
cd /var/www/
symfony new symfony 2.8
php composer update

# Configuracion de Virtual Host. El servicio de Virtual Host es HTTPS
cat > /etc/httpd/conf.d/symfony.conf <<EOF
<VirtualHost _default_:80>
    ServerAdmin admin@example.com
    DocumentRoot /var/www/symfony/web
    DirectoryIndex app.php

    <Directory "/var/www/symfony/web">
         AllowOverride All
         Allow from All
    </Directory>

    BrowserMatch "MSIE [2-6]" \
                 nokeepalive ssl-unclean-shutdown \
                 downgrade-1.0 force-response-1.0
    BrowserMatch "MSIE [17-9]" ssl-unclean-shutdown
</VirtualHost>
EOF

apachectl -k stop
service httpd restart

## Permisos Cache
cd /var/www/symfony
chmod -R 777 app/cache app/logs
setfacl -R -m u:apache:rwX -m u:`whoami`:rwX app/cache app/logs
setfacl -dR -m u:apache:rwX -m u:`whoami`:rwX app/cache app/logs
