#!/bin/bash

APP_DIR=$1
PIM_PARAMETER_CONFIG=$APP_DIR/app/config/parameters.yml


cd $APP_DIR


function configure {

    echo " - - - Starting Config"

    adjustwebserver
    checkrequiredresources

    su apache -c "akeneo-config.sh $APP_DIR installandupgrade"

    cronrunner
    setupdaemon

    echo "Config Ended"
}

function installandupgrade {
    echo " - - - Install and Upgrade"
    
    envconfig

    composerinstall
    yarn install
    bin/console cache:clear --no-warmup --env=prod
    bin/console pim:installer:assets --symlink --clean --env=prod
    if [ -n "${PIM_FRESH_INSTALL}" ] 
        then
        bin/console pim:install --force --symlink --clean --env=prod
    fi
    yarn run webpack
}

function checkrequiredresources {

    echo " - - - Checking Required Resources"

    set +e

    # Check for MySQL connection
    MYSQL_CAN_CONNECT=0
    MYSQL_TRIES=0
    while [ $MYSQL_CAN_CONNECT -eq 0 ] && [ $MYSQL_TRIES -lt 12 ]
    do
        MYSQL_CONNECT_STATUS=$(mysql -h "${MYSQL_DB_HOST}" -u "${MYSQL_DB_USER}" -p"${MYSQL_DB_PASSWORD}" -e "SHOW schemas;" -s --skip-column-names)
        if [ $? -eq 0 ]
            then
                echo " - - MYSQL_CAN_CONNECT=1"
                MYSQL_CAN_CONNECT=1
            else
                sleep 5
                MYSQL_TRIES=$((MYSQL_TRIES+1))
        fi
    done

    if [ $MYSQL_CAN_CONNECT -eq 0 ]
        then
        echo " !!! ERROR: Cannot connect to required service: MYSQL"
        exit
    fi

    set -e

}

function resetindexes {
    php bin/console akeneo:elasticsearch:reset-indexes --env=prod
    php bin/console pim:product:index --all --env=prod
    php bin/console pim:product-model:index --all --env=prod
}

function cronrunner {
    if [ -n "${CRON_RUNNER}" ] && [ -e devops/akeneo.cron ]
        then
        echo "Setting as Cron Runner"
        cp devops/akeneo.cron /etc/cron.d/akeneo
    else
        cronoff
    fi
}

function setupdaemon {
    if [ -e devops/akeneo-daemon.conf ]
        then
        echo "Setting as Akeneo Daemon"
        cp devops/akeneo-daemon.conf /opt/docker/etc/supervisor.d/akeneo-daemon.conf
        supervisorctl reread
        supervisorctl update
    fi
}

function cronoff {
    # Remove Akeneo Cron Task Definition
    if [ -e /etc/cron.d/akeneo ]
        then
        echo "Turning off Akeneo cron"
        rm /etc/cron.d/akeneo
    fi
}

function version {
    # Make version public
    if [ -e version ]
        then
        cp version web/version

    fi
}

function adjustwebserver {
    if [ -n "${POSTFIX_FROM_ADDRESS}" ]
        then
        echo "php_admin_value[sendmail_path] = /usr/sbin/sendmail -t -i -f ${POSTFIX_FROM_ADDRESS}" >> /etc/php/7.0/fpm/pool.d/application.conf
        service php-fpm restart
    fi
}

function disabledebug {
    phpdismod xdebug
    service php-fpm restart
    service apache restart
}

function enabledebug {
    if [ -n "${XDEBUG_CONFIG}" ]
        then
        phpenmod xdebug
    else
        phpdismod xdebug
    fi
    service php-fpm restart
    service apache restart
}

function composerinstall {
    mkdir -p ~/.composer/
    authjson > ~/.composer/auth.json

    ## Add the SSH Fingerprint to the SSH Known hosts, so that the composer command doesn't crap out.
    ssh-keyscan -p 443 -t rsa,dsa distribution.akeneo.com >> ~/.ssh/known_hosts 

    if [ -n "${PIM_FRESH_INSTALL}" ] 
    then
        composer install --optimize-autoloader --prefer-dist -vvv
    else
        composer install --optimize-autoloader --prefer-dist
    fi
    
}

