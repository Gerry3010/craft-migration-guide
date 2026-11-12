# Craft 6 (Laravel) on PHP-FPM, with nginx as a separate stage.
#
# Code and vendor/ live in the image, not in a code volume, so a rebuild
# can't be shadowed by a stale named volume. Only runtime data is shared
# (storage, uploads, plugin assets).
FROM php:8.5-fpm-alpine AS base

# icu-data-full: Alpine's icu-libs only ships English ICU data, and intl then
# formats dates in other locales with English month names.
# libwebp: GD needs it for WebP transforms, otherwise the images come out empty.
RUN apk add --no-cache \
        icu-libs icu-data-full libzip libpng libjpeg-turbo libwebp freetype oniguruma \
    && apk add --no-cache --virtual .build \
        $PHPIZE_DEPS icu-dev libzip-dev libpng-dev libjpeg-turbo-dev libwebp-dev freetype-dev oniguruma-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j"$(nproc)" intl pdo_mysql zip gd bcmath exif pcntl \
    && apk del .build

RUN { \
      echo 'memory_limit = 512M'; \
      echo 'upload_max_filesize = 64M'; \
      echo 'post_max_size = 64M'; \
      echo 'max_execution_time = 120'; \
      echo 'opcache.enable = 1'; \
      echo 'opcache.validate_timestamps = 0'; \
    } > /usr/local/etc/php/conf.d/craft.ini

WORKDIR /app

FROM base AS app
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY . .
# Install after copying the code: post-autoload-dump runs artisan
# (package:discover, craft:setup:publish), which needs the whole tree.
# Plugin assets are NOT published here because there is no database yet.
# The publish service in compose.yml does that on every start.
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-progress \
    && mkdir -p storage/framework/cache storage/framework/sessions storage/framework/views \
        storage/logs storage/runtime bootstrap/cache public/uploads public/vendor \
    && chown -R www-data:www-data storage bootstrap/cache public/uploads public/vendor

# nginx gets the same public files so try_files and static delivery work.
# PHP goes to the app container over FastCGI.
FROM nginx:1.29-alpine AS web
COPY --from=app /app/public /app/public
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
