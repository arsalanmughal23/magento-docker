#!/bin/sh

# Magento CLI 2.4.9

mkdir -p magento apache-config


#region Dockerfile
cat > Dockerfile << 'Dockerfile'
FROM php:8.3-apache

# Install required system dependencies
RUN apt-get update && apt-get install -y \
    git \
    zip \
    unzip \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libicu-dev \
    libxslt1-dev \
    libzip-dev \
    libonig-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    cron \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    bcmath \
    ctype \
    curl \
    dom \
    ftp \
    gd \
    intl \
    mbstring \
    opcache \
    pdo_mysql \
    simplexml \
    soap \
    sockets \
    xsl \
    zip

# Enable Apache mod_rewrite
RUN a2enmod rewrite

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set recommended PHP.ini settings
RUN { \
    echo "memory_limit=2G"; \
    echo "max_execution_time=1800"; \
    echo "max_input_time=1800"; \
    echo "post_max_size=2G"; \
    echo "upload_max_filesize=2G"; \
    echo "date.timezone=UTC"; \
    } > /usr/local/etc/php/conf.d/magento.ini

WORKDIR /var/www/html
Dockerfile
#endregion


#region dockerComposeFile
cat > docker-compose.yml << 'dockerComposeFile'
services:
    web:
        build: .
        container_name: magento_web
        ports:
            - "80:80"
            - "443:443"
        volumes:
            - ./magento:/var/www/html
            - ./apache-config:/etc/apache2/sites-available
        environment:
            - PHP_MEMORY_LIMIT=2G
            - PHP_MAX_EXECUTION_TIME=1800
            - PHP_POST_MAX_SIZE=2G
            - PHP_UPLOAD_MAX_FILESIZE=2G
        depends_on:
            - db
            - opensearch
        networks:
            - magento_network

    db:
        image: mysql:8.0
        container_name: magento_db
        ports:
            - "3306:3306"
        environment:
            - MYSQL_ROOT_PASSWORD=root_password
            - MYSQL_DATABASE=magento
            - MYSQL_USER=magento
            - MYSQL_PASSWORD=magento123
        volumes:
            - db_data:/var/lib/mysql
        networks:
            - magento_network
        command: --max_allowed_packet=256M --log_bin_trust_function_creators=1

    opensearch:
        image: opensearchproject/opensearch:2.11.0
        container_name: magento_opensearch
        environment:
            - discovery.type=single-node
            - plugins.security.disabled=true
            - OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g
        ports:
            - "9200:9200"
            - "9600:9600"
        volumes:
            - opensearch_data:/usr/share/opensearch/data
        networks:
            - magento_network

    phpmyadmin:
        image: phpmyadmin/phpmyadmin
        container_name: magento_phpmyadmin
        ports:
            - "8080:80"
        environment:
            - PMA_HOST=db
            - PMA_PORT=3306
        depends_on:
            - db
        networks:
            - magento_network

    mailhog:
        image: mailhog/mailhog
        container_name: magento_mailhog
        ports:
            - "1025:1025"  # SMTP port
            - "8025:8025"  # Web UI
        networks:
            - magento_network

networks:
    magento_network:
        driver: bridge

volumes:
    db_data:
    opensearch_data:
dockerComposeFile
#endregion


#region .gitignore
cat > .gitignore << 'gitignore'
# Docker environment files to exclude
docker-compose.yml.backup
*.env
.env.local
.env.*.local

# Magento directory specific ignores (for magento/ folder)
/magento/app/code/
/magento/app/design/
/magento/app/etc/config.php
/magento/app/etc/env.php
/magento/app/etc/installation.txt
/magento/generated/
/magento/pub/static/
/magento/pub/media/
/magento/var/
/magento/vendor/
/magento/.git/
/magento/.gitignore
/magento/.gitattributes
/magento/.github/
/magento/.gitmodules

# Magento 2 specific files
/magento/.htaccess
/magento/.htaccess.sample
/magento/.user.ini
/magento/.php-cs-fixer.dist.php
/magento/auth.json
/magento/auth.json.sample
/magento/package.json
/magento/package.json.sample
/magento/Gruntfile.js
/magento/Gruntfile.js.sample
/magento/grunt-config.json
/magento/grunt-config.json.sample
/magento/composer.lock
/magento/composer.phar

# Logs and temporary files
/magento/var/log/
/magento/var/report/
/magento/var/session/
/magento/var/tmp/
/magento/var/cache/
/magento/var/page_cache/
/magento/var/view_preprocessed/
/magento/var/composer_home/
/magento/var/export/
/magento/var/import/
/magento/var/import_history/
/magento/var/backups/

# Static content
/magento/pub/static/_cache/
/magento/pub/static/deployed_version.txt
/magento/pub/static/.htaccess

