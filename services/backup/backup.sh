#!/bin/bash

backup_name="$1"
backup_local_path="$2"

random=$(xxd -l 8 -p /dev/urandom)

target_file="${random}.tar.gz"
target_path="/tmp/${target_file}"
echo "compressing '${backup_local_path}' to '${target_path}'"

if [ -d "${backup_local_path}" ]; then
    echo "${backup_local_path} is a directory"
    tar -czf "${target_path}" --directory="${backup_local_path}" . 2>&1
else
    echo "${backup_local_path} is a single file"
    tar -czf "${target_path}" --directory=$(dirname "${backup_local_path}") "$(basename ${backup_local_path})"  2>&1
fi

echo "copying '${backup_name}.tar.gz' to cloud"
# bucket uses object versioning, so we can just overwrite any existing file
gcloud storage cp "${target_path}" "gs://${GCP_BUCKET}/${backup_name}.tar.gz"

echo "deleting tmp file '${target_path}'"
rm "${target_path}"

echo "finished backing up ${backup_name} successfully :)"
