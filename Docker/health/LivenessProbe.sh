#!/bin/bash -xe
if [[ "$STRICT_LIVENESS_PROBE" = "true" ]]; then
  if [[ "$TLS_ENABLED" = "true" ]];
  then
    status=$(curl -L --cacert /run/secrets/"$SIP_TLS_CA_SECRET"/ca.crt --cert /data/certificates/tls-srv.crt   --key /data/certificates/tls-srv.key https://localhost:2379/health)
  else
    status=$(curl -L http://localhost:2379/health)
  fi
  if echo "$status" |  grep -i "true"; then
    exit 0
  else
    exit 1
  fi
else
  if [ -e ${ETCD_DATA_DIR}/etcd.liveness ]
  then
    if grep -qi 'alive' ${ETCD_DATA_DIR}/etcd.liveness; then
      exit 0
    else
      exit 1
    fi
  else
    if grep -qi 'alive' ~/etcd.liveness; then
      exit 0
    else
      exit 1
    fi
  fi
fi
