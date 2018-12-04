# TGC Magento Local Development

Local Development Environment Powered by Docker and Docker Compose

## Prerequisites
* Docker Installed
* Docker Compose Installed
* A 5-10 gigs of Disk Space available (depending on how much data you restore to your local environment)

### Folder Structure
 
```
 |-- projects
     |-- tgc
         |-- docker-compose.yml
         |-- magento << This is where you clone the TGC/Web repo
             | -- (Magento root: i.e. app/, skin/, index.php, etc)
         |-- solr << This is where you clone the TGC/Solr repo
             |-- (Solr repo: devops/, conf/, solr app archive)
         |-- api << This is where you clone the TGC/API repo
             |-- (API repo: src/, vendor/, build.sh, etc)
         |-- db << Empty folder for persisting the DB data files
```

### Initial Setup

1. Create the `tgc` project folder
2. Clone the TGC/Web repo into the `tgc/magento` folder
3. Clone the TGC/Api repo into the `tgc/api` folder
4. Clone the TGC/Solr repo into the `tgc/solr` folder
3. Create empty `db` folder in `tgc` project folder
4. Copy the `[magento]/devops/docker-compose.full-sample.yml` to your `tgc` project folder
5. Update any Environment Variables

### Start Development Stack

> This stack provides a basic environment for Local Development using the Docker Images that can help setup unified development environments.

1. Perform Intial Setup (above)
2. Run `docker-compose up` from the `tgc` project folder
_This will attach the terminal to the containers and output useful information from all the containers. `docker-compose up -d` will detach, if you don't want the logs._
3. Redis instances are setup as the cache endpoints, so you can clear cache from Magento Admin, or the CLI just like normal linux servers.
_See useful Docker Commands below to operate on the containers_

### Magento Configuration

This system creates a one time run processor, using supervisord, that sets up Magento Configs, and installs Magento if not already installed, and sets all the proper permissions. See `[magento]/devops/magento-config.sh` for commands and sequence of events.

> This script gets copied as a system executable that is run by supervisor once when the container starts, and can be run if you want to reset things by hand. 

From a bash prompt in the web service container: execute `magento-config.sh`

### Shared Folders
To enable local development, we need to share folders between the host (your computer in this case) and the service container. For Magento, by default we share the entire Magento codebase with the container to the webserver root. For the API, we share the src, and the configs.

* `./magento:/var/www` < Magento Root to the webserver doc root
* `./api/src:/app/src` < API Source Directory
* `./api/conf:/usr/local/tgc-api/conf` < API Config into Runtime Folder

### Docker Commands for development

Docker Compose

> docker-compose commands must be run from the folder where the docker-compose file resides.

* `docker-compose up` - _Pulls/Builds/Starts all the services configured in the docker-compose.yml file. The up command attaches to the containers and outputs the the logs to the terminal `-d` to detach_
* `docker-compose down` - _Stops and removes all containers runnng the services in docker-compose.yml._ _(ephemeral volumes lost)_
* `docker-compose stop` - _Stops all containers runnng the services in docker-compose.yml._ _(ephemeral volumes left intact)_
* `docker-compose build [service]` - _Runs `docker build` for the service image_
* `docker-compose restart [service]` - _Stops and starts the service container_ _(ephemeral volumes intact)_
* `docker-compose rm [service]` - _Removes a stopped service container_ _(ephemeral volumes lost)_
* `docker ps` - _Lists out the running containers `-a` lists stopped containers too_
* `docker logs [container id/name]` - _Outputs logs from the container `-l` attaches to the container and follows the logs in the terminal_
* `docker exec -it [container id/name] bash`  - _Attaches to the container and starts a bash prompt_ _(kinda like ssh into the container)_
* `docker build [file location]` -  _Builds an image from the file location, looks for a `Dockerfile`_

### Switching Between Stores
> There are 3 properties that are managed by this Magento code base. In the `docker-compose.yml` file we set some domains for setting up the different store web server configs. 

Use the following example environment variables to load the appropriate stores:

    - DOMAIN_US=us.tgc.dev
    - DOMAIN_AU=au.tgc.dev
    - DOMAIN_UK=uk.tgc.dev

> The Magento Config service uses these to create the web server configs. See `devops/magento-config.sh` for details.

