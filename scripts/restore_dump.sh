#!/bin/bash

# Restore the dump from first argument to the database running in wt_mongo service

# Check if the number of arguments is correct
if [ $# -ne 1 ]; then
    echo "Usage: $0 <dump_file>"
    exit 1
fi

# Check if the dump file exists
if [ ! -f $1 ]; then
    echo "File $1 does not exist"
    exit 1
fi

# copy dump file to container
docker cp $1 $(docker ps --filter=name=wt_mongo -q):/tmp

# Restore the dump from /tmp
docker exec -i $(docker ps --filter=name=wt_mongo -q) mongorestore --gzip --drop --archive=/tmp/$1
