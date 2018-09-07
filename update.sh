#!/bin/bash

GUIDOCKER_DEFAULT_PROJECTS_DIR=~/development/projects

function magento2-simple {

  ls -al $GUIDOCKER_DEFAULT_PROJECTS_DIR

  echo " - - - "
  echo "Enter the project that we are grabbing configs from:"
  read PROJECTKEY

  PROJECT_DIR="$GUIDOCKER_DEFAULT_PROJECTS_DIR/$PROJECTKEY"
  ls -al $PROJECT_DIR

  echo " - - - "
  echo "Enter the Magento 2 repo directory that we are grabbing configs from:"
  read MAGENTO_FOLDER

  MAGENTO_DIR="$PROJECT_DIR/$MAGENTO_FOLDER"

  echo $MAGENTO_DIR
  #ls -al $MAGENTO_DIR

  if [ -e "$MAGENTO_DIR/pub/index.php" ]
    then
      echo "Found Magento Install."

      echo " - - - "

      echo " Do you want to update dockerize from your Magento 2 Install? (Y/n)"
      read DOCKERIZE_CONFIRM

      if [ -n "$DOCKERIZE_CONFIRM" ] && [ "$DOCKERIZE_CONFIRM" == "Y" ]
        then
          clear

          echo "We are moving the devops directory from your Magento Project..."
          sleep 1
          cp -R $MAGENTO_DIR/devops/* magento2-simple/devops/ 
          
          echo "We are moving the Dockerfile and ignore file..."
          sleep 1
          cp $MAGENTO_DIR/Dockerfile magento2-simple/Dockerfile 
          cp $MAGENTO_DIR/.dockerignore magento2-simple/.dockerignore

          echo " - - - "

          echo "If all went well, you can know adjust the files and then commit any valuable generic changes to the dockerize project"

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
  echo "Enter the project that we are grabbing configs from:"
  read PROJECTKEY

  PROJECT_DIR="$GUIDOCKER_DEFAULT_PROJECTS_DIR/$PROJECTKEY"
  ls -al $PROJECT_DIR

  echo " - - - "
  echo "Enter the Akeneo 2 repo directory that we are grabbing configs from:"
  read APP_FOLDER

  AKENEO_DIR="$PROJECT_DIR/$APP_FOLDER"

  echo $AKENEO_DIR
  #ls -al $AKENEO_DIR

  if [ -e "$AKENEO_DIR/app/config/pim_parameters.yml" ]
    then
      echo "Found Akeneo Install."

      echo " - - - "

      echo " Do you want to update dockerize from your Akeneo 2 Install? (Y/n)"
      read DOCKERIZE_CONFIRM

      if [ -n "$DOCKERIZE_CONFIRM" ] && [ "$DOCKERIZE_CONFIRM" == "Y" ]
        then
          clear

          echo "We are moving the devops directory from your Akeneo Project..."
          sleep 1
          mkdir -p akeneo2-simple/devops
          cp -R $AKENEO_DIR/devops/* akeneo2-simple/devops/ 
          
          echo "We are moving the Dockerfile and ignore file..."
          sleep 1
          cp $AKENEO_DIR/Dockerfile akeneo2-simple/Dockerfile 
          cp $AKENEO_DIR/.dockerignore akeneo2-simple/.dockerignore

          echo " - - - "

          echo "If all went well, you can know adjust the files and then commit any valuable generic changes to the dockerize project"

          echo " - - - "

        else
          clear
          echo "Maybe next time then... good bye!"

      fi

    else
      clear
      echo "! ! ! -- -- - - -"
      echo "Looks like there is no Akeneo Project here."
      echo "Please check the files and make sure that you have your magento project in $PROJECT_DIR"

  fi 

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