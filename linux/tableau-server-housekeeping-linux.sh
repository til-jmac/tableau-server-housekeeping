#!/bin/bash
#Tableau Server on Linux Housekeeping Script
#Originally created by Jonathan MacDonald @ The Information Lab

# 	HOW TO USE THIS SCRIPT:
#		Create a new directory called scripts in your Tableau server data directory… 
#			mkdir /var/opt/tableau/tableau_server/data/scripts
#
#		Copy this file to your server into the above folder… 
#			cp tableau-server-housekeeping.sh /var/opt/tableau/tableau_server/data/scripts/
#
#		Change ownership of this directory and its contents to user:tsmagent and group:tableau… 
#			sudo chown -R tsmagent:tableau /var/opt/tableau/tableau_server/data/scripts/
#
#		Make the script executable… 
#			sudo chmod +x /var/opt/tableau/tableau_server/data/scripts/tableau-server-housekeeping.sh
#
#		Execute the script as the tsm admin user to test it works correctly in your environment…
#			su $tsmuser -c /var/opt/tableau/tableau_server/data/scripts/tableau-server-housekeeping.sh
#
#		Schedule it using cron to run on a regular basis…
#			su $tsmuser -c "crontab -e"
#		
#		For example, to schedule it to run once a day at 01:00, add this to your crontab…
#			0 1 * * * /var/opt/tableau/tableau_server/data/scripts/tableau-server-housekeeping-linux.sh > /home/$tsmuser/tableau-server-housekeeping.log


#VARIABLES SECTION
# Set some variables - you should change these to match your own environment

# Grab the current date in YYYY-MM-DD format
DATE=`date +%Y-%m-%d`
# Grab the current datetime for timestamping the log entries
TIMESTAMP=`date '+%Y-%m-%d %H:%M:%S'`
# Tableau Server version
VERSION=$TABLEAU_SERVER_DATA_DIR_VERSION
# Path to TSM executable
TSMPATH="/opt/tableau/tableau_server/packages/customer-bin.$VERSION"
# Export this path to environment variables (for cron to run properly)
#PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:$TSMPATH
# Who is your TSM administrator user?
tsmuser="tsmadmin"
# What is your TSM administrator user's password?
tsmpassword="tableau123"
# Where is your Tableau Server data directory installed? No need to change if default
data_path=$TABLEAU_SERVER_DATA_DIR

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

# LOGS SECTION

# get the path to the log archive folder
log_path=$(tsm configuration get -k basefilepath.log_archive -u $tsmuser -p $tsmpassword)
echo $TIMESTAMP "The path for storing log archives is $log_path" 

#go to logs path
#cd $log_path

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

# go to the backup path
# cd $backup_path

# count the number of log files eligible for deletion and output 
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
