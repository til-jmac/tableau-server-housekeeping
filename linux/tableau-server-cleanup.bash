#!/bin/bash
#Tableau Server on Linux Cleanup Script
#Originally created by Jonathan MacDonald @ The Information Lab

# 	HOW TO USE THIS SCRIPT:
# 		Run the setup.bash script in this Github repo to fetch the script and install it in your system correctly 
#		https://github.com/til-jmac/tableau-server-housekeeping/blob/master/linux/setup.bash
#
#		Test that the script works in your environment by running it manually
#			You must execute the script as a user that is a member of the tsmadmin group
#
#		Run as a user that is a member of the tsmadmin group:
#				/var/opt/tableau/tableau_server/scripts/tableau-server-cleanup.bash
#
#		Schedule the script using cron to run on a regular basis
#		
#		For example, to schedule it to run once a week at 03:00, add this to your crontab
#			0 3 * * 0 /var/opt/tableau/tableau_server/scripts/tableau-server-cleanup.bash > /home/<TSM_USER>/tableau-server-cleanup.log

#VARIABLES SECTION
# Set some variables - you should change these to match your own environment

# Grab the current datetime for timestamping the log entries
TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`

# END OF VARIABLES SECTION

# LOAD ENVIRONMENT & USER INPUT

# Load the Tableau Server environment variables into the cron environment
source /etc/profile.d/tableau_server.sh

# In case that doesn't work then this might do it 
load_environment_file() {
  if [[ -f /etc/opt/tableau/tableau_server/environment.bash ]]; then
    source /etc/opt/tableau/tableau_server/environment.bash
    env_file_exists=1
  fi
}

# Call the environment loading function
load_environment_file

# Function to check TSM availability and configuration
check_tsm_prerequisites() {
  TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
  echo $TIMESTAMP "Checking TSM availability..."
  
  # Check if TSM is available
  if ! command -v tsm &> /dev/null; then
    echo $TIMESTAMP "ERROR: TSM command not found. Please ensure Tableau Server is installed and TSM is in PATH."
    exit 2
  fi
  
  # Check TSM version
  if ! tsm version &> /dev/null; then
    echo $TIMESTAMP "ERROR: TSM is not responsive. Please check Tableau Server status."
    exit 3
  fi
  
  # Check if we can access TSM status
  if ! tsm status &> /dev/null; then
    echo $TIMESTAMP "ERROR: Cannot access TSM status. Please check TSM permissions."
    exit 4
  fi
  
  echo $TIMESTAMP "TSM validation completed successfully."
}

# Verify user is member of tsmadmin group or root
if ! (id -nG | grep -q tsmadmin || [ ${EUID} -eq 0 ]); then
	echo "ERROR: Script must be run as a member of the tsmadmin group or as root."
	exit 1
fi

# Run TSM validation
check_tsm_prerequisites

# CLEANUP SECTION

# cleanup old logs and temp files 
TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
echo $TIMESTAMP "Cleaning up Tableau Server log and temp files..."
tsm maintenance cleanup -l -t
if [ $? -ne 0 ]; then
  TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
  echo $TIMESTAMP "ERROR: Cleanup operation failed."
  exit 5
fi

# END OF CLEANUP SECTION

# END OF SCRIPT
TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
echo $TIMESTAMP "Cleanup completed successfully"