#!/bin/bash

set -e

###############################################
## Run MAGENTO SETUP from environment variables
###############################################

MAGENTO_ROOT=/var/www
LOCAL_XML_PATH="$MAGENTO_ROOT/app/etc/local.xml"
TEMPLATE="$LOCAL_XML_PATH.template"

if [ ! -e $MAGENTO_ROOT/index.php ] 
    then
    cp $MAGENTO_ROOT/index.php.sample $MAGENTO_ROOT/index.php
fi

touch $MAGENTO_ROOT/maintenance.flag

if [ -z "${MAGENTO_REDIS_CACHE_PORT}" ]
    then
    export MAGENTO_REDIS_CACHE_PORT="6379"
fi

if [ -z "${MAGENTO_REDIS_PAGE_CACHE_PORT}" ]
    then
    export MAGENTO_REDIS_PAGE_CACHE_PORT="6379"
fi

if [ -z "${MAGENTO_REDIS_SESSION_PORT}" ]
    then
    export MAGENTO_REDIS_SESSION_PORT="6379"
fi

if [ -z "${MAGENTO_REDIS_PAGE_CACHE_ENDPOINT}" ] && [ -n "${MAGENTO_REDIS_CACHE_ENDPOINT}" ]
    then
    export MAGENTO_REDIS_PAGE_CACHE_ENDPOINT=${MAGENTO_REDIS_CACHE_PORT}
fi

if [ -n "${MAGENTO_REDIS_CACHE_ENDPOINT}" ]
    then
    TEMPLATE="$LOCAL_XML_PATH.redis.template"
fi

###############################################
## Install MAGENTO from environment variables
###############################################
INSTALLED_SQL="SELECT value FROM core_config_data WHERE path = 'system/status/install'"
INSTALLED_SQL_CLEAR="DELETE FROM core_config_data WHERE path = 'system/status/install'"
INSTALLED_SQL_INSERT="INSERT INTO core_config_data (scope, scope_id, path, value) VALUES ('default', '0', 'system/status/install', 'complete')"

set +e 
CAN_CONNECT=0
TRIES=0
while [ $CAN_CONNECT -eq 0 ] && [ $TRIES -lt 6 ]
do
    MAGENTO_CONNECT_STATUS=$(mysql -h "${DB_HOST}" -u "${DB_USERNAME}" -p"${DB_PASSWORD}" -e "SHOW schemas;" -s --skip-column-names)
    if [ $? -eq 0 ]
        then
        CAN_CONNECT=1
        else
        sleep 5
        TRIES=$((TRIES+1))
    fi
done
MAGENTO_INSTALL_STATUS=$(mysql -h "${DB_HOST}" -u "${DB_USERNAME}" -p"${DB_PASSWORD}" "${DB_NAME}" -e "$INSTALLED_SQL" -s --skip-column-names)

set -e


if [ "$MAGENTO_INSTALL_STATUS" != "complete" ] && [ -n "${ADMIN_USER_USERNAME}" ] && [ -n "${ADMIN_USER_PASSWORD}" ]
    then
    echo "Installing Magento via CLI...."
    echo "mysql -h ${DB_HOST} -u ${DB_USERNAME} -p'${DB_PASSWORD}' ${DB_NAME}"

    rm -f $LOCAL_XML_PATH
    mysql -h "${DB_HOST}" -u "${DB_USERNAME}" -p"${DB_PASSWORD}" "${DB_NAME}" -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
    php "$MAGENTO_ROOT/install.php" -- --license_agreement_accepted "yes" --locale "en_US" --timezone "America/Los_Angeles" \
        --default_currency "USD" --db_host "${DB_HOST}" --db_name "${DB_NAME}" --db_user "${DB_USERNAME}" \
        --db_pass "${DB_PASSWORD}" --db_prefix "" --session_save "${SESSION_SAVE}" --admin_frontname "${ADMIN_FRONT_NAME}" \
        --url "${BASE_URL}" --secure_base_url "${SECURE_URL}" --admin_firstname "${ADMIN_USER_FIRST}" --admin_lastname "${ADMIN_USER_LAST}" \
        --admin_email "${ADMIN_USER_EMAIL}" --admin_username "${ADMIN_USER_USERNAME}" --admin_password "${ADMIN_USER_PASSWORD}" \
        --use_rewrites "yes" --use_secure "yes" --use_secure_admin "yes" --skip_url_validation "yes" \
        --encryption_key "${CRYPT_KEY}"
    
    echo "Updating the DB with Install Status"
    mysql -h "${DB_HOST}" -u "${DB_USERNAME}" -p"${DB_PASSWORD}" "${DB_NAME}" -e "$INSTALLED_SQL_INSERT"

    else
    echo "Magento Already Marked Install Status: Complete"

