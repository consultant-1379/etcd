#!/bin/bash

export KUBECTL="/usr/local/bin/kubectl"
#Fail if empty argument received
if [[ "$#" < 4 ]];
then
    echo "ERROR : Wrong number of arguments"
    echo "ERROR : Usage post_rollback.sh -n <Kubernetes_namespace> -rn <Release Name>"
fi

if [[ $1 != "-n" ]]
then
    echo "ERROR : Incorrect argument for -n passed. Please verify and try again"
    echo "ERROR : Usage post_rollback.sh -n <Kubernetes_namespace> -rn <Release Name>"
    exit 1
fi

if [[ $3 != "-rn" ]]
then
    echo "ERROR : Incorrect argument for -rn passed. Please verify and try again"
    echo "ERROR : Usage post_rollback.sh -n <Kubernetes_namespace> -rn <Release Name>"
    exit 1
fi

export namespace=$2
export releaseName=$4
echo "INFO : Using namespace $namespace"
echo "$releaseName"
# Validate namespace
$KUBECTL get namespace $namespace &>/dev/null

version_of_pod_0=$(kubectl get pod eric-data-distributed-coordinator-ed-0 --namespace=$namespace -o=jsonpath='{.metadata.labels.app\.kubernetes\.io/version}' 2>&1 | tr -d '\"')

echo "INFO: waiting for the change of version in pod-1"

while :
do
    version_of_pod_1=$(kubectl get pod eric-data-distributed-coordinator-ed-1 --namespace=$namespace -o=jsonpath='{.metadata.labels.app\.kubernetes\.io/version}' 2>&1 | tr -d '\"')

    if [[ "$version_of_pod_0" != "$version_of_pod_1" &&  "$version_of_pod_1" != "Error from server (NotFound): pods eric-data-distributed-coordinator-ed-1 not found"  ]];
    then
        echo "INFO: version of pod-1 is changed, continuing with the other steps"
        break
    elif [[ "$version_of_pod_1" == "Error from server (NotFound): pods eric-data-distributed-coordinator-ed-1 not found" ]] ;
    then
        echo $version_of_pod_1
        echo "Rollback is in progress, please have patience until the version of DCED pod is changed"
        continue
    else
        sleep 2
    fi
done

sts_name="eric-data-distributed-coordinator-ed"
#get number of replica
echo "INFO : Get Replica count for namespace $namespace"
replicas=$(kubectl get sts eric-data-distributed-coordinator-ed -n $namespace -o=jsonpath='{.status.replicas}')
 if [ $? != 0 ]; then
    echo "ERROR : could not fetch replica count for $namespace"
    exit 1
fi
echo "INFO : Replica count is  $replicas"

#Scale down the DCED StatefulSet to replicas=0
echo "INFO : Scale down the DCED StatefulSet to replicas=0"
$KUBECTL scale statefulset.apps/eric-data-distributed-coordinator-ed --replicas=0 -n $namespace
$KUBECTL wait --for=delete pod/eric-data-distributed-coordinator-ed-0 -n $namespace --timeout=2m

#Scale up the DCED StatefulSet to replicas=1
echo "INFO : Scale up the DCED StatefulSet to replicas=1"
$KUBECTL scale statefulset.apps/eric-data-distributed-coordinator-ed --replicas=1 -n $namespace
#Waiting for pod-0 to come up
status=$($KUBECTL get po eric-data-distributed-coordinator-ed-0 -n $namespace | tr "\n" ' ' |tr -s ' ' |cut -d ' ' -f8)
while [ ${status} != "Running" ]
do
    status=$($KUBECTL get po eric-data-distributed-coordinator-ed-0 -n $namespace | tr "\n" ' ' |tr -s ' ' |cut -d ' ' -f8)
    sleep 20
done
#Step 4
echo "INFO : Restoring snapshot started"

#fetch ETCD_DATA_DIR from container
ETCD_DATA_DIR=`$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- env | grep "ETCD_DATA_DIR" |cut -d'=' -f2`
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- bash -c "rm -rf ${ETCD_DATA_DIR}/restore_data"
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- bash -c "mkdir -p ${ETCD_DATA_DIR}/member/snap"

#Run snapshot restore command
echo "INFO : Run snapshot restore command"

#fetch env variable before restore data
HOSTNAME=`$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- bash -c 'echo $HOSTNAME'`
echo "Hostname: ${HOSTNAME}"
ETCD_INITIAL_ADVERTISE_PEER_URLS=`$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- bash -c 'echo $ETCD_INITIAL_ADVERTISE_PEER_URLS'`
echo "ETCD_INITIAL_ADVERTISE_PEER_URLS: ${ETCD_INITIAL_ADVERTISE_PEER_URLS}"
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- bash -c "/usr/local/bin/etcdctl snapshot restore ${ETCD_DATA_DIR}/snapshot/backup.db --name ${HOSTNAME} --initial-cluster ${HOSTNAME}=${ETCD_INITIAL_ADVERTISE_PEER_URLS} --initial-advertise-peer-urls ${ETCD_INITIAL_ADVERTISE_PEER_URLS} --data-dir=${ETCD_DATA_DIR}/restore_data"

#Kill etcd process and then wait for 2 seconds
echo "INFO : Kill etcd process"
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- bash -c "pkill --exact etcd"
sleep 10

#Delete older wal and snap file
echo "INFO : Delete older wal and snap file"
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- bash -c "rm -f ${ETCD_DATA_DIR}/member/wal/*.wal"

$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- bash -c "rm -f ${ETCD_DATA_DIR}/member/snap/*snap"

#Copy member directory from backup to /data
echo "INFO : Copy member directory from backup to /data"
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- bash -c "cp -Rf ${ETCD_DATA_DIR}/restore_data/member ${ETCD_DATA_DIR}"

echo "INFO : Restoring snapshot completed"
#Step 5
echo "Delete POD-0"
$KUBECTL delete pod eric-data-distributed-coordinator-ed-0 -n $namespace

#Step 6
echo "Scaling back to expected replicas."
echo "INFO : Scale down the DCED StatefulSet to replicas=3"

$KUBECTL scale statefulset.apps/eric-data-distributed-coordinator-ed --replicas=3 -n $namespace

echo "INFO : Waiting for to get etcd version"
$KUBECTL rollout status statefulset.apps/eric-data-distributed-coordinator-ed -w -n $namespace

echo "INFO : ETCD version After rollback"
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace  -- bash -c "etcd --version"
echo "INFO : DCED version after rollback"
helm status $releaseName
echo "INFO : pod status"
$KUBECTL get pod -n $namespace | grep "$sts_name"
