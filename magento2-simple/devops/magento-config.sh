#!/bin/bash

APP_DIR=$1

cd $APP_DIR
CONFIGPARSER=$APP_DIR/devops/configuration/parseconfig.php

# Initialize Variables
export MAGE_CONTAINER_ROLE=${MAGE_CONTAINER_ROLE:-'process'}
export REDIS_MAGENTO_CACHE_PORT=${REDIS_MAGENTO_CACHE_PORT:-'6379'}
export REDIS_MAGENTO_FPC_PORT=${REDIS_MAGENTO_FPC_PORT:-'6379'}
export REDIS_MAGENTO_SESSIONS_PORT=${REDIS_MAGENTO_SESSIONS_PORT:-'6379'}
export REDIS_MAGENTO_CACHE_DB=${REDIS_MAGENTO_CACHE_DB:-'0'}
export REDIS_MAGENTO_FPC_DB=${REDIS_MAGENTO_FPC_DB:-'1'}
export REDIS_MAGENTO_SESSIONS_DB=${REDIS_MAGENTO_SESSIONS_DB:-'2'}

LOCAL_ENV_PATH=app/etc/env.php
PROCESS_ENV_PATH=pub/static/process/env.php
LOCAL_CONFIG_PATH=app/etc/config.php
PROCESS_CONFIG_PATH=pub/static/process/config.php

function parseconfigenvvars {
    php $CONFIGPARSER
}

function configure {
    echo " - - Running Command: magento-config.sh /app configure"

    export MAGE_PROCESS_RUNNER=0

    adjustwebserver
    webserveroff
    cronoff
    mapdomains
    disabledebug
    checkrequiredresources
    setinstallstatus
    setinstallpermissions
    su www-data -c "magento-config.sh $APP_DIR installandupgrade"
    setruntimepermissions
    cronrunner
    enabledebug
    postfix
    installnewrelicapm
    service php-fpm restart
    mapdomains_vhost
    webserveron
    echo " - - Config Ended"
}

function installandupgrade {
    echo " - - Running Command: magento-config.sh /app installandupgrade as web user"

    mainton
    composerinstall

    if [ "${MAGE_PROCESS_RUNNER}" -eq 1 ]
        then
            installmagento
            envconfig > $LOCAL_ENV_PATH
            parseconfigenvvars
            backupdb
            upgrade
            cleancache
            version
            uploadbuildcache
        else
            envconfig > $LOCAL_ENV_PATH
            rm -rf $APP_DIR/var/cache/ $APP_DIR/generated/
            version
    fi

    maintoff
}

function webserveroff {
    service apache stop
}

function webserveron {
    service apache start
}

function archivebuildcache {
    tar -czf build-cache-vendor.tar.gz vendor composer.json composer.lock
    mv build-cache-vendor.tar.gz build-cache/
}

