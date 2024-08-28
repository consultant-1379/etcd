#!/bin/bash

export KUBECTL="/usr/local/bin/kubectl"
#Fail if empty argument received
if [[ "$#" < 4 ]];
then
    echo "ERROR : Wrong number of arguments"
    echo "ERROR : Usage post_rollback_upg.sh -n <Kubernetes_namespace> -rn <Release Name>"
fi

if [[ $1 != "-n" ]]
then
    echo "ERROR : Incorrect argument for -n passed. Please verify and try again"
    echo "ERROR : Usage post_rollback_upg.sh -n <Kubernetes_namespace> -rn <Release Name>"
    exit 1
fi

if [[ $3 != "-rn" ]]
then
    echo "ERROR : Incorrect argument for -rn passed. Please verify and try again"
    echo "ERROR : Usage post_rollback_upg.sh -n <Kubernetes_namespace> -rn <Release Name>"
    exit 1
fi

export namespace=$2
export releaseName=$4
echo "INFO : Using namespace $namespace"
echo "$releaseName"
# Validate namespace
$KUBECTL get namespace $namespace &>/dev/null

sts_name="eric-data-distributed-coordinator-ed"
#get number of replica
echo "INFO : Get Replica count for namespace $namespace"
#replicas=$($KUBECTL get sts $sts_name -n $namespace -o=jsonpath='{.status.replicas}')
replicas=$(kubectl get sts eric-data-distributed-coordinator-ed -n $namespace -o=jsonpath='{.status.replicas}')
 if [ $? != 0 ]; then
    echo "ERROR : could not fetch replica count for $namespace"
    exit 1
fi
echo "INFO : Replica count is  $replicas"

#Step 4
echo "INFO : Restoring snapshot started"

#fetch ETCD_DATA_DIR from container
ETCD_DATA_DIR=`$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- env | grep "ETCD_DATA_DIR" |cut -d'=' -f2`
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- bash -c "rm -rf ${ETCD_DATA_DIR}/restore_data"
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- bash -c "mkdir -p ${ETCD_DATA_DIR}/member/snap"

#Run snapshot restore command
echo "INFO : Run snapshot restore command"

#fetch env variable before restore data
HOSTNAME=`$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- env | grep "HOSTNAME" |cut -d'=' -f2`
ETCD_INITIAL_ADVERTISE_PEER_URLS=`$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- env | grep "ETCD_INITIAL_ADVERTISE_PEER_URLS" |cut -d'=' -f2`
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- bash -c "/usr/local/bin/etcdctl snapshot restore ${ETCD_DATA_DIR}/snapshot/backup.db --name ${HOSTNAME} --initial-cluster ${HOSTNAME}=${ETCD_INITIAL_ADVERTISE_PEER_URLS} --initial-advertise-peer-urls ${ETCD_INITIAL_ADVERTISE_PEER_URLS} --data-dir=${ETCD_DATA_DIR}/restore_data"

#Kill etcd process and then wait for 2 seconds
echo "INFO : Kill etcd process"
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- bash -c "pkill --exact etcd"
#Note: After executing the above command, if the control comes out of the container, then re-login into the container.
sleep 10

#Delete older wal and snap file
echo "INFO : Delete older wal and snap file"
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- bash -c "rm -f ${ETCD_DATA_DIR}/member/wal/*.wal"

$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- bash -c "rm -f ${ETCD_DATA_DIR}/member/snap/*snap"

#Copy member directory from backup to /data
echo "INFO : Copy member directory from backup to /data"
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- bash -c "cp -Rf ${ETCD_DATA_DIR}/restore_data/member ${ETCD_DATA_DIR}"
sleep 30

echo "INFO : Restoring snapshot completed"
#Step 5
echo "Delete POD-0"
$KUBECTL delete pod eric-data-distributed-coordinator-ed-0 -n $namespace

