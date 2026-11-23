#!/bin/bash
#Tableau Server on Linux Housekeeping Script
#Originally created by Jonathan MacDonald @ The Information Lab

# 	HOW TO USE THIS SCRIPT:
# 		Run the setup script to fetch the script and install it in your system correctly 
#
#		Test that the script works in your environment by running it manually
#
#		Run as a user that is a member of the tsmadmin group:
#				sudo su -l <tsmusername> -c /var/opt/tableau/tableau_server/scripts/tableau-server-housekeeping-linux.bash
#
#		Schedule the script using cron to run on a regular basis
#			sudo su -l $tsmuser -c "crontab -e"
#		
#		Schedule it daily: log archive runs immediately before cleanup in this script.
#		ziplogs collects about the last two days of logs by default and cleanup -l removes
#		logs older than one day, so a weekly schedule loses most logs.
#
#		For example, to schedule it to run once a day at 01:00, add this to your crontab
#			0 1 * * * /var/opt/tableau/tableau_server/scripts/tableau-server-housekeeping-linux.bash > /home/<TSM_USER>/tableau-server-housekeeping.log

#VARIABLES SECTION
# Set some variables - you should change these to match your own environment
# Or put your values in /etc/tableau-server-housekeeping.conf (VAR="value" lines): settings
# there override these defaults and survive updates by setup.bash

# Grab the current date in YYYY-MM-DD format
DATE=$(date +%Y-%m-%d)
# Grab the current datetime for timestamping the log entries
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
# The OS group whose members are allowed to run tsm commands
tsm_group="tsmadmin"
# Do you want to copy your backups to another location after completion?
copy_backup="no"
# If yes to above, where do you want to copy them? Must be set to an existing directory when copy_backup is "yes"
external_backup_path=""
# How many days do you want to keep old backup files for? 
backup_days="7"
# What do you want to name your backup files? (will automatically append current date to this filename)
backup_name="tableau-server-backup"
# Do you want to copy your archived logs to another location after completion?
copy_logs="no"
# Where do you want to save your archived logs? Must be set to an existing directory when copy_logs is "yes"
external_log_path=""
# How many days to you want to keep archived log files for?
log_days="7"

# END OF VARIABLES SECTION

