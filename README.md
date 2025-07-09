# Housekeeping scripts for Tableau Server

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Tableau](https://img.shields.io/badge/Tableau-2018.2%2B-orange.svg)](https://www.tableau.com/)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux-lightgrey.svg)](https://github.com/til-jmac/tableau-server-housekeeping)

Robust, production-ready housekeeping scripts for Tableau Server with comprehensive error handling and TSM validation.

## Features

- **Cross-platform**: Windows (CMD) and Linux (Bash) versions
- **Comprehensive error handling**: TSM validation, detailed error messages, and specific exit codes
- **Flexible configuration**: Command line parameters and customizable variables
- **Production-ready**: Tested validation checks and robust error handling
- **Easy automation**: Ready for cron (Linux) or Task Scheduler (Windows)

## Available Scripts

### Windows Scripts (2019.2+)
- `tableau-server-backup-script.cmd` - Creates backups and exports settings
- `tableau-server-cleanup-script.cmd` - Cleans up logs and temporary files  
- `tableau-server-log-archive-script.cmd` - Archives current log files

### Linux Scripts

**Individual Function Scripts** (Windows equivalent structure):
- `tableau-server-backup.bash` - Creates backups and exports settings
- `tableau-server-cleanup.bash` - Cleans up logs and temporary files
- `tableau-server-log-archive.bash` - Archives current log files  

**Combined Scripts** (Linux-specific):
- `tableau-server-housekeeping-linux.bash` - Complete housekeeping (backup, logs, cleanup)
- `tableau-server-logs-cleanup.bash` - Archives logs and performs cleanup (legacy)

**Script Organization**: Linux now offers both individual scripts (matching Windows functionality) and combined scripts for convenience. Use individual scripts for targeted operations or combined scripts for comprehensive housekeeping.

## Prerequisites

- **Tableau Server 2018.2 or later**
- **User Permissions**: The user running the scripts must be a member of:
  - Linux: `tsmadmin` group
  - Windows: Local Administrators group  
- **TSM availability**: Scripts validate TSM is installed and responsive
- **File Access**: User needs read/write access to Tableau Server backup and log directories

## Installation

### Windows Installation
1. Download the appropriate scripts from the `windows/2019.2 and later/` folder
2. Place scripts in a secure location accessible to your Tableau Server
3. Run as a user who is a member of the Local Administrators group

### Linux Installation

**Easy way**: Use the setup script
```bash
wget https://raw.githubusercontent.com/til-jmac/tableau-server-housekeeping/master/linux/setup.bash
chmod +x setup.bash
./setup.bash
```

**Manual way**: Download scripts directly and customize as needed

## Usage

### Windows Scripts (2019.2+)

**Backup Script:**
```cmd
tableau-server-backup-script.cmd -n <filename> -d <days> -o <true/false>
```

**Cleanup Script:**
```cmd
tableau-server-cleanup-script.cmd
```

**Log Archive Script:**
```cmd
tableau-server-log-archive-script.cmd -d <days>
```

**Parameters:**
- `-n, --name`: Name of the backup file (no spaces, periods or special characters)
- `-d, --days`: Delete files older than N days
- `-o, --overwrite`: Overwrite existing files with same name (true/false)
- `-h, --help`: Show help

### Linux Scripts

**Backup Only:**
```bash
/path/to/tableau-server-backup.bash
```

**Cleanup Only:**
```bash
/path/to/tableau-server-cleanup.bash
```

**Log Archive Only:**
```bash
/path/to/tableau-server-log-archive.bash <retention_days>
```

**Complete Housekeeping:**
```bash
/path/to/tableau-server-housekeeping-linux.bash
```

**Legacy Logs & Cleanup:**
```bash
/path/to/tableau-server-logs-cleanup.bash
```

**With credentials (pre-2019.2):**
```bash
/path/to/script.bash <username> <password> [additional_params]
```

**Note**: Run as a user who is a member of the `tsmadmin` group

## Error Handling & Exit Codes

All scripts include comprehensive error handling with specific exit codes for troubleshooting:

| Exit Code | Meaning |
|-----------|---------|
| 0 | Success |
| 1 | Not running with required administrator privileges |
| 2 | TSM command not found or not accessible |
| 3 | TSM not responsive or configuration issues |
| 4 | TSM configuration access denied |
| 5 | Failed to retrieve directory paths |
| 6 | Archive/Settings export operation failed |
| 7 | Backup/Cleanup operation failed |

## TSM Validation

Scripts automatically validate:
- TSM command availability
- TSM service responsiveness  
- TSM configuration access
- Required directory paths
- Proper permissions

## Troubleshooting

### Common Issues

**"TSM command not found"**
- Ensure Tableau Server is installed
- Check TSM is in system PATH
- Verify running as correct user

**"Cannot access TSM configuration"**
- Check user is member of tsmadmin group (Linux) or Local Administrators (Windows)
- Verify TSM service is running
- Check Tableau Server status

**"Permission denied"**
- Ensure user is member of required group (tsmadmin/Local Administrators)
- Verify file permissions on script files
- Check directory permissions for backup/log paths

### Testing Scripts

Always test scripts in a development environment first:

```bash
# Test mode - check what would happen
./script.bash --dry-run  # (if supported)

# Check TSM access
tsm version
tsm status

# Verify permissions
id -nG  # Linux - should show tsmadmin group
```

## Automation

### Windows Task Scheduler
Create scheduled tasks to run scripts automatically:

```cmd
schtasks /create /tn "Tableau Backup" /tr "C:\path\to\tableau-server-backup-script.cmd -n daily-backup -d 7 -o false" /sc daily /st 02:00
```

### Linux Cron
Add to crontab for automatic execution:

```bash
# Daily backup at 2 AM
0 2 * * * /var/opt/tableau/tableau_server/scripts/tableau-server-backup.bash >> /var/log/tableau-backup.log 2>&1

# Weekly cleanup on Sunday at 3 AM  
0 3 * * 0 /var/opt/tableau/tableau_server/scripts/tableau-server-logs-cleanup.bash >> /var/log/tableau-cleanup.log 2>&1
```

## Security Considerations

- Store scripts in secure locations with appropriate permissions
- Use dedicated service accounts with only required group membership (tsmadmin/Local Administrators)
- Regularly review and update retention policies
- Monitor script execution logs for security events
- Consider encrypting backup destinations
- Avoid running with unnecessary elevated privileges

## Version Compatibility

| Tableau Server Version | Script Version | Notes |
|-------------------------|----------------|-------|
| 2018.2 - 2019.1 | `windows/2018.2 to 2019.1/` | Requires username/password |
| 2019.2+ | `windows/2019.2 and later/` | No credentials required |
| All Linux versions | `linux/` | Auto-detects version |

## Contributing

These scripts are actively maintained and tested. Please:
- Test thoroughly in development environments
- Report issues via GitHub Issues
- Submit pull requests for improvements

## Support

For questions or feedback:
- **Email**: support@theinformationlab.co.uk
- **GitHub Issues**: [Create an issue](https://github.com/til-jmac/tableau-server-housekeeping/issues) for bug reports or feature requests

## License

MIT License - See LICENSE file for details.

