
FROM composer:2.6 as composer

WORKDIR /app
COPY . /app

RUN composer install --no-dev --optimize-autoloader \
 && php artisan config:cache \
 && php artisan route:cache \
 && php artisan view:cache

# === Final Stage ===
FROM php:8.2-fpm

# Install dependencies
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    curl \
    git \
    npm \
    && docker-php-ext-install pdo pdo_mysql mbstring exif pcntl bcmath gd

WORKDIR /var/www

COPY --from=composer /app /var/www

# Set permissions
RUN chown -R www-data:www-data /var/www \
 && chmod -R 755 /var/www

EXPOSE 9000
CMD ["php-fpm"]

