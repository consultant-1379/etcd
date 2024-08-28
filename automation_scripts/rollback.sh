#!/bin/bash

export KUBECTL="/usr/local/bin/kubectl"


#Fail if empty argument received
if [[ "$#" < 6 ]];
then
    echo "ERROR : Wrong number of arguments"
    echo "ERROR : Usage rollback.sh -n <Kubernetes_namespace> -rn <Release Name> -rev <Revision>"
fi

if [[ $1 != "-n" ]]
then
    echo "ERROR : Incorrect argument for -n passed. Please verify and try again"
    echo "ERROR : Usage rollback.sh -n <Kubernetes_namespace> -rn <Release Name> -rev <Revision>"
    exit 1
fi

if [[ $3 != "-rn" ]]
then
    echo "ERROR : Incorrect argument for -rn passed. Please verify and try again"
    echo "ERROR : Usage rollback.sh -n <Kubernetes_namespace> -rn <Release Name> -rev <Revision>"
    exit 1
fi

if [[ $5 != "-rev" ]]
then
    echo "ERROR : Incorrect argument for -rev passed. Please verify and try again"
    echo "ERROR : Usage rollback.sh -n <Kubernetes_namespace> -rn <Release Name> -rev <Revision>"
    exit 1
fi
export namespace=$2
export releaseName=$4
export revision=$6
echo "INFO : Using namespace $namespace"
echo "$releaseName and $revision"
# Validate namespace
$KUBECTL get namespace $namespace &>/dev/null

if [ $? != 0 ]; then
    echo "ERROR : The namespace $namespace does not exist. You can use \"kubectl get namespace\" command to verify your namespace"
    exit 1
fi

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
(( replica_count = $replicas - 1))


# Check pod status before retriving member IDs
echo "INFO : Check POD Status : Started"
for i in $(seq 0 $replica_count)
do
    status=$($KUBECTL get po $sts_name-$i -n $namespace | tr "\n" ' ' |tr -s ' ' |cut -d ' ' -f8)
    ready=$($KUBECTL get po $sts_name-$i -n $namespace |tr "\n" ' ' |tr -s ' ' |cut -d ' ' -f7)
    if [[ "${ready}" -ne "1/1" && "${ready}" -ne  "2/2" && "${ready}" -ne  "3/3" ]] || [[ ${status} != "Running" ]]
    then
        echo "INFO : POD status is incorrect for Member $sts_name-$i. Please check and correct before proceeding"
    else
        echo "INFO : POD status for Member $sts_name-$i is correct."
    fi
done
echo "INFO : Check POD Status : Completed"

echo "INFO : ETCD version before rollback"
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace  -- bash -c "etcd --version"

echo "INFO : DCED version before rollback"
helm ls -n $namespace | grep "$sts_name"

echo "INFO : Scaling down to single pod started"
for (( i=$replica_count ; i>0;--i))
do
    echo "INFO : Remove the last member from the Distributed Coordinator ED cluster"
    $KUBECTL exec -it eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- bash -c 'etcdctl member remove $(etcdctl member list | sort -Vk3 | tail -n 1 | cut -d, -f1 )'
    if [ $? != 0 ];
    then
        exit 1
    fi

    echo "INFO : Scale down the DCED StatefulSet."
    $KUBECTL scale statefulset.apps/eric-data-distributed-coordinator-ed -n $namespace --replicas=$i
    if [ $? != 0 ];
    then
        exit 1
    fi

    sleep 30
    echo "INFO : Delete PVC"
    $KUBECTL delete pvc `kubectl get pvc -n $namespace --sort-by='{.metadata.name}' | grep data-eric-data-distributed-coordinator-ed | tail -n1 | cut -d' ' -f 1` -n $namespace
    if [ $? != 0 ]; then
        exit 1
    fi
    sleep 20
done
echo "INFO : Scaling down to single pod completed"

#Step 2
echo "INFO : Taking the snapshot in DCED pod-0 started"
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace  -- mkdir -p /data/snapshot

$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace  -- etcdctl snapshot save /data/snapshot/backup.db

echo "INFO : Taking the snapshot in DCED pod-0 completed"

#Step 3
echo "Rollback to provided DCED version"
helm rollback $releaseName -n $namespace $revision

#Scale out the DCED StatefulSet to replicas=0
echo "INFO : Scale out the DCED StatefulSet to replicas=0"
$KUBECTL scale statefulset.apps/eric-data-distributed-coordinator-ed --replicas=0 -n $namespace

#Scale out the DCED StatefulSet to replicas=1
echo "INFO : Scale out the DCED StatefulSet to replicas=1"
$KUBECTL scale statefulset.apps/eric-data-distributed-coordinator-ed --replicas=1 -n $namespace
sleep 120

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

#Step 6
echo "Scaling back to expected replicas."
echo "INFO : Scale out the DCED StatefulSet to replicas=3"
$KUBECTL scale statefulset.apps/eric-data-distributed-coordinator-ed --replicas=3 -n $namespace

echo "INFO : Wait for ~ 2 minutes to get etcd version"
sleep 120
echo "INFO : ETCD version After rollback"
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace  -- bash -c "etcd --version"
echo "INFO : DCED version after rollback"
helm ls -n $namespace | grep "$sts_name"
echo "INFO : pod status"
$KUBECTL get pod -n $namespace | grep "$sts_name"