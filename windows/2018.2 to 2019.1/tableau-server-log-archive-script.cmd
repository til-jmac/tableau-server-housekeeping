:: THE INFORMATION LAB LOG ARCHIVAL SCRIPT
:: https://github.com/til-jmac/tableau-server-housekeeping
:: Authored by Jonathan MacDonald
:: Last updated 17/06/2019
:: How to use this script
:: By default, Tableau Server does not automatically archive/delete its log files. 
:: So a process is required to firstly archive old log files, then clean up the current logs to free up disk space. 
:: This script helps with the first part, by archiving old log files. This script will also clean out the ARCHiVED logs older than N days.
:: To clean out the current, active log files, you will want to run the cleanup command, I have a script for that too.
:: 1) I would recommend you schedule this script to run once a week
:: 2) Use this script in conjunction with my backup and cleanup scripts, which you can find at the Github link above
:: 3) Run this script with elevated privileges as the user that has permissions to run TSM
:: 4) You MUST input all command line parameters in the order specified, or the script will fail
:: Give me a shout on Twitter @macdonaldj for questions, comments or feedback

@echo OFF
cls

:: Checks that the script is being run with Admin rights. 
:check_admin
NET SESSION >NUL 2>&1
if %ERRORLEVEL% NEQ 0 (
  ECHO %date% %time% : This script must be run as Administrator. Cancelling.
  EXIT /B 1
)

:: Let's grab a consistent date in the same format that Tableau Server writes the date to the end of the backup file name
:set_date
FOR /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') DO SET "dt=%%a"
SET "YY=%dt:~2,2%" & SET "YYYY=%dt:~0,4%" & SET "MM=%dt:~4,2%" & SET "DD=%dt:~6,2%"
SET "HH=%dt:~8,2%" & SET "Min=%dt:~10,2%" & SET "Sec=%dt:~12,2%"
SET "mydate=%YYYY%-%MM%-%DD%"

:: Parses command line parameters
:parse_command_line_params
IF "%1"=="" GOTO end_parse
IF "%1"=="-u" GOTO tsmadmin_arg
IF "%1"=="--username" GOTO tsmadmin_arg
IF "%1"=="-p" GOTO tsmpassword_arg
IF "%1"=="--password" GOTO tsmpassword_arg
IF "%1"=="-d" GOTO archivedays_arg
IF "%1"=="--days" GOTO archivedays_arg
IF "%1"=="-h" GOTO show_help
IF "%1"=="--help" GOTO show_help

:tsmadmin_arg
SHIFT
SET tsmadmin=%1
ECHO %date% %time% : Executing TSM as user: "%tsmadmin%"
SHIFT
GOTO parse_command_line_params

:tsmpassword_arg
SHIFT
SET tsmpassword=%1
ECHO %date% %time% : Using %tsmadmin% password: "***SECRET***"
SHIFT
GOTO parse_command_line_params

:archivedays_arg
SHIFT
SET archivedays=%1
ECHO %date% %time% : Setting the log archive retention period to "%archivedays%" days
SHIFT
GOTO parse_command_line_params

:end_parse

:check_username
IF "%tsmadmin%" == "" (
	ECHO ERROR: Please specify a valid TSM user. Cancelling. 
	GOTO show_help
	)

:check_password
IF "%tsmpassword%" == "" (
	ECHO ERROR: Please specify a valid TSM password. Cancelling.
	GOTO show_help
	)

:check_retention_period
IF "%archivedays%" == "" (
	ECHO ERROR: Please specify a valid log archive retention period. Cancelling.
	GOTO show_help
	)

:: Grab the location of the log archive directory
:set_archive_dir
ECHO %date% %time% : Getting the location of the default log archive directory
FOR /F "tokens=* USEBACKQ" %%F IN (`tsm configuration get -k basefilepath.log_archive -u %tsmadmin% -p %tsmpassword%`) DO (SET "archivepath=%%F")
ECHO The default archive path is: 
ECHO %archivepath%

:: In v2018.2.0 the slashes in the default path are the wrong direction, so let's fix this
:fix_archive_dir
SET "archivepath=%archivepath:/=\%"
ECHO The corrected archive path is now: 
ECHO %archivepath% 

:: Now let's actually do some stuff
:: Check for previous log archives and remove files older than N days
:delete_old_files
ECHO %date% %time% : Cleaning out archive files older than %archivedays% days
FORFILES -p "%archivepath%" -s -m *.zip /D -%archivedays% /C "cmd /c del @path" 2>nul

:: Then we archive the logs
:archive
ECHO %date% %time% : Archiving Tableau Server log files
CALL tsm maintenance ziplogs -a -o -f logs-%mydate% -u %tsmadmin% -p %tsmpassword%

:end_msg
IF %ERRORLEVEL% EQU 0 (
	ECHO %date% %time% : Log archival completed succesfully. 
	EXIT /B 0 
	)
IF %ERRORLEVEL% GTR 0 (
	ECHO %date% %time% : Log archival failed with exit code %ERRORLEVEL%
	GOTO show_help
	) 

:show_help
ECHO Usage: 
ECHO tableau-server-log-archive-script.cmd -u ^<username^> -p ^<password^> -d ^<days^>
ECHO Global parameters (use in sequence):
ECHO 		-u,--username 		TSM administrator username
ECHO 		-p,--password 		TSM administrator password 
ECHO 		-d,--days 		Delete log archives in the log archive path older than N days
ECHO 		-h,--help 		Show this help 
EXIT /B 3
