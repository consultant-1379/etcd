#!/bin/bash
# runs defragmentation command every set interval(minute)
while true; do
  if [[ "$TLS_ENABLED" = "true" ]];
  then
    bash -c 'unset ETCDCTL_ENDPOINTS; /usr/local/bin/etcdctl defrag  --endpoints=:${CLIENT_PORTS} --insecure-skip-tls-verify || true'
  else
    /usr/local/bin/etcdctl --user root:${ACL_ROOT_PASSWORD} defrag --endpoints=:${CLIENT_PORTS} || true
  fi
  sleep ${DEFRAGMENT_PERIODIC_INTERVAL}m
done