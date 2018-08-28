# Magento 2 Local Development

Local Development Environment Powered by Docker and Docker Compose

## Prerequisites
* Docker Installed
* Docker Compose Installed
* A couple gigs of Disk Space available

### Folder Structure
 
 ```
 |-- projects
     |-- project
        |-- magento << This is where you clone this repo  
        |-- magento-db << Folder used for storing and persisting the DB data files.
        |-- magento-es << Folder used for storing and persisting elasticsearch data files.
        |-- docker-compose.yml << File used to build the magento service.  
```

### Initial Setup

1. Create the `project` project folder
2. Create the `magento` folder inside of the `project` folder 
3. Clone the project M2 repo into the `project/magento` folder
4. Copy the `docker-compose.sample.yml` from `project/magento/devops` to the `project` project folder. 
5. Rename `docker-compose.sample.yml` to `docker-compose.yml`
6. Update any Environment Variables in `docker-compose.yml` to reflect the environment you want to build.  For example, you might want use a custom domain name for your site.  Update `CONFIG__DEFAULT__WEB__UNSECURE__BASE_URL=http://project.guidance.local/` to `CONFIG__DEFAULT__WEB__UNSECURE__BASE_URL=http://project.mydomain.local/`
7. Setup/Start Portainer Docker Web GUI (Optional: See bottom of this README). 


> **Note about Setup Speed**
There are some shared volumes listed in the magento-web section of the docker-compose.yml file. If this is the first setup, it's much faster if you 
comment those out. You can copy those files to your local after you get
everything running, then you can uncomment those volumes, and share back your 
local copy.

### Start Development Stack
> This stack provides a basic environment for M2 Development using the same Docker Images that will be built and deployed to the dev/stage/production environments.
1. Perform Intial Setup (above)
2. Run `docker-compose up` from the `project` project folder
_This will attach the terminal to the containers and output useful information from all the containers including the magento applcation from the `magento-web` service container._
3. Update your local `/etc/hosts` file to point your magento site to `localhost`.  Example of `/etc/hosts`
```
##
# Host Database
#
# localhost is used to configure the loopback interface
# when the system is booting.  Do not change this entry.
##
127.0.0.1   localhost project.guidance.local project-admin.guidance.local
255.255.255.255 broadcasthost
::1             localhost
```

### Magento Configuration
This system creates a one time run processor that sets up Magento Configs, and installs Magento if not already installed, and sets all the proper permissions. See `magento/devops/magento-config.sh` for commands and sequence of events.
> This script gets copied as a system executable that is run by supervisor once when the container starts, and can be run if you want to reset things by hand. 
From a bash prompt in the web service container: execute `magento-config.sh /app configure`

#### Roles and Modes

> Role Concept: You can run this stack in different ways: As a web nodes, or a process node. For scalable stacks, the static content is shared between the nodes. So, the process node runs the static deploy and the web nodes wait for the static versions to line up, prior to them becoming live. We use `MAGE_CONTAINER_ROLE=[web|process]` this variable defaults to process.

> Mode Concept: You can run this stack in different ways: In developer mode, and in production mode. 

The standard `MAGE_MODE=[developer|production]` environment variable applies to the Magento functionality. The Magento Configuration script also pivots for a couple things when the site is in Production Mode. 

- The Static Content Deploy will run on the process node, if the site is in production mode
- The entire configuration script is dependent on the version file, and shares the static content version and the code version between the different nodes. See the `pub/static/process` folder once you have a full build.


### Debugging using Xdebug

Debugging requires some setup on a IDE like PHPStorm or NetBeans, some people also like to use a browser debugging extension that adds debug session cookies for you.

> Concept: When xdebug is enabled, it will publish debugging information to your workstation on port 9000. Your IDE can listen from that debugging information and show you the results, allowing your to communicate stepping information back to the web server. So, we need to configure the Web container to publish that information, and we need to configure the IDE to listen for that information.

#### Debug - Configure your web container

The `magento-config.sh` setup script will look for ENV Var `XDEBUG_CONFIG` and if present it will enable xdebug. To enable:
Add `- XDEBUG_CONFIG=remote_host=10.0.0.171 remote_enable=1` to your docker-compose.yml, replacing the remote_host IP address with the internal IP of your workstation.
Uncomment the `- "./magento/var:/app/var"` line in your docker-compose.yml in the services:web:volumes section. This will allow you to set up path mappings to the var/generation Magento directory in your IDE

#### Debug - Configure the Browser

> While this is option, it gives you a little control over when you are debugging and when you want to disable.

Download and configure a Chrome or Firefox Xdebug Extension, and configure or make note of the IDE Session Key (e.g. PHPSTORM)

