#!/bin/bash

# Timezone config check
if [ -f /usr/share/zoneinfo/$TZ ]
then
  echo "The current timezone is $TZ"
else
  echo "The configured timezone $TZ does not exist in the host, use UTC instead."
  export TZ="UTC"
fi

/bragent/health/httpprobe_main &

if [ "$TLS_ENABLED" == "true" ]; then
    declare -a certificates=("/run/secrets/eric-data-distributed-coordinator-ed-etcd-bro-client-cert" \
    "/run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert/" \
    "/run/secrets/$SIP_TLS_CA_SECRET"
    );
    for cert in "${certificates[@]}"; do
        echo "Waiting for certificate to be mounted at $cert"
        while [[ -z "$(ls $cert)" ]]; do
            sleep 1
        done
        echo "Certificates mounted at $cert"
    done
fi

/bragent/certMonitoring.sh &

java $JVM_HEAP_OPTS $CMD_OPTS -jar /bragent/bragent-0.0.1-SNAPSHOT.jar
