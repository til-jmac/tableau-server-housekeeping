#!/bin/bash

# Fetch it from Github and save as /etc/init.d/obliterate_ts
# Make it executable and ensure it's owned by root
# Symlink it to /etc/rc0.d with the name K01obliterate_ts
# Upon termination, scripts in /etc/rc0.d are all run in sequence, so this should deactivate and obliterate the server at termination time

exec &> /home/ubuntu/terminate.log

source /etc/profile.d/tableau_server

bash /opt/tableau/tableau_server/packages/scripts.${$TABLEAU_SERVER_DATA_DIR_VERSION}/tableau-server-obliterate -y -y -y -l

echo "The obliterate script ran successfully" >> /home/ubuntu/terminate.log

/usr/bin/aws s3 cp /home/ubuntu/terminate.log s3://server-essentials/terminate.log