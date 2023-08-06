docker run -it --rm \
    --name ansible_env \
    --group-add 1006 \
    -e ANSIBLE_CONFIG='/ansible/ansible.cfg' \
    -e ANSIBLE_LOOKUP_INFISICAL_KEY=$(cat '../key.txt' | xargs) \
    -v $(pwd)/../ansible:/ansible \
    -w /ansible \
    ansible_env