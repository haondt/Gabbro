# Ansible env

How to use ansible environment
  - go to the directory
    ```shell
    cd ansible_env
    ```
  - build the docker image
    ```shell
    ./build.sh
    ```
  - start the docker image (interactive mode)
    ```shell
    ./run.sh
    ```

Some ansible commands:

- Test connection by pinging
  ```bash
  ansible -i inventory.yml all -m ping
  ```
- Ping nodes in a specific group
  ```bash
  ansible -i inventory.yml docker_hosts -m ping
  ```
- Print the full compiled config of your inventory
  ```bash
  ansible-inventory -i inventory.yml --list
  ```
- Run a playbook
  ```shell
  ansible-playbook playbook.yml
  ```
- See which hosts are compatible with a playbook
  ```shell
  ansible-playbook playbook.yml --list-hosts
  ```