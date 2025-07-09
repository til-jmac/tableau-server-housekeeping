#!/bin/bash
#Tableau Server on Linux Log Archive Script
#Originally created by Jonathan MacDonald @ The Information Lab

# 	HOW TO USE THIS SCRIPT:
# 		Run the setup.bash script in this Github repo to fetch the script and install it in your system correctly 
#		https://github.com/til-jmac/tableau-server-housekeeping/blob/master/linux/setup.bash
#
#		Test that the script works in your environment by running it manually
#			You must execute the script as a user that is a member of the tsmadmin group
#
#		NOTE If Server release is behind 2019.2, you have to add your tsm username and password at the end of the command to execute the script. 
#			This avoids you having to hardcode credentials into the script itself
#
#				/var/opt/tableau/tableau_server/scripts/tableau-server-log-archive.bash <tsmusername> <tsmpassword> <days>
#
#		*UPDATE* starting in 2019.2 the above requirement to include credentials will no longer be necessary,
# 			provided the user executing the script is a member of the tsmadmin group  
#				/var/opt/tableau/tableau_server/scripts/tableau-server-log-archive.bash <days>
#
#		Schedule the script using cron to run on a regular basis
#		
#		For example, to schedule it to run once a week at 02:00, add this to your crontab
#			0 2 * * 0 /var/opt/tableau/tableau_server/scripts/tableau-server-log-archive.bash 7 > /home/<TSM_USER>/tableau-server-log-archive.log

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
  if ! tsm configuration get -k basefilepath.log_archive $tsmparams &> /dev/null; then
    echo $TIMESTAMP "ERROR: Cannot access TSM configuration. Please check TSM permissions."
    exit 4
  fi
  
  echo $TIMESTAMP "TSM validation completed successfully."
}

# Parse command line arguments
if [ "$#" -eq 3 ] ; then
	# Get tsm username from command line input
	tsmuser="$1"
	# Get tsm password from command line input
	tsmpassword="$2"
	# Get retention days from command line input
	log_days="$3"
	tsmparams="-u $tsmuser -p $tsmpassword"
elif [ "$#" -eq 1 ] && [ $(echo $TABLEAU_SERVER_DATA_DIR_VERSION | cut -d. -f1) -ge 20192 ]  && (id -nG | grep -q tsmadmin || [ ${EUID} -eq 0 ]) ; then 
	# 2019.2 workflow. If running as tsmadmin member or root, do not set userinfo
	log_days="$1"
	declare tsmparams
else
	echo "Usage: $0 [<username> <password>] <retention_days>"
	echo "  retention_days: Delete log archives older than N days"
	echo "  For Tableau Server 2019.2+, credentials are not required if running as tsmadmin member"
	exit 1
fi

# Run TSM validation
check_tsm_prerequisites

# LOGS SECTION

# get the path to the log archive folder
log_path=$(tsm configuration get -k basefilepath.log_archive $tsmparams)
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
else 
	TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
	echo $TIMESTAMP $lines found, deleting...
	#remove log archives older than the specified number of days
	find "$log_path" -type f -name '*.zip' -mtime +$log_days -exec rm {} \;
	TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
	echo $TIMESTAMP "Old log cleanup completed."		
fi

#archive current logs 
TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
echo $TIMESTAMP "Archiving current logs..."
tsm maintenance ziplogs -a -o -f logs-$DATE.zip $tsmparams
if [ $? -ne 0 ]; then
  TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
  echo $TIMESTAMP "ERROR: Log archive operation failed."
  exit 6
fi

#copy logs to different location (optional)
if [ "$copy_logs" == "yes" ]; then
	TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
	echo $TIMESTAMP "Copying logs to remote share"
	cp "$log_path/logs-$DATE.zip" "$external_log_path/"
fi

# END OF LOGS SECTION

# END OF SCRIPT
TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
echo $TIMESTAMP "Log archival completed successfully"