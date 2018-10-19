FROM ubuntu:18.04

LABEL maintainer="Angel M. Adames <angelmadames@gmail.com"

ENV DEBIAN_FRONTEND noninteractive
ENV NVM_DIR /usr/local/bin/nvm
ENV NODE_VERSION 10.11.0

# Update package list and upgrade available packages
RUN apt update; apt upgrade -y

# Add PPAs and repositories
RUN apt install -y software-properties-common ca-certificates curl; \
  apt-add-repository ppa:nginx/stable -y; \
  apt-add-repository ppa:ondrej/php -y; \
  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -; \
  echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

# Update package list one more time
RUN apt update

# Update package lists & install some basic packages
RUN apt install --fix-missing -y apt-utils bash-completion build-essential cifs-utils curl \
    dos2unix gcc git git-flow graphviz libmcrypt4 libnotify-bin libpcre3-dev \
    libpng-dev mcrypt nano ntp pv python-pip python2.7-dev re2c \
    software-properties-common supervisor unzip vim whois zip zsh yarn

# Configure locale
RUN echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale

# Set my timezone
RUN ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# User configuration
RUN adduser homestead; \
  usermod -p $(echo secret | openssl passwd -1 -stdin) homestead

# PHP installation
RUN apt install --allow-downgrades --allow-remove-essential --allow-change-held-packages -y \
  php-pear php-xdebug php7.1-bcmath php7.1-cli php7.1-curl php7.1-dev \
  php7.1-gd php7.1-imap php7.1-intl php7.1-ldap php7.1-mbstring php7.1-memcached \
  php7.1-mysql php7.1-pgsql php7.1-readline php7.1-soap php7.1-sqlite3 php7.1-xml \
  php7.1-zip

RUN update-alternatives --set php /usr/bin/php7.1; \
  update-alternatives --set php-config /usr/bin/php-config7.1; \
  update-alternatives --set phpize /usr/bin/phpize7.1

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php; \
  mv composer.phar /usr/local/bin/composer
RUN printf "\nPATH=\"/home/homestead/.composer/vendor/bin:\$PATH\"\n" | tee -a /home/homestead/.profile

# PHP configuration
# Customize PHP CLI configuration
RUN sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.1/cli/php.ini; \
  sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.1/cli/php.ini; \
  sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.1/cli/php.ini; \
  sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.1/cli/php.ini

# Install Nginx & PHP-FPM
RUN apt-get install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages \
  nginx php7.1-fpm

RUN rm /etc/nginx/sites-enabled/default; \
  rm /etc/nginx/sites-available/default

# Customize PHP-FPM configuration
RUN echo "xdebug.remote_enable = 1" >> /etc/php/7.1/mods-available/xdebug.ini; \
  echo "xdebug.remote_connect_back = 1" >> /etc/php/7.1/mods-available/xdebug.ini; \
  echo "xdebug.remote_port = 9000" >> /etc/php/7.1/mods-available/xdebug.ini; \
  echo "xdebug.max_nesting_level = 512" >> /etc/php/7.1/mods-available/xdebug.ini; \
  echo "opcache.revalidate_freq = 0" >> /etc/php/7.1/mods-available/opcache.ini

RUN sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.1/fpm/php.ini; \
  sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.1/fpm/php.ini; \
  sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.1/fpm/php.ini; \
  sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.1/fpm/php.ini; \
  sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" /etc/php/7.1/fpm/php.ini; \
  sed -i "s/post_max_size = .*/post_max_size = 100M/" /etc/php/7.1/fpm/php.ini; \
  sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.1/fpm/php.ini

RUN printf "[openssl]\n" | tee -a /etc/php/7.1/fpm/php.ini; \
  printf "openssl.cainfo = /etc/ssl/certs/ca-certificates.crt\n" | tee -a /etc/php/7.1/fpm/php.ini

RUN printf "[curl]\n" | tee -a /etc/php/7.1/fpm/php.ini; \
  printf "curl.cainfo = /etc/ssl/certs/ca-certificates.crt\n" | tee -a /etc/php/7.1/fpm/php.ini

# Disable XDebug on the CLI
RUN phpdismod -s cli xdebug

# Customize Nginx & PHP-FPM to configured user
RUN sed -i "s/user www-data;/user homestead;/" /etc/nginx/nginx.conf; \
  sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/" /etc/nginx/nginx.conf; \
  sed -i "s/user = www-data/user = homestead/" /etc/php/7.1/fpm/pool.d/www.conf; \
  sed -i "s/group = www-data/group = homestead/" /etc/php/7.1/fpm/pool.d/www.conf

# Add homestead user to required groups
RUN usermod -aG sudo homestead; usermod -aG www-data homestead

# Installing Node related packages using NVM
RUN mkdir -p $NVM_DIR; curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash
RUN . $NVM_DIR/nvm.sh; \
  nvm install $NODE_VERSION; \
  nvm alias default $NODE_VERSION; \
  nvm use default

# Install additional utilities
RUN apt install -y chromium-browser xvfb imagemagick x11-apps

# Install wp-cli
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar; \
  chmod +x wp-cli.phar; \
  mv wp-cli.phar /usr/local/bin/wp

# Copy configuration files
COPY serve.sh /serve.sh
COPY nginx.default.conf /etc/nginx/sites-enabled/default.conf
COPY supervisor.conf /etc/supervisor/conf.d/supervisor.conf

# One last upgrade check
RUN apt update; apt upgrade -y

# Clean up
RUN apt autoremove -y; \
  apt clean -y

# Ensuring permissions are OK
RUN mkdir -p /run/php
RUN chown -R homestead:homestead /home/homestead

EXPOSE 80 443 22

CMD [ "/usr/bin/supervisord" ]