fi


###############################################
## Create MAGENTO local.xml from environment variables
###############################################
cat << CONFIGFILE > $LOCAL_XML_PATH
<config>
    <global>
        <install>
            <date><![CDATA[Wed Aug 23 05:29:22 UTC 2017]]></date>
        </install>
        <crypt>
            <key><![CDATA[${CRYPT_KEY}]]></key>
        </crypt>
        <disable_local_modules>false</disable_local_modules>
        <resources>
            <db>
                <table_prefix><![CDATA[${DB_TABLE_PREFIX}]]></table_prefix>
            </db>
            <default_setup>
                <connection>
                    <host><![CDATA[${DB_HOST}]]></host>
                    <username><![CDATA[${DB_USERNAME}]]></username>
                    <password><![CDATA[${DB_PASSWORD}]]></password>
                    <dbname><![CDATA[${DB_NAME}]]></dbname>
                    <initStatements><![CDATA[SET NAMES utf8]]></initStatements>
                    <model><![CDATA[mysql4]]></model>
                    <type><![CDATA[pdo_mysql]]></type>
                    <pdoType><![CDATA[]]></pdoType>
                    <active>1</active>
                </connection>
            </default_setup>
        </resources>
        <cache>
            <backend>Mage_Cache_Backend_Redis</backend>
            <backend_options>
                <server>${MAGENTO_REDIS_CACHE_ENDPOINT}</server> <!-- or absolute path to unix socket -->
                <port>${MAGENTO_REDIS_CACHE_PORT}</port>
                <persistent></persistent> <!-- Specify a unique string like "cache-db0" to enable persistent connections. -->
                <database>0</database>
                <password></password>
                <force_standalone>1</force_standalone>  <!-- 0 for phpredis, 1 for standalone PHP -->
                <connect_retries>1</connect_retries>    <!-- Reduces errors due to random connection failures -->
                <read_timeout>10</read_timeout>         <!-- Set read timeout duration -->
                <automatic_cleaning_factor>0</automatic_cleaning_factor> <!-- Disabled by default -->
                <compress_data>1</compress_data>  <!-- 0-9 for compression level, recommended: 0 or 1 -->
                <compress_tags>1</compress_tags>  <!-- 0-9 for compression level, recommended: 0 or 1 -->
                <compress_threshold>20480</compress_threshold>  <!-- Strings below this size will not be compressed -->
                <compression_lib>gzip</compression_lib> <!-- Supports gzip, lzf and snappy -->
            </backend_options>
        </cache>
        <full_page_cache>
            <backend>Mage_Cache_Backend_Redis</backend>
            <backend_options>
                <server>${MAGENTO_REDIS_PAGE_CACHE_ENDPOINT}</server> <!-- or absolute path to unix socket -->
                <port>${MAGENTO_REDIS_CACHE_PORT}</port>
                <persistent></persistent> <!-- Specify a unique string like "cache-db0" to enable persistent connections. -->
                <database>0</database>
                <password></password>
                <force_standalone>1</force_standalone>  <!-- 0 for phpredis, 1 for standalone PHP -->
                <connect_retries>1</connect_retries>    <!-- Reduces errors due to random connection failures -->
                <read_timeout>10</read_timeout>         <!-- Set read timeout duration -->
                <automatic_cleaning_factor>0</automatic_cleaning_factor> <!-- Disabled by default -->
                <compress_data>1</compress_data>  <!-- 0-9 for compression level, recommended: 0 or 1 -->
                <compress_tags>1</compress_tags>  <!-- 0-9 for compression level, recommended: 0 or 1 -->
                <compress_threshold>20480</compress_threshold>  <!-- Strings below this size will not be compressed -->
                <compression_lib>gzip</compression_lib> <!-- Supports gzip, lzf and snappy -->
            </backend_options>
        </full_page_cache>
        <session_save>db</session_save>
        <redis_session>                       <!-- All options seen here are the defaults -->
            <host>${MAGENTO_REDIS_SESSION_ENDPOINT}</host>            <!-- Specify an absolute path if using a unix socket -->
            <port>${MAGENTO_REDIS_SESSION_PORT}</port>
            <password></password>             <!-- Specify if your Redis server requires authentication -->
            <timeout>2.5</timeout>            <!-- This is the Redis connection timeout, not the locking timeout -->
            <persistent></persistent>         <!-- Specify unique string to enable persistent connections. E.g.: sess-db0; bugs with phpredis and php-fpm are known: https://github.com/nicolasff/phpredis/issues/70 -->
            <db>0</db>                        <!-- Redis database number; protection from accidental loss is improved by using a unique DB number for sessions -->
            <compression_threshold>2048</compression_threshold>  <!-- Set to 0 to disable compression (recommended when suhosin.session.encrypt=on); known bug with strings over 64k: https://github.com/colinmollenhour/Cm_Cache_Backend_Redis/issues/18 -->
            <compression_lib>gzip</compression_lib>              <!-- gzip, lzf, lz4 or snappy -->
            <log_level>1</log_level>               <!-- 0 (emergency: system is unusable), 4 (warning; additional information, recommended), 5 (notice: normal but significant condition), 6 (info: informational messages), 7 (debug: the most information for development/testing) -->
            <max_concurrency>6</max_concurrency>                 <!-- maximum number of processes that can wait for a lock on one session; for large production clusters, set this to at least 10% of the number of PHP processes -->
            <break_after_frontend>5</break_after_frontend>       <!-- seconds to wait for a session lock in the frontend; not as critical as admin -->
            <break_after_adminhtml>30</break_after_adminhtml>
            <first_lifetime>600</first_lifetime>                 <!-- Lifetime of session for non-bots on the first write. 0 to disable -->
            <bot_first_lifetime>60</bot_first_lifetime>          <!-- Lifetime of session for bots on the first write. 0 to disable -->
            <bot_lifetime>7200</bot_lifetime>                    <!-- Lifetime of session for bots on subsequent writes. 0 to disable -->
            <disable_locking>0</disable_locking>                 <!-- Disable session locking entirely. -->
        </redis_session>
    </global>
    <admin>
        <routers>
            <adminhtml>
                <args>
                    <frontName><![CDATA[admin]]></frontName>
                </args>
            </adminhtml>
        </routers>
    </admin>
