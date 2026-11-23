:: THE INFORMATION LAB HOUSEKEEPING SCRIPT
:: Authored by Jonathan MacDonald
:: Last updated 04/10/2016
:: How to use this script
:: The first part of this script contains all the variables that you should customise to your installation, for example what version of Tableau Server you are running, where you want to save your backup files to, etc.
:: Once you've customised these variables, save the script somewhere in your Tableau Server installation directory, e.g. a 'Scripts' directory, and then use a job scheduler to run it to the frequency you require.
:: See here for more information: http://www.theinformationlab.co.uk/2014/07/25/tableau-server-housekeeping-made-easy/
 
@echo OFF
 
:: VARIABLES SECTION - PLEASE CUSTOMISE THESE VARIABLES TO YOUR SYSTEM HERE!
 
set VERSION=10.0
:: Please customise this to the version of Tableau Server you are running.
 
set "BINPATH=D:\Program Files\Tableau\Tableau Server\%VERSION%\bin"
:: In case you don't have tabadmin set in your Path environment variable, this command sets the path to the Tableau Server bin directory in order to use the tabadmin command.
:: Customise this to match your the path of your Tableau Server installation. The version variable above is included.
 
set "BACKUPPATH=C:\Program Files\Tableau\Backups"
:: This command sets the path to the backup folder.
:: Change this to match the location of the folder you would like to save your backups to
 
set "LOGPATH=C:\Program Files\Tableau\Backups"
:: This command sets the path to the log files folder
:: Change this to match the location of the folder you would like to save your zipped log files to
 
set SAVESTAMP=%DATE:/=-%
:: This command creates a variable called SAVESTAMP which grabs the system time and formats in to look like DD-MM-YYYY
:: This gets rid of the slashes in the system date which messes up the commands later when we're trying to append the date to the filename
 
:: SCRIPT INITIATION
 
echo %date% %time%: *** Housekeeping started ***
:: Prints that text to the DOS prompt
 
cd /d %BINPATH%
:: changes directory to the above path and takes into account a drive change with the /d command
 
:: ROTATING THE LOG FILES
 
echo %date% %time%: Cleaning out old log files...
forfiles -p %LOGPATH% -s -m *.zip /D -28 /C "cmd /c del @path"
:: Cleans out files in the specified directory that end with a .zip extension and are older than 28 days
:: If you are running this script weekly, this ensures that only 4 weeks of log files are saved.
:: You will likely want to adjust this if you plan to run this script more frequently.
 
echo %date% %time%: Backing up log files...
tabadmin ziplogs -l -n -f
move logs.zip %LOGPATH%\logs-%SAVESTAMP%.zip
:: Grabs the Tableau Server logfiles and zips them
:: Then moves the zip file to the specified directory appending the system date to the filename
 
:: BACKING UP THE TABLEAU SERVER
 
echo %date% %time%: Cleaning out old backup files...
forfiles -p %BACKUPPATH% -s -m *.tsbak /D -14 /C "cmd /c del @path"
:: Cleans out files in the specified directory that end in .tsbak extension and are older than 14 days
:: If you are running this script weekly, this ensures that only 2 backup files are saved.
:: You will likely want to adjust this if you plan to run this script more frequently.
 
echo %date% %time%: Backing up data...
tabadmin backup %BACKUPPATH%\tableau-server-backup -d
:: Backs up the Tableau Server and creates a file ts_backup.tsbak with the system date appended to the filename
 
:: CLEANUP AND RESTART
 
echo %date% %time%: Running cleanup and restarting Tableau server...
tabadmin stop
tabadmin cleanup
tabadmin start
:: Cleans out the Tableau server logs after stopping the server to ensure all logs and temp files are cleaned up, but not the HTTP requests table in the Postgres, so your usage stats are retained.
 
echo %date% %time%: *** Housekeeping completed ***
:: Prints that text to the DOS prompt to show that the jobs are all done