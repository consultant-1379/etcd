#!/bin/bash

export KUBECTL="/usr/local/bin/kubectl"
sts_name="eric-data-distributed-coordinator-ed"
#get number of replica

replicas=$(kubectl get sts eric-data-distributed-coordinator-ed -o=jsonpath='{.status.replicas}')
echo "INFO : Replica count is  $replicas"

#Scale down the DCED StatefulSet to replicas=0
echo "INFO : Scale down the DCED StatefulSet to replicas=0"
$KUBECTL scale statefulset.apps/eric-data-distributed-coordinator-ed --replicas=0

#Scale down the DCED StatefulSet to replicas=1
echo "INFO : Scale down the DCED StatefulSet to replicas=1"
$KUBECTL scale statefulset.apps/eric-data-distributed-coordinator-ed --replicas=1
sleep 120

#Step 4
echo "INFO : Restoring snapshot started"

#fetch ETCD_DATA_DIR from container
ETCD_DATA_DIR=`$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -- env | grep "ETCD_DATA_DIR" |cut -d'=' -f2`
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -- bash -c "rm -rf ${ETCD_DATA_DIR}/restore_data"
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -- bash -c "mkdir -p ${ETCD_DATA_DIR}/member/snap"

#Run snapshot restore command
echo "INFO : Run snapshot restore command"

#fetch env variable before restore data
HOSTNAME=`$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -- env | grep "HOSTNAME" |cut -d'=' -f2`
ETCD_INITIAL_ADVERTISE_PEER_URLS=`$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -- env | grep "ETCD_INITIAL_ADVERTISE_PEER_URLS" |cut -d'=' -f2`
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -- bash -c "/usr/local/bin/etcdctl snapshot restore ${ETCD_DATA_DIR}/snapshot/backup.db --name ${HOSTNAME} --initial-cluster ${HOSTNAME}=${ETCD_INITIAL_ADVERTISE_PEER_URLS} --initial-advertise-peer-urls ${ETCD_INITIAL_ADVERTISE_PEER_URLS} --data-dir=${ETCD_DATA_DIR}/restore_data"
#Kill etcd process and then wait for 2 seconds
echo "INFO : Kill etcd process"
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -- bash -c "pkill --exact etcd"
#Note: After executing the above command, if the control comes out of the container, then re-login into the container.
sleep 10

#Delete older wal and snap file
echo "INFO : Delete older wal and snap file"
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -- bash -c "rm -f ${ETCD_DATA_DIR}/member/wal/*.wal"

$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -- bash -c "rm -f ${ETCD_DATA_DIR}/member/snap/*snap"

#Copy member directory from backup to /data
echo "INFO : Copy member directory from backup to /data"
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -- bash -c "cp -Rf ${ETCD_DATA_DIR}/restore_data/member ${ETCD_DATA_DIR}"
sleep 30

echo "INFO : Restoring snapshot completed"
#Step 5
echo "Delete POD-0"
$KUBECTL delete pod eric-data-distributed-coordinator-ed-0

#Step 6
echo "Scaling back to expected replicas."
echo "INFO : Scale down the DCED StatefulSet to replicas=3"

$KUBECTL scale statefulset.apps/eric-data-distributed-coordinator-ed --replicas=3

echo "INFO : Wait for ~ 2 minutes to get etcd version"
sleep 120
echo "INFO : ETCD version After rollback"
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced  -- bash -c "etcd --version"
echo "INFO : pod status"
$KUBECTL get pod | grep "$sts_name"