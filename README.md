# Gabbro

# Configuration

This repository contains the deployment information for my home server, Gabbro. It is structured in such a way that many services can be added without being overly repetitive or lost in giant docker files.
This is achieved by segmenting services into seperate docker files, and combining them back together with a python script. The structure is more clearly defined below:

## 1. Common files

There are 3 common `docker-compose.*` files and 1 common `.env` file.

#### `docker-compose.service-base.yml`

This file contains a single service definition. When loading a `docker-compose.yml` file from a service, each container in the file (i.e. `.services.*`) will be joined with this base service.
The value `{{ COM_GABBRO_CONTAINER }}` will be replaced with the name of the container from the service. For example, given the following `docker-compose.service-base.yml`:

```yml
services:
  {{ COM_GABBRO_CONTAINER }}:
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

Any appearances of the string `{{ SOME_VAR }}` will be replaced with corresponding value from the environment file in any docker compose file. For example, if the docker compose file contains the string `{{ KEY }}` and
the env file contains the line `KEY=VALUE`, then all occurrences of `{{ KEY }}` will be replaced by `VALUE`.

### Environment Files

Values can be defined in the base environment file (`.env`) to be made available to the base docker files and all service docker files. Additionally, an environment file can be defined inside the services folder
(i.e. `services/$service/.env`). The values in this environment file will be made available to the service docker compose file as well as the `docker-compose.service-base.yml` file. Note that the env file itself is **not**
copied to the deployment, so any environment variables that should be made available to the service itself should be defined in the `environment:` section of the docker compose file.

### Plugins

A key can be written as `{{ plugin_name('argument1', 'argument2', ...) }}`. In this case, a plugin engine will run and try to resolve the plugin, and use that for the value instead of searching the environment files.
The following plugins are supported:
- `{{ secret('path/to/folder', 'SECRET_NAME') }}` - this will make a url request to Infisical to try and retrieve the secret. It will use the key in `key.txt` as an authorization token to retrieve the secret.


## 4. Final Steps

Once everything has been hydrated and merged into the final docker compose file, it is placed in the tmp directory at `tmp/docker-compose.yml`.

# Deployment

The project is deployed in two steps. Firstly, the python script is run. This will run the change detection, and add the service files in `tmp`.

```shell
python3 ./scripts/build.py
```