function checkrequiredresources {

    echo " - - Checking required resources (redis connectivity, mysql connectivity, etc...)"

    set +e

    # Check for Redis Connections
    if [ -n "${REDIS_MAGENTO_SESSIONS_HOST}" ]
        then
        REDIS_SESSIONS_CAN_CONNECT=0
        REDIS_SESSION_TRIES=0
        while [ $REDIS_SESSIONS_CAN_CONNECT -eq 0 ] && [ $REDIS_SESSION_TRIES -lt 12 ]
        do
            REDIS_CONNECT_STATUS=$(echo "INFO" && echo "QUIT" | nc ${REDIS_MAGENTO_SESSIONS_HOST} ${REDIS_MAGENTO_SESSIONS_PORT})
            if [ $? -eq 0 ]
                then
                    echo " - - REDIS_SESSIONS_CAN_CONNECT=1"
                    REDIS_SESSIONS_CAN_CONNECT=1
                else
                    sleep 5
                    REDIS_SESSION_TRIES=$((REDIS_SESSION_TRIES+1))
            fi
        done

        if [ $REDIS_SESSIONS_CAN_CONNECT -eq 0 ]
            then
            echo " !!! ERROR: Cannot connect to required service: REDIS SESSIONS"
            exit
        fi
    fi

    # Check for Redis Connections
    if [ -n "${REDIS_MAGENTO_CACHE_HOST}" ]
        then
        REDIS_CACHE_CAN_CONNECT=0
        REDIS_CACHE_TRIES=0
        while [ $REDIS_CACHE_CAN_CONNECT -eq 0 ] && [ $REDIS_CACHE_TRIES -lt 12 ]
        do
            REDIS_CONNECT_STATUS=$(echo "INFO" && echo "QUIT" | nc ${REDIS_MAGENTO_CACHE_HOST} ${REDIS_MAGENTO_CACHE_PORT})
            if [ $? -eq 0 ]
                then
                    echo " - - REDIS_CACHE_CAN_CONNECT=1"
                    REDIS_CACHE_CAN_CONNECT=1
                else
                    sleep 5
                    REDIS_CACHE_TRIES=$((REDIS_CACHE_TRIES+1))
            fi
        done

        if [ $REDIS_CACHE_CAN_CONNECT -eq 0 ]
            then
            echo " !!! ERROR: Cannot connect to required service: REDIS CACHE"
            exit
        fi
    fi

    # Check for Redis Connections
    if [ -n "${REDIS_MAGENTO_FPC_HOST}" ]
        then
        REDIS_FPC_CAN_CONNECT=0
        REDIS_FPC_TRIES=0
        while [ $REDIS_FPC_CAN_CONNECT -eq 0 ] && [ $REDIS_FPC_TRIES -lt 12 ]
        do
            REDIS_CONNECT_STATUS=$(echo "INFO" && echo "QUIT" | nc ${REDIS_MAGENTO_FPC_HOST} ${REDIS_MAGENTO_FPC_PORT})
            if [ $? -eq 0 ]
                then
                    echo " - - REDIS_FPC_CAN_CONNECT=1"
                    REDIS_FPC_CAN_CONNECT=1
                else
                    sleep 5
                    REDIS_FPC_TRIES=$((REDIS_FPC_TRIES+1))
            fi
        done

        if [ $REDIS_FPC_CAN_CONNECT -eq 0 ]
            then
            echo " !!! ERROR: Cannot connect to required service: REDIS FPC"
            exit
        fi
    fi

    # Check for MySQL connection
    MYSQL_CAN_CONNECT=0
    MYSQL_TRIES=0
    while [ $MYSQL_CAN_CONNECT -eq 0 ] && [ $MYSQL_TRIES -lt 12 ]
    do
        MAGENTO_CONNECT_STATUS=$(mysql -h "${MAGENTO_DB_HOST}" -u "${MAGENTO_DB_USER}" -p"${MAGENTO_DB_PASSWORD}" -e "SHOW schemas;" -s --skip-column-names)
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

    # Read version files from the static directory
    STATIC_DEPLOY_VERSION=$(cat pub/static/deployed_version.txt)
    STATIC_PROCESS_VERSION=$(cat pub/static/process/deployed_version.txt)
    CODE_PROCESS_VERSION=$(cat pub/static/process/code-version)
    CODE_WEB_VERSION=$(cat version)


    if [ "${MAGE_CONTAINER_ROLE}" == "process" ] && [[ "$CODE_PROCESS_VERSION" != "$CODE_WEB_VERSION" || "$STATIC_DEPLOY_VERSION" != "$STATIC_PROCESS_VERSION" ]]
       then

        export MAGE_PROCESS_RUNNER=1

        # Clear the process version
        rm pub/static/process/deployed_version.txt
        rm pub/static/process/code-version
    fi

    if [ "${MAGE_PROCESS_RUNNER}" -eq 0 ]
        then
        # Check to make sure that the process container has run before me...

        # Check for new version of static assets created by process container
        STATIC_DEPLOY_TRIES=0
        STATIC_CONTENT_VERIFIED=0
        while [ $STATIC_CONTENT_VERIFIED -eq 0 ] && [ $STATIC_DEPLOY_TRIES -lt 300 ]
        do
            STATIC_DEPLOY_TRIES=$((STATIC_DEPLOY_TRIES+1))

            downloadbuildcache

            # Read version files from the static directory
            STATIC_DEPLOY_VERSION=$(cat pub/static/deployed_version.txt)
            STATIC_PROCESS_VERSION=$(cat pub/static/process/deployed_version.txt)
            CODE_PROCESS_VERSION=$(cat pub/static/process/code-version)

            if [ "$STATIC_DEPLOY_VERSION" == "$STATIC_PROCESS_VERSION" ] && [ "$CODE_PROCESS_VERSION" == "$CODE_WEB_VERSION" ]
                then
                    echo " - - STATIC_CONTENT_VERIFIED..."
                    if [ $STATIC_DEPLOY_TRIES -gt 1 ]
                        then
                        echo " - - STATIC_CONTENT_VERIFIED=1"
                        STATIC_CONTENT_VERIFIED=1
                    fi
                else
                    echo " - - Deploy version: $STATIC_DEPLOY_VERSION"
                    echo " - - Process version: $STATIC_PROCESS_VERSION"
                    echo " - - Code process version: $CODE_PROCESS_VERSION"
                    echo " - - Code web version:     $CODE_WEB_VERSION"
                    sleep 05
            fi
        done

        if [ $STATIC_CONTENT_VERIFIED -eq 0 ]
            then
            echo " !!! ERROR: Cannot verify that the static content has been deployed by the process container"
            exit
        fi

    fi 

    set -e

}