# Optional settings file: values in it override the defaults above and survive updates
settings_file="/etc/tableau-server-housekeeping.conf"
if [[ -f "$settings_file" ]]; then
	read -r settings_owner settings_mode < <(stat -c '%u %a' "$settings_file")
	if [[ "$settings_owner" != 0 ]] || (( 8#${settings_mode:-777} & 022 )) || [[ ! -r "$settings_file" ]]; then
		echo "ERROR: $settings_file must be readable, owned by root and not writable by group or others."
		exit 11
	fi
	source "$settings_file"
fi

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
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$TIMESTAMP" "Checking TSM availability..."
  
  # Check if TSM is available
  if ! command -v tsm &> /dev/null; then
    echo "$TIMESTAMP" "ERROR: TSM command not found. Please ensure Tableau Server is installed and TSM is in PATH."
    exit 2
  fi
  
  # Check TSM version
  if ! tsm version &> /dev/null; then
    echo "$TIMESTAMP" "ERROR: TSM is not responsive. Please check Tableau Server status."
    exit 3
  fi
  
  # Check if we can access TSM configuration
  if ! tsm configuration get -k basefilepath.log_archive &> /dev/null; then
    echo "$TIMESTAMP" "ERROR: Cannot access TSM configuration. Please check TSM permissions."
    exit 4
  fi
  
  echo "$TIMESTAMP" "TSM validation completed successfully."
}

# Verify user is member of the TSM group or root
if ! (id -nG | tr ' ' '\n' | grep -qx "$tsm_group" || [ ${EUID} -eq 0 ]); then
	echo "ERROR: Script must be run as a member of the $tsm_group group or as root."
	exit 1
fi

# Validate retention days (backup_days) is a positive integer
if ! [[ "$backup_days" =~ ^[1-9][0-9]*$ ]]; then
	echo "ERROR: backup_days must be a positive integer (got '$backup_days')."
	exit 9
fi

# Validate retention days (log_days) is a positive integer
if ! [[ "$log_days" =~ ^[1-9][0-9]*$ ]]; then
	echo "ERROR: log_days must be a positive integer (got '$log_days')."
	exit 10
fi

# Validate the copy destinations when copying is enabled
if [ "$copy_backup" == "yes" ] && { [ -z "$external_backup_path" ] || [ ! -d "$external_backup_path" ]; }; then
	echo "ERROR: copy_backup is yes but external_backup_path ('$external_backup_path') is empty or not an existing directory."
	exit 12
fi
if [ "$copy_logs" == "yes" ] && { [ -z "$external_log_path" ] || [ ! -d "$external_log_path" ]; }; then
	echo "ERROR: copy_logs is yes but external_log_path ('$external_log_path') is empty or not an existing directory."
	exit 12
fi

# Run TSM validation
check_tsm_prerequisites

# Failures that must not block the backup are remembered here and returned at the end
exit_code=0

# LOGS SECTION

# get the path to the log archive folder
log_path=$(tsm configuration get -k basefilepath.log_archive)
if [ $? -ne 0 ] || [ -z "$log_path" ]; then
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$TIMESTAMP" "ERROR: Failed to retrieve log archive path from TSM configuration."
  exit 5
fi
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "$TIMESTAMP" "The path for storing log archives is $log_path" 

#archive current logs 
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "$TIMESTAMP" "Archiving current logs..."
tsm maintenance ziplogs -t -o -f "logs-$DATE.zip"
if [ $? -ne 0 ]; then
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$TIMESTAMP" "ERROR: Log archive operation failed. Skipping log retention, copy and Tableau Server cleanup, continuing with backup."
  exit_code=6
  logs_archived="no"
else
  logs_archived="yes"
fi

if [ "$logs_archived" == "yes" ]; then
	# count the number of log files eligible for deletion and output 
	TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
	echo "$TIMESTAMP" "Cleaning up old log files..."
	lines=$(find "$log_path" -maxdepth 1 -type f -name 'logs-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].zip' -mtime +"$((log_days - 1))" | wc -l)
	if [ "$lines" -eq 0 ]; then 
		TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
		echo "$TIMESTAMP" "$lines found, skipping..."
	else 
		TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
		echo "$TIMESTAMP" "$lines found, deleting..."
		#remove log archives older than the specified number of days
		find "$log_path" -maxdepth 1 -type f -name 'logs-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].zip' -mtime +"$((log_days - 1))" -exec rm {} \;
		TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
		echo "$TIMESTAMP" "Cleaning up completed."		
	fi
	#copy logs to different location (optional)
	if [ "$copy_logs" == "yes" ]; then
		TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
		echo "$TIMESTAMP" "Copying logs to remote share"
		if ! cp "$log_path/logs-$DATE.zip" "$external_log_path/"; then
			TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
			echo "$TIMESTAMP" "ERROR: Log archive succeeded but copying it to $external_log_path failed (continuing)."
			[ "$exit_code" -eq 0 ] && exit_code=13
		fi
	fi
fi

# END OF LOGS SECTION


# CLEANUP SECTION

# cleanup old logs and temp files 
if [ "$logs_archived" != "yes" ]; then
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$TIMESTAMP" "Skipping Tableau Server cleanup because the log archive failed."
else
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$TIMESTAMP" "Cleaning up Tableau Server..."
  tsm maintenance cleanup -l -t
  if [ $? -ne 0 ]; then
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$TIMESTAMP" "ERROR: Cleanup operation failed. Continuing with backup."
    [ "$exit_code" -eq 0 ] && exit_code=8
  fi
fi

# END OF CLEANUP SECTION


# BACKUP SECTION

# get the path to the backups folder
backup_path=$(tsm configuration get -k basefilepath.backuprestore)
if [ $? -ne 0 ] || [ -z "$backup_path" ]; then
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$TIMESTAMP" "ERROR: Failed to retrieve backup path from TSM configuration."
  exit 5
fi
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "$TIMESTAMP" "The path for storing backups is $backup_path"

#create current backup
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "$TIMESTAMP" "Backup up Tableau Server data..."
tsm maintenance backup -f "$backup_name" -d
if [ $? -ne 0 ]; then
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$TIMESTAMP" "ERROR: Backup operation failed."
  exit 7
fi

#export current settings
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "$TIMESTAMP" "Exporting current settings..."
tsm settings export -f "$backup_path/${backup_name}-settings-$DATE.json"
if [ $? -ne 0 ]; then
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$TIMESTAMP" "ERROR: Settings export failed."
  exit 6
fi

# count the number of backup files eligible for deletion and output
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "$TIMESTAMP" "Cleaning up old backups..."
lines=$(find "$backup_path" -maxdepth 1 -type f \( -name "${backup_name}-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].tsbak" -o -name "${backup_name}-settings-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].json" -o -name 'settings-[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9].json' -o -name 'settings-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].json' \) -mtime +"$((backup_days - 1))" | wc -l)
if [ "$lines" -eq 0 ]; then 
	TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
	echo "$TIMESTAMP" "$lines old backups found, skipping..."
else 
	TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
	echo "$TIMESTAMP" "$lines old backups found, deleting..."
	#remove backup files older than N days
	find "$backup_path" -maxdepth 1 -type f \( -name "${backup_name}-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].tsbak" -o -name "${backup_name}-settings-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].json" -o -name 'settings-[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9].json' -o -name 'settings-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].json' \) -mtime +"$((backup_days - 1))" -exec rm -f {} \;
fi
#copy backups to different location (optional)
if [ "$copy_backup" == "yes" ]; then
	TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
	echo "$TIMESTAMP" "Copying backup and settings to remote share"
	if ! cp "$backup_path"/* "$external_backup_path"/; then
		TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
		echo "$TIMESTAMP" "ERROR: Backup succeeded but copying it to $external_backup_path failed."
		[ "$exit_code" -eq 0 ] && exit_code=13
	fi
fi

# END OF BACKUP SECTION

# RESTART SECTION

# restart the server (optional, uncomment to run)
	#echo "Restarting Tableau Server"
	#tsm restart

# END OF RESTART SECTION

# END OF SCRIPT
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
if [ "$exit_code" -ne 0 ]; then
  echo "$TIMESTAMP" "Housekeeping completed with errors (exit code $exit_code)"
  exit "$exit_code"
fi
echo "$TIMESTAMP" "Housekeeping completed"
