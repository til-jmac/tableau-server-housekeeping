:: THE INFORMATION LAB CLEANUP SCRIPT
:: https://github.com/til-jmac/tableau-server-housekeeping
:: Authored by Jonathan MacDonald
:: Last updated 17/06/2019
:: How to use this script
:: By default, Tableau Server does not automatically archive/delete its log files. 
:: So a process is required to firstly archive old log files, then clean up the current logs to free up disk space. 
:: This script helps with the second part, by cleaning out the current, active logs.
:: To archive these logs prior to deletion, you will want to run a ziplogs command, I have a script for that too.
:: 1) I would recommend you schedule this script to run once a week, immediately following the log archival script
:: 2) Use this script in conjunction with my log archival and backup scripts, which you can find at the Github link above
:: 3) Run this script with elevated privileges as the user that has permissions to run TSM
:: 4) You MUST input all command line parameters in the order specified, or the script will fail
:: 5) This will execute the cleanup script with the following options: -l (deletes old log files) -t (deletes old temp files) -v (verbose output)
::    Modify the script below if you would like to change those options
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

:: Parses command line parameters
:parse_command_line_params
IF "%1"=="" GOTO end_parse
IF "%1"=="-u" GOTO tsmadmin_arg
IF "%1"=="--username" GOTO tsmadmin_arg
IF "%1"=="-p" GOTO tsmpassword_arg
IF "%1"=="--password" GOTO tsmpassword_arg
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

:: Then we archive the logs
:cleanup
ECHO %date% %time% : Cleaning up Tableau Server log and temp files
CALL tsm maintenance cleanup -l  -t -v -u %tsmadmin% -p %tsmpassword%

:end_msg
IF %ERRORLEVEL% EQU 0 (
	ECHO %date% %time% : Cleanup completed succesfully. 
	EXIT /B 0 
	)
IF %ERRORLEVEL% GTR 0 (
	ECHO %date% %time% : Cleanup failed with exit code %ERRORLEVEL%
	GOTO show_help
	) 

:show_help
ECHO Usage: 
ECHO tableau-server-cleanup-script.cmd -u ^<username^> -p ^<password^>
ECHO Global parameters (use in sequence):
ECHO 		-u,--username 		TSM administrator username
ECHO 		-p,--password 		TSM administrator password 
ECHO 		-h,--help 		Show this help 
EXIT /B 3