function cronrunner {
    if [ -n "${CRON_RUNNER}" ]
        then
        echo "Setting as Cron Runner"
        cp devops/web/cron/magento /etc/cron.d/magento
    else
        cronoff
    fi
}

function cronoff {
    # Remove Magento Cron Task Definition
    if [ -e /etc/cron.d/magento ]
        then
        echo "Turning off Magento cron"
        rm /etc/cron.d/magento
    fi
}

function mainton {
    # Put up maintenance page
    touch var/.maintenance.flag

    if [ -n "${MAGE_FORCE_MAINTENANCE}" ]
        then
        echo "!!! !!! Exiting config process because we are in Forced Maintenance Mode !!! !!!"
        exit
    fi
}

function maintoff {
    # Put up maintenance page
    if [ -e var/.maintenance.flag ]
        then
        rm var/.maintenance.flag
    fi
}

function version {
    # Make version public
    if [ -e version ]
        then
        cp version pub/version

        if [ "${MAGE_PROCESS_RUNNER}" -eq 1 ]
            then
            mkdir -p pub/static/process
            cp version pub/static/process/code-version
        fi

    fi
}

function backupdb {
    if [ -n "${PREDEPLOY_BACKUP}" ]
        then
        BACKUP_FILENAME="pre-$(cat version)"
        n98-magerun2.phar db:dump -c gz $BACKUP_FILENAME
        aws s3 mv $BACKUP_FILENAME.sql.gz s3://$BACKUP_S3BUCKET/predeploy_backups/
    fi
}

function adjustwebserver {
    if [ -n "${POSTFIX_FROM_ADDRESS}" ]
        then
        echo "php_admin_value[sendmail_path] = /usr/sbin/sendmail -t -i -f ${POSTFIX_FROM_ADDRESS}" >> /etc/php/7.1/fpm/pool.d/www.conf
    fi
    service php-fpm restart
}

function disabledebug {
    phpdismod xdebug
    service php-fpm restart
}

function enabledebug {
    if [ -n "${XDEBUG_CONFIG}" ]
        then
        phpenmod xdebug
    else
        phpdismod xdebug
    fi
    service php-fpm restart
}

