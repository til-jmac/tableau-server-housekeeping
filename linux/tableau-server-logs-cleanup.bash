#!/bin/bash
#Tableau Server on Linux Logs and Cleanup Script
#Originally created by Jonathan MacDonald @ The Information Lab

# 	HOW TO USE THIS SCRIPT:
# 		Run the setup.bash script in this Github repo to fetch the script and install it in your system correctly 
#		https://github.com/til-jmac/tableau-server-housekeeping/blob/master/linux/setup.bash
#
#		Test that the script works in your environment by running it manually
#			You must execute the script as a user that is a member of the tsmadmin group
#			sudo su -l <tsmusername> -c /var/opt/tableau/tableau_server/scripts/tableau-server-housekeeping.sh <tsmusername> <tsmpassword>
#
#		Run as a user that is a member of the tsmadmin group  
#
#		Schedule the script using cron to run on a regular basis
#			sudo su -l $tsmuser -c "crontab -e"
#		
#		For example, to schedule it to run once a day at 01:00, add this to your crontab
#			0 1 * * * /var/opt/tableau/tableau_server/scripts/<SCRIPT_FILE_NAME_HERE> > /home/<TSM_USER>/tableau-server-housekeeping.log

#VARIABLES SECTION
# Set some variables - you should change these to match your own environment

# Grab the current date in YYYY-MM-DD format
DATE=`date +%Y-%m-%d`
# Grab the current datetime for timestamping the log entries
TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
# Do you want to copy your archived logs to another location after completion?
copy_logs="no"
# Where do you want to save your archived logs?
external_log_path="/tmp/log-archives/"
# How many days to you want to keep archived log files for?
log_days="7"
# What do you want to name your logs file? (will automatically append current date to this filename)
log_name="logs"

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
  
  # Check if we can access TSM configuration
  if ! tsm configuration get -k basefilepath.log_archive &> /dev/null; then
    echo $TIMESTAMP "ERROR: Cannot access TSM configuration. Please check TSM permissions."
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

# LOGS SECTION

# get the path to the log archive folder
log_path=$(tsm configuration get -k basefilepath.log_archive)
if [ $? -ne 0 ] || [ -z "$log_path" ]; then
  TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
  echo $TIMESTAMP "ERROR: Failed to retrieve log archive path from TSM configuration."
  exit 5
fi
TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
echo $TIMESTAMP "The path for storing log archives is $log_path" 

# count the number of log files eligible for deletion and output 
TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
echo $TIMESTAMP "Cleaning up old log files..."
lines=$(find "$log_path" -type f -name '*.zip' -mtime +$log_days | wc -l)
if [ $lines -eq 0 ]; then 
	TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
	echo $TIMESTAMP $lines found, skipping...	
else echo $TIMESTAMP $lines found, deleting...
	#remove log archives older than the specified number of days
	find "$log_path" -type f -name '*.zip' -mtime +$log_days -exec rm {} \;
	TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
	echo $TIMESTAMP "Cleaning up completed."		
fi

#archive current logs 
TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
echo $TIMESTAMP "Archiving current logs..."
tsm maintenance ziplogs -t -o -f logs-$DATE.zip
if [ $? -ne 0 ]; then
  TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
  echo $TIMESTAMP "ERROR: Log archive operation failed."
  exit 6
fi
#copy logs to different location (optional)
if [ "$copy_logs" == "yes" ]; then
	TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
	echo $TIMESTAMP "Copying logs to remote share"
	cp "$log_path/$log_name-$DATE" "$external_log_path"/ 
fi

# END OF LOGS SECTION

# CLEANUP AND RESTART SECTION

# cleanup old logs and temp files 
TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
echo $TIMESTAMP "Cleaning up Tableau Server..."
tsm maintenance cleanup -a
if [ $? -ne 0 ]; then
  TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
  echo $TIMESTAMP "ERROR: Cleanup operation failed."
  exit 7
fi
# restart the server (optional, uncomment to run)
	#echo "Restarting Tableau Server"
	#tsm restart

# END OF CLEANUP AND RESTART SECTION

# END OF SCRIPT
TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
echo $TIMESTAMP "Housekeeping completed"
