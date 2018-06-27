#!/bin/bash


APP_DIR=$1

cd $APP_DIR

# Initialize Variables
export MAGE_CONTAINER_ROLE=${MAGE_CONTAINER_ROLE:-'process'}
LOCAL_ENV_PATH=app/etc/env.php
PROCESS_ENV_PATH=pub/static/process/env.php
LOCAL_CONFIG_PATH=app/etc/config.php
PROCESS_CONFIG_PATH=pub/static/process/config.php

function configure {
    echo " - - Running Command: magento-config.sh /app configure"

    export MAGE_PROCESS_RUNNER=0

    adjustwebserver
    cronoff
    disabledebug
    checkrequiredresources
    setinstallstatus
    setinstallpermissions
    su application -c "magento-config.sh $APP_DIR installandupgrade"
    setruntimepermissions
    cronrunner
    enabledebug
    postfix
    installnewrelicapm
    service php-fpm restart
    echo " - - Config Ended"
}

function installandupgrade {
    echo " - - Running Command: magento-config.sh /app installandupgrade"

    mainton
    composerinstall

    if [ "${MAGE_PROCESS_RUNNER}" -eq 1 ]
        then
            installmagento
            envconfig > $LOCAL_ENV_PATH
            deployruntimeconfig > $LOCAL_CONFIG_PATH
            backupdb
            upgrade
            cleancache
        else
            cp $PROCESS_ENV_PATH $LOCAL_ENV_PATH
            cp $PROCESS_CONFIG_PATH $LOCAL_CONFIG_PATH
    fi

    version
    maintoff
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
        echo "php_admin_value[sendmail_path] = /usr/sbin/sendmail -t -i -f ${POSTFIX_FROM_ADDRESS}" >> /etc/php/7.0/fpm/pool.d/application.conf
    fi
    echo "variables_order=EGPCS" >> /opt/docker/etc/php/php.ini
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
    authjson > ~/.composer/auth.json
    composer install
    echo " - - Composer Install Finish"
}

function setinstallpermissions {
    set -x
    if [ "${MAGENTO_INSTALL_STATUS}" != "complete" ] 
        then
        echo " - - Setting Install Permissions"
        chmod -R a+wX app/etc
        chmod -R a+wX var/log
        chown -R application:application var/log
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
        chown -R application:application pub/static
        chown -R application:application var/log
        chown application:application pub/media
    fi

    set +x
}

function upgrade {
    echo " - - Running Magento Upgrade"

    php bin/magento cache:flush

    php bin/magento setup:upgrade

    if [ "${MAGE_MODE}" == "production" ]
        then
        php bin/magento setup:static-content:deploy en_US

        # Store the process version
        mkdir -p pub/static/process
        cp pub/static/deployed_version.txt pub/static/process/deployed_version.txt

        # Copy out the env and config files for distribution
        cp $LOCAL_CONFIG_PATH $PROCESS_CONFIG_PATH
        cp $LOCAL_ENV_PATH $PROCESS_ENV_PATH

    fi
}

