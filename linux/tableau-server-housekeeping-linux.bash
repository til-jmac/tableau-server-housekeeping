#!/bin/bash
#Tableau Server on Linux Housekeeping Script
#Originally created by Jonathan MacDonald @ The Information Lab

# 	HOW TO USE THIS SCRIPT:
# 		Run the setup script to fetch the script and install it in your system correctly 
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
# Do you want to copy your backups to another location after completion?
copy_backup="no"
# If yes to above, where do you want to copy them? 
external_backup_path="/tmp/backups/"
# How many days do you want to keep old backup files for? 
backup_days="7"
# What do you want to name your backup files? (will automatically append current date to this filename)
backup_name="tableau-server-backup"
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

# Get tsm username from command line
tsmuser=$1

# Get tsm password from command line
tsmpassword=$2 

# Load the Tableau Server environment variables into the cron environment
source /etc/profile.d/tableau_server.sh

# In case that doesn't work then this might do it 
load_environment_file() {
  if [[ -f /etc/opt/tableau/tableau_server/environment.bash ]]; then
    source /etc/opt/tableau/tableau_server/environment.bash
    env_file_exists=1
  fi
}

# LOGS SECTION

# get the path to the log archive folder
log_path=$(tsm configuration get -k basefilepath.log_archive -u $tsmuser -p $tsmpassword)
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
tsm maintenance ziplogs -a -t -o -f logs-$DATE.zip -u $tsmuser -p $tsmpassword
#copy logs to different location (optional)
if [ "$copylogs" == "yes" ];
	then
	echo $TIMESTAMP "Copying logs to remote share"
	cp $log_path/$log_name-$DATE $external_log_path/ 
fi

# END OF LOGS SECTION

# BACKUP SECTION

# get the path to the backups folder
backup_path=$(tsm configuration get -k basefilepath.backuprestore -u $tsmuser -p $tsmpassword)
echo $TIMESTAMP "The path for storing backups is $backup_path" 

# count the number of backup files eligible for deletion and output 
echo $TIMESTAMP "Cleaning up old backups..."
lines=$(find $backup_path -type f -name '*.tsbak' -mtime +$backup_days | wc -l)
if [ $lines -eq 0 ]; then 
	echo $TIMESTAMP $lines old backups found, skipping...
	else $TIMESTAMP $lines old backups found, deleting...
		#remove backup files older than N days
		find $backup_path -type f -name '*.tsbak' -mtime +$backup_days -exec rm {} \;
fi

#export current settings
echo $TIMESTAMP "Exporting current settings..."
tsm settings export -f $backup_path/settings.json -u $tsmuser -p $tsmpassword
#create current backup
echo $TIMESTAMP "Backup up Tableau Server data..."
tsm maintenance backup -f $backup_name -d -u $tsmuser -p $tsmpassword
#copy backups to different location (optional)
if [ "$copybackup" == "yes" ];
	then
	echo $TIMESTAMP "Copying backup and settings to remote share"
	cp $backup_path/* $external_backup_path/
fi

# END OF BACKUP SECTION

# CLEANUP AND RESTART SECTION

# cleanup old logs and temp files 
echo $TIMESTAMP "Cleaning up Tableau Server..."
tsm maintenance cleanup -a -u $tsmuser -p $tsmpassword
# restart the server (optional, uncomment to run)
	#echo "Restarting Tableau Server"
	#tsm restart -u $tsmuser -p $tsmpassword

# END OF CLEANUP AND RESTART SECTION

# END OF SCRIPT
echo $TIMESTAMP "Housekeeping completed"