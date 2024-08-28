#!/bin/bash

export KUBECTL="/usr/local/bin/kubectl"

#Fail if empty argument received
if [[ "$#" < 4 ]];
then
    echo "ERROR : Wrong number of arguments"
    echo "ERROR : Usage pre_rollback.sh -n <Kubernetes_namespace> -rn <Release Name>"
fi

if [[ $1 != "-n" ]]
then
    echo "ERROR : Incorrect argument for -n passed. Please verify and try again"
    echo "ERROR : Usage pre_rollback.sh -n <Kubernetes_namespace> -rn <Release Name>"
    exit 1
fi

if [[ $3 != "-rn" ]]
then
    echo "ERROR : Incorrect argument for -rn passed. Please verify and try again"
    echo "ERROR : Usage pre_rollback.sh -n <Kubernetes_namespace> -rn <Release Name>"
    exit 1
fi

export namespace=$2
export releaseName=$4
echo "INFO : Using namespace $namespace"
echo "$releaseName"
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

    $KUBECTL wait --for=delete pod/eric-data-distributed-coordinator-ed-$i -n $namespace --timeout=2m

    echo "INFO : Delete PVC"
    $KUBECTL delete pvc `kubectl get pvc -n $namespace --sort-by='{.metadata.name}' | grep data-eric-data-distributed-coordinator-ed | tail -n1 | cut -d' ' -f 1` -n $namespace
    if [ $? != 0 ]; then
        exit 1
    fi

done
echo "INFO : Scaling down to single pod completed"

#Step 2
echo "INFO : Taking the snapshot in DCED pod-0 started"
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace  -- mkdir -p /data/snapshot

$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced -n $namespace  -- etcdctl snapshot save /data/snapshot/backup.db

echo "INFO : Taking the snapshot in DCED pod-0 completed"
