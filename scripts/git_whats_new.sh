#!/bin/bash

for dir in $(find src/ -maxdepth 1 -mindepth 1 -type d | sort) ; do \
  pushd $dir &> /dev/null
  echo "${dir} -"
  git log --first-parent --oneline stable..master
  popd &> /dev/null
done
