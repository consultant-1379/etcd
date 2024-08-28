#!/bin/bash
# runs compact command once the nospace alarm raised
echo "Running Compaction"
/usr/local/bin/etcdctl compact $(/usr/local/bin/etcdctl endpoint status --write-out="json" | egrep -o '"revision":[0-9]*' | egrep -o '[0-9].*')
# runs defragmentation command
echo "Running Defragmentation"
if [[ "$TLS_ENABLED" = "true" ]];
then
    bash -c 'unset ETCDCTL_ENDPOINTS; /usr/local/bin/etcdctl defrag  --endpoints=:${CLIENT_PORTS} --insecure-skip-tls-verify'
else
    unset ETCDCTL_ENDPOINTS; /usr/local/bin/etcdctl --user root:${ACL_ROOT_PASSWORD} defrag --endpoints=:${CLIENT_PORTS}
fi
echo "Endpoint after compaction and defragmentation -"
bash -c 'unset ETCDCTL_ENDPOINTS; /usr/local/bin/etcdctl --write-out=table endpoint status --endpoints=:${CLIENT_PORTS} --insecure-skip-tls-verify'
# wait for delay mins for all pod defragging
echo "Delay Alarm Removal for (minutes):"+${DISARM_ALARM_PEER_INTERVAL}
sleep ${DISARM_ALARM_PEER_INTERVAL}m
# remove nospace alarm
/usr/local/bin/etcdctl alarm disarm