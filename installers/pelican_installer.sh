#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Project 'pelican-installer'                                                        #
#                                                                                    #
# Copyright (C) 2024 - 2028, Anthony Lester, <friendlyneighborhoodgeeks@gmail.com>   #
#                                                                                    #
#   This program is free software: you can redistribute it and/or modify             #
#   it under the terms of the GNU General Public License as published by             #
#   the Free Software Foundation, either version 3 of the License, or                #
#   (at your option) any later version.                                              #
#                                                                                    #
#   This program is distributed in the hope that it will be useful,                  #
#   but WITHOUT ANY WARRANTY; without even the implied warranty of                   #
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                    #
#   GNU General Public License for more details.                                     #
#                                                                                    #
#   You should have received a copy of the GNU General Public License                #
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.           #
#                                                                                    #
# https://github.com/friendlyngeeks/pelican-installer/blob/master/LICENSE            #
#                                                                                    #
# This script is not associated with the official Pelican Project.                   #
# https://github.com/friendlyngeeks/pelican-installer/                               #
#                                                                                    #
######################################################################################

# ------------------ Variables ----------------- #

# Domain name / IP
export FQDN=""

# Default MySQL credentials
export MYSQL_DB=""
export MYSQL_USER=""
export MYSQL_PASSWORD=""

# Environment
export timezone=""
export email=""

# Initial admin account
export user_email=""
export user_username=""
export user_firstname=""
export user_lastname=""
export user_password=""

# Assume SSL, will fetch different config if true
export ASSUME_SSL=false
export CONFIGURE_LETSENCRYPT=false

# Firewall
export CONFIGURE_FIREWALL=false

# Use eMail Notifications
export CONFIGURE_MAIL=false

DATE=$(date +%F)

COLOR_RD='\033[0;31m'
COLOR_GN='\033[0;32m'
COLOR_NC='\033[0m'


# ------------------ Helpers ----------------- #

output() {
  echo "$1"
}

success() {
  echo ""
  echo "${COLOR_GN}SUCCESS${COLOR_NC}: $1" 1>&2
  echo ""
}

error() {
  echo ""
  echo "${COLOR_RD}ERROR${COLOR_NC}: $1" 1>&2
  echo ""
}


# check for curl
if ! [ -x "$(command -v curl)" ]; then
  echo "* curl is required in order for this script to work."
  echo "* install using apt (Debian and derivatives) or yum/dnf (CentOS)"
  exit 1
fi


# --------------- Main panel installation functions --------------- #

install_composer() {
  output "Installing composer.."
  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
  success "Composer installed!"
}

pcdl_dl() {
    output "Downloading pelican github latest release .. "

    mkdir -p /var/www/pelican
    cd /var/www/pelican
    curl -Lo panel.tar.gz https://github.com/pelican-dev/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/

    cp .env.example .env

    success "Downloaded pelican panel files!"  
}

install_composer_deps() {
  output "Installing composer dependencies.."
  [ "$OS" == "rocky" ] || [ "$OS" == "almalinux" ] && export PATH=/usr/local/bin:$PATH
  COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
  success "Installed composer dependencies!"
}

# sudo composer install --no-dev --optimize-autoloader

# env setup
php artisan p:environment:setup
php artisan p:environment:database

# panel mail setup
if (CONFIGURE_MAIL) {
    php artisan p:environment:mail
}


# ------------------ Welcome ----------------- #

welcome ""


# ------------------ Menu ----------------- #

done=false
while [ "$done" == false ]; do
  options=(
    "Install the panel"
    #"Install Wings"
    #"Install both [0] and [1] on the same machine (wings script runs after panel)"
    # "Uninstall panel or wings\n"

    #"Install panel with canary version of the script (the versions that lives in master, may be broken!)"
    #"Install Wings with canary version of the script (the versions that lives in master, may be broken!)"
    #"Install both [3] and [4] on the same machine (wings script runs after panel)"
    #"Uninstall panel or wings with canary version of the script (the versions that lives in master, may be broken!)"
  )

  actions=(
    "panel"
    #"wings"
    #"panel;wings"
    # "uninstall"

    #"panel_canary"
    #"wings_canary"
    #"panel_canary;wings_canary"
    #"uninstall_canary"
  )

  output "What would you like to do?"

  for i in "${!options[@]}"; do
    output "[$i] ${options[$i]}"
  done

  echo -n "* Input 0-$((${#actions[@]} - 1)): "
  read -r action

  [ -z "$action" ] && error "Input is required" && continue

  valid_input=("$(for ((i = 0; i <= ${#actions[@]} - 1; i += 1)); do echo "${i}"; done)")
  [[ ! " ${valid_input[*]} " =~ ${action} ]] && error "Invalid option"
  [[ " ${valid_input[*]} " =~ ${action} ]] && done=true && IFS=";" read -r i1 i2 <<<"${actions[$action]}" && execute "$i1" "$i2"
done


# ------------ User input functions ------------ #

ask_email_setup() {
  echo -e -n "* Would you like to enable panel notifications via eMail? (y/N): "
  read -r CONFIRM_SSL

  if [[ "$CONFIRM_SSL" =~ [Yy] ]]; then
    CONFIGURE_LETSENCRYPT=true
    ASSUME_SSL=false
  fi
}


# --------------- Main functions --------------- #

perform_panel_install() {
  output "Starting installation.. this might take a while!"
  dep_install
  install_composer
  ptdl_dl
  install_composer_deps
  create_db_user "$MYSQL_USER" "$MYSQL_PASSWORD"
  create_db "$MYSQL_DB" "$MYSQL_USER"
  configure
  set_folder_permissions
  insert_cronjob
  install_pteroq
  configure_nginx
  [ "$CONFIGURE_LETSENCRYPT" == true ] && letsencrypt

  return 0
}

# ------------------- Install ------------------ #

perform_panel_install