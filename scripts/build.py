from git import Repo
from types import SimpleNamespace
import re, os, requests, yaml, shutil, fnmatch

def represent_none(self, _):
    return self.represent_scalar('tag:yaml.org,2002:null', '')
yaml.add_representer(type(None), represent_none)

class Consts:
    INFISICAL_URL="http://infisical.gabbro-ce"

def load_file(fn):
    try:
        with open(fn, 'r') as f:
            return f.read()
    except FileNotFoundError:
        raise FileNotFoundError(fn)

def get_secret_key():
    return load_file('key.txt').strip()

# get changed files
def get_changes():
    repo = Repo(".")
    assert not repo.bare
    head = repo.commit("HEAD")
    diff = head.diff("HEAD~", create_patch=False)
    return [i.a_path for i in diff]

# get changed services
def filter_services(files):
    base_files = [
        r'\.env',
        r'docker-compose\..*\.yml'
    ]

    bp = re.compile('^' + '|'.join([f'({i})' for i in base_files]) + '$')
    if len([i for i in files if bp.match(i)]) > 0:
        return [d for d in next(os.walk('services'))[1] if os.path.isfile(f'services/{d}/docker-compose.yml')]
    sp = re.compile(r'^services\/([^/]+)\/.+$')
    services = [sp.search(i).group(1) for i in files if sp.match(i)]
    return [s for s in services if os.path.isfile(f'services/{s}/docker-compose.yml')]

# load env file into a dictionary
def load_env_file(fn):
    plugin_pattern = re.compile(r"^\s*([^\s#]+)\s*=\{\{\s*([A-Za-z_-]+)\s*\(\s*([^)]*)\s*\)\s*\}\}\s*$")
    plugin_args_pattern = re.compile("(?:'([^']*)')|([0-9]+)")

    base_pattern = re.compile(r"^\s*([^\s#]+)\s*=\s*([^\s#]*)\s*$")
    ignore_pattern = re.compile(r"^\s*(#.*)?$")

    d = {}
    with open(fn, 'r') as f:
        for l in f:
            l = l.strip()

            im = ignore_pattern.match(l)
            if im:
                continue

            pm = plugin_pattern.match(l)
            if pm:
                g = [i for i in pm.groups() if i != None]
                args = ([''.join(i) for i in plugin_args_pattern.findall(g[2])])
                if g[0] in d:
                    raise ValueError(f"Multiple entries for variable: {g[0]}")
                d[g[0]] = plugin(g[1], args)
                continue

            bm = base_pattern.match(l)
            if bm:
                k, v = [i.strip() for i in bm.groups()]
                if k in d:
                    raise ValueError(f"Multiple entries for variable: {k}")
                d[k] = v
                continue
            raise ValueError(f"Malformed environment variable: {l}")
    return d

# execute a plugin
def plugin(name, args):
    if name == 'secret':
        if len(args) != 2:
            print(f"Unexpected number of arguments for plugin \'secret\': {args}")
        key = get_secret_key()
        url = f"{Consts().INFISICAL_URL}/api/v3/secrets/raw/{args[1]}?environment=prod&workspaceId=64cb8985f721447f27fb5123&secretPath=/{args[0]}/"
        try:
            response = requests.get(url, headers={"Authorization": f"Bearer {key}"})
            if response.status_code == 200:
                return f"{response.json()['secret']['secretValue']}"
            response.raise_for_status()
        except:
            raise ValueError(f"Unable to retrieve secret {args[0]}/{args[1]}")
    raise ValueError(f"Unkown plugin: {name}")

# replace {{ KEY }} with VALUE from d
def hydrate(s, d):
    def rpl(match):
        k = match.group(1).strip()
        if k not in d:
            raise KeyError(f"Key '{k}' not found in environment")
        return d[k]
    p = re.compile(r"{{\s*([^{}\s]+)\s*}}")
    return re.sub(p, rpl, s)

# deep merge two dictionaries created from yaml
# when merging primitives, the one from d2 is preferred
def deep_merge(d1, d2, conflicts="new", path=""):
    if conflicts not in ["new", "old", "err"]:
        raise ValueError("Unexpected conflict resolution:" + conflicts)
    def merge_list(l1, l2):
        return list(set(l1 + l2))
    result = d1.copy()
    for k, v in d2.items():
        if k not in result:
            result[k] = v
            continue
        if type(v) != type(result[k]):
            if conflicts == "new":
                result[k] = v
            elif conflicts == "err":
                raise KeyError(f"Multiple entries found for key: {path}.{k}")
            continue
        if isinstance(v, dict):
            result[k] = deep_merge(result[k], v, conflicts, path + "." + k)
            continue
        if isinstance(v, (tuple, list)):
            result[k] = merge_list(result[k], v)
            continue

        if conflicts == "new":
            result[k] = v
        elif conflicts == "err":
            raise KeyError(f"Multiple entries found for key: {path}.{k}")
    return result

