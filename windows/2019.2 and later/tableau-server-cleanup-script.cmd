:: THE INFORMATION LAB CLEANUP SCRIPT
:: https://github.com/til-jmac/tableau-server-housekeeping
:: Authored by Jonathan MacDonald
:: Last updated 14/08/2020
:: How to use this script
:: By default, Tableau Server does not automatically archive/delete its log files.
:: So a process is required to firstly archive old log files, then clean up the current logs to free up disk space.
:: This script helps with the second part, by cleaning out the current, active logs.
:: To archive these logs prior to deletion, you will want to run a ziplogs command, I have a script for that too.
:: 1) I would recommend you schedule this script to run once a week, immediately following the log archival script
:: 2) Use this script in conjunction with my log archival and backup scripts, which you can find at the Github link above
:: 3) Run this script with elevated privileges as the user that has permissions to run TSM
:: 4) You MUST input all command line parameters in the order specified, or the script will fail
:: 5) This will execute the cleanup script with the following options: -l (deletes old log files) -t (deletes old temp files)
::    Modify the script below if you would like to change those options
:: Give me a shout on Twitter @macdonaldj for questions, comments or feedback

:: Exit codes:
::   0  Success (or help shown)
::   1  Not run as Administrator
::   2  TSM not available
::   3  Cannot read TSM status
::   9  Cleanup failed
::   10 Invalid arguments

@echo OFF
SETLOCAL
cls

:: Parses command line parameters
:parse_command_line_params
IF "%~1"=="" GOTO end_parse
IF "%~1"=="-h" GOTO show_help
IF "%~1"=="--help" GOTO show_help
ECHO ERROR: Unrecognised argument: "%~1"
GOTO invalid_args

:end_parse

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

:: Check if TSM status is accessible
:: tsm output goes to a temp file so we can show its error message on failure
ECHO %date% %time% : Validating TSM status access
SET "tmpfile=%TEMP%\tableau-cleanup-script-%RANDOM%.tmp"
CALL tsm status > "%tmpfile%" 2>&1
if %ERRORLEVEL% NEQ 0 (
  ECHO %date% %time% : ERROR: Cannot access TSM status. Please ensure you have proper TSM permissions. TSM output:
  TYPE "%tmpfile%"
  DEL /F "%tmpfile%" >NUL 2>&1
  EXIT /B 3
)
DEL /F "%tmpfile%" >NUL 2>&1

:: Then we clean up the logs and temp files
:cleanup
ECHO %date% %time% : Cleaning up Tableau Server log and temp files
CALL tsm maintenance cleanup -l -t
if %ERRORLEVEL% NEQ 0 (
  ECHO %date% %time% : ERROR: Cleanup operation failed with exit code %ERRORLEVEL%
  EXIT /B 9
)

:end_msg
ECHO %date% %time% : Cleanup completed successfully.
EXIT /B 0

:: -h/--help shows usage and exits 0
:show_help
CALL :print_usage
EXIT /B 0

:: Invalid arguments show usage and exit 10
:invalid_args
CALL :print_usage
EXIT /B 10

:print_usage
ECHO Usage:
ECHO tableau-server-cleanup-script.cmd
ECHO Global parameters (use in sequence):
ECHO 		-h,--help 		Show this help
GOTO :EOF
