
.PHONY: help

help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

buildcache:
	docker-compose exec magento-web magento-config.sh /app archivebuildcache

extractbuild:
	cd magento && rm -rf vendor && tar -xzf ../build-cache/build-cache-vendor.tar.gz