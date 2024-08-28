#!/bin/bash
if [[ "$TLS_ENABLED" == "true" ]] ; then
  declare -a certificates=("/run/secrets/eric-data-distributed-coordinator-ed-etcd-bro-client-cert" \
    "/run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert/" \
    "/run/secrets/$SIP_TLS_CA_SECRET"
  );
  for cert in "${certificates[@]}"; do
    if [[ -z "$(ls $cert)" ]]; then
      echo "Certificates not mounted at $cert"
      exit 0
    fi
  done
fi
pgrep -fl java
