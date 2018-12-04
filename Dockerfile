FROM composer/composer:1.1-php5-alpine as build

ENV NOVOSGA_VER=v1.5.1 \
    NOVOSGA_MD5=a201469188d7209c20a473f34a1c2d21

ENV NOVOSGA_FILE=novosga.tar.gz \
    NOVOSGA_DIR=/var/www/html \
    NOVOSGA_URL=https://github.com/novosga/novosga/archive/${NOVOSGA_VER}.tar.gz

WORKDIR $NOVOSGA_DIR

RUN set -xe \
    && apk add --no-cache gettext-dev gettext tar \
    && docker-php-ext-install gettext \
    && docker-php-ext-install pcntl \
    && curl -fSL ${NOVOSGA_URL} -o ${NOVOSGA_FILE} \
    && echo "${NOVOSGA_MD5}  ${NOVOSGA_FILE}" | md5sum -c \
    && tar -xz --strip-components=1 -f ${NOVOSGA_FILE} \
    && rm ${NOVOSGA_FILE} \
    && composer install --no-dev

FROM php:5.6.24-apache

EXPOSE 80

RUN echo 'session.save_path = "/tmp"' > /usr/local/etc/php/conf.d/sessionsavepath.ini && \
    echo 'date.timezone = ${TZ}' > /usr/local/etc/php/conf.d/datetimezone.ini

# Install PHP extensions and PECL modules.(Inserted for ldap)
RUN buildDeps=" \
        libbz2-dev \
        libmemcached-dev \
        libmysqlclient-dev \
        libsasl2-dev \
    " \
    runtimeDeps=" \
            curl \
            git \
            libfreetype6-dev \
            libicu-dev \
            libjpeg-dev \
            libldap2-dev \
            libmcrypt-dev \
            libmemcachedutil2 \
            libpng12-dev \
            libpq-dev \
            libxml2-dev \
        " \
    && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y $buildDeps $runtimeDeps

RUN apt-get update \
    && apt-get install -y postgresql-server-dev-all --no-install-recommends \
    && docker-php-ext-install gettext pdo_mysql pdo_pgsql \
    && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ \
    && docker-php-ext-install ldap \
    && a2enmod rewrite \
    && apt-get remove -y --purge postgresql-server-dev-all \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && a2enmod rewrite

COPY --from=build /var/www/html /var/www/html

RUN echo "RedirectMatch ^/$ /public" > .htaccess \ 
    && chown -R 33:33 /var/www/html

#set default env vars
ENV TZ="America/Fortaleza" \
    DATABASE_SGDB="postgres" \
    DATABASE_NAME="sgadb" \
    NOVOSGA_ADMIN_USERNAME="admin" \
    NOVOSGA_ADMIN_FIRSTNAME="Administrator" \
    NOVOSGA_ADMIN_LASTNAME="Global" \
    NOVOSGA_ADMIN_PASSWORD="123456" \
    DATABASE_PORT="5432"

RUN chown -R 33:33 bin/

COPY painel /var/www/html/painel
RUN chown -R 33:33 /var/www/html/painel

COPY start.sh /usr/local/bin
RUN chmod +x /usr/local/bin/start.sh

COPY start_db.php /usr/local/bin/
RUN chmod +x /usr/local/bin/start_db.php

CMD ["start.sh"]