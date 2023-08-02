#!/usr/bin/env bash

# get changed files
changes=$(git diff-tree --no-commit-id --name-only -r HEAD~2 | grep "^\(services\/*\|\.env\)")

# check if any changes are in the base dir
for change in $changes
do
    if ! [[ $change =~ ^services\/.*$ ]]
    then
        # get all services
        changes=$(ls -d services/*/)
        break
    fi
done

# format the files to just the folder names
tmp=()
for change in $changes
do
    if [[ $change =~ ^(services\/[A-Za-z0-9]+\/).*$ ]]
    then
        tmp+=(${BASH_REMATCH[1]})
    fi
done

# remove repeated values
changes=$(printf "%s\n" "${tmp[@]}" | sort -u)

# check for detected changes
if [[ $(expr length "$changes") == 0 ]]
then
    echo "No changes detected"
    exit 0
fi
echo -e "Changes detected for the following services:\n    $(echo $changes | sed 's/ /\n    /')"