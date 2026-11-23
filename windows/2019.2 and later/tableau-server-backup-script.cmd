:: THE INFORMATION LAB BACKUP SCRIPT
:: https://github.com/til-jmac/tableau-server-housekeeping
:: Authored by Jonathan MacDonald
:: Last updated 14/08/2020
:: How to use this script
:: 1) Create a scripts directory somewhere that makes sense for this (and other) scripts to be kept. Inside your Tableau Server 'data' folder is a good place.
:: 2) The command line parameters are ALL required. Ensure you use them in the correct order or the script will fail
:: 3) Run this script as a user with permissions to authenticate to TSM. Also run it with elevated (administrator) privileges.
:: 4) I would recommend you backup daily.
:: 5) Use this script in conjunction with my log archival and cleanup scripts, which you can find at the Github link above
:: Give me a shout on Twitter @macdonaldj for questions, comments or feedback

:: Exit codes:
::   0  Success (or help shown)
::   1  Not run as Administrator
::   2  TSM not available
::   3  Cannot read TSM configuration
::   5  Configured backup path is empty
::   6  Backup failed
::   7  Settings export failed
::   8  Could not determine the date stamp
::   10 Missing or invalid arguments

@echo OFF
SETLOCAL
cls

:: Sets global script variables for later
SET "filename="
SET "backupdays="
SET "overwrite_requested=false"

:: Parses command line parameters
:parse_command_line_params
IF "%~1"=="" GOTO end_parse
IF "%~1"=="-n" GOTO name_arg
IF "%~1"=="--name" GOTO name_arg
IF "%~1"=="-d" GOTO backupdays_arg
IF "%~1"=="--days" GOTO backupdays_arg
IF "%~1"=="-o" GOTO overwrite_requested_arg
IF "%~1"=="--overwrite" GOTO overwrite_requested_arg
IF "%~1"=="-h" GOTO show_help
IF "%~1"=="--help" GOTO show_help
ECHO ERROR: Unrecognised argument: "%~1"
GOTO invalid_args

:name_arg
SET "filename=%~2"
ECHO %date% %time% : Setting the filename to: "%filename%"
SHIFT
SHIFT
GOTO parse_command_line_params

:backupdays_arg
SET "backupdays=%~2"
ECHO %date% %time% : Setting the backup retention period to: "%backupdays%" days
SHIFT
SHIFT
GOTO parse_command_line_params

:overwrite_requested_arg
SET "overwrite_requested=%~2"
ECHO %date% %time% : Setting overwrite request to: "%overwrite_requested%"
SHIFT
SHIFT
GOTO parse_command_line_params

:end_parse

:: Series of checks to ensure command line params are input and valid
:check_filename
IF NOT DEFINED filename (
	ECHO ERROR: Please specify a valid filename. Cancelling.
	GOTO invalid_args
	)

:check_retention_period
IF NOT DEFINED backupdays (
	ECHO ERROR: Please specify a valid retention period. Cancelling.
	GOTO invalid_args
	)
:: Days must be a positive whole number. FOR /F with digits as delimiters returns a token only if a non-digit is present.
:: The leading 1 stops a value starting with ; being skipped as a comment line. The quotes keep characters special to cmd inert.
SET "days_invalid="
FOR /F "delims=0123456789" %%A IN ("1%backupdays%") DO SET "days_invalid=1"
IF "%backupdays:~0,1%"=="0" SET "days_invalid=1"
IF DEFINED days_invalid (
	ECHO ERROR: The retention period must be a whole number of days, 1 or more. Cancelling.
	GOTO invalid_args
	)

:check_overwrite_flag
IF NOT DEFINED overwrite_requested (
	ECHO ERROR: Please specify true/false for overwrite flag. Cancelling.
	GOTO invalid_args
	)
IF /I "%overwrite_requested%"=="true" GOTO check_admin
IF /I "%overwrite_requested%"=="false" GOTO check_admin
ECHO ERROR: Please specify true/false for overwrite flag. Cancelling.
GOTO invalid_args

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

:: Let's find the locations of some directories using tsm
:: ECHO Setting the script location variable
:: Grab the location of this script
:: SET script_dir=%~dp0

