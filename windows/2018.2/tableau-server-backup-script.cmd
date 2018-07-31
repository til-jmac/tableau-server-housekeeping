:: THE INFORMATION LAB HOUSEKEEPING SCRIPT
:: Authored by Jonathan MacDonald
:: Last updated 27/07/2018
:: How to use this script
:: The first part of this script contains all the variables that you should customise to your installation, for example what version of Tableau Server you are running, where you want to save your backup files to, etc.
:: Once you've customised these variables, save the script somewhere in your Tableau Server installation directory, e.g. a 'Scripts' directory
:: Then use a job scheduler to run it to the frequency you require. 
:: Ensure that the user that is assigned to run this script has permissions to run TSM and with elevated (admin) rights 
:: See here for more information: http://www.theinformationlab.co.uk/2014/07/25/tableau-server-housekeeping-made-easy/

@echo OFF

:parse_command_line_params
IF "%1"=="" GOTO end_parse
IF "%1"=="-o" SET overwrite_requested=1
IF "%1"=="--overwrite" SET overwrite_requested=1
IF "%1"=="-n" GOTO name_arg
IF "%1"=="--name" GOTO name_arg

:name_arg
SHIFT
SET filename=%1
SHIFT

:end_parse

:: Let's grab a consistent date
For /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c-%%a-%%b)

:: Let's find the locations of some directories using tsm 

:: Grab the location of this script
SET script_dir=%~dp0

:: Grab the location of the backup directory
FOR /F "tokens=* USEBACKQ" %%F IN (`tsm configuration get -k basefilepath.backuprestore`) DO (SET backuppath=%%F)

:: Derive the location of the install directory 
FOR %%I IN ("%backuppath%\..\..\..\..") DO SET install_dir=%%~fI

:: Set the user that has rights to run TSM commands
SET tsmadmin=someusername

:: Set the password of the above user
SET tsmpassword=somepassword

:: How many DAYS of previous backups do you want to keep? This behaviour will change depending on how frequently you run this script
:: For example, if you run this script daily, and set the number of previous days to 7, then you will always have the most recent 7 backups. 
:: Another example, if you run this script weekly, and you want to keep the last 4 backup files, then set this value to 28
SET backupdays=7

:: Check for previous backups and remove backup files older than N days
echo %date% %time%: Cleaning out old backup files...
forfiles -p %backuppath% -s -m *.tsbak /D -%backupdays% /C "cmd /c del @path"

:: Take the backup
:: First we need to check if a backup exists for today already, since the new TSM backup command will not overwrite a file of the same name
IF "%overwrite_requested%" EQU "1" del %filename%-%mydate% >nul 2>&1

:: Then we take the backup
tsm maintenance backup -f %filename% -d -u %tsmadmin% -p %tsmpassword%

echo Backup Complete

exit 0
