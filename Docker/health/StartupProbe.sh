#!/bin/bash -xe
# grep the control file for pod status
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
