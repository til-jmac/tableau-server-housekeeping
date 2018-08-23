IF "%1"=="-n" 				GOTO name_arg
IF "%1"=="--name" 			GOTO name_arg
IF "%1"=="-u" 				GOTO tsmadmin_arg
IF "%1"=="--username" 		GOTO tsmadmin_arg
IF "%1"=="-p" 				GOTO tsmpassword_arg
IF "%1"=="--password" 		GOTO tsmpassword_arg
IF "%1"=="-d" 				GOTO backupdays_arg
IF "%1"=="--days" 			GOTO backupdays_arg
IF "%1"=="-h" 				GOTO show_help
IF "%1"=="--help" 			GOTO show_help


:name_arg
SHIFT
SET filename=%1
SHIFT
ECHO %date% %time% : Setting the filename to "%filename%"
GOTO parse_command_line_params

:tsmadmin_arg
SHIFT
SET tsmadmin=%1
SHIFT
ECHO %date% %time% : Executing TSM as user: %tsmadmin%
GOTO parse_command_line_params

:tsmpassword_arg
SHIFT
SET tsmpassword=%1
SHIFT
ECHO %date% %time% : Using %tsmadmin% password %tsmpassword%
GOTO parse_command_line_params

:backupdays_arg
SHIFT
SET backupdays=%1
ECHO %date% %time% : Setting the backup retention period to %backupdays% days
SHIFT
GOTO parse_command_line_params



:: Series of checks to ensure command line params are input and valid
:check_filename
IF "%filename%" == "" (
	ECHO ERROR: Please specify a valid filename. Cancelling.
	GOTO show_help
	)

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
IF "%backupdays%" == "" (
	ECHO ERROR: Please specify a valid retention period. Cancelling.
	GOTO show_help
	)


:overwrite_requested
SHIFT
SET overwrite_requested=1
SHIFT
ECHO %date% %time% : Overwrite requested 
GOTO parse_command_line_params

:settings_export 
SHIFT
SET settings_export=1
SHIFT
ECHO %date% %time% : Setting export requested
GOTO parse_command_line_params
