#!/bin/sh

domain=local.xarthisius.xyz
role=manager,celery
image=wholetale/gwvolman:v1.2.1
registry_user=fido
registry_pass=secretpass
r2d_version=xarthisius/repo2docker_wholetale:20240926
matlab_file_installation_key=secretkey
node_id=$(docker info --format "{{.Swarm.NodeID}}")
celery_args="-Q ${role},${node_id} --hostname=${node_id} -c 3"

sudo umount /usr/local/lib > /dev/null 2>&1 || true
docker stop -t 0 celery_worker >/dev/null 2>&1
docker rm celery_worker > /dev/null 2>&1

# docker pull ${image} > /dev/null 2>&1

echo "${celery_args}"
  
# -e GIRDER_API_URL=https://girder.${domain}/api/v1 \   # Add if you are not using 127.0.0.1

docker run \
    --name celery_worker \
    --label traefik.enable=false \
    -e HOSTDIR=/host \
    -e TRAEFIK_NETWORK=wt_traefik-net \
    -e TRAEFIK_ENTRYPOINT=websecure \
    -e REGISTRY_USER=${registry_user} \
    -e REGISTRY_URL=https://registry.${domain} \
    -e REGISTRY_PASS=${registry_pass} \
    -e DOMAIN=${domain} \
    -e REPO2DOCKER_VERSION="${r2d_version}" \
    -e WT_LICENSE_PATH="$PWD"/volumes/licenses \
    -e WT_VOLUMES_PATH="$PWD"/volumes \
    -e MATLAB_FILE_INSTALLATION_KEY=${matlab_file_installation_key} \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -v /:/host \
    -v /var/cache/davfs2:/var/cache/davfs2 \
    -v /run/mount.davfs:/run/mount.davfs \
    --add-host=registry.${domain}:host-gateway \
    --add-host=images.${domain}:host-gateway \
    --add-host=girder.${domain}:host-gateway \
    --device /dev/fuse \
    --cap-add SYS_ADMIN \
    --cap-add SYS_PTRACE \
    --security-opt apparmor:unconfined \
    --network wt_celery \
    -d ${image} ${celery_args}

docker exec -ti celery_worker chown davfs2:davfs2 /host/run/mount.davfs
docker exec -ti celery_worker chown davfs2:davfs2 /host/var/cache/davfs2