function composerinstall {
    echo " - - Composer Install"
    mkdir -p ~/.composer/
    if [ -n "${MAGENTO_REPO_PUBLIC}" ] && [ -n "${MAGENTO_REPO_PRIVATE}" ]
        then
        composer config --global --auth http-basic.repo.magento.com "${MAGENTO_REPO_PUBLIC}" "${MAGENTO_REPO_PRIVATE}"
    fi
    if [ -n "${PACKAGIST_USERNAME}" ] && [ -n "${PACKAGIST_TOKEN}" ]
        then
        composer config --global --auth http-basic.repo.packagist.com "${PACKAGIST_USERNAME}" "${PACKAGIST_TOKEN}"
    fi
    composer install --prefer-dist -o
    echo " - - Composer Install Finish"
}

function setinstallpermissions {
    set -x
    if [ "${MAGENTO_INSTALL_STATUS}" != "complete" ] 
        then
        echo " - - Setting Install Permissions"
        chmod -R a+wX app/etc
        chmod -R a+wX var/log
        chown -R www-data:www-data var/log
        chmod a+wX var
        chmod a+wX pub/media
        chmod a+wX pub/static
    fi
    set +x
}

function setruntimepermissions {
    set -x
    if [ "${MAGE_PROCESS_RUNNER}" -eq 1 ]
        then
        echo " - - Setting Runtime Permissions"
        chmod -R g-w app/etc
        chmod -R o-w app/etc
        chmod g-w pub/media
        chmod g-w pub/static
        chmod o-w pub/media
        chmod o-w pub/static
        echo " - - Setting Post-static-deploy Permissions"
        chown -R www-data:www-data pub/static
        chown -R www-data:www-data var/log
        chown www-data:www-data pub/media
    fi

    set +x
}

function upgrade {
    echo " - - Running Magento Upgrade"

    php bin/magento cache:flush

    php bin/magento setup:upgrade

    envconfig > $LOCAL_ENV_PATH

    if [ "${MAGE_MODE}" == "production" ]
        then
        php bin/magento setup:static-content:deploy en_US

        # Store the process version
        mkdir -p pub/static/process
        cp pub/static/deployed_version.txt pub/static/process/deployed_version.txt

        # Copy out the config files for distribution
        cp $LOCAL_CONFIG_PATH $PROCESS_CONFIG_PATH

    fi
}

function uploadbuildcache {
    CODE_WEB_VERSION=$(cat version)
    if [ -n "${BUILD_CACHE_BUCKET}" ] && [ "${MAGE_PROCESS_RUNNER}" -eq 1 ]
        then
        tar -czf "build-cache-$CODE_WEB_VERSION.tar.gz" pub/static
        aws s3 cp "build-cache-$CODE_WEB_VERSION.tar.gz" "s3://${BUILD_CACHE_BUCKET}/${BUILD_CACHE_PATH}/"
    fi
}

function downloadbuildcache {
    CODE_WEB_VERSION=$(cat version)
    if [ -n "${BUILD_CACHE_BUCKET}" ] 
        then
            if [ ! -e "build-cache-$CODE_WEB_VERSION.tar.gz" ] 
                then
                aws s3 cp "s3://${BUILD_CACHE_BUCKET}/${BUILD_CACHE_PATH}/build-cache-$CODE_WEB_VERSION.tar.gz" .
            fi
        tar -xzf "build-cache-$CODE_WEB_VERSION.tar.gz"
    fi
}

function cleancache {
    echo " - - Clearing Cache"
    php bin/magento cache:clean
    php bin/magento cache:flush
}

