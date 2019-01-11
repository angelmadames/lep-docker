FROM ubuntu:18.04

# Maintainer
LABEL maintainer="Angel Adames <a.adames@gbh.com.do>"

# Environment
ENV DEBIAN_FRONTEND noninteractive

ENV PHP_VERSION 7.2

ENV NVM_DIR /usr/local/bin/nvm
ENV NVM_VERSION 0.33.11

ENV NODE_VERSION 10.15.0

# Update package list and upgrade available packages
RUN apt update; apt upgrade -y

# Add PPAs and repositories
RUN apt install -y \
  software-properties-common \
  ca-certificates \
  curl; \
  apt-add-repository ppa:nginx/stable -y; \
  apt-add-repository ppa:ondrej/php -y; \
  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -; \
  echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

# Update package list one more time
RUN apt update

# Update package lists & install some basic packages
RUN apt install -y \
  --fix-missing -y \
  apt-utils \
  bash-completion \
  build-essential \
  dos2unix \
  gcc \
  git \
  libmcrypt4 \
  libpcre3-dev \
  libpng-dev \
  mcrypt \
  nano \
  supervisor \
  vim \
  yarn \
  zsh

# Configure locale
RUN echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale

# Set my timezone
RUN ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# User configuration
RUN adduser homestead; \
  usermod -p $(echo secret | openssl passwd -1 -stdin) homestead

# PHP installation
RUN apt install -y \
  --allow-downgrades \
  --allow-remove-essential \
  --allow-change-held-packages \
  php-pear \
  php-xdebug \
  php${PHP_VERSION}-bcmath \
  php${PHP_VERSION}-cli \
  php${PHP_VERSION}-curl \
  php${PHP_VERSION}-dev \
  php${PHP_VERSION}-gd \
  php${PHP_VERSION}-imap \
  php${PHP_VERSION}-intl \
  php${PHP_VERSION}-ldap \
  php${PHP_VERSION}-mbstring \
  php${PHP_VERSION}-memcached \
  php${PHP_VERSION}-mysql \
  php${PHP_VERSION}-pgsql \
  php${PHP_VERSION}-readline \
  php${PHP_VERSION}-soap \
  php${PHP_VERSION}-sqlite3 \
  php${PHP_VERSION}-xml \
  php${PHP_VERSION}-zip

RUN update-alternatives --set php /usr/bin/php${PHP_VERSION}; \
  update-alternatives --set php-config /usr/bin/php-config${PHP_VERSION}; \
  update-alternatives --set phpize /usr/bin/phpize${PHP_VERSION}

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php; \
  mv composer.phar /usr/local/bin/composer
RUN printf "\nPATH=\"/home/homestead/.composer/vendor/bin:\$PATH\"\n" | tee -a /home/homestead/.profile

# PHP configuration
# Customize PHP CLI configuration
RUN sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/${PHP_VERSION}/cli/php.ini; \
  sed -i "s/display_errors = .*/display_errors = On/" /etc/php/${PHP_VERSION}/cli/php.ini; \
  sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/${PHP_VERSION}/cli/php.ini; \
  sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/${PHP_VERSION}/cli/php.ini

# Install Nginx & PHP-FPM
RUN apt-get install -y \
  --allow-change-held-packages \
  --allow-downgrades \
  --allow-remove-essential \
  nginx \
  php${PHP_VERSION}-fpm

RUN rm /etc/nginx/sites-enabled/default; \
  rm /etc/nginx/sites-available/default

# Customize PHP-FPM configuration
RUN echo "xdebug.remote_enable = 1" >> /etc/php/${PHP_VERSION}/mods-available/xdebug.ini; \
  echo "xdebug.remote_connect_back = 1" >> /etc/php/${PHP_VERSION}/mods-available/xdebug.ini; \
  echo "xdebug.remote_port = 9000" >> /etc/php/${PHP_VERSION}/mods-available/xdebug.ini; \
  echo "xdebug.max_nesting_level = 512" >> /etc/php/${PHP_VERSION}/mods-available/xdebug.ini; \
  echo "opcache.revalidate_freq = 0" >> /etc/php/${PHP_VERSION}/mods-available/opcache.ini

RUN sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/${PHP_VERSION}/fpm/php.ini; \
  sed -i "s/display_errors = .*/display_errors = On/" /etc/php/${PHP_VERSION}/fpm/php.ini; \
  sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/${PHP_VERSION}/fpm/php.ini; \
  sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/${PHP_VERSION}/fpm/php.ini; \
  sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" /etc/php/${PHP_VERSION}/fpm/php.ini; \
  sed -i "s/post_max_size = .*/post_max_size = 100M/" /etc/php/${PHP_VERSION}/fpm/php.ini; \
  sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/${PHP_VERSION}/fpm/php.ini

RUN printf "[openssl]\n" | tee -a /etc/php/${PHP_VERSION}/fpm/php.ini; \
  printf "openssl.cainfo = /etc/ssl/certs/ca-certificates.crt\n" | tee -a /etc/php/${PHP_VERSION}/fpm/php.ini

RUN printf "[curl]\n" | tee -a /etc/php/${PHP_VERSION}/fpm/php.ini; \
  printf "curl.cainfo = /etc/ssl/certs/ca-certificates.crt\n" | tee -a /etc/php/${PHP_VERSION}/fpm/php.ini

# Disable XDebug on the CLI
RUN phpdismod -s cli xdebug

# Customize Nginx & PHP-FPM to configured user
RUN sed -i "s/user www-data;/user homestead;/" /etc/nginx/nginx.conf; \
  sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/" /etc/nginx/nginx.conf; \
  sed -i "s/user = www-data/user = homestead/" /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf; \
  sed -i "s/group = www-data/group = homestead/" /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf

# Add homestead user to required groups
RUN usermod -aG sudo homestead; usermod -aG www-data homestead

# Installing Node related packages using NVM
RUN mkdir -p $NVM_DIR; curl -o- https://raw.githubusercontent.com/creationix/nvm/v${NVM_VERSION}/install.sh | bash
RUN . $NVM_DIR/nvm.sh; \
  nvm install $NODE_VERSION; \
  nvm alias default $NODE_VERSION; \
  nvm use default

# Install additional utilities
RUN apt install -y \
  xvfb \
  imagemagick \
  x11-apps

# Install wp-cli
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar; \
  chmod +x wp-cli.phar; \
  mv wp-cli.phar /usr/local/bin/wp

# Copy configuration files
COPY serve.sh /serve.sh
COPY nginx.default.conf /etc/nginx/sites-enabled/default.conf
COPY supervisor.conf /etc/supervisor/conf.d/supervisor.conf

# Clean up
RUN apt autoremove -y; \
  apt clean -y

# Ensuring permissions are OK
RUN mkdir -p /run/php
RUN chown -R homestead:homestead /home/homestead

EXPOSE 80 443 22

CMD [ "/usr/bin/supervisord" ]
