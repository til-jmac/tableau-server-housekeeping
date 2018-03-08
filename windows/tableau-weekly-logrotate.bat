:: THE INFORMATION LAB WEEKLY LOG ROTATION SCRIPT
:: Authored by Jonathan MacDonald
:: Last updated 04/10/2016
:: How to use this script
:: The first part of this script contains all the variables that you should customise to your installation, for example what version of Tableau Server you are running, where you want to save your backup files to, etc.
:: Once you've customised these variables, save the script somewhere in your Tableau Server installation directory, e.g. a 'Scripts' directory, and then use a job scheduler to run it to the frequency you require.
:: See here for more information: http://www.theinformationlab.co.uk/2014/07/25/tableau-server-housekeeping-made-easy/
 
@echo OFF
 
:: VARIABLES SECTION - PLEASE CUSTOMISE THESE VARIABLES TO YOUR SYSTEM HERE!
 
set VERSION=10.2
:: Please customise this to the version of Tableau Server you are running.
 
set "BINPATH=D:\Program Files\Tableau\Tableau Server\%VERSION%\bin"
:: In case you don't have tabadmin set in your Path environment variable, this command sets the path to the Tableau Server bin directory in order to use the tabadmin command.
:: Customise this to match your the path of your Tableau Server installation. The version variable above is included.
 
set "BACKUPPATH=D:\Backups\"
:: This command sets the path to the backup folder.
:: Change this to match the location of the folder you would like to save your backups to
 
set "LOGPATH=D:\Backups\Logs"
:: This command sets the path to the log files folder
:: Change this to match the location of the folder you would like to save your zipped log files to
 
set SAVESTAMP=%DATE%
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
move logs.zip %LOGPATH%\logs-uat-%SAVESTAMP%.zip
:: Grabs the Tableau Server logfiles and zips them
:: Then moves the zip file to the specified directory appending the system date to the filename