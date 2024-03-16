backup_name="$1"
backup_local_path="$2"

random=$(xxd -l 8 -p /dev/urandom)
ts=$(date +%s)

target_file="${backup_name}_${ts}_${random}.tar.gz"
target_path="/tmp/${target_file}"
echo "backing up '${backup_local_path}' to '${target_path}'"

if [ -d "${backup_local_path}" ]; then
    tar -czf "${target_path}" --directory="${backup_local_path}" . 2>&1
else
    tar -czf "${target_path}" --directory=$(dirname "${backup_local_path}") "$(basename ${backup_local_path})"  2>&1
fi

echo "copying '${target_file}' to cloud"
# bucket uses object versioning, so we can just overwrite any existing file
gcloud storage cp "${target_path}" "gs://$GCP_BUCKET/"

echo "deleting tmp file '${target_path}'"
rm "${target_path}"
