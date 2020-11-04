#!/bin/bash

#
# Usage :
#   bash install_prestashop.sh dirname location [-v | --version version] [--github | --web] (--manual | -- (PrestaShop params))
# e.g.
#   bash install_prestashop.sh test . --web -- --domain=prestashop.ps -db_server=localhost --db_name=prestashop2 --db_user=root --db_password="root"
# or
#   bash install_prestashop.sh test . -v 1.6.1.9 --manual
#
# --- By Ilshidur (https://github.com/Ilshidur)
#   Feel free to submit pull requests !
#
# TODO: Use https://api.github.com/repos/PrestaShop/PrestaShop/releases
#

# Inspired of https://gist.github.com/julienbourdeau/205df55bcf8aa290bd9e

# Constants for console colors
RED='\e[0;31m'
GREEN='\e[0;32m'
ORANGE='\e[0;33m'
NC='\e[0m' # No Color

# Constants
GIT_REPO="git@github.com:PrestaShop/PrestaShop.git"

# User variables with the default values
installfrom="web"
location="~/"
dirname="PrestaShop"
version=""
installPrms="_MANUAL_" # PrestaShop CLI install parameters, _MANUAL_ means no automated prestashop install via CLI

function usage
{
  echo -e "${GREEN}Usage: install_prestashop [location] [--version version] [--github | --web] ${NC}"
  echo -e "e.g."
  echo -e "  bash ./install_prestashop.sh test ."
  echo -e "  bash ./install_prestashop.sh test . --github"
  echo -e "  bash ./install_prestashop.sh test . --web -- --domain=localhost/prestashop --name=PrestaShopTest --db_server=localhost --db_name=prestashop --db_user=root --db_password=root --email=email@domail.tld --password=root --db_clear=1 --db_create=1"
  echo -e "  bash ./install_prestashop.sh --help"
}

function install_from_git
{
  cd $location
  if [ -d $location$dirname ]; then
    echo -e "${RED}$location$dirname already exists !${NC}"
    exit 1
  fi

  echo -e "${GREEN}Downloading to $location$dirname ... ${NC}"
  git clone -q --recursive $GIT_REPO $dirname || { echo -e "${RED}Git clone failed ! ${NC}" ; exit 1; }

  cd $dirname
}

function install_from_web
{
  tempZip="prestashop_${version}.zip"

  cd $location
  if [ -d $location$dirname ]; then
    echo -e "${RED}$location$dirname already exists !${NC}"
    exit 1
  fi
  if [ -d $tempZip ]; then
    echo -e "${ORANGE}Deleting existing $tempZip ${NC}"
    rm -rf $tempZip || { echo -e "${RED}rm ${tempZip} failed ! ${NC}" ; exit 1; }
  fi

  mkdir $dirname
  cd $dirname
  echo -e "${GREEN}Downloading from https://download.prestashop.com/download/releases to $location$dirname ... ${NC}"
  wget -q "https://download.prestashop.com/download/releases/${tempZip}" || { echo -e "${RED}wget failed ! ${NC}" ; exit 1; }
  echo -e "${GREEN}Extracting ${tempZip} ... ${NC}"
  unzip -q $tempZip
  rm -rf $tempZip

  if [ -f prestashop.zip ]; then
    unzip -o -q prestashop.zip
    rm -rf prestashop.zip
  fi

  # If PrestaShop is in a folder, moves it outside the folder
  if [ $(find ./* -maxdepth 0 -type d | wc -l) == 1 ]; then # Dir count
    mv $(find ./* -maxdepth 0 -type d)/* .
  fi
}

install ()
{
  # The install dir name differs from PrestaShop's website install to Git repository
  installDir='install'
  case $1 in
    github)
       installDir='install-dev'
       ;;
    web)
       installDir='install'
       ;;
  esac

  echo -e "${GREEN}Installing PrestaShop. This may take a while ... ${NC}"
  # PrestaShop 1.6 install won't exit with code "1" if the install fails
  php "./${installDir}/index_cli.php" $installPrms || { echo -e "${RED}Prestashop install failed ! ${NC}" ; exit 1; }

  rm -rf $installDir
}

function setup_permissions
{
  echo -e "${GREEN}Setting up permissions ... ${NC}"
  chmod a+w -R config/
  chmod a+w -R cache/
  chmod a+w -R log/
  chmod a+w -R img/
  chmod a+w -R mails/
  chmod a+w -R modules/
  chmod a+w -R themes/default-bootstrap/lang/
  chmod a+w -R themes/default-bootstrap/pdf/lang/
  chmod a+w -R themes/default-bootstrap/cache/
  chmod a+w -R translations/
  chmod a+w -R upload/
  chmod a+w -R download/
}

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  usage
  exit 1
fi

if [ "$1" != "" ]; then
  dirname=$1
else
  echo -e "${RED}Missing 1st parameter : dirname ${NC}"
  exit 1
fi

if [ "$2" != "" ]; then
  location=$2
else
  echo -e "${RED}Missing 2nd parameter : location ${NC}"
  exit 1
fi

# Fix location : "." to "./", "~" to "~/" ...
if [ "$2" = "~" ] || [ "$2" = "." ] || [ "$2" = ".." ]; then
  location=$location"/"
fi

# Start reading params from the 3rd
shift
shift
while [ "$1" != "" ]; do
  case "$1" in
    "-v" | "--version" )
      shift
      version=$1
      ;;
    "--github" )
      installfrom="github"
      ;;
    "--web" )
      installfrom="web"
      ;;
    "--manual" )
      installPrms="_MANUAL_"
      ;;
    "--" )
        # Get the rest of the params
        while [ "$1" != "" ]; do
          installPrms=$installPrms$1" "
          shift
        done
        ;;
    "-h" | "--help" )
      usage
      exit 1
      ;;
    * )
      usage
      exit 1
  esac
  shift
done

if [ ! -w . ]; then
  echo -e "${RED}Insufficient permissions. Please run as root or add +w permissions on this directory.${NC}"
  exit 1
fi

if [ "$version" == "" ]; then
  echo -e "${ORANGE}Getting latest PrestaShop version tag ... ${NC}"
  version=$(curl -s https://api.github.com/repos/PrestaShop/PrestaShop/releases | grep -Po '(?<="tag_name": ")[^"]*' | head -n 1)
fi

echo -e "${GREEN}[Prestashop v$version] ${NC}"

case $installfrom in
  github )
     install_from_git
     ;;
  web )
     install_from_web
     ;;
esac

setup_permissions

if [ "$installPrms" == "_MANUAL_" ]; then
  echo -e "${ORANGE}PrestaShop will not be installed (--manual). ${NC}"
else
  install $installfrom
fi

if [ "$installfrom" == "github" ]; then
  # Installation from GitHub needs to install dependencies with Composer
  if [ ! command -v composer >/dev/null 2>&1 ]; then
    echo -e "${ORANGE}'composer' command not found. The dependencies won't be installed ! ${NC}"
  else
    echo -e "${GREEN}Installing dependencies ... ${NC}"
    composer install || echo -e "${RED}Composer install failed ! ${NC}" ;
  fi
fi

echo -e "${GREEN}Done ! Now get to work :) ${NC}"

exit 0
