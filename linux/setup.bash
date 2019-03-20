#!/bin/bash

# Must be run as root
[ ${EUID} -ne 0 ] && {
    errcho "This script must be run as root. Canceling."
    exit 1
  }

# Loading necessary environment
source /etc/profile.d/tableau_server.sh

# In case that fails, then we'll try this
load_environment_file() {
  if [[ -f /etc/opt/tableau/tableau_server/environment.bash ]]; then
    source /etc/opt/tableau/tableau_server/environment.bash
    env_file_exists=1
  fi
}

# Some more variables
script_url='https://raw.githubusercontent.com/til-jmac/tableau-server-housekeeping/master/linux/tableau-server-housekeeping-linux.bash'
script_file='tableau-server-housekeeping-linux.bash'
script_dir='$TABLEAU_SERVER_DATA_DIR/scripts'
tmp_dir='/tmp'

# Setting up housekeeping script
cd $tmp_dir
wget $script_url

if [[ ! -e $script_dir ]]; then
    mkdir $script_dir
fi

cp $script_file $script_dir
chown -R $TABLEAU_SERVER_UNPRIVILEGED_USERNAME:$TABLEAU_SERVER_UNPRIVILEGED_USERNAME $script_dir
chmod +x $script_dir/$script_file

# Script is set up, now to schedule in crontab
echo 'Tableau Server housekeeping script is now installed. Please refer to the script documentation to schedule in crontab'