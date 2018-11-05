#!/bin/bash

APP_DIR=$1

cd $APP_DIR

function run {
    rm -rf var/cache/* web/cache/*
    composer install --optimize-autoloader --prefer-dist
    yarn install
    bin/console cache:clear --no-warmup --env=prod
    bin/console pim:installer:assets --clean --env=prod
    yarn run webpack
    ln -nfs /var/sftp/import app/import
    ln -nfs /var/sftp/export app/export
}

$2
