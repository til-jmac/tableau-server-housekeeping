:: THE INFORMATION LAB LOG ARCHIVAL SCRIPT
:: https://github.com/til-jmac/tableau-server-housekeeping
:: Authored by Jonathan MacDonald
:: Last updated 14/08/2020
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

:: Exit codes:
::   0  Success (or help shown)
::   1  Not run as Administrator
::   2  TSM not available
::   3  Cannot read TSM configuration
::   5  Configured log archive path is empty
::   6  ziplogs failed
::   8  Could not determine the date stamp
::   10 Missing or invalid arguments

@echo OFF
SETLOCAL
cls

:: Sets global script variables for later
SET "archivedays="

:: Parses command line parameters
:parse_command_line_params
IF "%~1"=="" GOTO end_parse
IF "%~1"=="-d" GOTO archivedays_arg
IF "%~1"=="--days" GOTO archivedays_arg
IF "%~1"=="-h" GOTO show_help
IF "%~1"=="--help" GOTO show_help
ECHO ERROR: Unrecognised argument: "%~1"
GOTO invalid_args

:archivedays_arg
SET "archivedays=%~2"
ECHO %date% %time% : Setting the log archive retention period to "%archivedays%" days
SHIFT
SHIFT
GOTO parse_command_line_params

:end_parse

:check_retention_period
IF NOT DEFINED archivedays (
	ECHO ERROR: Please specify a valid log archive retention period. Cancelling.
	GOTO invalid_args
	)

:: Checks that the script is being run with Admin rights. fltmc needs elevation but, unlike NET SESSION, not the Server service.
:check_admin
fltmc >NUL 2>&1
if %ERRORLEVEL% NEQ 0 (
  ECHO %date% %time% : This script must be run as Administrator. Cancelling.
  EXIT /B 1
)

:: Check if TSM is available and responsive
:check_tsm_availability
ECHO %date% %time% : Checking TSM availability
CALL tsm version >NUL 2>&1
if %ERRORLEVEL% NEQ 0 (
  ECHO %date% %time% : ERROR: TSM is not available or not in PATH. Please ensure Tableau Server is installed and TSM is accessible.
  EXIT /B 2
)

:: Let's grab a consistent date in the same format that Tableau Server writes the date to the end of the backup file name
:set_date
SET "mydate="
FOR /F %%a IN ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') DO SET "mydate=%%a"
IF NOT DEFINED mydate (
  ECHO %date% %time% : ERROR: Could not determine the current date using PowerShell.
  EXIT /B 8
)

:: Grab the location of the log archive directory
:: tsm output goes to a temp file so we can check its exit code and show its error message on failure
:set_archive_dir
ECHO %date% %time% : Getting the location of the default log archive directory
SET "tmpfile=%TEMP%\tableau-log-archive-script-%RANDOM%.tmp"
CALL tsm configuration get -k basefilepath.log_archive > "%tmpfile%" 2>&1
if %ERRORLEVEL% NEQ 0 (
  ECHO %date% %time% : ERROR: Cannot read basefilepath.log_archive from TSM configuration. Please ensure you have proper TSM permissions. TSM output:
  TYPE "%tmpfile%"
  DEL /F "%tmpfile%" >NUL 2>&1
  EXIT /B 3
)
SET "archivepath="
FOR /F "usebackq tokens=*" %%F IN ("%tmpfile%") DO SET "archivepath=%%F"
DEL /F "%tmpfile%" >NUL 2>&1
IF NOT DEFINED archivepath (
  ECHO %date% %time% : ERROR: Log archive directory path is empty. Please check TSM configuration.
  EXIT /B 5
)
ECHO The default archive path is:
ECHO %archivepath%

:: In v2018.2.0 the slashes in the default path are the wrong direction, so let's fix this
:fix_archive_dir
SET "archivepath=%archivepath:/=\%"
:: Strip one trailing backslash, otherwise FORFILES /P "...\" reads it as an escaped quote
IF "%archivepath:~-1%"=="\" SET "archivepath=%archivepath:~0,-1%"
ECHO The corrected archive path is now:
ECHO %archivepath%

:: Now let's actually do some stuff
:: Check for previous log archives and remove files older than N days
:: FORFILES reports "No files found" as an error when nothing is old enough, which is normal, so hide only that message
:delete_old_files
ECHO %date% %time% : Cleaning out archive files older than %archivedays% days
FORFILES /P "%archivepath%" /S /M *.zip /D -%archivedays% /C "cmd /c del @path" 2>&1 | FINDSTR /V /C:"No files found"

:: Then we archive the logs
:archive
ECHO %date% %time% : Archiving Tableau Server log files
CALL tsm maintenance ziplogs -a -o -f logs-%mydate%
if %ERRORLEVEL% NEQ 0 (
  ECHO %date% %time% : ERROR: Log archive operation failed with exit code %ERRORLEVEL%
  EXIT /B 6
)

:end_msg
ECHO %date% %time% : Log archival completed successfully.
EXIT /B 0

:: -h/--help shows usage and exits 0
:show_help
CALL :print_usage
EXIT /B 0

:: Missing or invalid arguments show usage and exit 10
:invalid_args
CALL :print_usage
EXIT /B 10

:print_usage
ECHO Usage:
ECHO tableau-server-log-archive-script.cmd -d ^<days^>
ECHO Global parameters (use in sequence):
ECHO 		-d,--days 		Delete log archives in the log archive path older than N days
ECHO 		-h,--help 		Show this help
GOTO :EOF