function cleancache {
    echo " - - Clearing Cache"
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

        deployinstallconfig > $LOCAL_CONFIG_PATH

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

function authjson {
  cat <<AUTHJSON
{
   "http-basic": {
      "repo.magento.com": {
         "username": "${MAGENTO_REPO_PUBLIC}",
         "password": "${MAGENTO_REPO_PRIVATE}"
      }
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

function redisconfig {
    if [ -n "${REDIS_MAGENTO_CACHE_HOST}" ] && [ -n "${REDIS_MAGENTO_FPC_HOST}" ]
    then
        cat <<REDISCONFIGFILE
'cache' =>
array(
   'frontend' =>
   array(
      'default' =>
      array(
         'backend' => 'Cm_Cache_Backend_Redis',
         'backend_options' =>
         array(
            'server' => '${REDIS_MAGENTO_CACHE_HOST}',
            'database' => '0',
            'port' => '${REDIS_MAGENTO_CACHE_PORT}'
            ),
    ),
    'page_cache' =>
    array(
      'backend' => 'Cm_Cache_Backend_Redis',
      'backend_options' =>
       array(
         'server' => '${REDIS_MAGENTO_FPC_HOST}',
         'port' => '${REDIS_MAGENTO_FPC_PORT}',
         'database' => '0',
         'compress_data' => '0'
       )
    )
  )
),
REDISCONFIGFILE
    else
        echo ''
    fi
}

function sessionconfig {
    if [ -n "${REDIS_MAGENTO_SESSIONS_HOST}" ]
    then
        cat <<REDISCONFIGFILE
'session' =>
array (
  'save' => 'redis',
  'redis' =>
  array (
    'host' => '${REDIS_MAGENTO_SESSIONS_HOST}',
    'port' => '${REDIS_MAGENTO_SESSIONS_PORT}',
    'password' => '',
    'timeout' => '2.5',
    'persistent_identifier' => '',
    'database' => '0',
    'compression_threshold' => '2048',
    'compression_library' => 'gzip',
    'log_level' => '1',
    'max_concurrency' => '6',
    'break_after_frontend' => '5',
    'break_after_adminhtml' => '30',
    'first_lifetime' => '600',
    'bot_first_lifetime' => '60',
    'bot_lifetime' => '7200',
    'disable_locking' => '0',
    'min_lifetime' => '60',
    'max_lifetime' => '2592000'
  )
),
REDISCONFIGFILE
    else
        cat <<REDISCONFIGFILE
  'session' =>
  array (
    'save' => '${MAGENTO_SESSION_SAVE}',
  ),
REDISCONFIGFILE
    fi
}


function envconfig {

    REDIS_CONFIG=$(redisconfig)
    SESSION_CONFIG=$(sessionconfig)

    cat <<CONFIGFILE
<?php
return array (
  'backend' => 
  array (
    'frontName' => '${MAGENTO_BACKEND_PATH}',
  ),
  'queue' => 
  array (
    'amqp' => 
    array (
      'host' => '',
      'port' => '',
      'user' => '',
      'password' => '',
      'virtualhost' => '/',
      'ssl' => '',
    ),
  ),
  'db' => 
  array (
    'connection' => 
    array (
      'indexer' => 
      array (
        'host' => '${MAGENTO_DB_HOST}',
        'dbname' => '${MAGENTO_DB_NAME}',
        'username' => '${MAGENTO_DB_USER}',
        'password' => '${MAGENTO_DB_PASSWORD}',
        'model' => 'mysql4',
        'engine' => 'innodb',
        'initStatements' => 'SET NAMES utf8;',
        'active' => '1',
        'persistent' => NULL,
      ),
      'default' => 
      array (
        'host' => '${MAGENTO_DB_HOST}',
        'dbname' => '${MAGENTO_DB_NAME}',
        'username' => '${MAGENTO_DB_USER}',
        'password' => '${MAGENTO_DB_PASSWORD}',
        'model' => 'mysql4',
        'engine' => 'innodb',
        'initStatements' => 'SET NAMES utf8;',
        'active' => '1',
      ),
    ),
    'table_prefix' => '',
  ),
  'crypt' => 
  array (
    'key' => '${MAGENTO_CRYPT_KEY}',
  ),
  'resource' =>
  array (
    'default_setup' => 
    array (
      'connection' => 'default',
    ),
  ),
  'x-frame-options' => 'SAMEORIGIN',
  'MAGE_MODE' => '${MAGE_MODE}',
  'cache_types' => 
  array (
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
    'config_webservice' => 1,
  ),
  'install' => 
  array (
    'date' => 'Sat, 01 Jul 2017 00:01:31 +0000',
  ),
  $REDIS_CONFIG
  $SESSION_CONFIG
);
CONFIGFILE
}

function deployinstallconfig {

    cat <<CONFIGFILE
<?php
return array (
  'modules' =>
  array (
    'Magento_Store' => 1,
    'Magento_AdminNotification' => 1,
    'Magento_Directory' => 1,
    'Magento_Theme' => 1,
    'Magento_Eav' => 1,
    'Magento_AdvancedPricingImportExport' => 1,
    'Magento_Rule' => 1,
    'Magento_Customer' => 1,
    'Magento_Backend' => 1,
    'Magento_Amqp' => 1,
    'Magento_Authorization' => 1,
    'Magento_Indexer' => 1,
    'Magento_Cms' => 1,
    'Magento_Backup' => 1,
    'Magento_Catalog' => 1,
    'Magento_Payment' => 1,
    'Magento_AdvancedCatalog' => 1,
    'Magento_MediaStorage' => 1,
    'Magento_CatalogImportExport' => 1,
    'Magento_CatalogImportExportStaging' => 1,
    'Magento_SalesSequence' => 1,
    'Magento_Ui' => 1,
    'Magento_Search' => 1,
    'Magento_Sales' => 1,
    'Magento_Msrp' => 1,
    'Magento_SalesRule' => 1,
    'Magento_Checkout' => 1,
    'Magento_Downloadable' => 1,
    'Magento_GiftCard' => 1,
    'Magento_Staging' => 1,
    'Magento_Widget' => 1,
    'Magento_Vault' => 1,
    'Magento_CheckoutAgreements' => 1,
    'Magento_CheckoutStaging' => 1,
    'Magento_AdvancedCheckout' => 1,
    'Magento_CmsStaging' => 1,
    'Magento_CmsUrlRewrite' => 1,
    'Magento_Config' => 1,
    'Magento_ConfigurableImportExport' => 1,
    'Magento_ConfigurableProduct' => 1,
    'Magento_Wishlist' => 1,
    'Magento_Contact' => 1,
    'Magento_Cookie' => 1,
    'Magento_Cron' => 1,
    'Magento_CurrencySymbol' => 1,
    'Magento_CustomAttributeManagement' => 1,
    'Magento_CustomerBalance' => 1,
    'Magento_CustomerCustomAttributes' => 1,
    'Magento_CustomerFinance' => 1,
    'Magento_CustomerImportExport' => 1,
    'Magento_CatalogRule' => 1,
    'Magento_Cybersource' => 1,
    'Magento_Deploy' => 1,
    'Magento_Developer' => 1,
    'Magento_Dhl' => 1,
    'Magento_AdvancedRule' => 1,
    'Magento_ProductAlert' => 1,
    'Magento_ImportExport' => 1,
    'Magento_Reports' => 1,
    'Magento_Captcha' => 1,
    'Magento_AdvancedSearch' => 1,
    'Magento_Email' => 1,
    'Magento_User' => 1,
    'Magento_Enterprise' => 1,
    'Magento_Eway' => 1,
    'Magento_Fedex' => 1,
    'Magento_TargetRule' => 1,
    'Magento_GiftCardAccount' => 1,
    'Magento_GiftCardImportExport' => 1,
    'Magento_Tax' => 1,
    'Magento_GiftMessage' => 1,
    'Magento_GiftMessageStaging' => 1,
    'Magento_Weee' => 1,
    'Magento_GiftWrapping' => 1,
    'Magento_GiftWrappingStaging' => 1,
    'Magento_GoogleAdwords' => 1,
    'Magento_GoogleAnalytics' => 1,
    'Magento_GoogleOptimizer' => 1,
    'Magento_GoogleOptimizerStaging' => 1,
    'Magento_PageCache' => 1,
    'Magento_GroupedImportExport' => 1,
    'Magento_GroupedProduct' => 1,
    'Magento_GroupedProductStaging' => 1,
    'Magento_DownloadableImportExport' => 1,
    'Magento_AdminGws' => 1,
    'Magento_Security' => 1,
    'Magento_WebsiteRestriction' => 1,
    'Magento_LayeredNavigation' => 1,
    'Magento_LayeredNavigationStaging' => 1,
    'Magento_Logging' => 1,
    'Magento_Marketplace' => 1,
    'Magento_CatalogEvent' => 1,
    'Magento_MessageQueue' => 1,
    'Magento_CatalogRuleConfigurable' => 1,
    'Magento_MsrpStaging' => 1,
    'Magento_MultipleWishlist' => 1,
    'Magento_Multishipping' => 1,
    'Magento_MysqlMq' => 1,
    'Magento_NewRelicReporting' => 1,
    'Magento_Newsletter' => 1,
    'Magento_OfflinePayments' => 1,
    'Magento_OfflineShipping' => 1,
    'Magento_VersionsCms' => 1,
    'Magento_Banner' => 1,
    'Magento_PaymentStaging' => 1,
    'Magento_Paypal' => 1,
    'Magento_Persistent' => 1,
    'Magento_PersistentHistory' => 1,
    'Magento_PricePermissions' => 1,
    'Magento_GiftRegistry' => 1,
    'Magento_ProductVideo' => 1,
    'Magento_CatalogStaging' => 1,
    'Magento_PromotionPermissions' => 1,
    'Magento_Authorizenet' => 1,
    'Magento_Reminder' => 1,
    'Magento_ConfigurableProductStaging' => 1,
    'Magento_RequireJs' => 1,
    'Magento_ResourceConnections' => 1,
    'Magento_Review' => 1,
    'Magento_ReviewStaging' => 1,
    'Magento_Reward' => 1,
    'Magento_Rma' => 1,
    'Magento_RmaStaging' => 1,
    'Magento_Rss' => 1,
    'Magento_AdvancedSalesRule' => 1,
    'Magento_CatalogSearch' => 1,
    'Magento_SalesArchive' => 1,
    'Magento_SalesInventory' => 1,
    'Magento_CustomerSegment' => 1,
    'Magento_SalesRuleStaging' => 1,
    'Magento_BannerCustomerSegment' => 1,
    'Magento_SampleData' => 1,
    'Magento_ScalableCheckout' => 1,
    'Magento_ScalableInventory' => 1,
    'Magento_ScalableOms' => 1,
    'Magento_ScheduledImportExport' => 1,
    'Magento_Elasticsearch' => 1,
    'Magento_SearchStaging' => 1,
    'Magento_Integration' => 1,
    'Magento_SendFriend' => 1,
    'Magento_Shipping' => 1,
    'Magento_Sitemap' => 1,
    'Magento_Solr' => 1,
    'Magento_CatalogInventoryStaging' => 1,
    'Magento_CatalogPermissions' => 1,
    'Magento_Support' => 1,
    'Magento_Swagger' => 1,
    'Magento_Swatches' => 1,
    'Magento_SwatchesLayeredNavigation' => 1,
    'Magento_GiftCardStaging' => 1,
    'Magento_BundleStaging' => 1,
    'Magento_TaxImportExport' => 1,
    'Magento_GoogleTagManager' => 1,
    'Magento_Translation' => 1,
    'Magento_UrlRewrite' => 1,
    'Magento_Ups' => 1,
    'Magento_CatalogUrlRewriteStaging' => 1,
    'Magento_EncryptionKey' => 1,
    'Magento_Usps' => 1,
    'Magento_Variable' => 1,
    'Magento_Braintree' => 1,
    'Magento_Version' => 1,
    'Magento_CatalogRuleStaging' => 1,
    'Magento_VisualMerchandiser' => 1,
    'Magento_Webapi' => 1,
    'Magento_WebapiSecurity' => 1,
    'Magento_Invitation' => 1,
    'Magento_DownloadableStaging' => 1,
    'Magento_WeeeStaging' => 1,
    'Magento_CatalogWidget' => 1,
    'Magento_ProductVideoStaging' => 1,
    'Magento_Worldpay' => 1,
  ),
);
CONFIGFILE
}

function deployruntimeconfig {

    cat <<CONFIGFILE
<?php
return array (
  'modules' =>
  array (
    'Magento_Store' => 1,
    'Magento_AdminNotification' => 1,
    'Magento_Directory' => 1,
    'Magento_Theme' => 1,
    'Magento_Eav' => 1,
    'Magento_AdvancedPricingImportExport' => 1,
    'Magento_Rule' => 1,
    'Magento_Customer' => 1,
    'Magento_Backend' => 1,
    'Magento_Amqp' => 1,
    'Magento_Authorization' => 1,
    'Magento_Indexer' => 1,
    'Magento_Cms' => 1,
    'Magento_Backup' => 1,
    'Magento_Catalog' => 1,
    'Magento_Payment' => 1,
    'Magento_AdvancedCatalog' => 1,
    'Magento_MediaStorage' => 1,
    'Magento_CatalogImportExport' => 1,
    'Magento_CatalogImportExportStaging' => 1,
    'Magento_SalesSequence' => 1,
    'Magento_Ui' => 1,
    'Magento_Search' => 1,
    'Magento_Sales' => 1,
    'Magento_Msrp' => 1,
    'Magento_SalesRule' => 1,
    'Magento_Checkout' => 1,
    'Magento_Downloadable' => 1,
    'Magento_GiftCard' => 1,
    'Magento_Staging' => 1,
    'Magento_Widget' => 1,
    'Magento_Vault' => 1,
    'Magento_CheckoutAgreements' => 1,
    'Magento_CheckoutStaging' => 1,
    'Magento_AdvancedCheckout' => 1,
    'Magento_CmsStaging' => 1,
    'Magento_CmsUrlRewrite' => 1,
    'Magento_Config' => 1,
    'Magento_ConfigurableImportExport' => 1,
    'Magento_ConfigurableProduct' => 1,
    'Magento_Wishlist' => 1,
    'Magento_Contact' => 1,
    'Magento_Cookie' => 1,
    'Magento_Cron' => 1,
    'Magento_CurrencySymbol' => 1,
    'Magento_CustomAttributeManagement' => 1,
    'Magento_CustomerBalance' => 1,
    'Magento_CustomerCustomAttributes' => 1,
    'Magento_CustomerFinance' => 1,
    'Magento_CustomerImportExport' => 1,
    'Magento_CatalogRule' => 1,
    'Magento_Cybersource' => 1,
    'Magento_Deploy' => 1,
    'Magento_Developer' => 1,
    'Magento_Dhl' => 1,
    'Magento_AdvancedRule' => 1,
    'Magento_ProductAlert' => 1,
    'Magento_ImportExport' => 1,
    'Magento_Reports' => 1,
    'Magento_Captcha' => 1,
    'Magento_AdvancedSearch' => 1,
    'Magento_Email' => 1,
    'Magento_User' => 1,
    'Magento_Enterprise' => 1,
    'Magento_Eway' => 1,
    'Magento_Fedex' => 1,
    'Magento_TargetRule' => 1,
    'Magento_GiftCardAccount' => 1,
    'Magento_GiftCardImportExport' => 1,
    'Magento_Tax' => 1,
    'Magento_GiftMessage' => 1,
    'Magento_GiftMessageStaging' => 1,
    'Magento_Weee' => 1,
    'Magento_GiftWrapping' => 1,
    'Magento_GiftWrappingStaging' => 1,
    'Magento_GoogleAdwords' => 1,
    'Magento_GoogleAnalytics' => 1,
    'Magento_GoogleOptimizer' => 1,
    'Magento_GoogleOptimizerStaging' => 1,
    'Magento_PageCache' => 1,
    'Magento_GroupedImportExport' => 1,
    'Magento_GroupedProduct' => 1,
    'Magento_GroupedProductStaging' => 1,
    'Magento_DownloadableImportExport' => 1,
    'Magento_AdminGws' => 1,
    'Magento_Security' => 1,
    'Magento_WebsiteRestriction' => 1,
    'Magento_LayeredNavigation' => 1,
    'Magento_LayeredNavigationStaging' => 1,
    'Magento_Logging' => 1,
    'Magento_Marketplace' => 1,
    'Magento_CatalogEvent' => 1,
    'Magento_MessageQueue' => 1,
    'Magento_CatalogRuleConfigurable' => 1,
    'Magento_MsrpStaging' => 1,
    'Magento_MultipleWishlist' => 1,
    'Magento_Multishipping' => 1,
    'Magento_MysqlMq' => 1,
    'Magento_NewRelicReporting' => 1,
    'Magento_Newsletter' => 1,
    'Magento_OfflinePayments' => 1,
    'Magento_OfflineShipping' => 1,
    'Magento_VersionsCms' => 1,
    'Magento_Banner' => 1,
    'Magento_PaymentStaging' => 1,
    'Magento_Paypal' => 1,
    'Magento_Persistent' => 1,
    'Magento_PersistentHistory' => 1,
    'Magento_PricePermissions' => 1,
    'Magento_GiftRegistry' => 1,
    'Magento_ProductVideo' => 1,
    'Magento_CatalogStaging' => 1,
    'Magento_PromotionPermissions' => 1,
    'Magento_Authorizenet' => 1,
    'Magento_Reminder' => 1,
    'Magento_ConfigurableProductStaging' => 1,
    'Magento_RequireJs' => 1,
    'Magento_ResourceConnections' => 1,
    'Magento_Review' => 1,
    'Magento_ReviewStaging' => 1,
    'Magento_Reward' => 1,
    'Magento_Rma' => 1,
    'Magento_RmaStaging' => 1,
    'Magento_Rss' => 1,
    'Magento_AdvancedSalesRule' => 1,
    'Magento_CatalogSearch' => 1,
    'Magento_SalesArchive' => 1,
    'Magento_SalesInventory' => 1,
    'Magento_CustomerSegment' => 1,
    'Magento_SalesRuleStaging' => 1,
    'Magento_BannerCustomerSegment' => 1,
    'Magento_SampleData' => 1,
    'Magento_ScalableCheckout' => 1,
    'Magento_ScalableInventory' => 1,
    'Magento_ScalableOms' => 1,
    'Magento_ScheduledImportExport' => 1,
    'Magento_Elasticsearch' => 1,
    'Magento_SearchStaging' => 1,
    'Magento_Integration' => 1,
    'Magento_SendFriend' => 1,
    'Magento_Shipping' => 1,
    'Magento_Sitemap' => 1,
    'Magento_Solr' => 1,
    'Magento_CatalogInventoryStaging' => 1,
    'Magento_CatalogPermissions' => 1,
    'Magento_Support' => 1,
    'Magento_Swagger' => 1,
    'Magento_Swatches' => 1,
    'Magento_SwatchesLayeredNavigation' => 1,
    'Magento_GiftCardStaging' => 1,
    'Magento_BundleStaging' => 1,
    'Magento_TaxImportExport' => 1,
    'Magento_GoogleTagManager' => 1,
    'Magento_Translation' => 1,
    'Magento_UrlRewrite' => 1,
    'Magento_Ups' => 1,
    'Magento_CatalogUrlRewriteStaging' => 1,
    'Magento_EncryptionKey' => 1,
    'Magento_Usps' => 1,
    'Magento_Variable' => 1,
    'Magento_Braintree' => 1,
    'Magento_Version' => 1,
    'Magento_CatalogRuleStaging' => 1,
    'Magento_VisualMerchandiser' => 1,
    'Magento_Webapi' => 1,
    'Magento_WebapiSecurity' => 1,
    'Magento_Invitation' => 1,
    'Magento_DownloadableStaging' => 1,
    'Magento_WeeeStaging' => 1,
    'Magento_CatalogWidget' => 1,
    'Magento_ProductVideoStaging' => 1,
    'Magento_Worldpay' => 1,
    'Shopial_Facebook' => 0,
  ),
);
CONFIGFILE
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
