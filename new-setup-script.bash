#!/bin/bash

# Download & execute setup script
mkdir -p /var/opt/tableau/tableau_server/scripts
wget https://raw.githubusercontent.com/til-jmac/tableau-server-housekeeping/master/linux/setup.bash -P /tmp
cp /tmp/setup.bash /var/opt/tableau/tableau_server/scripts/setup.bash
chmod +x /var/opt/tableau/tableau_server/scripts/setup.bash
chown -R tableau:tableau /var/opt/tableau/tableau_server/scripts
source /var/opt/tableau/tableau_server/scripts/setup.bash

# Schedule housekeeping for 1am every day
crontab -u $tsm_admin_user -l > mycron
echo "00 01 * * * /var/opt/tableau/tableau_server/scripts/tableau-server-backup.bash $tsm_admin_user $tsm_admin_pass" >> mycron
echo "30 00 * * 7 /var/opt/tableau/tableau_server/scripts/tableau-server-logs-cleanup.bash $tsm_admin_user $tsm_admin_pass" >> mycron
crontab -u $tsm_admin_user mycron
rm mycron

# Sync backups and log files to AWS S3 bucket
cp /tmp/s3-backup-sync.bash /var/opt/tableau/tableau_server/scripts/s3-backup-sync.bash
chmod +x /var/opt/tableau/tableau_server/scripts/s3-backup-sync.bash
chown -R tableau:tableau /var/opt/tableau/tableau_server/scripts
crontab -u $tsm_admin_user -l > mycron
echo "0 2 * * * /var/opt/tableau/tableau_server/scripts/s3-backup-sync.bash ${TableauEnvironment} > /home/til/tableau-server-sync.log" >> mycron
crontab -u $tsm_admin_user mycron
rm mycron