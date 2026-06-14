#!/bin/sh

# Magento CLI 2.4.9

mkdir -p magento apache-config


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
