from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

from urllib.error import HTTPError, URLError

from ansible.errors import AnsibleError
from ansible.module_utils.common.text.converters import to_text, to_native
from ansible.module_utils.urls import open_url, ConnectionError, SSLValidationError
from ansible.plugins.lookup import LookupBase
from ansible.utils.display import Display
from urllib.parse import urlencode

import json

display = Display()

DOCUMENTATION="""
name: infisical
author: haondt
options:
  host:
    env:
      - name: ANSIBLE_LOOKUP_INFISICAL_HOST
    ini:
      - section: infisical
        key: host
    vars:
      - name: ansible_lookup_infisical_host
    required: True
    type: string
  environment:
    env:
      - name: ANSIBLE_LOOKUP_INFISICAL_ENVIRONMENT
    ini:
      - section: infisical
        key: environment
    vars:
      - name: ansible_lookup_infisical_environment
    required: True
    type: string
  workspace_id:
    env:
      - name: ANSIBLE_LOOKUP_INFISICAL_WORKSPACE_ID
    ini:
      - section: infisical
        key: workspace_id
    vars:
      - name: ansible_lookup_infisical_workspace_id
    required: True
    type: string
  key:
    env:
      - name: ANSIBLE_LOOKUP_INFISICAL_KEY
    ini:
      - section: infisical
        key: key
    vars:
      - name: ansible_lookup_infisical_key
    required: True
    type: string
"""

EXAMPLES = """
- name: my secret
  debug: msg: {{ lookup('infisical', 'path/to/secret') }}
"""

RETURN = """
  _list:
    description: list of secrets
    type: list
    elements: str
"""

class LookupModule(LookupBase):
    def run(self, terms, variables=None, **kwargs):

        self.set_options(var_options=variables, direct=kwargs)

        ret = []
        for term in terms:

            path = [i.strip() for i in term.split('/') if len(i.strip()) > 0]
            if len(path) == 0:
                raise AnsibleError("Unable to parse term: %s" % term)
            secretName = path[-1]
            if len(path) > 1:
                path = '/' + '/'.join(path[:-1]) + '/'
            else:
                path = None

            display.vvvv("getting url for %s" % ((path or '') + secretName))
            try:
                url = self.get_option('host') + f'/api/v3/secrets/raw/{secretName}'
                params = {
                    'environment': self.get_option('environment'),
                    'workspaceId': self.get_option('workspace_id')
                }
                if path is not None:
                    params['secretPath'] = path
                url += "?" + urlencode(params)
                response = open_url(url, headers={'Authorization': 'Bearer ' + self.get_option('key')})
            except HTTPError as e:
                raise AnsibleError("Received HTTP error for %s : %s" % (term, to_native(e)))
            except URLError as e:
                raise AnsibleError("Failed lookup url for %s : %s" % (term, to_native(e)))
            except SSLValidationError as e:
                raise AnsibleError("Error validating the server's certificate for %s: %s" % (term, to_native(e)))
            except ConnectionError as e:
                raise AnsibleError("Error connecting to %s: %s" % (term, to_native(e)))

            ret.append(json.loads(response.read())['secret']['secretValue'])
        return ret