@echo off
:: Stub of the Tableau tsm CLI for CI. Batch file on purpose, as the real tsm is, so a missing CALL is caught.
:: STUB_BACKUP_DIR / STUB_ARCHIVE_DIR: what "configuration get" returns and where files are written.
:: STUB_FAIL: version | status | config | backup | export | ziplogs | cleanup makes that command exit 1.
setlocal EnableExtensions
echo [stub tsm] %* 1>&2
set "fname="
call :getf %*
if "%~1"=="version" goto version
if "%~1"=="status" goto status
if "%~1"=="configuration" goto configuration
if "%~1"=="settings" goto settings
if "%~1"=="maintenance" goto maintenance
goto unsupported

:getf
if "%~1"=="" exit /b 0
if "%~1"=="-f" set "fname=%~2"
shift
goto getf

:version
if "%STUB_FAIL%"=="version" exit /b 1
echo Tableau Services Manager version stub
exit /b 0

:status
if "%STUB_FAIL%"=="status" exit /b 1
echo Status: RUNNING
exit /b 0

:configuration
if not "%~2"=="get" goto unsupported
if "%STUB_FAIL%"=="config" exit /b 1
if "%~4"=="basefilepath.backuprestore" goto cfg_backup
if "%~4"=="basefilepath.log_archive" goto cfg_archive
goto unsupported
:cfg_backup
echo(%STUB_BACKUP_DIR%
exit /b 0
:cfg_archive
echo(%STUB_ARCHIVE_DIR%
exit /b 0

:settings
if not "%~2"=="export" goto unsupported
if "%STUB_FAIL%"=="export" exit /b 1
echo {}>"%fname%"
exit /b 0

:maintenance
if "%~2"=="backup" goto backup
if "%~2"=="ziplogs" goto ziplogs
if "%~2"=="cleanup" goto cleanup
goto unsupported

:backup
if "%STUB_FAIL%"=="backup" exit /b 1
set "today="
for /f %%d in ('powershell -NoProfile -Command "[datetime]::Now.ToString('yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture)"') do set "today=%%d"
if exist "%STUB_BACKUP_DIR%\%fname%-%today%.tsbak" goto backup_exists
echo backup>"%STUB_BACKUP_DIR%\%fname%-%today%.tsbak"
exit /b 0
:backup_exists
echo Error: file %fname%-%today%.tsbak already exists 1>&2
exit /b 1

:ziplogs
if "%STUB_FAIL%"=="ziplogs" exit /b 1
echo zip>"%STUB_ARCHIVE_DIR%\%fname%"
exit /b 0

:cleanup
if "%STUB_FAIL%"=="cleanup" exit /b 1
echo Cleanup done
exit /b 0

:unsupported
echo stub tsm: unsupported command: %* 1>&2
exit /b 99