</config>
CONFIGFILE

echo "Magento Configuration Written"


###############################################
## Clear Cache and Setup MAGENTO file permissions
###############################################

rm -rf "$MAGENTO_ROOT/var/cache"
echo "File Cache Cleared"

if [ -n "${REDIS_CACHE_ENDPOINT}" ]
    then
    echo "Clean Redis Cache"
    echo "FLUSHALL" | nc "${REDIS_CACHE_ENDPOINT}" "${REDIS_CACHE_PORT}"
fi

mkdir -p "$MAGENTO_ROOT/media"

if [ -n "${NFS_ENDPOINT}" ]
    then
    # Run EFS Mount Command in the Container after it starts

    echo "Setting Up the NFS File Share"
    mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 "${NFS_ENDPOINT}":/ /var/efs
    mkdir -p "/var/efs/media"
    rm -rf "$MAGENTO_ROOT/media"
    ln -nfs "/var/efs/media" "$MAGENTO_ROOT"
    mkdir -p "/var/efs/var"
    rm -rf "$MAGENTO_ROOT/var"
    ln -nfs "/var/efs/var" "$MAGENTO_ROOT"
fi

echo "Updating Ownership of media/var/etc"
chown -R application:application "$MAGENTO_ROOT/media"
chown -R application:application "$MAGENTO_ROOT/var"
chown -R application:application "$MAGENTO_ROOT/app/etc"

echo "Updating Permission for media/var"
find "$MAGENTO_ROOT/media" -type d -exec chmod 755 {} \;
find "$MAGENTO_ROOT/media" -type f -exec chmod 644 {} \;
find "$MAGENTO_ROOT/var" -type d -exec chmod 755 {} \;
find "$MAGENTO_ROOT/var" -type f -exec chmod 644 {} \;
find "$MAGENTO_ROOT/app/etc" -type d -exec chmod 755 {} \;
find "$MAGENTO_ROOT/app/etc" -type f -exec chmod 644 {} \;

echo "Running Upgrades"
su application -c "n98-magerun.phar sys:setup:run"

if [ -e $MAGENTO_ROOT/maintenance.flag ]; then rm $MAGENTO_ROOT/maintenance.flag; fi


echo "Claim Cron Runner, or Delete Crontab File"

if [ -n "${CRON_RUNNER}" ]
    then
    
    chown -R application:application "$MAGENTO_ROOT/cron.sh"
    chown -R application:application "$MAGENTO_ROOT/cron.php"

    chmod u+x "$MAGENTO_ROOT/cron.sh"
    chmod u+x "$MAGENTO_ROOT/cron.php"
else
    echo "Not a Cron Runner, removing our cron task"
    if [ -e /etc/cron.d/magento ]; then rm /etc/cron.d/magento; fi
    if [ -e /opt/docker/etc/supervisor.d/cron.conf ]; then rm /opt/docker/etc/supervisor.d/cron.conf; fi
fi