#### Debug - Configure the IDE

In PHPStorm for instance, you need to create a debugging server configuration. Create a new "PHP Remote Debug" config, and a server config, pointing to the domain name, port 80, xdebug as the debugger, and the IDE Session key from the configure the browser step. Add a file mapping from your local disk to the container directory. e.g. `magento` to `/app`.
Once you have that configuration in place. Now you can click the debugging listen button to toggle on the listener. (this is what starts listening to port 9000)

#### Debug - Starting the debugger listening and console

Once you have the container publishing, the browser debugging session activated, and the IDE listening for the debugging information. Then you can add a breakpoint somewhere (I like to just put one in the pub/index.php, so that I know it gets hit) then refresh the page. You should get a debugger console that focuses on the breakpoint that you have added. From here your debugger is alive, and you can step through the code and be a happy camper.

#### Debug - Notes

Having xDebug enabled, you can experience a performance hit, especially in developer mode. So, it's probably a good idea that when you are not actively using the debugger, you can switch off the xdebug php extension.
The `magento-config.sh` configuration script has a couple helpers. So if you run `bash` against your web container (See Docker Commands below) then you can enable/disable PHP Debug by using the following commands.

* `magento-config.sh /app enabledebug` << Enables
* `magento-config.sh /app disabledebug` << Disables
 
> You may need to restart php-fpm to fully disable `service php-fpm restart`

### Shared Folders
For the best Performance with M2, we need to share limited folders. By default we share the folders necessary for development.
* `[magento]/app` < Magento Code Folder, location of all custom code.
* `[magento]/var/log` < Magento Log Folder.
* `[magento]/pub/media` < Magento Media Folder.

### Postfix Configuration

The following environment variables are used by the config script to setup the postfix configuration files.

Use the MailHog for Local Development, and the AWS SES for QA/Stage/Production
If you use AWS SES, then the from address needs to be verified as a sending address in the SES console. 

    # Used to config the use of MailHog
    - POSTFIX_RELAYURL=email
    - POSTFIX_RELAYPORT=1025
        
    # Used to Configure AWS SES as the SMTP Relay
    - POSTFIX_RELAYURL=email-smtp.us-east-1.amazonaws.com
    - POSTFIX_RELAYPORT=587
    - POSTFIX_SES_USER=AKIA***********XUTQ
    - POSTFIX_SES_PASS=AhUU********************zYSIUq
    - POSTFIX_FROM_ADDRESS=no-reply@notifications.guidance.com

### Cron Configuration

The following environment variable is used to turn on the Magento cron task

If `CRON_RUNNER` exists, then the config process adds the devops/cron/magento file into the cron tab folder.

Add the following ENV item to the docker-compose web container definition to have the Magento cron run on your local 
environment

    - CRONRUNNER=1


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
* `docker build [file location]` -  _Builds an image from the file location, looks for a `Dockerfile` in that folder_
* `docker cp [container id/name]:/app/vendor ./magento/` - _Copies the vendor folder from the container to your local_ 

### Services in Docker Compose

> The Docker Compose Sample File outlines the services that are being, or can be, used from your local environment.

`magento-web:` The Magento Web and Application Server.  It Contains the following process and applications, all run by supervisord:
* Apache (ver 2.4)
* PHP-FPM (ver 7.1)
* Postfix

`magento-db:` The Database Server. Uses the latest Percona version 5.7

`magento-es:` Elasticsearch server. It's used as default magento search engine end documents storage database. Uses the latest Elasticsearch 2.* version.

`magento-redis-cache:` Standard Magento cache. Uses the latest Redis version.

`magento-redis-fpc:` Full Page Cache. Uses the latest Redis version.

`magento-redis-sessions:` Session Cache. Uses the latest Redis version.

`email:` The Email Service. Users the latest Mailhog image from Mailhog. The Web Server needs to have the postfix service running and configured to relay messages to it. (Done through supervisor configs, see Magento Web Dockerfile)

### If you're intrested in using a Web GUI to manage your Docker environment
Portainer is a simple management solution for Docker.
It consists of a web UI that allows you to easily manage your Docker containers, images, networks and volumes.

To use Portainer, follow these instructions:
1. Copy/paste this command in to your terminal
`docker volume create portainer_data && docker run -d -p 9000:9000 --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer`
2. Access portainer by visiting: http://localhost:9000/
3. Create password for the user "admin"
4. Choose "local" and select "connect"
NOTE: Portainer data persists after container restarts.  This is made possible via `docker volume create portainer_data` used earlier.  

For more info on Portainer, visit: 
https://portainer.readthedocs.io/en/stable/
