#!/bin/bash

GUIDOCKER_DEFAULT_PROJECTS_DIR=~/development/projects

# function install {
#   DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
#   echo $DIR
#   echo "$0"
#   echo $PATH
# }

function magento2-simple {

  ls -al $GUIDOCKER_DEFAULT_PROJECTS_DIR

  echo " - - - "
  echo "Enter the project that we are dockerizing:"
  read PROJECTKEY

  PROJECT_DIR="$GUIDOCKER_DEFAULT_PROJECTS_DIR/$PROJECTKEY"
  ls -al $PROJECT_DIR

  echo " - - - "
  echo "Enter the Magento 2 repo directory that we are dockerizing:"
  read MAGENTO_FOLDER

  MAGENTO_DIR="$PROJECT_DIR/$MAGENTO_FOLDER"

  echo $MAGENTO_DIR
  #ls -al $MAGENTO_DIR

  if [ -e "$MAGENTO_DIR/pub/index.php" ]
    then
      echo "Found Magento Install."

      echo " - - - "

      echo " Do you want to Dockerize your Magento 2 Install? (Y/n)"
      read DOCKERIZE_CONFIRM

      if [ -n "$DOCKERIZE_CONFIRM" ] && [ "$DOCKERIZE_CONFIRM" == "Y" ]
        then
          clear
          echo "One moment while we initialize the project folders... "
          sleep 1
          mkdir -p $PROJECT_DIR/magento-db/data
          mkdir -p $PROJECT_DIR/magento-es/data

          echo "We are moving the devops directory to your Magento Project..."
          sleep 1
          cp -R magento2-simple/devops $MAGENTO_DIR/
          
          echo "We are moving the Dockerfile and ignore file..."
          sleep 1
          cp magento2-simple/Dockerfile $MAGENTO_DIR/
          cp magento2-simple/.dockerignore $MAGENTO_DIR/


          if [ -e "$PROJECT_DIR/docker-compose.yml" ]
            then 
              echo "Looks like you already have a docker-compose file for this project..."
              sleep 1
              echo "We will copy a dockerize sample for your purusal"
              sleep 1
              cp magento2-simple/devops/docker-compose.sample.yml $PROJECT_DIR/
            else
              echo "We are moving the docker-compose file Project dir: $PROJECT_DIR"
              sleep 1
              cp magento2-simple/devops/docker-compose.sample.yml $PROJECT_DIR/docker-compose.yml
          fi

          echo " - - - "

          echo "If all went then you should now be able to go to your project directory, do a little setup and then run: docker-compose up"
          echo "Please read the Readme at devops/readme.md in the Magento project"

          echo " - - - "

        else
          clear
          echo "Maybe next time then... good bye!"

      fi

    else
      clear
      echo "! ! ! -- -- - - -"
      echo "Looks like there is no Magento Project here."
      echo "Please check the files and make sure that you have your magento project in $PROJECT_DIR"

  fi 

}

function magento1-simple {

  ls -al $GUIDOCKER_DEFAULT_PROJECTS_DIR

  echo " - - - "
  echo "Enter the project that we are dockerizing:"
  read PROJECTKEY

  PROJECT_DIR="$GUIDOCKER_DEFAULT_PROJECTS_DIR/$PROJECTKEY"
  ls -al $PROJECT_DIR

  echo " - - - "
  echo "Enter the Magento 1 repo directory that we are dockerizing:"
  read MAGENTO_FOLDER

  MAGENTO_DIR="$PROJECT_DIR/$MAGENTO_FOLDER"

  echo $MAGENTO_DIR
  #ls -al $MAGENTO_DIR

  if [ -e "$MAGENTO_DIR/app/etc/config.xml" ]
    then
      echo "Found Magento Install."

      echo " - - - "

      echo " Do you want to Dockerize your Magento 1 Install? (Y/n)"
      read DOCKERIZE_CONFIRM

      if [ -n "$DOCKERIZE_CONFIRM" ] && [ "$DOCKERIZE_CONFIRM" == "Y" ]
        then
          clear
          echo "One moment while we initialize the project folders... "
          sleep 1
          mkdir -p $PROJECT_DIR/magento-db/data
          mkdir -p $PROJECT_DIR/magento-es/data

          echo "We are moving the devops directory to your Magento Project..."
          sleep 1
          cp -R magento1-simple/devops $MAGENTO_DIR/
          
          echo "We are moving the Dockerfile and ignore file..."
          sleep 1
          cp magento1-simple/Dockerfile $MAGENTO_DIR/
          cp magento1-simple/.dockerignore $MAGENTO_DIR/


          if [ -e "$PROJECT_DIR/docker-compose.yml" ]
            then 
              echo "Looks like you already have a docker-compose file for this project..."
              sleep 1
              echo "We will copy a dockerize sample for your purusal"
              sleep 1
              cp magento1-simple/devops/docker-compose.sample.yml $PROJECT_DIR/
            else
              echo "We are moving the docker-compose file Project dir: $PROJECT_DIR"
              sleep 1
              cp magento1-simple/devops/docker-compose.sample.yml $PROJECT_DIR/docker-compose.yml
          fi

          echo " - - - "

          echo "If all went then you should now be able to go to your project directory, do a little setup and then run: docker-compose up"
          echo "Please read the Readme at devops/readme.md in the Magento project"

          echo " - - - "

        else
          clear
          echo "Maybe next time then... good bye!"

      fi

    else
      clear
      echo "! ! ! -- -- - - -"
      echo "Looks like there is no Magento Project here."
      echo "Please check the files and make sure that you have your magento project in $PROJECT_DIR"

  fi 

}

