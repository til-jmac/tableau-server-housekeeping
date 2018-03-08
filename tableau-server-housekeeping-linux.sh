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
VERSION="10500.18.0210.2209"
# Path to TSM executable
TSMPATH="/opt/tableau/tableau_server/packages/customer-bin.$VERSION"
# Export this path to environment variables (for cron to run properly)
PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:$TSMPATH
# Who is your TSM administrator user?
tsmuser="tsmadmin"
# What is your TSM administrator user's password?
tsmpassword="tableau123"
# Where is your Tableau Server data directory installed? No need to change if default
datapath="/var/opt/tableau/tableau_server"

# Do you want to copy your backups to another location after completion?
copybackup="no"
# If yes to above, where do you want to copy them? 
backuppath="/tmp/backups/"
# How many days do you want to keep old backup files for? 
backupdays="7"
# What do you want to name your backup files? (will automatically append current date to this filename)
backupname="tableau-server-backup"

# Do you want to copy your archived logs to another location after completion?
copylogs="no"
# Where do you want to save your archived logs?
logpath="/tmp/log-archives/"
# How many days to you want to keep archived log files for?
logdays="7"
# What do you want to name your logs file? (will automatically append current date to this filename)
logsname="logs"

# END OF VARIABLES SECTION

# LOGS SECTION

#go to logs path
cd $datapath/data/tabsvc/files/log-archives/
echo $TIMESTAMP "Cleaning up old log files..."
# count the number of log files eligible for deletion and output 
lines=$(find $datapath/data/tabsvc/files/log-archives/ -type f -name '*.zip' -mtime +$logdays | wc -l)
if [ $lines -eq 0 ]; then 
	echo $TIMESTAMP $lines found, skipping...
	
	else $TIMESTAMP $lines found, deleting...
		#remove log archives older than the specified number of days
		find $datapath/data/tabsvc/files/log-archives/ -type f -name '*.zip' -mtime +$logdays -exec rm {} \;
	echo $TIMESTAMP "Cleaning up completed."		
fi


#archive current logs 
echo $TIMESTAMP "Archiving current logs..."
tsm maintenance ziplogs -a -t -o -f logs-$DATE.zip -u $tsmuser -p $tsmpassword
#copy logs to different location (optional)
if [ "$copylogs" == "yes" ];
	then
	echo $TIMESTAMP "Copying logs to remote share"
	cp $datapath/data/tabsvc/files/log-archives/$logsname-$DATE
fi

# END OF LOGS SECTION

# BACKUP SECTION

cd $datapath/data/tabsvc/files/backups/
echo $TIMESTAMP "Cleaning up old backups..."
# count the number of log files eligible for deletion and output 
lines=$(find $datapath/data/tabsvc/files/backups/ -type f -name '*.tsbak' -mtime +$backupdays | wc -l)
if [ $lines -eq 0 ]; then 
	echo $TIMESTAMP $lines old backups found, skipping...
	else $TIMESTAMP $lines old backups found, deleting...
		#remove backup files older than N days
		find $datapath/data/tabsvc/files/backups/ -type f -name '*.tsbak' -mtime +$backupdays -exec rm {} \;
fi

#export current settings
echo $TIMESTAMP "Exporting current settings..."
tsm settings export -f $datapath/data/tabsvc/files/backups/settings.json -u $tsmuser -p $tsmpassword
#create current backup
echo $TIMESTAMP "Backup up Tableau Server data..."
tsm maintenance backup -f $backupname -d -u $tsmuser -p $tsmpassword
#copy backups to different location (optional)
if [ "$copybackup" == "yes" ];
	then
	echo $TIMESTAMP "Copying backup and settings to remote share"
	cp $datapath/data/tabsvc/files/backups/* $backuppath/
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