:: Grab the location of the backup directory
:: The first call only checks the exit code. On failure tsm runs again unredirected so its own error message is shown
:set_backup_dir
ECHO %date% %time% : Getting the location of the default backup directory
CALL tsm configuration get -k basefilepath.backuprestore >NUL 2>&1
if %ERRORLEVEL% NEQ 0 (
  ECHO %date% %time% : ERROR: Cannot read basefilepath.backuprestore from TSM configuration. Please ensure you have proper TSM permissions. TSM output:
  CALL tsm configuration get -k basefilepath.backuprestore
  EXIT /B 3
)
:: FOR /F runs tsm in a child cmd, so no CALL is needed, and only stdout is read
SET "backuppath="
FOR /F "usebackq tokens=*" %%F IN (`tsm configuration get -k basefilepath.backuprestore`) DO SET "backuppath=%%F"
IF NOT DEFINED backuppath (
  ECHO %date% %time% : ERROR: Backup directory path is empty. Please check TSM configuration.
  EXIT /B 5
)
ECHO The default backup path is:
ECHO %backuppath%

:: In v2018.2.0 the slashes in the default path are the wrong direction, so let's fix this
:fix_backup_dir
SET "backuppath=%backuppath:/=\%"
:: Strip one trailing backslash, otherwise FORFILES /P "...\" reads it as an escaped quote
IF "%backuppath:~-1%"=="\" SET "backuppath=%backuppath:~0,-1%"
ECHO The corrected backup path is now:
ECHO %backuppath%

:: ECHO Deriving the location of the install directory
:: Derive the location of the install directory
:: FOR %%I IN ("%backuppath%\..\..\..\..") DO SET install_dir=%%~fI

:: The new TSM backup command will not overwrite a file of the same name
:: Given we are appending today's date to the end of the filename this should not be a problem if you are backing up daily
:: However, if you are backing up more frequently than that, for testing for example, you may want to overwrite the existing file
:: Using the '-o' parameter with this script will overwrite the existing file
:: So let's check if this was used
:check_overwrite
ECHO %date% %time% : Checking if overwrite was requested
IF /I "%overwrite_requested%"=="true" GOTO overwrite
GOTO no_overwrite

:: It was used so let's delete today's backup and settings files if they are there
:overwrite
ECHO %date% %time% : Overwrite was requested. Cleaning out any existing files with the same name
IF EXIST "%backuppath%\%filename%-%mydate%.tsbak" DEL /F "%backuppath%\%filename%-%mydate%.tsbak" >nul 2>&1
IF EXIST "%backuppath%\%filename%-settings-%mydate%.json" DEL /F "%backuppath%\%filename%-settings-%mydate%.json" >nul 2>&1
GOTO bakup

:: It wasn't used so let's just go ahead and backup
:no_overwrite
ECHO %date% %time% : Overwrite was not requested, proceeding

:: Now let's actually do some stuff
:: First we take the backup
:bakup
ECHO %date% %time% : Backing up Tableau Server data
CALL tsm maintenance backup -f "%filename%" -d
if %ERRORLEVEL% NEQ 0 (
  ECHO %date% %time% : ERROR: Backup operation failed with exit code %ERRORLEVEL%
  EXIT /B 6
)

:: Then we backup the settings config file
:settings_bakup
CALL tsm settings export -f "%backuppath%\%filename%-settings-%mydate%.json"
if %ERRORLEVEL% NEQ 0 (
  ECHO %date% %time% : ERROR: Settings export failed with exit code %ERRORLEVEL%
  EXIT /B 7
)

:: Now that the new backup and settings export have succeeded, remove backup files older than N days
:: Only files this script creates (named after -n) in the backup directory itself are matched, subfolders are not searched
:: Running this last means the newest backup always survives
:: FORFILES reports "No files found" as an error when nothing is old enough, which is normal, so hide only that message
:delete_old_files
ECHO %date% %time% : Cleaning out backup files older than %backupdays% days
FORFILES /P "%backuppath%" /M "%filename%-*.tsbak" /D -%backupdays% /C "cmd /c del @path" 2>&1 | FINDSTR /V /C:"No files found"

:: Do the same for the settings .json files
:delete_old_settings_files
ECHO %date% %time% : Cleaning out backup files older than %backupdays% days
FORFILES /P "%backuppath%" /M "%filename%-settings-*.json" /D -%backupdays% /C "cmd /c del @path" 2>&1 | FINDSTR /V /C:"No files found"

:end_msg
ECHO %date% %time% : Backup completed successfully.
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
ECHO tableau-server-backup-script.cmd -n ^<filename^> -d ^<days^> -o ^<true/false^>
ECHO Required parameters (use in sequence):
ECHO 		-n,--name 		Name of the backup file (no spaces, periods or funny characters)
ECHO 		-d,--days 		Delete backups older than N days, N a whole number 1 or more. Only files named ^<filename^>-*.tsbak
ECHO 		          		and ^<filename^>-settings-*.json in the backup location are deleted
ECHO 		-o,--overwrite 		Overwrite any existing backup with the same name (takes appended date into account)
ECHO 		-h,--help 		Show this help
GOTO :EOF