function akeneo2-simple {

  ls -al $GUIDOCKER_DEFAULT_PROJECTS_DIR

  echo " - - - "
  echo "Enter the project that we are dockerizing:"
  read PROJECTKEY

  PROJECT_DIR="$GUIDOCKER_DEFAULT_PROJECTS_DIR/$PROJECTKEY"
  ls -al $PROJECT_DIR

  echo " - - - "
  echo "Enter the Akeneo 2 repo directory that we are dockerizing:"
  read APP_FOLDER

  APP_DIR="$PROJECT_DIR/$APP_FOLDER"

  echo $APP_DIR

  if [ -e "$APP_DIR/app/config/pim_parameters.yml" ]
    then
      echo "Found Akeneo Install."

      echo " - - - "

      echo " Do you want to Dockerize your Akeneo 2 Install? (Y/n)"
      read DOCKERIZE_CONFIRM

      if [ -n "$DOCKERIZE_CONFIRM" ] && [ "$DOCKERIZE_CONFIRM" == "Y" ]
        then
          clear
          echo "One moment while we initialize the project folders... "
          sleep 1
          mkdir -p $PROJECT_DIR/akeneo-db/data
          mkdir -p $PROJECT_DIR/akeneo-es/data

          echo "We are moving the devops directory to your Akeneo Project..."
          sleep 1
          cp -R akeneo2-simple/devops $APP_DIR/
          
          echo "We are moving the Dockerfile and ignore file..."
          sleep 1
          cp akeneo2-simple/Dockerfile $APP_DIR/
          cp akeneo2-simple/.dockerignore $APP_DIR/


          if [ -e "$PROJECT_DIR/docker-compose.yml" ]
            then 
              echo "Looks like you already have a docker-compose file for this project..."
              sleep 1
              echo "We will copy a dockerize sample for your purusal"
              sleep 1
              cp akeneo2-simple/devops/docker-compose.sample.yml $PROJECT_DIR/
            else
              echo "We are moving the docker-compose file Project dir: $PROJECT_DIR"
              sleep 1
              cp akeneo2-simple/devops/docker-compose.sample.yml $PROJECT_DIR/docker-compose.yml
          fi

          echo " - - - "

          echo "If all went then you should now be able to go to your project directory, do a little setup and then run: docker-compose up"
          echo "Please read the Readme at devops/readme.md in the Akeneo project"

          echo " - - - "

        else
          clear
          echo "Maybe next time then... good bye!"

      fi

    else
      clear
      echo "! ! ! -- -- - - -"
      echo "Looks like there is no Akeneo Project here."
      echo "Please check the files and make sure that you have your Akeneo project in $PROJECT_DIR"

  fi 

}

function init {
  echo "Initialize Project Structure"
}

function help {
  cat <<HELPTEXT
!!! Help 
Test Help Text

HELPTEXT
}

COMMAND=$1

if [ -z "$1" ]
  then
    help
fi 

$COMMAND ${@:2}