# Media files
/magento/pub/media/catalog/
/magento/pub/media/customer/
/magento/pub/media/downloadable/
/magento/pub/media/import/
/magento/pub/media/theme/
/magento/pub/media/tmp/
/magento/pub/media/wysiwyg/
/magento/pub/media/.htaccess

# Generated code
/magento/generated/code/
/magento/generated/metadata/

# Setup files
/magento/setup/config/state.json
/magento/update/CONFIG_STATUS.json

# Node dependencies (if any)
/magento/node_modules/
/magento/package-lock.json
/magento/yarn.lock

# IDE and OS files
.idea/
.vscode/
*.swp
*.swo
*~
.DS_Store
Thumbs.db
Desktop.ini
*.log
*.tmp
*.cache

# Shell scripts and backups (except important ones)
*.sh.backup
*.sh~
*.sh.old
*.yml.backup
*.yml~
*.conf.backup
setup-magento.sh.backup
setup-magento.sh~

# Test and coverage
/magento/dev/tests/
/magento/dev/tools/
/magento/phpunit.xml
/magento/phpunit.xml.dist
.clover
.coveralls.yml
coverage/
.coverage/
.coverage.*
phpunit.xml
phpunit.xml.dist
*.phar

# Database local files
*.sql
*.sql.gz
*.db
*.sqlite

# Certificate files
*.pem
*.crt
*.key
*.p12

# Archive files
*.zip
*.tar
*.tar.gz
*.rar
*.7z

# Docker-specific excludes
*.pid
docker-compose.override.yml
docker-compose.*.yml
.docker/
.dockerignore

# Environment configuration
.env
.env.*
!.env.example
!.env.sample

# User-specific files
*.user
*.user.ini
*.local

# Backup and temporary files from editors
*~
*.bak
*.orig
*.old
*.backup

# Magento 2.4+ specific
/magento/.gitlab-ci.yml
/magento/.travis.yml
/magento/.phpunit.result.cache

# Security sensitive files
/magento/app/etc/config.php.bak
/magento/app/etc/env.php.bak
/magento/auth.json.bak
**/config.php.bak
**/env.php.bak

# MacOS specific
.AppleDouble
.LSOverride
._*
.Spotlight-V100
.Trashes
.fseventsd

# Linux specific
.directory
*.part
*.swp
*.swo
*~.nib
.goutputstream-*
.goutputstream-*.lock
*.xpr
*.pyc
*.pyo
.python_history
.racket-options.rktd
.session
.urxvt
.xsession-errors

# Backup files from various tools
composer.phar
composer.lock (if you want to regenerate)
gitignore
#endregion


#region .dockerignore
cat > .dockerignore << 'dockerignore'
# Docker ignore file
.git
.gitignore
.gitattributes
.github/
*.md
*.log
*.tmp
*.swp
*.swo
*~
.DS_Store
.idea/
.vscode/
node_modules/
vendor/
magento/var/
magento/vendor/
magento/generated/
magento/pub/static/
magento/pub/media/
magento/.git/
*.sql
*.sql.gz
*.tar.gz
*.zip
docker-compose.override.yml
*.env
!.env.example
dockerignore
#endregion


#region virtualHost
mkdir -p apache-config && cat > apache-config/magento.conf << 'virtualHost'
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
virtualHost
#endregion


sudo chown -R $USER:$USER . && chmod -R 755 .


docker compose build --no-cache && docker compose up -d


docker exec -it magento_web \
    composer create-project --repository-url=https://repo.magento.com/ \
    magento/project-community-edition=2.4.9 .


docker exec -it magento_web php bin/magento setup:install \
    --base-url=http://localhost \
    --db-host=db \
    --db-name=magento \
    --db-user=magento \
    --db-password=magento123 \
    --admin-firstname=Admin \
    --admin-lastname=User \
    --admin-email=magentoadmin@yopmail.com \
    --admin-user=admin \
    --admin-password=Admin123! \
    --language=en_US \
    --currency=USD \
    --timezone=America/Chicago \
    --use-rewrites=1 \
    --search-engine=opensearch \
    --opensearch-host=opensearch \
    --opensearch-port=9200


docker exec -it magento_web sh -c "\
    find var generated vendor pub/static pub/media app/etc -type f -exec chmod g+w {} + && \
    find var generated vendor pub/static pub/media app/etc -type d -exec chmod g+ws {} + && \
    chown -R :www-data . && \
    chmod u+x bin/magento"


docker exec magento_web sh -c "\
    php bin/magento config:set system/smtp/disable 0 && \
    php bin/magento config:set system/smtp/host mailhog && \
    php bin/magento config:set system/smtp/port 8025 && \
    php bin/magento cache:flush"


docker exec magento_web sh -c "\
    php bin/magento module:disable Magento_AdminAdobeImsTwoFactorAuth && \
    php bin/magento module:disable Magento_TwoFactorAuth && \
    php bin/magento setup:upgrade && \
    php bin/magento cache:flush"
