#!/bin/bash

# env var syntax:
# BACKUP__0__NAME
# BACKUP__0__LOCAL_PATH
# BACKUP__0__CRON

i=0
while true; do
    backup_name="BACKUP__${i}__NAME"
    backup_local_path="BACKUP__${i}__LOCAL_PATH"
    backup_cron="BACKUP__${i}__CRON"
    if [ -z "${!backup_name}" ] || \
        [ -z "${!backup_local_path}" ] || \
        [ -z "${!backup_cron}" ]; then
        break
    fi
    echo "${!backup_cron} /config/backup.sh \"${!backup_name}\" \"${!backup_local_path}\" >> /var/log/cron.log 2>&1"

    ((i++))
done

echo ""