function setinstallpermissions {
echo " - - - Set Install Permissions"
}

function setruntimepermissions {
echo " - - - Set Runtime Install Permissions"
}

function upgrade {
echo " - - - Upgrade"
}

function cleancache {
echo " - - - Clean Cache"
}

function piminstall {
echo " - - - PIM Install"
}

function authjson {
  cat <<AUTHJSON
{
    "github-oauth": {
        "github.com": "${GITHUB_TOKEN}"
    }
}
AUTHJSON
}

function postfix {

    if [ -n "${POSTFIX_SES_USER}" ] && [ -n "${POSTFIX_SES_PASS}" ]
        then

        cp devops/postfix/main.cf /etc/postfix/main.cf

        cat << POSTFIXMAINFILE >> /etc/postfix/main.cf

relayhost = [${POSTFIX_RELAYURL}]:${POSTFIX_RELAYPORT}
smtp_sasl_auth_enable = yes
smtp_sasl_security_options = noanonymous
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_use_tls = yes
smtp_tls_security_level = encrypt
smtp_sasl_mechanism_filter = login
smtp_tls_note_starttls_offer = yes
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
smtp_generic_maps = hash:/etc/postfix/generic
POSTFIXMAINFILE

        cat << POSTFIXPASSWDFILE > /etc/postfix/sasl_passwd
[${POSTFIX_RELAYURL}]:${POSTFIX_RELAYPORT} ${POSTFIX_SES_USER}:${POSTFIX_SES_PASS}
POSTFIXPASSWDFILE

        cat << POSTFIXGENERICFILE > /etc/postfix/generic
@$(hostname) ${POSTFIX_FROM_ADDRESS}
POSTFIXGENERICFILE

        postmap /etc/postfix/sasl_passwd
        postmap /etc/postfix/generic

        chmod 0600 /etc/postfix/sasl_passwd.db
        rm /etc/postfix/sasl_passwd

        else
        cat << POSTFIXMAINFILE >> /etc/postfix/main.cf

relayhost = [${POSTFIX_RELAYURL}]:${POSTFIX_RELAYPORT}
POSTFIXMAINFILE

    fi

    service postfix restart

}

function envconfig {

    cat << CONFIGFILE > $PIM_PARAMETER_CONFIG
# This file is auto-generated during the composer install
parameters:
    database_driver: pdo_mysql
    database_host: ${MYSQL_DB_HOST}
    database_port: null
    database_name: ${MYSQL_DB_NAME}
    database_user: ${MYSQL_DB_USER}
    database_password: ${MYSQL_DB_PASSWORD}
    locale: en
    secret: ${PIM_SECRET}
    product_index_name: akeneo_pim_product
    product_proposal_index_name: akeneo_pim_product_proposal
    product_model_index_name: akeneo_pim_product_model
    product_and_product_model_index_name: akeneo_pim_product_and_product_model
    index_hosts: 'elastic:changeme@${PIM_ELASTICSEARCH_HOST}: ${PIM_ELASTICSEARCH_PORT}'    
CONFIGFILE
}

function installnewrelicapm {
    
    if [[ ${INSTALL_NEWRELIC_APM} == "true" && -n ${NEWRELIC_LICENSE_KEY} ]]; then
        echo "Installing New Relic APM"
        echo newrelic-php5 newrelic-php5/application-name string "${APPNAME}" | debconf-set-selections
        echo newrelic-php5 newrelic-php5/license-key string "${NEWRELIC_LICENSE_KEY}" | debconf-set-selections
        wget -O - https://download.newrelic.com/548C16BF.gpg | apt-key add -
        sh -c 'echo "deb http://apt.newrelic.com/debian/ newrelic non-free" \
        > /etc/apt/sources.list.d/newrelic.list'
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get -y install newrelic-php5
        service nginx restart
        service php-fpm restart
    else
        echo "Bypassing New Relic APM install.  INSTALL_NEWRELIC_APM either unset/not equal to TRUE or NEWRELIC_LICENSE_KEY unset"
    fi
}


function configuremonitoring {
    installnewrelicapm
}


$2