def build_service_yaml(service, base_env, base_yaml):
    # create environment
    service_env = {}
    service_env_fname = f"services/{service}/.env"
    if (os.path.isfile(service_env_fname)):
        service_env = load_env_file(service_env_fname)

    # merge environment with base
    intersection = set(service_env.keys()) & set(base_env.keys())
    if intersection:
        raise ValueError(f"Found multiple env entries for the following keys: {intersection}")
    service_env = {**base_env, **service_env}

    # load service yaml
    service_yaml = load_file(f"services/{service}/docker-compose.yml")

    # hydrate service_yaml
    service_hydrated = hydrate(service_yaml, service_env)

    # get containers in service
    service_loaded = yaml.safe_load(service_hydrated)
    containers = service_loaded['services'].keys()
    for container in containers:
        # hydrate base_yaml with container name and service + base environment
        container_env = service_env.copy()
        container_env['COM_GABBRO_CONTAINER'] = container
        container_hydrated = hydrate(base_yaml, container_env)
        container_loaded = yaml.safe_load(container_hydrated)

        # merge container description from service into container base yaml
        container_loaded = deep_merge(container_loaded, {'services': { f"{container}": service_loaded['services'][container] } })
        # merge container base yaml into service yaml
        service_loaded = deep_merge(service_loaded, container_loaded)
    return SimpleNamespace(dict=service_loaded, env=service_env)

def clear_tmp():
    if os.path.isdir('tmp'):
        shutil.rmtree('tmp')
    os.makedirs("tmp")

def ignore_docker_compose(dir, files):
    p = 'services/[^/]+/docker-compose.yml'
    return [i for i in files if re.match(p, os.path.join(dir, i))]

def cpy_services(services):
    for svc in services:
        src = f'services/{svc}'
        dst = f'tmp/{svc}'
        shutil.copytree(src, dst, ignore=ignore_docker_compose)

def main():
    #  Get changes
    changes = get_changes()
    changed_services = filter_services(changes)
    if len(changed_services) == 0:
        print("No changes detected")
        return
    print("Changes detected for the following services:\n    " + "\n    ".join(changed_services))

    # get all services
    services = filter_services([".env"])

    # recreate tmp folder
    clear_tmp()

    # load base files
    base_env = load_env_file(".env")
    base_yaml = load_file('docker-compose.service-base.yml')

    # generate config objects for each service
    service_configs = [build_service_yaml(s, base_env, base_yaml) for s in services]
    containers = [c for cs in [service_configs[i].dict['services'].keys() for i, s in enumerate(services) if s in changed_services] for c in cs]

    # merge service configs
    service_config = service_configs[0].dict.copy()
    for cfg in service_configs[1:]:
        service_config = deep_merge(service_config, cfg.dict, conflicts="err")

    # merge in overrides
    override_yaml = load_file("docker-compose.overrides.yml")
    override_hydrated = hydrate(override_yaml, base_env)
    override_obj = yaml.safe_load(override_hydrated)
    final_cfg = deep_merge(service_config, override_obj)

    # create final file
    final_yaml = yaml.dump(final_cfg, default_flow_style=False)
    header = load_file("docker-compose.header.yml")
    final_yaml = header + final_yaml

    # save
    with open('tmp/docker-compose.yml', 'w') as f:
        f.write(final_yaml)
    with open('changes.txt', 'w') as f:
        f.write('\n'.join(containers))

    # copy and hydrate extra service files
    cpy_services(services)
    for (i, service) in enumerate(services):
        if os.path.isfile(f'tmp/{service}/hydrate.gabbro'):
            with open(f'tmp/{service}/hydrate.gabbro', 'r') as f:
                for fn in f:
                    fn = f'tmp/{service}/{fn.strip()}'
                    data = load_file(fn)
                    hydrated = hydrate(data, service_configs[i].env)
                    with open(fn, 'w') as _f:
                        _f.write(hydrated)

if __name__ == '__main__':
    try:
        main()
    # discard stack trace
    except Exception as e:
        print(f"{type(e).__name__}:", e)
        exit(1)


