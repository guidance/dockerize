
.PHONY: help

help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

buildcache:
	cd .. && docker-compose exec magento-web magento-config.sh /app archivebuildcache

extractcache:
	rm -rf vendor && tar -xzf ../build-cache/build-cache-vendor.tar.gz

pullcache: buildcache extractcache ## Pull the composer and vendor folders from the container to the host

startweb: ## Start the Magento Web Container (with all the dependent containers)
	cd .. && docker-compose up magento-web

bashweb: ## Execute bash against the Magento Web
	cd .. && docker-compose exec magento-web bash

down: ## Take the stack completely down
	cd .. && docker-compose down

archivecomposer: 
	cd .. && docker-compose exec magento-web tar -czf build-cache-composer.tar.gz composer.json composer.lock vendor/composer

copycomposer: 
	cd .. && docker-compose exec magento-web mv build-cache-composer.tar.gz build-cache/
	
extractlocalcomposer:
	tar -xzf ../build-cache/build-cache-composer.tar.gz

pullcomposer: archivecomposer copycomposer extractlocalcomposer ## Pulls the composer files from the container to the host

updatecomposer:
	tar -czf build-cache-composer.tar.gz composer.json composer.lock vendor/composer && mv build-cache-composer.tar.gz ../build-cache/ && cd .. && docker-compose exec magento-web mv build-cache/build-cache-composer.tar.gz .

extractcomposer: 
	cd .. && docker-compose exec magento-web tar -xzf build-cache-composer.tar.gz

pushcomposer: updatecomposer extractcomposer ## Pushes the composer files from the host to the container
