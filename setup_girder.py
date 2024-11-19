#!/usr/bin/env python3
import json
import requests
import time
import os
import sys

params = {
    "login": "admin",
    "email": "root@dev.null",
    "firstName": "John",
    "lastName": "Doe",
    "password": "arglebargle123",
    "admin": True,
}
headers = {"Content-Type": "application/json", "Accept": "application/json"}
domain = os.environ.get("domain", "local.xarthisius.xyz")

def final_msg():
    print("-------------- You should be all set!! -------------")
    print(f"try going to https://girder.{domain} and log in with: ")
    print("  user : %s" % params["login"])
    print("  pass : %s" % params["password"])

api_url = f"https://girder.{domain}/api/v1"

# Give girder time to start
while True:
    print("Waiting for Girder to start")
    r = requests.get(api_url)
    if r.status_code == 200:
        break
    time.sleep(2)

print("Creating admin user")
r = requests.post(api_url + "/user", params=params, headers=headers)
if r.status_code == 400:
    print("Admin user already exists. Database was not purged.")
    print("If that is OK:")
    final_msg()
    sys.exit()
# Store token for future requests
headers["Girder-Token"] = r.json()["authToken"]["token"]

print("Creating default assetstore")
r = requests.post(
    api_url + "/assetstore",
    headers=headers,
    params={
        "type": 0,
        "name": "Base",
        "root": "/srv/data/base",
    },
)

print("Setting up Plugin")

settings = [
    {
        "key": "core.cors.allow_origin",
        "value": f"https://dashboard.{domain},http://localhost:4200,https://legacy.{domain}",
    },
    {
        "key": "core.cors.allow_headers",
        "value": (
            "Accept-Encoding, Authorization, Content-Disposition, Set-Cookie, "
            "Content-Type, Cookie, Girder-Authorization, Girder-Token, "
            "X-Requested-With, X-Forwarded-Server, X-Forwarded-For, "
            "X-Forwarded-Host, Remote-Addr, Cache-Control"
        ),
    },
    # {"key": "core.cookie_domain", "value": f".{domain}"},
    {"key": "worker.api_url", "value": "http://girder:8080/api/v1"},
    {"key": "worker.broker", "value": "redis://redis/"},
    {"key": "worker.backend", "value": "redis://redis/"},
    {"key": "oauth.globus_client_id", "value": os.environ.get("GLOBUS_CLIENT_ID")},
    {
        "key": "oauth.globus_client_secret",
        "value": os.environ.get("GLOBUS_CLIENT_SECRET"),
    },
    #{"key": "oauth.orcid_client_id", "value": os.environ.get("ORCID_CLIENT_ID")},
    #{
    #    "key": "oauth.orcid_client_secret",
    #    "value": os.environ.get("ORCID_CLIENT_SECRET"),
    #},
    {"key": "oauth.providers_enabled", "value": ["globus"]},
    # {"key": "dm.globus_gc_dir", "value": "/opt/globusconnectpersonal"},
    #{
    #    "key": "wholetale.zenodo_extra_hosts",
    #    "value": ["https://sandbox.zenodo.org/record/"]
    #},
    {"key": "dm.private_storage_path", "value": "/srv/data/ps"},
    {"key": "wholetale.homes_root", "value": "/srv/data/homes"},
    {"key": "wholetale.workspaces_root", "value": "/srv/data/workspaces"},
    {"key": "wholetale.runs_root", "value": "/srv/data/runs"},
    {"key": "wholetale.versions_root", "value": "/srv/data/versions"},
    {"key": "wholetale.dashboard_link_title", "value": "Tale Dashboard"},
    {"key": "wholetale.catalog_link_title", "value": "Data Catalog"},
    {"key": "wholetale.enable_data_catalog", "value": True},
]

r = requests.put(
    api_url + "/system/setting", headers=headers, params={"list": json.dumps(settings)}
)
try:
    r.raise_for_status()
except requests.exceptions.HTTPError:
    if r.status_code >= 400 and r.status_code < 500:
        print(f"Request died with {r.status_code}: {r.reason}")
        print(f"Returned: {r.text}")
    raise

with open("dev_images.json", "r") as fp:
    images = json.load(fp)

for image in images:
    print(f"Creating {image['name']} image")
    image["config"] = json.dumps(image["config"])
    r = requests.post(api_url + "/image", headers=headers, params=image)
    r.raise_for_status()

#print("Restarting girder to update WebDav roots")
#r = requests.put(api_url + "/system/restart", headers=headers)
#r.raise_for_status()
final_msg()
