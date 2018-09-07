#!/bin/bash

APP_DIR=$1

cd $APP_DIR

function run {
    rm -rf var/cache/* web/cache/*
    php bin/console pim:installer:assets --env=prod
    yarn run webpack
    ln -nfs /var/sftp/import app/import
    ln -nfs /var/sftp/export app/export
}

$2
