#!/bin/bash

echo "restore starts"
unset ETCDCTL_ENDPOINTS
ordinal=${ETCD_NAME##*-}
RESTORE_DIR=${ETCD_DATA_DIR}/restore_data
SNAPSHOT_DIR=${ETCD_DATA_DIR}/member/snap
BACKUPFILE=backup.db

if [[ ordinal -eq 0 ]]; then
  # node 0
      rm -rf ${RESTORE_DIR}
      mkdir -p ${SNAPSHOT_DIR}
      echo "Launch command etcdctl snapshot restore"
      /usr/local/bin/etcdctl snapshot restore ${SNAPSHOT_DIR}/${BACKUPFILE} --name ${HOSTNAME} --initial-cluster ${HOSTNAME}=${ETCD_INITIAL_ADVERTISE_PEER_URLS} --initial-advertise-peer-urls ${ETCD_INITIAL_ADVERTISE_PEER_URLS} --data-dir=${RESTORE_DIR}
      echo "kill etcd"
      pkill --exact etcd
      echo "sleep a while so that agent can detect that the service is down"
      sleep 2
      echo "copy member directory from backup to /data"
      cp -Rf ${RESTORE_DIR}/member ${ETCD_DATA_DIR}
      rm ${SNAPSHOT_DIR}/${BACKUPFILE}
else
  # other nodes
  echo "Remove /data/member directory"
  rm -Rf ${ETCD_DATA_DIR}/member
  echo "/data/member directory removed."
  sleep 3
  rm ${SNAPSHOT_DIR}/${BACKUPFILE}
fi
echo "restore ends"
