FROM webdevops/php-apache:ubuntu-14.04

RUN apt-get update && apt-get install -y mysql-client nano php5-xdebug

RUN rm -rf /var/lib/apt/lists/*

RUN cd ~ && wget https://files.magerun.net/n98-magerun.phar && \
 chmod +x ./n98-magerun.phar && \
 sudo cp ./n98-magerun.phar /usr/local/bin/

RUN curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip" && \ 
 unzip awscli-bundle.zip && \
 ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws && \
 aws --version && rm awscli-bundle.zip

ENV APPLICATION_PATH=/var/www \
 WEB_DOCUMENT_ROOT=/var/www \
 CRYPT_KEY="" \
 DB_TABLE_PREFIX="" \
 DB_HOST="" \
 DB_USERNAME="" \
 DB_PASSWORD="" \
 DB_NAME="magento" \
 DB_INIT_STATEMENTS="SET NAMES utf8" \
 DB_MODEL="mysql4" \
 DB_TYPE="pdo_mysql" \
 DB_PDO_TYPE="" \
 SESSION_SAVE="files" \
 BASE_URL="" \
 SECURE_URL="" \
 ADMIN_USER_FIRST="" \
 ADMIN_USER_LAST="" \
 ADMIN_USER_EMAIL="" \
 ADMIN_USER_USERNAME="" \
 ADMIN_USER_PASSWORD="" \
 ADMIN_FRONT_NAME="admin"


# Add Cron to Supervisord
COPY devops/cron.conf /opt/docker/etc/supervisor.d/cron.conf
COPY devops/magento.cron /etc/cron.d/magento
RUN chmod 644 /etc/cron.d/magento

# Add Config to Supervisord
COPY devops/magento-config.conf /opt/docker/etc/supervisor.d/magento-config.conf
COPY devops/magento-config.sh /usr/local/bin/
# Add for Windows compatibility
RUN tr -d '\015' </usr/local/bin/magento-config.sh >/usr/local/bin/magento-config.sh
RUN chmod +x /usr/local/bin/magento-config.sh

ADD . /var/www

WORKDIR /var/www

RUN mkdir -p /var/www/var/log/

RUN mkdir -p /var/www/media
RUN chmod 777 /var/www/media
