#!/bin/bash

last_modified=$(stat -c %Y ${ETCD_DATA_DIR}/cert_watcher.txt)

doRestart=false
while true
do
  for var in "$@"
  do
    CERT=$var
    if [[ ! -z ${CERT} ]]
    then
       epoch_arr=$(stat -c %Y ${CERT})
       current_modified=${epoch_arr[0]}
       if [ $last_modified -lt $current_modified ]; then
          last_modified=$current_modified
          echo "[ ${CERT} ] Caught Certificate renewed event."
          doRestart=true
        fi
    fi
  done
  if [ "$doRestart" = true ] ; then
    bash /usr/local/bin/scripts/restart.sh &
    doRestart=false
    touch ${ETCD_DATA_DIR}/cert_watcher.txt
  fi
  sleep 5
done
