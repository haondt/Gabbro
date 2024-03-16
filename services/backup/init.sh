#!/bin/bash

# set up gcp
echo "Setting up GCP auth..."
gcloud auth login --cred-file=$GCP_CREDENTIALS

# get crontab goin
echo "Setting up crontab..."
/config/create_crontab.sh > /etc/cron.d/backup-cron
crontab /etc/cron.d/backup-cron
cron

# watch cron log
echo "Watching cron output..."
tail -f /var/log/cron.log
