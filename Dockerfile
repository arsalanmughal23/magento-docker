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
