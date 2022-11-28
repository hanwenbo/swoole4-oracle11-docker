FROM php:7.4

LABEL maintainer="job@fashop.cn"

# Version
ENV PHPREDIS_VERSION 4.0.1
ENV HIREDIS_VERSION 0.13.3
ENV SWOOLE_VERSION 4.4.12

# Timezone
RUN /bin/cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo 'Asia/Shanghai' > /etc/timezone
# Libs
RUN apt-get update \
    && apt-get install -y \
    unixodbc \
    unixodbc-dev \
    libmagickwand-dev \
    libmagickcore-dev \
    curl \
    wget \
    git \
    zip \
    libcurl4-gnutls-dev \
    libz-dev \
    libssl-dev \
    libnghttp2-dev \
    libpcre3-dev \
    libwebp-dev \
    libjpeg-dev \
    libpng-dev \
    libfreetype6-dev \
    libzip-dev \
    libaio* \
    && apt-get clean \
    && apt-get autoremove

# Composer
RUN curl -sS https://getcomposer.org/installer | php \
    && mv composer.phar /usr/local/bin/composer \
    && composer self-update --clean-backups

# imagick gd extension
RUN pecl install imagick-3.4.3 \
    && docker-php-ext-enable imagick \
    && docker-php-ext-configure gd --with-webp=/usr/include/webp --with-jpeg=/usr/include --with-freetype=/usr/include/freetype2/ \
    && docker-php-ext-install -j$(nproc) gd

# PDO extension
RUN docker-php-ext-install pdo_mysql

# Bcmath extension
RUN docker-php-ext-install bcmath

# Zip extension
RUN docker-php-ext-install zip


# Redis extension
RUN wget http://pecl.php.net/get/redis-${PHPREDIS_VERSION}.tgz -O /tmp/redis.tar.tgz \
    && pecl install /tmp/redis.tar.tgz \
    && rm -rf /tmp/redis.tar.tgz \
    && docker-php-ext-enable redis

# Hiredis
RUN wget https://github.com/redis/hiredis/archive/v${HIREDIS_VERSION}.tar.gz -O hiredis.tar.gz \
    && mkdir -p hiredis \
    && tar -xf hiredis.tar.gz -C hiredis --strip-components=1 \
    && rm hiredis.tar.gz \
    && ( \
    cd hiredis \
    && make -j$(nproc) \
    && make install \
    && ldconfig \
    ) \
    && rm -r hiredis

# Swoole extension
RUN wget https://github.com/swoole/swoole-src/archive/v${SWOOLE_VERSION}.tar.gz -O swoole.tar.gz \
    && mkdir -p swoole \
    && tar -xf swoole.tar.gz -C swoole --strip-components=1 \
    && rm swoole.tar.gz \
    && ( \
    cd swoole \
    && phpize \
    && ./configure --enable-mysqlnd --enable-openssl \
    && make -j$(nproc) \
    && make install \
    ) \
    && rm -r swoole \
    && docker-php-ext-enable swoole

# oracle11
RUN cd / \
    && wget http://hongxingxcx.oss-cn-beijing.aliyuncs.com/oracle11.zip -O oracle11.zip \
    && unzip oracle11.zip \
    && rm oracle11.zip \
    && ( \
    cd /oracle11/instantclient \
#    && ln -s libclntsh.so.11.1 libclntsh.so \
#    && ln -s libocci.so.11.1 libocci.so \
#    && ln -s libnnz11.so libnnz.so \
    && cp libnnz11.so /usr/lib/ \
    ) \
    && docker-php-ext-configure oci8 --with-oci8=instantclient,/oracle11/instantclient \
    && docker-php-ext-install oci8 \
    && extension=oci8.so \
    && docker-php-ext-configure pdo_oci --with-pdo-oci=instantclient,/oracle11/instantclient \
    && docker-php-ext-install pdo_oci \
    && extension=pdo_oci.so

# install driver sqlsrv
# RUN pecl install sqlsrv
# RUN pecl install pdo_sqlsrv


# Install "pdo_odbc" extension.
RUN docker-php-ext-configure pdo_odbc --with-pdo-odbc=unixODBC,/usr \
    && docker-php-ext-install pdo_odbc

RUN set -ex; \
	docker-php-source extract; \
	{ \
		echo '# https://github.com/docker-library/php/issues/103#issuecomment-271413933'; \
		echo 'AC_DEFUN([PHP_ALWAYS_SHARED],[])dnl'; \
		echo; \
		cat /usr/src/php/ext/odbc/config.m4; \
	} > temp.m4; \
	mv temp.m4 /usr/src/php/ext/odbc/config.m4; \
	docker-php-ext-configure odbc --with-unixODBC=shared,/usr; \
	docker-php-ext-install odbc; \
	docker-php-source delete

WORKDIR /var/www/project

