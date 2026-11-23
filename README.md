# Housekeeping scripts for Tableau Server

[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux-lightgrey.svg)](https://github.com/til-jmac/tableau-server-housekeeping)

Backup, log archive and cleanup scripts for Tableau Server, built on `tsm`. Windows (CMD) and Linux (Bash).

**Warnings**
- Retention deletes files. It matches only dated files with the configured name prefix (`<name>-YYYY-MM-DD.tsbak`, `<name>-settings-YYYY-MM-DD.json`, `logs-YYYY-MM-DD.zip`; on Linux also old `settings-<date>.json`), non-recursively, and runs only after the new backup or archive succeeds.
- The scripts run elevated or as a tsm administrator: keep them where the Tableau service account and ordinary users cannot modify them (see [Scheduling](#scheduling)).
- Windows scripts must run elevated. Linux scripts must run as a member of `tsm_group` (default `tsmadmin`) or root.
- Legacy Windows scripts are unmaintained (see [Version Compatibility](#version-compatibility)).

## Scripts

### Windows (Tableau Server 2019.2 and later): `windows/2019.2 and later/`

| Script | Does |
|--------|------|
| `tableau-server-backup-script.cmd` | `tsm maintenance backup`, `tsm settings export`, then deletes old backups |
| `tableau-server-log-archive-script.cmd` | `tsm maintenance ziplogs`, then deletes old archives |
| `tableau-server-cleanup-script.cmd` | `tsm maintenance cleanup -l -t` |

### Linux: `linux/`

| Script | Does |
|--------|------|
| `tableau-server-backup.bash` | Backup, settings export, retention, optional copy |
| `tableau-server-log-archive.bash` | `ziplogs`, retention, optional copy |
| `tableau-server-cleanup.bash` | `tsm maintenance cleanup -l -t` |
| `tableau-server-housekeeping-linux.bash` | Log archive, cleanup, then backup in one script |
| `tableau-server-logs-cleanup.bash` | Log archive then cleanup in one script |
| `setup.bash` | Installs the backup, log-archive and cleanup scripts (not the two combined scripts) |

## Requirements

**Windows**
- Elevated prompt (checked with `fltmc`; exit 1 if not elevated)
- `tsm` on PATH
- PowerShell available (used for the `yyyy-MM-dd` date stamp)

**Linux**
- Member of `tsm_group` or root
- `tsm` on PATH
- Tableau environment file: `/etc/profile.d/tableau_server.sh` and/or `/etc/opt/tableau/tableau_server/environment.bash`

## Installation

**Windows:** copy the scripts from `windows/2019.2 and later/` to a folder on the server.

**Linux:** run as root. Installs to `$TABLEAU_SERVER_DATA_DIR/scripts`, owned `root:root`, mode 0755. Refuses a symlinked scripts directory.
```bash
wget https://raw.githubusercontent.com/til-jmac/tableau-server-housekeeping/master/linux/setup.bash
chmod +x setup.bash
sudo ./setup.bash
```

**Migration:** `setup.bash` no longer installs `tableau-server-logs-cleanup.bash`. Existing installs keep the old copy and any cron line calling it; switch to the log-archive and cleanup scripts.

## Usage

### Windows

Parameters can be given in any order. `-n` and `-d` are required for backup, `-d` for log archive; `-o` defaults to `false`.

```cmd
tableau-server-backup-script.cmd -n <name> -d <days> [-o <true/false>]
tableau-server-log-archive-script.cmd -d <days>
tableau-server-cleanup-script.cmd
```

| Parameter | Meaning |
|-----------|---------|
| `-n, --name` | Backup name: letters, digits, underscore and hyphen only |
| `-d, --days` | Delete this script's files older than N days; whole number, 1 to 32768 |
| `-o, --overwrite` | `true` or `false` (default). `true` deletes today's existing backup and settings file of the same name before backing up, so a failed run leaves no backup for that day |
| `-h, --help` | Show help |

Files created and deleted by retention (backup and archive directories come from `tsm configuration get`):

| Script | Creates | Retention deletes |
|--------|---------|-------------------|
| backup | `<name>-YYYY-MM-DD.tsbak`, `<name>-settings-YYYY-MM-DD.json` | Same names, dated, older than N days |
| log archive | `logs-YYYY-MM-DD.zip` | `logs-YYYY-MM-DD.zip` older than N days |

### Linux

Configured by variables at the top of each script, not arguments (except log archive).

| Variable | Scripts | Meaning |
|----------|---------|---------|
| `tsm_group` | all | Group allowed to run the script (default `tsmadmin`) |
| `backup_name` | backup, housekeeping | Backup name; date is appended |
| `backup_days` | backup, housekeeping | Retention in days, positive integer |
| `copy_backup`, `external_backup_path` | backup, housekeeping | Copy backup directory contents (`cp "$backup_path"/*`) to another path |
| `log_days` | housekeeping, logs-cleanup | Archive retention in days, positive integer |
| `copy_logs`, `external_log_path` | log-archive, housekeeping, logs-cleanup | Copy today's archive to another path |

`tableau-server-log-archive.bash` requires the retention days as its single argument, which overrides `log_days`:
```bash
tableau-server-log-archive.bash 7
```

Settings export is `<backup_name>-settings-YYYY-MM-DD.json`. Linux backup retention deletes `<backup_name>-YYYY-MM-DD.tsbak`, `<backup_name>-settings-YYYY-MM-DD.json` and the old `settings-DD-MM-YYYY.json` / `settings-YYYY-MM-DD.json`; log retention deletes `logs-YYYY-MM-DD.zip`. Other names (for example `<name>-weekly-...` or `settings-before-upgrade.json`) are kept.

## Scheduling

**Security:** the scripts run elevated, so anyone who can edit them or their folders gets admin rights. A new top-level folder on `C:\` is typically writable by ordinary users. Lock it down:

```cmd
icacls C:\TableauScripts /inheritance:r /grant:r "Administrators:(OI)(CI)F" "SYSTEM:(OI)(CI)F"
```

Do the same for the log folder and the backup and log-archive folders. On Linux the scripts must be root-owned and not writable by the Tableau service account (`setup.bash` installs them that way).

Schedule backup daily. Schedule log archive daily, immediately before cleanup: ziplogs collects roughly the last two days of logs and cleanup removes logs older than one day, so weekly runs lose logs. Do not let jobs overlap a long-running backup.

### Windows Task Scheduler

Run from cmd.exe, not PowerShell. Paths must not contain spaces; use the Task Scheduler GUI if they must. Placeholders: `DOMAIN\svc-tableau`, `C:\TableauScripts`, `C:\TableauLogs`. `/rp *` prompts for the password. `/rl HIGHEST` runs the task elevated.

```cmd
schtasks /create /tn "Tableau Backup" /ru "DOMAIN\svc-tableau" /rp * /rl HIGHEST /sc daily /st 01:00 /tr "cmd /c C:\TableauScripts\tableau-server-backup-script.cmd -n daily-backup -d 7 -o false >> C:\TableauLogs\backup.log 2>&1"
schtasks /create /tn "Tableau Log Archive" /ru "DOMAIN\svc-tableau" /rp * /rl HIGHEST /sc daily /st 03:00 /tr "cmd /c C:\TableauScripts\tableau-server-log-archive-script.cmd -d 7 >> C:\TableauLogs\log-archive.log 2>&1"
schtasks /create /tn "Tableau Cleanup" /ru "DOMAIN\svc-tableau" /rp * /rl HIGHEST /sc daily /st 03:30 /tr "cmd /c C:\TableauScripts\tableau-server-cleanup-script.cmd >> C:\TableauLogs\cleanup.log 2>&1"
```

Task Scheduler runs cleanup even if the archive failed: leave enough time after the backup and archive, and check `log-archive.log`.

The account must be allowed to run `tsm` and have write access to the log folder. Use `schtasks /run /tn "<name>"` to start a task manually.

### Linux cron

Add to the crontab of a `tsm_group` user (`sudo su -l <tsm user> -c "crontab -e"`):

```bash
0 1 * * * /var/opt/tableau/tableau_server/scripts/tableau-server-backup.bash >> /home/<TSM_USER>/tableau-server-backup.log 2>&1

# archive then cleanup; cleanup is skipped if the archive fails
0 3 * * * /var/opt/tableau/tableau_server/scripts/tableau-server-log-archive.bash 7 >> /home/<TSM_USER>/tableau-server-log-archive.log 2>&1 && /var/opt/tableau/tableau_server/scripts/tableau-server-cleanup.bash >> /home/<TSM_USER>/tableau-server-cleanup.log 2>&1
```

Alternatively schedule `tableau-server-housekeeping-linux.bash` once daily; it runs log archive, cleanup, then backup. A ziplogs failure skips log retention, copy and cleanup; a cleanup failure is logged; both still run the backup and exit non-zero at the end (6 or 8).

## Exit codes

Read from each script's exit statements. `-` means the code is not used by that script.

### Windows

Windows exit 4 is unused.

| Code | backup | log-archive | cleanup |
|------|--------|-------------|---------|
| 0 | Success or help shown | Success or help shown | Success or help shown |
| 1 | Not run as Administrator | Not run as Administrator | Not run as Administrator |
| 2 | TSM not available | TSM not available | TSM not available |
| 3 | Cannot read TSM configuration | Cannot read TSM configuration | Cannot read TSM status |
| 5 | Backup path empty | Log archive path empty | - |
| 6 | Backup failed | ziplogs failed | - |
| 7 | Settings export failed | - | - |
| 8 | Date stamp failed | Date stamp failed | - |
| 9 | - | - | Cleanup failed |
| 10 | Missing or invalid arguments | Missing or invalid arguments | Invalid arguments |

### Linux

In housekeeping-linux, ziplogs failure (6) and cleanup failure (8) are returned at the end, after the backup has run. Codes are unchanged.

| Code | backup | log-archive | cleanup | housekeeping-linux | logs-cleanup |
|------|--------|-------------|---------|--------------------|--------------|
| 0 | Success | Success | Success | Success | Success |
| 1 | Not in `tsm_group` or root | Not in `tsm_group` or root, or not exactly one argument | Not in `tsm_group` or root | Not in `tsm_group` or root | Not in `tsm_group` or root |
| 2 | `tsm` not found | `tsm` not found | `tsm` not found | `tsm` not found | `tsm` not found |
| 3 | `tsm version` failed | `tsm version` failed | `tsm version` failed | `tsm version` failed | `tsm version` failed |
| 4 | Cannot read TSM configuration | Cannot read TSM configuration | `tsm status` failed | Cannot read TSM configuration | Cannot read TSM configuration |
| 5 | Backup path empty or unreadable | Log archive path empty or unreadable | Cleanup failed | Log archive or backup path empty or unreadable | Log archive path empty or unreadable |
| 6 | Settings export failed | ziplogs failed | - | ziplogs or settings export failed | ziplogs failed |
| 7 | Backup failed | Invalid `log_days` | - | Backup failed | Cleanup failed |
| 8 | Invalid `backup_days` | - | - | Cleanup failed | Invalid `log_days` |
| 9 | - | - | - | Invalid `backup_days` | - |
| 10 | - | - | - | Invalid `log_days` | - |

## Troubleshooting

Check what the scripts check:
```
tsm version
tsm status
tsm configuration get -k basefilepath.backuprestore
tsm configuration get -k basefilepath.log_archive
```
Linux: `id -nG` should list `tsm_group`.

## Version Compatibility

| Tableau Server | Scripts | Status |
|----------------|---------|--------|
| 2019.2 and later (Windows) | `windows/2019.2 and later/` | Current. No TSM credentials passed |
| 2018.2 to 2019.1 (Windows) | `windows/legacy/2018.2 to 2019.1/` | Unmaintained. Passes TSM username and password on the command line |
| Before 2018.2 (Windows) | `windows/legacy/Pre-2018.2/` | Unmaintained. Uses `tabadmin`, which no longer exists |
| Linux | `linux/` | Current. No TSM credentials passed |

## Support

[GitHub Issues](https://github.com/til-jmac/tableau-server-housekeeping/issues) or support@theinformationlab.co.uk
