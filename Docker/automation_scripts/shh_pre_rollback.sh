#!/bin/bash

export KUBECTL="/usr/local/bin/kubectl"

sts_name="eric-data-distributed-coordinator-ed"
#get number of replica
replicas=$(kubectl get sts eric-data-distributed-coordinator-ed  -o=jsonpath='{.status.replicas}')
echo "INFO : Replica count is  $replicas"
(( replica_count = $replicas - 1))

# Check pod status before retriving member IDs
echo "INFO : Check POD Status : Started"
for i in $(seq 0 $replica_count)
do
    status=$($KUBECTL get po $sts_name-$i  | tr "\n" ' ' |tr -s ' ' |cut -d ' ' -f8)
    ready=$($KUBECTL get po $sts_name-$i  |tr "\n" ' ' |tr -s ' ' |cut -d ' ' -f7)
    if [[ "${ready}" -ne "1/1" && "${ready}" -ne  "2/2" && "${ready}" -ne  "3/3" ]] || [[ ${status} != "Running" ]]
    then
        echo "INFO : POD status is incorrect for Member $sts_name-$i. Please check and correct before proceeding"
    else
        echo "INFO : POD status for Member $sts_name-$i is correct."
    fi
done
echo "INFO : Check POD Status : Completed"

echo "INFO : ETCD version before rollback"
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced   -- bash -c "etcd --version"

echo "INFO : DCED version before rollback"
helm ls  | grep "$sts_name"

echo "INFO : Scaling down to single pod started"
for (( i=$replica_count ; i>0;--i))
do
    echo "INFO : Remove the last member from the Distributed Coordinator ED cluster"
    $KUBECTL exec -it eric-data-distributed-coordinator-ed-0 -c dced  -- bash -c 'etcdctl member remove $(etcdctl member list | sort -Vk3 | tail -n 1 | cut -d, -f1 )'
    if [ $? != 0 ];
    then
        exit 1
    fi

    echo "INFO : Scale down the DCED StatefulSet."
    $KUBECTL scale statefulset.apps/eric-data-distributed-coordinator-ed  --replicas=$i
    if [ $? != 0 ];
    then
        exit 1
    fi

    sleep 30
    echo "INFO : Delete PVC"
    $KUBECTL delete pvc `kubectl get pvc  --sort-by='{.metadata.name}' | grep data-eric-data-distributed-coordinator-ed | tail -n1 | cut -d' ' -f 1`
    if [ $? != 0 ]; then
        exit 1
    fi
    sleep 20
done
echo "INFO : Scaling down to single pod completed"

#Step 2
echo "INFO : Taking the snapshot in DCED pod-0 started"
$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced   -- mkdir -p /data/snapshot

$KUBECTL exec eric-data-distributed-coordinator-ed-0 -c dced   -- etcdctl snapshot save /data/snapshot/backup.db

echo "INFO : Taking the snapshot in DCED pod-0 completed"