# Gabbro

This repository is mirrored on GitHub at https://github.com/haondt/Gabbro and the upstream source is on GitLab at https://gitlab.com/burghardtnoah/gabbro/.

This repo contains the configuration for my homelab v2, Gabbro. For v1, see [Obsidian](https://github.com/haondt/Obsidian).

## Related Repositories:

- [Gabbro-CE](https://github.com/haondt/Gabbro-CE) - the cloud environment for automating deployment of Gabbro
- [Gabbro-Bot](https://github.com/haondt/Gabbro-Bot) - discord bot to help with managing Gabbro docker containers
- [gabbro-healthcheck-watcher](https://github.com/haondt/gabbro-healthcheck-watcher/) - small script to be run on vps to listen for healtcheck pings from Gabbro

# Configuration

This repository contains the deployment information for my home server, Gabbro. It is structured in such a way that many services can be added without being overly repetitive or lost in giant docker files.
This is achieved by segmenting services into seperate docker files, and combining them back together with a python script. The structure is more clearly defined below:

## 1. Common files

There are 3 common `docker-compose.*` files and 1 common `.env` file.

#### `docker-compose.service-base.yml`

This file contains a single service definition. When loading a `docker-compose.yml` file from a service, each container in the file (i.e. `.services.*`) will be joined with this base service.
The value `{{ COM_HAONDT_CONTAINER }}` will be replaced with the name of the container from the service. For example, given the following `docker-compose.service-base.yml`:

```yml
services:
  {{ COM_HAONDT_CONTAINER }}:
    environment:
      PGID: 1000
    volumes:
      - vol1:/data
```

And the following docker compose file at `services/foo/docker-compose.yml`:

```yml
services:
  foo:
    environment:
      PUID: 800
      PGID: 900
    depends-on:
      - bar
  bar:
```

The final docker compose file will contain:

```yml
services:
  foo:
    environment:
      PUID: 800
      PGID: 900
    depends-on:
      - bar
    volumes:
      - vol1:/data
  bar:
    environment:
      PGID: 1000
    volumes:
      - vol1:/data
```

Notice how if a primitive field is provided in both files (e.g. `*.environment.PGID`), the one in the service file will take priority over the base. If the field is an array, it will be merged with the values from both.

#### `docker-compose.overrides.yml`

This file will be merged with the final docker compose file. If there is a primitive field in both, the value in `docker-compose.overrides.yml` will be prioiritized.

#### `docker-composer.header.yml`

This file will be prepended to the top of the final docker compose file.

#### `.env`

This provides the base set of environment variables that will be available for hydration in all docker compose files.


## 2. Service Files

For each directory in `services/*` that contains a `docker-compose.yml` file, the script will merge its services with `docker-compose.service-base.yml` as described above, and then merge it into the final docker compose file.
All of the non-`docker-compose.yml` files in the service directory will also be copied into `tmp/$service/*`.

## 3. Hydration

Any appearances of the string `{{ SOME_VAR }}` will be replaced with corresponding value from the environment file in any docker compose file. For example, if the docker compose file contains the string `{{ KEY }}` and the env file contains the line `KEY=VALUE`, then all occurrences of `{{ KEY }}` will be replaced by `VALUE`.

Non-docker files can also be hydrate by including a `hydrate.gabbro` file in the service folder. All files listed in `hydrate.gabbro` will be hydrated in the same manner.

### Environment Files

Values can be defined in the base environment file (`.env`) to be made available to the base docker files and all service docker files. Additionally, an environment file can be defined inside the services folder
(i.e. `services/$service/.env`). The values in this environment file will be made available to the service docker compose file as well as the `docker-compose.service-base.yml` file. Note that the env file itself is **not**
copied to the deployment, so any environment variables that should be made available to the service itself should be defined in the `environment:` section of the docker compose file.

### Plugins

A key can be written as `{{ plugin_name('argument1', 'argument2', ...) }}`. In this case, a plugin engine will run and try to resolve the plugin, and use that for the value. Plugins are only supported inside `.env` files,
so a pluging should be mapped to an env var, and the env var can be used for hydration.

The following plugins are supported:
- `{{ secret('path/to/folder', 'SECRET_NAME') }}` - this will make a url request to Infisical to try and retrieve the secret. It requires the following env vars:
  - `INFISICAL_SECRET_KEY` - the bearer token for infisical
  - `INFISICAL_URL` - the base url for infisical
- `{{ gsm('SECRET_NAME', 'secret_tag1', 'secret_tag2', ...) }}` - this will make a url request to Gabbro Secret Manager to try and retrieve the secret. It requires the following env vars:
  - `GSM_API_KEY` - the bearer token for gabbro secret manager
  - `GSM_URL` - the base url for gabbro secret manager
  - it will retrieve a secret that has the matching name and all of the tags. this must result in **exactly one** secret in the response from gabbro secret manager
- `{{ env('MY_ENV_VAR') }}` - this will be replaced with the value of the environment variable
- `{{ yaml('PATH', 'foo', 'bar', 0, 'baz')}}` - this will get the yaml file at `PATH` and will use the remaning values to extract a value from the yaml object
  - `PATH` can be a file path or an environment variable that resolves to a file path, with priority on the latter.
  - the remaning arguments must be strings or ints
  - the object that the path resolves to must be a string

## 4. Final Steps

Once everything has been hydrated and merged into the final docker compose file, it is placed in the tmp directory at `tmp/docker-compose.yml`.

# Deployment

The project is deployed in two steps. Firstly, the python script is run. This will run the change detection, and add the service files in `tmp`.
It will also create a file called `changes.txt` that lists all the containers of the changed services.

```shell
python3 ./scripts/build.py
```

Next, it will call an ansible playbook, `ansible/playbooks/deploy.yml`, that will copy the files in `tmp` to the remote, and redeploy all the containers in `changes.txt`.

```shell
ansible-playbook playbooks/deploy.yml
```
