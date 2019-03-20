# Housekeeping scripts for Tableau Server
* Windows and Linux versions
* Customise these scripts for your environment by editing the variables at the top of each script OR making use of the command line parameters where offered. 
* Automate running them in cron (Linux) or Task Scheduler (Windows), or whatever enterprise job manager you use

The Linux version currently performs a backup, log archive, and cleanup all in one go, while the Windows versions are split up into three separate scripts. I plan to split up the Linux version too, for ease of use. You might also want to schedule a backup every day, but a log archive/cleanup once a week, for example.

## Windows version
These are divided into pre-2018.2 and post-2018.2 sections. 

**Pre-2018.28** these scripts require modification to match your environment. Open these in a text editor and edit the variables as needed.

**Post-2018.2** these scripts require you to input parameters at the command line, see below for example help, or run your chosen script with the '-h' parameter:

Usage: 
tableau-server-backup-script.cmd -n <filename> -u <username> -p <password> -d <days> -o <true/false>

Required parameters (use in sequence):
 		-n,--name 			Name of the backup file (no spaces, periods or funny characters)
 		-u,--username 		TSM administrator username
 		-p,--password 		TSM administrator password 
 		-d,--days 			Delete backup files in the backup location older than N days
 		-o,--overwrite 		Overwrite any existing backup with the same name (takes appended date into account)
 		-h,--help 			Show this help  

## Linux version

**Easy way** download and execute the *setup.bash* script to set up the housekeeping script on your server. This downloads the housekeeping script, installs it in a scripts folder in your Tableau Server data directory, and fixes its permissions so it's ready to run. The follow the instructions in the housekeeping script itself to schedule it in cron

**Expert way** download the housekeeping script yourself, modify and execute as needed 

## 2019.2 
Starting with 2019.2, TSM will no longer require credentials provided the user executing the TSM command is a member of the tsmadmin group (Linux) or the Local Administrators group (Windows). I will be working on updating these scripts to accommodate both old and new versions. 

###### NOTE these scripts are a work in progress and are offered with no support. Updates to Tableau software may result in these scripts breaking, and it might be a while before I get round to updating them, so please always test them first to ensure they do what you expect them to do. 

Find me on [twitter](https://twitter.com/macdonaldj) if you want to feed back, or just have a chat.

