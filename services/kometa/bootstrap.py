import yaml, os
from typing import Any

def represent_none(self, _):
    return self.represent_scalar('tag:yaml.org,2002:null', '')

yaml.add_representer(type(None), represent_none)

paths_to_persist: list[list[str | int]] = [
    ['trakt', 'authorization'],
    ['mal', 'authorization']
]

def set_nested_value(data: Any, keys: list[str | int], value: Any):
    for key in keys[:-1]:
        if isinstance(key, int) and isinstance(data, list):
            while len(data) <= key:
                data.append({})
            data = data[key]
        else:
            data = data.setdefault(key, {})
    if isinstance(keys[-1], int) and isinstance(data, list):
        while len(data) <= keys[-1]:
            data.append({})
        data[keys[-1]] = value
    else:
        data[keys[-1]] = value
    
def get_nested_value(data, keys):
    for key in keys:
        if isinstance(key, int) and isinstance(data, list):
            if len(data) > key:
                data = data[key]
            else:
                return None
        else:
            data = data.get(key, None)
            if data is None:
                return None
    return data



existing_path = '/config/config.yml'
config_path = '/config.yml'
existing_path = './existing.yml'
config_path = './config.yml'
existing = None
config = None
if os.path.isfile(existing_path):
    with open(existing_path, 'r') as f:
        existing_str = f.read()
        if len(existing_str) > 0:
            existing = yaml.safe_load(existing_str)
with open(config_path, 'r') as f:
    config = yaml.safe_load(f)

if existing is not None:
    for path in paths_to_persist:
        value = get_nested_value(existing, path)
        if value is not None:
            set_nested_value(config, path, value)
with open(existing_path, 'w') as f:
    yaml.dump(config, f)