function setinstallstatus {

    INSTALLED_SQL="SELECT value FROM core_config_data WHERE path = 'system/status/install'"

    set +e 

    echo "Checking Install Status: "
    export MAGENTO_INSTALL_STATUS=$(mysql -h "${MAGENTO_DB_HOST}" -u "${MAGENTO_DB_USER}" -p"${MAGENTO_DB_PASSWORD}" "${MAGENTO_DB_NAME}" -e "$INSTALLED_SQL" -s --skip-column-names)
    echo "Install Status: ${MAGENTO_INSTALL_STATUS}"

    set -e

} 
function installmagento {
    ###############################################
    ## Install MAGENTO from environment variables
    echo " - - Install Status: ${MAGENTO_INSTALL_STATUS}"
    if [ "${MAGENTO_INSTALL_STATUS}" != "complete" ] && [ -n "${MAGENTO_ADMIN_USER}" ] && [ -n "${MAGENTO_ADMIN_PASSWORD}" ]
        then
        echo " - - Installing Magento via CLI...."

        rm -f $LOCAL_ENV_PATH
        mysql -h "${MAGENTO_DB_HOST}" -u "${MAGENTO_DB_USER}" -p"${MAGENTO_DB_PASSWORD}" "${MAGENTO_DB_NAME}" -e "CREATE DATABASE IF NOT EXISTS ${MAGENTO_DB_NAME};"
        php bin/magento setup:install --base-url="${MAGENTO_BASE_URL}" \
            --db-host="${MAGENTO_DB_HOST}" --db-name="${MAGENTO_DB_NAME}" --db-user="${MAGENTO_DB_USER}" \
            --db-password="${MAGENTO_DB_PASSWORD}" --admin-firstname="${MAGENTO_ADMIN_FIRSTNAME}" \
            --admin-lastname="${MAGENTO_ADMIN_LASTNAME}" --admin-email="${MAGENTO_ADMIN_EMAIL}" \
            --admin-user="${MAGENTO_ADMIN_USER}" --admin-password="${MAGENTO_ADMIN_PASSWORD}" --language=en_US \
            --currency=USD --timezone=America/Los_Angeles --use-rewrites=1 --key="${MAGENTO_CRYPT_KEY}" \
            --backend-frontname="${MAGENTO_BACKEND_PATH}"

        echo "Updating the DB with Install Status"
        INSTALLED_SQL_INSERT="INSERT INTO core_config_data (scope, scope_id, path, value) VALUES ('default', '0', 'system/status/install', 'complete')"
        mysql -h "${MAGENTO_DB_HOST}" -u "${MAGENTO_DB_USER}" -p"${MAGENTO_DB_PASSWORD}" "${MAGENTO_DB_NAME}" -e "$INSTALLED_SQL_INSERT"

        else
        echo " - - Magento Already Marked Install Status: Complete"

    fi

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

function redisconfig {
    if [ -n "${REDIS_MAGENTO_CACHE_HOST}" ] && [ -n "${REDIS_MAGENTO_FPC_HOST}" ]
    then
        cat <<REDISCONFIGFILE
    'cache' => [
        'frontend' => [
            'default' => [
                'backend' => 'Cm_Cache_Backend_Redis',
                'backend_options' => [
                    'server' => '${REDIS_MAGENTO_CACHE_HOST}',
                    'database' => '${REDIS_MAGENTO_CACHE_DB}',
                    'port' => '${REDIS_MAGENTO_CACHE_PORT}'
                ]
            ],
            'page_cache' => [
                'backend' => 'Cm_Cache_Backend_Redis',
                'backend_options' => [
                    'server' => '${REDIS_MAGENTO_FPC_HOST}',
                    'port' => '${REDIS_MAGENTO_FPC_PORT}',
                    'database' => '${REDIS_MAGENTO_FPC_DB}',
                    'compress_data' => '0'
                ]
            ]
        ]
    ],
REDISCONFIGFILE
    else
        echo ''
    fi
}

function sessionconfig {
    if [ -n "${REDIS_MAGENTO_SESSIONS_HOST}" ]
    then
        cat <<REDISCONFIGFILE
    'session' => [
        'save' => 'redis',
        'redis' => [
            'host' => '${REDIS_MAGENTO_SESSIONS_HOST}',
            'port' => '${REDIS_MAGENTO_SESSIONS_PORT}',
            'password' => '',
            'timeout' => '2.5',
            'persistent_identifier' => '',
            'database' => '${REDIS_MAGENTO_SESSIONS_DB}',
            'compression_threshold' => '2048',
            'compression_library' => 'gzip',
            'log_level' => '1',
            'max_concurrency' => '24',
            'break_after_frontend' => '5',
            'break_after_adminhtml' => '30',
            'first_lifetime' => '600',
            'bot_first_lifetime' => '60',
            'bot_lifetime' => '7200',
            'disable_locking' => '0',
            'min_lifetime' => '60',
            'max_lifetime' => '2592000'
        ]
    ],
REDISCONFIGFILE
    else
        cat <<REDISCONFIGFILE
    'session' => [
        'save' => '${MAGENTO_SESSION_SAVE}',
    ],
REDISCONFIGFILE
    fi
}


function envconfig {

    REDIS_CONFIG=$(redisconfig)
    SESSION_CONFIG=$(sessionconfig)
    MCOM_CONFIG=$(mcomconfig)

    cat <<CONFIGFILE
<?php
return [
    'backend' => [
        'frontName' => '${MAGENTO_BACKEND_PATH}',
    ],
    'queue' => [
        'amqp' => [
            'host' => '',
            'port' => '',
            'user' => '',
            'password' => '',
            'virtualhost' => '/',
            'ssl' => ''
        ]
    ],
    'db' => [
        'connection' => [
            'indexer' => [
                'host' => '${MAGENTO_DB_HOST}',
                'dbname' => '${MAGENTO_DB_NAME}',
                'username' => '${MAGENTO_DB_USER}',
                'password' => '${MAGENTO_DB_PASSWORD}',
                'model' => 'mysql4',
                'engine' => 'innodb',
                'initStatements' => 'SET NAMES utf8;',
                'active' => '1',
                'persistent' => NULL
            ],
            'default' => [
                'host' => '${MAGENTO_DB_HOST}',
                'dbname' => '${MAGENTO_DB_NAME}',
                'username' => '${MAGENTO_DB_USER}',
                'password' => '${MAGENTO_DB_PASSWORD}',
                'model' => 'mysql4',
                'engine' => 'innodb',
                'initStatements' => 'SET NAMES utf8;',
                'active' => '1'
            ]
        ],
        'table_prefix' => ''
    ],
    'crypt' => [
        'key' => '${MAGENTO_CRYPT_KEY}',
    ],
    'resource' => [
        'default_setup' => [
            'connection' => 'default'
        ]
    ],
    'x-frame-options' => 'SAMEORIGIN',
    'MAGE_MODE' => '${MAGE_MODE}',
    'cache_types' => [
        'config' => 1,
        'layout' => 1,
        'block_html' => 1,
        'collections' => 1,
        'reflection' => 1,
        'db_ddl' => 1,
        'eav' => 1,
        'customer_notification' => 1,
        'target_rule' => 1,
        'full_page' => 1,
        'config_integration' => 1,
        'config_integration_api' => 1,
        'translate' => 1,
        'config_webservice' => 1
    ],
    'install' => [
        'date' => 'Sat, 01 Jul 2017 00:01:31 +0000'
    ],
    $REDIS_CONFIG
    $SESSION_CONFIG
    $MCOM_CONFIG
];
CONFIGFILE
}

function mapdomains {

    # For this to work, the enviornment must contain a variable that starts with MAGE_VHOST.
    # The value of MAGE_VHOST should be set wth followng format:
    # DOMAIN|MAGE_RUN_CODE|MAGE_RUN_TYPE
    #   DOMAIN = The value for apache Host
    #   MAGE_RUN_CODE - Built in Magento variable and is uniqe to each store/website
    #   MAGE_RUN_TYPE = Built in Magento variable, value can be either "store" or "website"
    # example:
    #   MAGE_VHOST_SITEA="store-a.domain.com|base|store"


    # Parse the enviornment and look for anything that matches $MAGE_VHOST.
    DETECTED_VHOSTS=$(env | grep "MAGE_VHOST")
    for VHOST in ${DETECTED_VHOSTS}
    do
        DOMAIN=$(echo ${VHOST} | cut -d '=' -f2 | cut -d '|' -f1)
        MAGE_RUN_CODE=$(echo ${VHOST} | cut -d '|' -f2)
        MAGE_RUN_TYPE=$(echo ${VHOST} | cut -d '|' -f3)
        
        VHOST_FILE_NAME="/opt/docker/etc/httpd/vhost.common.d/01-boilerplate.conf"

        echo " - - Values of ${VHOST}"
        echo " - - - - DOMAIN: ${DOMAIN}"
        echo " - - - - MAGE_RUN_CODE: ${MAGE_RUN_CODE}"
        echo " - - - - MAGE_RUN_TYPE: ${MAGE_RUN_TYPE}"

        echo "SetEnvIf Host $DOMAIN MAGE_RUN_TYPE=${MAGE_RUN_TYPE}" >> $VHOST_FILE_NAME
        echo "SetEnvIf Host $DOMAIN MAGE_RUN_CODE=${MAGE_RUN_CODE}" >> $VHOST_FILE_NAME

    done

}

function mapdomains_vhost {
  ## Dynamically set the vhosts based on values in the magento database;
  if [ "${MAGENTO_INSTALL_STATUS}" == "complete" ]; then

    VHOST_FILE_NAME="/opt/docker/etc/httpd/vhost.common.d/01-boilerplate.conf"
    MAGE_RUN_TYPE="website"
    mysql -h "${MAGENTO_DB_HOST}" -u "${MAGENTO_DB_USER}" -p"${MAGENTO_DB_PASSWORD}" "${MAGENTO_DB_NAME}" -e "SELECT website_id,code FROM store_website" -s --skip-column-names | while read website_id MAGE_RUN_CODE; do
      if [[ "${MAGE_RUN_CODE}" != "admin" && "${MAGE_RUN_CODE}" != "base" ]]; then
        HTTP_DOMAIN=$(mysql -h "${MAGENTO_DB_HOST}" -u "${MAGENTO_DB_USER}" -p"${MAGENTO_DB_PASSWORD}" "${MAGENTO_DB_NAME}" -e "SELECT value FROM core_config_data WHERE path = 'web/secure/base_url' AND scope_id=${website_id} AND scope='websites'" -s --skip-column-names);
        if [ -z "$HTTP_DOMAIN" ]
          then
            echo " -- No Domain";
          else
            TRAILING_SLASH_DOMAIN="$( echo "$HTTP_DOMAIN" | sed 's/https\?:\/\///')"
            DOMAIN="$( echo "$TRAILING_SLASH_DOMAIN" | sed 's/\///')"
            echo " - - - - DOMAIN: ${DOMAIN}"
            echo " - - - - MAGE_RUN_CODE: ${MAGE_RUN_CODE}"
            echo " - - - - MAGE_RUN_TYPE: ${MAGE_RUN_TYPE}"
            echo "SetEnvIf Host $DOMAIN MAGE_RUN_TYPE=${MAGE_RUN_TYPE}" >> $VHOST_FILE_NAME
            echo "SetEnvIf Host $DOMAIN MAGE_RUN_CODE=${MAGE_RUN_CODE}" >> $VHOST_FILE_NAME
          fi
      fi
    done
  fi
}

function installnewrelicapm {
    
    if [[ ${INSTALL_NEWRELIC_APM} == "true" && -n ${NEWRELIC_LICENSE_KEY} ]]; then
        echo " - - Installing New Relic APM"
        echo newrelic-php5 newrelic-php5/application-name string "${NEWRELIC_APM_NAME}" | debconf-set-selections
        echo newrelic-php5 newrelic-php5/license-key string "${NEWRELIC_LICENSE_KEY}" | debconf-set-selections
        wget -O - https://download.newrelic.com/548C16BF.gpg | apt-key add -
        sh -c 'echo "deb http://apt.newrelic.com/debian/ newrelic non-free" \
        > /etc/apt/sources.list.d/newrelic.list'
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get -y install newrelic-php5
        service php-fpm restart
    else
        echo " - - Bypassing New Relic APM install.  INSTALL_NEWRELIC_APM either unset/not equal to TRUE or NEWRELIC_LICENSE_KEY unset"
    fi
}

function configuremonitoring {
    installnewrelicapm
}

$2
