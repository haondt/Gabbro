#!/usr/bin/env bash

INFISICAL_URL="http://infisical.gabbro-ce"

# make sure required files are present
if ! [[ -r "./key.txt" ]]; then
    echo "Error: missing key.txt"
    exit 1
fi
secret_key=$(cat key.txt)

# get changed files
changes=$(git diff-tree --no-commit-id --name-only -r HEAD~2 | grep "^\(services\/.*\|\.env\|docker-compose\..*\.yml\)$")

# check if any changes are in the base dir
services=()
for change in $changes
do
    if [[ $change =~ ^services\/([A-Za-z0-9]+)\/.*$ ]]
    then
        # add service
        services+=(${BASH_REMATCH[1]})
        break
    else
        # get all services
        services=$(find services -type f -name "docker-compose.yml" -printf '%h\n' | sed 's|^services/||' | sort -u
        break
)
    fi
done

# check for detected changes
if [[ ${#services[@]} == 0 ]]
then
    echo "No changes detected"
    exit 0
fi
echo -e "Changes detected for the following services:\n    $(echo $services | sed 's/ /\n    /')"

# clear tmp folder
shopt -s extglob
rm -r tmp/!(".gitignore") 2>&-

# define function to load env files
load_env_files() {
    local -A merged_dict=()

    # Loop through all the arguments (.env file paths)
    for env_file_path in "$@"; do
        # Check if the file exists and is readable
        if [[ -r "$env_file_path" ]]; then
            while IFS= read -r line || [[ -n "$line" ]]; do
                # check for "plugins"
                rx="^\s*([^\s#]+)\s*={{\s*([A-Za-z]+)\s*\(\s*(?:'([^']+)')?(?:\s*,\s*'([^']+)')*\s*\)\s*}}\s*$"
                matches=$(python3 ./scripts/helper.py -r "$rx" "$line")
                hadmatch=$?
                if [[ $hadmatch -eq 0 ]]; then
                    # extract plugin
                    key=$(echo "$matches" | sed -n 1p)
                    fn=$(echo "$matches" | sed -n 2p)
                    value=""

                    # Check if the key already exists in the dictionary
                    if [[ -n "${merged_dict[$key]}" ]]; then
                        echo "Error: Key '$key' already exists in '$env_file_path'."
                        exit 1
                    fi

                    # check for secret plugin
                    if [[ "$fn" = "secret" ]]; then
                        path=$(echo "$matches" | sed -n 3p)
                        name=$(echo "$matches" | sed -n 4p)
                        if ! [[ -n "$path" && -n "$name" ]]; then
                            echo "Error: secret plugin missing path or name: $line";
                            exit 1
                        fi

                        # get secret
                        sc=$(curl -s --location --request GET "$INFISICAL_URL/api/v3/secrets/raw/$name?environment=prod&workspaceId=64cb8985f721447f27fb5123&secretPath=/$path/" --header "Authorization: Bearer $secret_key")
                        value=$(echo $sc | jq -r .secret.secretValue)
                        if [[ -z "$value" || "$value" = "null" ]]; then
                            echo "Error: unable to retrieve secret \"$path/$name\" in variable \"$line\"";
                            exit 1
                        fi
                    else
                        echo "Error: unknown plugin: $fn"
                        exit 1
                    fi
                    merged_dict["$key"]="$value"
                # Skip empty lines and comments, and extract key-value pair
                elif [[ "$line" =~ ^[[:space:]]*([^[:space:]#]+)[[:space:]]*=[[:space:]]*([^[:space:]#]*)[[:space:]]*$ ]]; then
                    key="${BASH_REMATCH[1]}"
                    value="${BASH_REMATCH[2]}"

                    # Check if the key already exists in the dictionary
                    if [[ -n "${merged_dict[$key]}" ]]; then
                        echo "Error: Key '$key' already exists in '$env_file_path'."
                        exit 1
                    fi

                    # Add key-value pair to the merged dictionary
                    merged_dict["$key"]="$value"
                elif [[ "$line" =~ ^[[:space:]]*[^#].*[A-Za-z0-9_-]+.* ]]; then
                    echo "Error: malformed env variable: \"$line\""
                    exit 1
                fi
            done < "$env_file_path"
        else
            echo "Error: $env_file_path not found or not readable."
            exit 1
        fi

        for key in "${!merged_dict[@]}"; do
            echo "$key=${merged_dict[$key]}"
        done
    done
}

# define function to perform variable substitution
sub() {
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ $line =~ ^.*\{\{\ .*\ \}\}.*$ ]]; then
            placeholders=$(echo "$line" | grep -o -P '(?<=\{\{ ).*?(?= \}\})' | sort -u)
            for key in $placeholders; do
                value=$(echo "$2" | grep -o -m1 "$key=[^[:space:]]*")
                if [[ $? -ne 0 || -z "$value" ]]; then echo "Error: key not found: $key"; exit 1; fi
                line=${line//\{\{ ${key} \}\}/${value#*=}}
            done
        fi
        echo "$line"
    done <<< "$1"
}

# define function to find conflicting definitions
get_conflicts() {
  # get top level keys
  k1=$(yq eval-all '
    select(fi == 0) as $f1 |
    select(fi == 1) as $f2 |
    ($f1 | keys) - (($f1 | keys) - ($f2 | keys))
  ' <(echo "$1") <(echo "$2"))

  # get f1 2nd level keys
  f1k2=$(yq eval-all '
    select(fi == 0) as $f1 |
    select(fi == 1) |
    .[] as $k | $f1[$k] | keys | .[] as $k2 | [$k + "." + $k2]
  ' <(echo "$1") <(echo "$k1"))

  # get f2 2nd level keys
  f2k2=$(yq eval-all '
    select(fi == 0) as $f1 |
    select(fi == 1) |
    .[] as $k | $f1[$k] | keys | .[] as $k2 | [$k + "." + $k2]
  ' <(echo "$2") <(echo "$k1"))

  # get overlap
  yq eval-all '
    select(fi == 0) as $f1 |
    select(fi == 1) as $f2 |
    $f1 - ([$f1[]] - $f2) |
    .[]
  ' <(echo "$f1k2") <(echo "$f2k2")
}

# generate yaml for each service
final_yaml=""
for service in $services
do
    # build environment
    env_file_paths=("./.env")
    if [[ -r "./services/$service/.env" ]]; then
        env_file_paths+=("./services/$service/.env")
    fi
    env=$(load_env_files "${env_file_paths[@]}")
    if ! [[ $? -eq 0 ]]; then echo "$env" | tail -n 1; exit 1; fi

    # build service file
    service_yaml=$(cat ./services/$service/docker-compose.yml)
    service_yaml=$(sub "$service_yaml" "$env")
    if ! [[ $? -eq 0 ]]; then echo "$service_yaml" | tail -n 1; exit 1; fi

    # apply base yaml template to services in service file
    containers=$(yq eval '.services | keys | .[]' <(echo "$service_yaml"))
    if ! [[ $? -eq 0 ]]; then echo "Error retrieving services from $service docker compose" | tail -n 1; exit 1; fi
    while IFS= read -r container || [[ -n "$container" ]]; do
        # build container yaml from base
        container_base_yaml=$(cat docker-compose.service-base.yml | sed "s/{{ COM_GABBRO_CONTAINER }}/$container/g")
        container_base_yaml=$(sub "$container_base_yaml" "$env")
        if ! [[ $? -eq 0 ]]; then echo "$container_base_yaml" | tail -n 1; exit 1; fi
        service_yaml=$(yq eval-all "select(fi == 0) *+ select(fi == 1)" <(echo "$container_base_yaml") <(echo "$service_yaml"))
    done <<< "$containers"

    # add finished service yaml to final yaml
    if [[ -z "$final_yaml" ]]; then
        final_yaml="$service_yaml"
    else


    fi

    echo "$service_yaml"


    exit 0

    # build base service file
    #base_yaml=$(cat docker-compose.service-base.yml | sed "s/{{ COM_GABBRO_SERVICE }}/$service/g")

    # concatenate files
    #cat_yaml=$(echo -e "$base_yaml" "\n---\n" "$service_yaml")
    #echo -e "$cat_yaml"


    base_yaml=$(sub "$base_yaml" "$env")
    if ! [[ $? -eq 0 ]]; then echo "$base_yaml" | tail -n 1; exit 1; fi

    echo "------------------------------"
    echo "$base_yaml"
    echo "$service_yaml"
    echo "------------------------------"
    yq eval-all '. as $item ireduce ({}; . * $item)' <(echo "$base_yaml") <(echo "$service_yaml")
    echo "------------------------------"


    # Output the merged dictionary
    #echo "$env" > tmp/.env


    #echo -e "$base_yaml" | yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "./services/$service/docker-compose.yml" -


done

# merge all service yamls together
