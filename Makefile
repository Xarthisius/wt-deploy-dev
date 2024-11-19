.PHONY: clean dirs dev images gwvolman_src wholetale_src dms_src home_src sources_wt \
	rebuild_dashboard watch_dashboard \
	restart_worker restart_girder globus_handler_src status update_src certs

SUBDIRS = src volumes/ps volumes/workspaces volumes/homes volumes/base volumes/versions volumes/runs volumes/licenses volumes/mountpoints volumes/tmp volumes/minio
TAG = latest
MEM_LIMIT = 2048
NODE = node --max_old_space_size=${MEM_LIMIT}
NG = ${NODE} ./node_modules/@angular/cli/bin/ng
YARN = /usr/local/bin/yarn

images:
	docker pull traefik:alpine
	docker pull mongo:4.4
	docker pull redis:latest
	docker pull registry:2.6
	docker pull node:carbon-slim
	docker pull xarthisius/girder:$(TAG)
	docker pull xarthisius/gwvolman:$(TAG)
	docker pull xarthisius/repo2docker_wholetale:$(TAG)
	docker pull xarthisius/ngx-dashboard:$(TAG)

.env:
	curl -s -o .env https://wt.xarthisius.xyz/wt_local_env

traefik/certs:
	mkdir -p traefik/certs

traefik/certs/fullchain.pem: traefik/certs
	curl -s -o traefik/certs/fullchain.pem https://wt.xarthisius.xyz/wt_local_cert

traefik/certs/privkey.pem: traefik/certs
	curl -s -o traefik/certs/privkey.pem https://wt.xarthisius.xyz/wt_local_key

certs: .env traefik/certs/fullchain.pem traefik/certs/privkey.pem

src/sem_viewer:
	git clone https://github.com/htmdec/sem_viewer src/sem_viewer

src/table_view:
	git clone https://github.com/htmdec/table_view src/table_view

src/synced_folders:
	git clone https://github.com/whole-tale/synced_folders src/synced_folders

src/girderfs:
	git clone https://github.com/whole-tale/girderfs src/girderfs

src/gwvolman:
	git clone https://github.com/whole-tale/gwvolman src/gwvolman

src/wholetale:
	git clone https://github.com/whole-tale/girder_wholetale src/wholetale

src/wt_data_manager:
	git clone https://github.com/whole-tale/girder_wt_data_manager src/wt_data_manager

src/wt_home_dir:
	git clone https://github.com/whole-tale/wt_home_dirs src/wt_home_dir

src/wt_versioning:
	git clone https://github.com/whole-tale/wt_versioning src/wt_versioning

src/virtual_resources:
	git clone https://github.com/whole-tale/virtual_resources src/virtual_resources

src/globus_handler:
	git clone https://github.com/whole-tale/globus_handler src/globus_handler

src/ngx-dashboard:
	git clone https://github.com/whole-tale/ngx-dashboard src/ngx-dashboard

sources_wt: src src/gwvolman src/wholetale src/wt_data_manager src/wt_home_dir src/globus_handler src/girderfs src/ngx-dashboard src/virtual_resources src/wt_versioning src/sem_viewer src/table_view src/synced_folders certs

dirs: $(SUBDIRS)

$(SUBDIRS):
	@sudo mkdir -p $@

services: dirs sources_wt

dev: services
	. ./.env && docker stack config --compose-file docker-stack.yml | docker stack deploy --compose-file - wt
	cid=$$(docker ps --filter=name=wt_girder -q);
	while [ -z $${cid} ] ; do \
		  echo $${cid} ; \
		  sleep 1 ; \
	    cid=$$(docker ps --filter=name=wt_girder -q) ; \
	done; \
	true
	. ./.env && ./setup_girder.py

restart_girder:
	docker exec --user=root -ti $$(docker ps --filter=name=wt_girder -q) touch /venv/lib/python3.12/site-packages/requests/__init__.py

rebuild_dashboard:
	docker run \
		--rm \
		--user=$${UID}:$${GID} \
		-ti \
		-e NODE_OPTIONS=--max-old-space-size=4096 \
		-v $${PWD}/src/ngx-dashboard:/srv/app \
		--entrypoint /bin/sh \
		-w /srv/app node:fermium \
			-c 'yarn install --network-timeout=360000 && \
			./node_modules/@angular/cli/bin/ng build --deleteOutputPath=false --progress'

watch_dashboard:
	docker run \
		--rm \
		--user=$${UID}:$${GID} \
		-ti \
		-e NODE_OPTIONS=--max-old-space-size=4096 \
		-v $${PWD}/src/ngx-dashboard:/srv/app \
		-w /srv/app \
		--entrypoint /bin/sh \
		node:fermium \
			-c 'yarn install --network-timeout=360000 && \
			./node_modules/@angular/cli/bin/ng build --watch --poll 15000 --deleteOutputPath=false --progress'

restart_worker:
	docker exec --user=root -ti $$(docker ps --filter=name=wt_girder -q) pip install -e /gwvolman
	docker service update --force --image=$$(docker service inspect wt_celery_worker --format={{.Spec.TaskTemplate.ContainerSpec.Image}}) wt_celery_worker

tail_girder_err:
	docker exec -ti $$(docker ps --filter=name=wt_girder -q) \
		tail -n 200 /home/girder/.girder/logs/error.log

reset_girder:
	docker exec -ti $$(docker ps --filter=name=wt_girder -q) \
		python3 -c 'from girder.models import getDbConnection;getDbConnection().drop_database("girder")'

clean:
	-./destroy_instances.py
	-docker stack rm wt
	limit=15 ; \
	until [ -z "$$(docker service ls --filter label=com.docker.stack.namespace=wt -q)" ] || [ "$${limit}" -lt 0 ]; do \
	  sleep 2 ; \
	  limit="$$((limit-1))" ; \
	done; true
	limit=15 ; \
	until [ -z "$$(docker network ls --filter label=com.docker.stack.namespace=wt -q)" ] || [ "$${limit}" -lt 0 ]; do \
	  sleep 2 ; \
	  limit="$$((limit-1))" ; \
	done; true
	for dir in volumes/mountpoints/* ; do \
	  for subdir in $$dir/* ; do \
	    sudo umount -lf $$subdir || true ; \
	  done \
	done; true
	for dir in ps workspaces homes base versions runs mountpoints ; do \
	  sudo rm -rf volumes/$$dir ; \
	done; true
	-docker volume rm wt_mongo-cfg wt_mongo-data

status:
	@-./scripts/git_status.sh

update_src:
	@-./scripts/git_pull_master.sh
