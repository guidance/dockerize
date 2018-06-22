FROM webdevops/php-apache:ubuntu-16.04

RUN apt-get update && apt-get install -y debconf-doc libsasl2-modules nano netcat

RUN	DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-client postfix php-xdebug 

RUN rm -rf /var/lib/apt/lists/*

RUN wget https://files.magerun.net/n98-magerun2.phar && \
    cp ./n98-magerun2.phar /usr/local/bin/ && \
    chmod +x /usr/local/bin/n98-magerun2.phar

# Setup Magento Configuration Service
COPY devops/magento-config.sh /usr/local/bin/magento-config.sh
RUN chmod +x /usr/local/bin/magento-config.sh
COPY devops/magento-config.conf /opt/docker/etc/supervisor.d/magento-config.conf

# Setup Postfix
COPY devops/postfix/postfix.conf /opt/docker/etc/supervisor.d/postfix.conf
COPY devops/postfix/main.cf /etc/postfix/main.cf

ENV MAGENTO_SESSION_SAVE=db

# Setup PHP-FPM
RUN echo "pm.max_children = 300" >> /etc/php/7.0/fpm/pool.d/application.conf

RUN echo "alias m2config=\"magento-config.sh /app configure\"" >> /root/.bashrc && \
	echo "alias m2fc=\"su - application -c 'cd /app && php bin/magento cache:flush'\"" >> /root/.bashrc && \
	echo "alias m2su=\"su - application -c 'cd /app && php bin/magento setup:upgrade'\"" >> /root/.bashrc

RUN mkdir -p /app

ADD . /app

WORKDIR /app

RUN mkdir -p /app/var/log

RUN chown -R application:application /app
