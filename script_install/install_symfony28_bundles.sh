#!/bin/bash
#
# Script de Instalacion para Symfony28 bajo CentOS 6.8
# 
# @author Juan.Mardones@grupogtd.com
# @author Javier Reyes <javier.reyesc1@gmail.com>

# Instalacion Inicial 
yum install vim epel-release
yum update

# Instalacion PHP56
rpm -Uvh https://mirror.webtatic.com/yum/el6/latest.rpm
yum install -y php56w php56w-opcache php56w-cli php56w-common php56w-gd php56w-pgsql php56w-pdo php56w-mysql php56w-mbstring php56w-xml

# Instalacion Apache
yum -y install httpd


# Configuracion PHP

PHP_TIMEZONE="America/Santiago"
sed -i "s/expose_php =.*/expose_php = Off/" /etc/php.ini
sed -i "s/;date.timezone =.*/date.timezone = ${PHP_TIMEZONE/\//\\/}/" /etc/php.ini
sed -i "s/memory_limit = 128M.*/memory_limit = 2048M/" /etc/php.ini


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


echo "Desea instalar Sonata? [S/n]:"
read install_sonata
if [ "$install_sonata" != "n" ]; then
    composer require sonata-project/admin-bundle
    composer require sonata-project/doctrine-orm-admin-bundle
    composer require sonata-project/easy-extends-bundle --no-update
    composer require knplabs/knp-menu-bundle
    cat >> app/config/config.yml <<EOF
sonata_block:
    default_contexts: [cms]
    blocks:
        # enable the SonataAdminBundle block
        sonata.admin.block.admin_list:
            contexts:   [admin]
EOF
    
    cat >> app/config/routing.yml <<EOF
admin:
    resource: '@SonataAdminBundle/Resources/config/routing/sonata_admin.xml'
    prefix: /admin

_sonata_admin:
    resource: .
    type: sonata_admin
    prefix: /admin
EOF
    sed -i '/$bundles = array/ a \\t\tnew Sonata\\CoreBundle\\SonataCoreBundle(),\n\t\tnew Sonata\\BlockBundle\\SonataBlockBundle(),\n\t\tnew Knp\\Bundle\\MenuBundle\\KnpMenuBundle(),\n\t\tnew Sonata\\DoctrineORMAdminBundle\\SonataDoctrineORMAdminBundle(),\n\t\tnew Sonata\\AdminBundle\\SonataAdminBundle(),\n\t\tnew Sonata\\EasyExtendsBundle\\SonataEasyExtendsBundle(),\n' app/AppKernel.php
    sed -i "s/#translator:.*/translator:      { fallbacks: [\"%locale%\"] }/" app/config/config.yml

    echo "Desea instalar el Administrador de Usuarios? [S/n]:"
    read install_ubundle
    if [ "$install_ubundle" != "n" ]; then

        composer require friendsofsymfony/user-bundle "~1.3"
        composer require sonata-project/user-bundle --no-update
        composer require sonata-project/doctrine-orm-admin-bundle  --no-update
        composer require friendsofsymfony/user-bundle "~1.3" --no-update
        composer update
        sed -i '/$bundles = array/ a \\t\tnew Sonata\\UserBundle\\SonataUserBundle("FOSUserBundle"),' app/AppKernel.php        
        sed -i '/$bundles = array/ a \\t\tnew FOS\\UserBundle\\FOSUserBundle(),' app/AppKernel.php


        cat > app/config/security.yml <<EOF
security:
    encoders:
        FOS\UserBundle\Model\UserInterface: bcrypt

    role_hierarchy:
        ROLE_ADMIN:       ROLE_USER
        ROLE_SUPER_ADMIN: ROLE_ADMIN

    providers:
        fos_userbundle:
            id: fos_user.user_provider.username

    firewalls:
        main:
            pattern: ^/
            form_login:
                provider: fos_userbundle
                csrf_provider: security.csrf.token_manager # Use form.csrf_provider instead for Symfony <2.4
            logout:       true
            anonymous:    true

    access_control:
        - { path: ^/login$, role: IS_AUTHENTICATED_ANONYMOUSLY }
        - { path: ^/register, role: IS_AUTHENTICATED_ANONYMOUSLY }
        - { path: ^/resetting, role: IS_AUTHENTICATED_ANONYMOUSLY }
        - { path: ^/admin/, role: ROLE_ADMIN }
EOF

        cat >> app/config/config.yml <<EOF

#FOS USER
fos_user:
    db_driver: orm # other valid values are 'mongodb', 'couchdb' and 'propel'
    firewall_name: main
    user_class: AppBundle\Entity\User
EOF
        
        cat >> app/config/routing.yml <<EOF

#FOS USER
fos_user_security:
    resource: "@FOSUserBundle/Resources/config/routing/security.xml"

fos_user_profile:
    resource: "@FOSUserBundle/Resources/config/routing/profile.xml"
    prefix: /profile

fos_user_register:
    resource: "@FOSUserBundle/Resources/config/routing/registration.xml"
    prefix: /register

fos_user_resetting:
    resource: "@FOSUserBundle/Resources/config/routing/resetting.xml"
    prefix: /resetting

fos_user_change_password:
    resource: "@FOSUserBundle/Resources/config/routing/change_password.xml"
    prefix: /profile
EOF
      

        php app/console sonata:easy-extends:generate SonataUserBundle -d src

        rpm -Uvh http://yum.postgresql.org/9.4/redhat/rhel-6-x86_64/pgdg-centos94-9.4-2.noarch.rpm
        yum update
        yum install postgresql94-server postgresql94-contrib
        #service postgresql-9.4 initdb
        service postgresql-9.4 start 

        #su -u postgres psql postgres
        #password postgres
        #vim /var/lib/pgsql/9.4/data/pg_hba.conf
        /etc/init.d/postgresql-9.4 restart

        php app/console doctrine:database:create
        php app/console doctrine:schema:update --force
        php app/console fos:user:create --super-admin
        php app/console assets:install  


    fi
fi


echo "Desea instalar Soporte para MongoDB? [S/n]:"
read install_mongo

if [ "$install_mongo" != "n" ]; then
    yum install mongodb

fi

php app/console cache:clear 


## Restableciendo limite de memoria php
sed -i "s/memory_limit = 2048M.*/memory_limit = 128M/" /etc/php.ini

## Permisos log y cache
HTTPUSER=apache 
chmod 2777 app/cache -R 
chmod 2777 app/logs -R 
setfacl -Rn -m u:"$HTTPDUSER":rwX -m u:`whoami`:rwX app/cache app/logs 
setfacl -dRn -m u:"$HTTPDUSER":rwX -m u:`whoami`:rwX app/cache app/logs 
