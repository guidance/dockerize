FROM webdevops/php-apache:ubuntu-16.04

RUN apt-get update && apt-get install -y debconf-doc libsasl2-modules nano netcat python-software-properties software-properties-common

RUN add-apt-repository -y ppa:ondrej/php
RUN add-apt-repository -y ppa:jonathonf/vim

RUN apt-get update -y

RUN	DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-client postfix php-xdebug 

RUN apt install -y php7.1 libapache2-mod-php7.1 php7.1-common php7.1-mbstring php7.1-xmlrpc php7.1-soap php7.1-gd \
	php7.1-xml php7.1-intl php7.1-mysql php7.1-cli php7.1-mcrypt php7.1-zip php7.1-curl php7.1-bcmath php7.1-fpm

RUN	DEBIAN_FRONTEND=noninteractive apt-get install -y vim

RUN mkdir -p /run/php && rm /usr/local/bin/php-fpm && ln -nfs /usr/sbin/php-fpm7.1 /usr/local/bin/php-fpm

RUN rm -f -- /opt/docker/etc/httpd/conf.d/10-php.conf && \
	echo "variables_order=EGPCS" >> /etc/php/7.1/apache2/conf.d/99-docker.ini && \
	echo "variables_order=EGPCS" >> /etc/php/7.1/cli/conf.d/99-docker.ini

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
RUN echo "pm.max_children = 300" >> /etc/php/7.1/fpm/pool.d/www.conf

RUN echo "alias m2config=\"magento-config.sh /app configure\"" >> /root/.bashrc && \
	echo "alias m2fc=\"su - application -c 'cd /app && php bin/magento cache:flush'\"" >> /root/.bashrc && \
	echo "alias m2su=\"su - application -c 'cd /app && php bin/magento setup:upgrade'\"" >> /root/.bashrc

RUN mkdir -p /app

ADD . /app

WORKDIR /app

RUN mkdir -p /app/var/log 

RUN mkdir -p /home/www-data && chown www-data:www-data /home/www-data && usermod -s /bin/bash -d /home/www-data www-data

RUN chown -R www-data:www-data /app
