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
#		NOTE you have to add your tsm username and password at the end of the command to execute the script. 
#			This avoids you having to hardcode credentials into the script itself
#
#		*UPDATE* starting in 2019.2 the above requirement to include credentials will no longer be necessary,
# 			provided the user executing the script is a member of the tsmadmin group  
#
#		Schedule the script using cron to run on a regular basis
#			sudo su -l $tsmuser -c "crontab -e"
#		
#		For example, to schedule it to run once a day at 01:00, add this to your crontab
#			0 1 * * * /var/opt/tableau/tableau_server/scripts/tableau-server-housekeeping-linux.sh > /home/<tsmuser>/tableau-server-housekeeping.log

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

if [ "$#" -eq 2 ] ; then
	# Get tsm username from command line input
	tsmuser="$1"
	# Get tsm password from command line input
	tsmpassword="$2" 
	tsmparams="-u $tsmuser -p $tsmpassword"
elif [ $(echo $TABLEAU_SERVER_DATA_DIR_VERSION | cut -d. -f1) -ge 20192 ]  && (id -nG | grep -q tsmadmin || [ ${EUID} -eq 0 ]) ; then 
	# 2019.2 workflow. If running as tsmadmin member or root, do not set userinfo
	declare tsmparams
fi

# LOGS SECTION

# get the path to the log archive folder
log_path=$(tsm configuration get -k basefilepath.log_archive $tsmparams)
echo $TIMESTAMP "The path for storing log archives is $log_path" 

# count the number of log files eligible for deletion and output 
echo $TIMESTAMP "Cleaning up old log files..."
lines=$(find $log_path -type f -name '*.zip' -mtime +$log_days | wc -l)
if [ $lines -eq 0 ]; then 
	echo $TIMESTAMP $lines found, skipping...
	
	else $TIMESTAMP $lines found, deleting...
		#remove log archives older than the specified number of days
		find $log_path -type f -name '*.zip' -mtime +$log_days -exec rm {} \;
	echo $TIMESTAMP "Cleaning up completed."		
fi

#archive current logs 
echo $TIMESTAMP "Archiving current logs..."
tsm maintenance ziplogs -a -t -o -f logs-$DATE.zip $tsmparams
#copy logs to different location (optional)
if [ "$copylogs" == "yes" ];
	then
	echo $TIMESTAMP "Copying logs to remote share"
	cp $log_path/$log_name-$DATE $external_log_path/ 
fi

# END OF LOGS SECTION

# CLEANUP AND RESTART SECTION

# cleanup old logs and temp files 
echo $TIMESTAMP "Cleaning up Tableau Server..."
tsm maintenance cleanup -a $tsmparams
# restart the server (optional, uncomment to run)
	#echo "Restarting Tableau Server"
	#tsm restart $tsmparams

# END OF CLEANUP AND RESTART SECTION

# END OF SCRIPT
echo $TIMESTAMP "Housekeeping completed"
