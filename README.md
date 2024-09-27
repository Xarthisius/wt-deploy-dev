Setting up a local instance of Whole Tale
=========================================

This directory contains scripts required to run a full instance of the Whole Tale platform  on a single system (e.g., laptop or VM). The installation uses a predefined domain `*.local.wholetale.org` which maps to localhost. This means that VM-based installations will require port forwarding to access (see below).


System requirements
-------------------
 * Linux (tested on Ubuntu 18.04, CoreOS; not working on MacOS _yet_)
 * docker 17.04.0+, swarm mode
 * python, requests
 * jq
 * make
 * Globus OAuth credentials (pinned at `#core-dev`)
 * SSL certs for .local.wholetale.org (pinned at `#core-dev`)
 * Default user with uid:1000 and gid:100
 * On Ubuntu, `apt-get install davfs2 fuse libfuse-dev`
  
 
Deployment process
------------------
The deployment process does the following:
* Pulls all required images
* Starts the WT stack via Docker swarm
* Starts the Celery worker (`gwvolman`)
    * **WARNING:** This container has fairly elavated privileges:
        *  it has access to host's filesystem
        *  it can perform multiple system calls as de facto host's root
    * **WARNING:** During `celery_worker`'s initialization host's `/usr/local` directory is overshadowed by the content of `/usr/local` from the container. 
* Runs `setup_girder.py` to initialize the instance

If you haven't already, initialize your system as a swarm master:
```
docker swarm init
```

Add default user (1000) and group (100), if not present:
```
[[ -z $(getent group 100) ]] && sudo groupadd -g 100 wtgroup
[[ -z $(getent passwd 1000) ]] && sudo useradd -g 100 -u 1000 wtuser
```

Export Globus Oauth ID and secret (available on `#core-dev`):
```
export GLOBUS_CLIENT_ID=<client ID>
export GLOBUS_CLIENT_SECRET=<client secret>
```

Export ORCID ID and secret (available on `#core-dev`):
```
export ORCID_CLIENT_ID=<client ID>
export ORCID_CLIENT_SECRET=<client secret>
```

Export cloudflare API TOKEN:
```
export WT_CLOUDFLARE_TOKEN=<cf_api_token>
```

Export domain you are using:
```
export WT_DOMAIN=local.wholetale.org
```

Clone this repository:

```
git clone https://github.com/whole-tale/deploy-dev
cd deploy-dev/
```

Create the traefik acme directory. Download SSL certs from `#core-dev` and copy to  `acme.json` in this directory. Change permissions and ownership:
```
mkdir traefik/acme
sudo chown root:root traefik/acme/acme.json
sudo chmod 0600 traefik/acme/acme.json
```


Run:
```
make dev
```

To confirm things are working, all `REPLICAS` should show `1/1`
```
$ docker service ls
ID                  NAME                MODE                REPLICAS            IMAGE                        PORTS
jpzhf12jh6wj        wt_dashboard        replicated          1/1                 wholetale/dashboard:latest
26gv8qfb85sq        wt_girder           replicated          1/1                 wholetale/girder:latest
irdizcla8jal        wt_mongo            replicated          1/1                 mongo:3.2
p46dbxbgcae3        wt_redis            replicated          1/1                 redis:latest
vyf55zx0x95y        wt_registry         replicated          1/1                 registry:2.6                 *:443->443/tcp
41u4zyqrrv79        wt_traefik          replicated          1/1                 traefik:alpine               *:80->80/tcp, *:8080->8080/tcp
```

The `celery_worker` runs outside of swarm, confirm that it's running:
```
$ docker ps | grep celery_worker
0e8124024f03        wholetale/gwvolman:latest                                "python3 -m girder_w…"   15 hours ago        Up 15 hours                             celery_worker
```

Note: If you're running in a VM, you'll need to setup  forwarding for port 443 (requires `sudo`):
```
$ sudo ssh -L 443:localhost:443 user@VM
```

You should now be able to open a browser to https://dashboard.local.wholetale.org to access your running instance of Whole Tale.

Modifications
---------
Anytime you modify `docker-stack.yml`, you will need to run `make dev` to see those changes reflected in Docker.

### Development Modifications
If you plan to modify and rebuild the dashboard code, you can follow these steps:
1. First, run a `make rebuild_dashboard`
2. Under `dashboard` in `docker-stack.yml`, uncomment the relevant `volumes` section u
3. Run `make dev` to deploy `docker-stack.yml` to the swarm

NOTE: if you fail to run `make rebuild_dashboard` first, Docker may create your `dist/` directory with incorrect permissions (which can lead to headaches later when writing build artifacts or serving built artifacts via NGINX)

Uninstall
---------

The following will remove all services and delete the volume data:

```
make clean
```
