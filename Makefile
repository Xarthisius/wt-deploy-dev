.PHONY: clean dirs dev images gwvolman_src wholetale_src dms_src home_src dashboard_src sources \
	rebuild_dashboard_old rebuild_dashboard watch_dashboard_old watch_dashboard_old_dev watch_dashboard \
	restart_worker restart_girder globus_handler_src

SUBDIRS = ps homes src
TAG = latest
MEM_LIMIT = 2048
NODE = node --max_old_space_size=${MEM_LIMIT}
NG = ${NODE} ./node_modules/@angular/cli/bin/ng
YARN = /usr/local/bin/yarn

images:
	docker pull traefik:alpine
	docker pull mongo:3.2
	docker pull redis:latest
	docker pull registry:2.6
	docker pull node:carbon-slim
	docker pull wholetale/girder:$(TAG)
	docker pull wholetale/gwvolman:$(TAG)
	docker pull wholetale/repo2docker_wholetale:$(TAG)
	docker pull wholetale/ngx-dashboard:$(TAG)

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

src/dashboard_old:
	git clone https://github.com/whole-tale/dashboard src/dashboard
	docker run --rm -ti -v $${PWD}/src/dashboard:/usr/src/node-app -w /usr/src/node-app node:carbon-slim sh -c "$$(cat dashboard_local/initial_build.sh)"

src/globus_handler:
	git clone https://github.com/whole-tale/globus_handler src/globus_handler

src/ngx-dashboard:
	git clone https://github.com/whole-tale/ngx-dashboard src/ngx-dashboard

sources: src/gwvolman src/wholetale src/wt_data_manager src/wt_home_dir src/dashboard src/globus_handler src/girderfs src/ngx-dashboard

dirs: $(SUBDIRS)

$(SUBDIRS):
	@mkdir $@

services: dirs sources

dev: services
	docker stack deploy --compose-file=docker-stack.yml wt
	./run_worker.sh
	cid=$$(docker ps --filter=name=wt_girder -q);
	while [ -z $${cid} ] ; do \
		  echo $${cid} ; \
		  sleep 1 ; \
	    cid=$$(docker ps --filter=name=wt_girder -q) ; \
	done; \
	true
	docker exec --user=root -ti $$(docker ps --filter=name=wt_girder -q) pip install -r /gwvolman/requirements.txt -e /gwvolman
	docker exec -ti $$(docker ps --filter=name=wt_girder -q) girder-install plugin plugins/wt_data_manager plugins/wholetale plugins/wt_home_dir plugins/globus_handler
	docker exec -ti $$(docker ps --filter=name=wt_girder -q) girder-install web --dev --plugins=oauth,gravatar,jobs,worker,wt_data_manager,wholetale,wt_home_dir,globus_handler
	./setup_girder.py

restart_girder:
	which jq || (echo "Please install jq to execute the 'restart_girder' make target" && exit 1)
	docker exec --user=root -ti $$(docker ps --filter=name=wt_girder -q) pip install -r /gwvolman/requirements.txt -e /gwvolman
	docker exec -ti $$(docker ps --filter=name=wt_girder -q) \
                curl -XPUT -s 'http://localhost:8080/api/v1/system/restart' \
                        --header 'Content-Type: application/json' \
                        --header 'Accept: application/json' \
                        --header 'Content-Length: 0' \
                        --header "Girder-Token: $$(docker exec -ti $$(docker ps --filter=name=wt_girder -q) \
                                curl 'http://localhost:8080/api/v1/user/authentication' \
                                --basic --user admin:arglebargle123 \
                                        | jq -r .authToken.token)"

	
rebuild_dashboard_old: src/dashboard
	sed -e "s|apiHOST|https://girder.local.wholetale.org|g" \
		-e "s|dashboardHOST|https://dashboard.local.wholetale.org|g" \
		-e "s|dataOneHOST|https://cn-stage-2.test.dataone.org|g" \
		-e "s|dashboardDev|true|g" \
		-e "s|authPROVIDER|Globus|g" -i src/dashboard/config/environment.js
	docker run --rm -ti -v $${PWD}/src/dashboard:/usr/src/node-app -w /usr/src/node-app node:carbon-slim sh -c 'NODE_ENV=development npm install && ./node_modules/.bin/ember build --environment=production'

watch_dashboard_old: src/dashboard
	sed -e "s|apiHOST|https://girder.local.wholetale.org|g" \
                -e "s|dashboardHOST|https://dashboard.local.wholetale.org|g" \
                -e "s|dataOneHOST|https://cn-stage-2.test.dataone.org|g" \
		-e "s|dashboardDev|true|g" \
                -e "s|authPROVIDER|Globus|g" -i src/dashboard/config/environment.js
	docker run --rm -ti -v $${PWD}/src/dashboard:/usr/src/node-app -w /usr/src/node-app node:carbon-slim sh -c 'NODE_ENV=development npm install && ./node_modules/.bin/ember serve --environment=production'

watch_dashboard_old_dev: src/dashboard
	sed -e "s|apiHOST|https://girder.local.wholetale.org|g" \
                -e "s|dashboardHOST|https://dashboard.local.wholetale.org|g" \
                -e "s|dataOneHOST|https://cn-stage-2.test.dataone.org|g" \
                -e "s|authPROVIDER|Globus|g" -i src/dashboard/config/environment.js
	docker run --rm -ti -v $${PWD}/src/dashboard:/usr/src/node-app -w /usr/src/node-app node:carbon-slim sh -c 'NODE_ENV=development npm install && ./node_modules/.bin/ember serve'

rebuild_dashboard:
	docker run --rm --user=$${UID}:$${GID} -ti -v $${PWD}/src/ngx-dashboard:/srv/app -w /srv/app bodom0015/ng '${YARN} install --network-timeout=360000 && ${NG} build --prod --deleteOutputPath=false --progress'

watch_dashboard:
	docker run --rm --user=$${UID}:$${GID} -ti -v $${PWD}/src/ngx-dashboard:/srv/app -w /srv/app bodom0015/ng '${YARN} install --network-timeout=360000 && ${NG} build --prod --watch --poll 15000 --deleteOutputPath=false --progress'

restart_worker:
	docker exec --user=root -ti $$(docker ps --filter=name=wt_girder -q) pip install -e /gwvolman
	./stop_worker.sh && ./run_worker.sh

tail_girder_err:
	docker exec -ti $$(docker ps --filter=name=wt_girder -q) \
		tail -n 200 /home/girder/.girder/logs/error.log

clean:
	-./stop_worker.sh
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
	-docker volume rm wt_mongo-cfg wt_mongo-data
