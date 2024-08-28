#!/bin/bash
# runs list Alarm command every 5(minute)
while true; do
  dbmaxsize=${ETCD_QUOTA_BACKEND_BYTES}
  dbsizetocleanup=$(((dbmaxsize*(${DB_THRESHOLD_PERCENTAGE}))/100))
  dbfilesize=$(wc -c /data/member/snap/db | awk '{print $1}')
  alarm=$(/usr/local/bin/etcdctl alarm list | grep 'NOSPACE')
  if [[ -n $alarm || $dbfilesize -ge $dbsizetocleanup ]];then
    if [[ -n $alarm ]];then
      echo "alarm detected:"+$alarm
    else
      echo "ETCD reached to the DB threshold of "+${DB_THRESHOLD_PERCENTAGE}+"%"
    fi
    echo "Endpoint status before compaction and defragmentation -"
    bash -c 'unset ETCDCTL_ENDPOINTS; /usr/local/bin/etcdctl --write-out=table endpoint status --endpoints=:${CLIENT_PORTS} --insecure-skip-tls-verify'
    nohup /usr/local/bin/scripts/handleAlarm.sh
  fi
  sleep ${MONITOR_ALARM_INTERVAL}m
done