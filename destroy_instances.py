#!/usr/bin/env python3
import json
import requests
import time
import os
import sys
from requests.auth import HTTPBasicAuth
from subprocess import check_output

headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
}

api_url = f'https://girder.{os.environ.get("WT_DOMAIN", "local.xarthisius.xyz")}/api/v1'

try:
    r = requests.get(api_url + '/user/authentication', auth=HTTPBasicAuth('admin', 'arglebargle123'))
except:
    print('Girder is no longer running')
    exit()
r.raise_for_status()
headers['Girder-Token'] = r.json()['authToken']['token']

print('Deleting all running instances')
r = requests.get(api_url + '/instance', headers=headers,
                 params={'limit': 0})
r.raise_for_status()
for instance in r.json():
    requests.delete(api_url + '/instance/' + instance['_id'], headers=headers)

cmd = "docker service ls --filter=name=tmp -q | xargs -r docker service rm"
print(check_output(cmd, shell=True))
