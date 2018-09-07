FROM webdevops/php-apache:centos-7-php7

RUN yum remove -y \
	php70w-bcmath \
	php70w-cli \
	php70w-common \
	php70w-fpm \
	php70w-gd \
	php70w-intl \
	php70w-ldap \
	php70w-mbstring \
	php70w-mcrypt \
	php70w-mysqlnd \
	php70w-opcache \
	php70w-pdo \
	php70w-pear \
	php70w-pecl-apcu \
	php70w-pecl-igbinary \
	php70w-pecl-imagick \
	php70w-pecl-memcached \
	php70w-process \
	php70w-soap \
	php70w-xml \
	php70w-xmlrpc

RUN yum remove webtatic-release -y

RUN rpm -Uvh http://rpms.remirepo.net/enterprise/remi-release-7.rpm

RUN curl --silent --location https://rpm.nodesource.com/setup_6.x | bash -

RUN curl --silent --location https://dl.yarnpkg.com/rpm/yarn.repo | tee /etc/yum.repos.d/yarn.repo

RUN yum -y install yum-utils yarn

#RUN yum update

RUN yum-config-manager --enable remi-php71

RUN yum install -y php \
	php-opcache \
	php-bcmath \
	php-cli \
	php-common \
	php-fpm \
	php-gd \
	php-intl \
	php-ldap \
	php-mbstring \
	php-mcrypt \
	php-mysqlnd \
	php-opcache \
	php-pdo \
	php-pear \
	php-pecl-apcu \
	php-pecl-igbinary \
	php-pecl-imagick \
	php-pecl-memcached \
	php-process \
	php-soap \
	php-xml \
	php-xmlrpc \
	php-zip \
	mysql

RUN mkdir -p /run/php-fpm

RUN rm -f /etc/php.d/redis.ini

RUN mkdir -p /home/apache && chown -R apache:apache /home/apache && usermod -s /bin/bash -d /home/apache apache

ADD . /app

RUN chown -R apache:apache /app

WORKDIR /app

COPY devops/ssh/akeneo-ee /home/apache/.ssh/id_rsa
RUN chmod 600 /home/apache/.ssh/id_rsa
COPY devops/ssh/akeneo-ee /root/.ssh/id_rsa
RUN chmod 600 /root/.ssh/id_rsa

# Add Config to Supervisord
COPY devops/akeneo-config.conf /opt/docker/etc/supervisor.d/akeneo-config.conf
COPY devops/akeneo-config.sh /usr/local/bin/
# Add for Windows compatibility
RUN tr -d '\015' </usr/local/bin/akeneo-config.sh >/usr/local/bin/akeneo-config.sh
RUN chmod +x /usr/local/bin/akeneo-config.sh
