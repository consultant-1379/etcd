#!/bin/bash

export KUBECTL="/usr/local/bin/kubectl"


#Fail if empty argument received
if [[ "$#" < 4 ]];
then
        echo "ERROR : Wrong number of arguments"
        echo "ERROR : Usage correct_dataInconsistency_dced.sh -n <Kubernetes_namespace> -p <Inconsistent POD name one> <Inconsistent POD name two>"
        exit 1
fi

if [[ $3 != "-p" ]]
then
        echo "ERROR : Incorrect argument for -p passed. Please verify and try again"
                echo "ERROR : Usage correct_dataInconsistency_dced.sh -n <Kubernetes_namespace> -p <Inconsistent POD name one> <Inconsistent POD name two>"
        exit 1

fi

#Checking whether -n and -p options are passed correctly ,and exits if not passed correctly

while  getopts ":n:p:" option ; do
case "${option}" in
    n)
        if [ "${OPTARG}" != ""  ]; then
                namespace=${OPTARG}
         else
            echo "ERROR : namespace argument not found. Please specify proper namespace"
            exit 1
         fi
        ;;
    p)
        if [ "${OPTARG}" != ""  ]; then
               pod_name_one=${OPTARG}
                echo "INFO : Inconsistent POD $pod_name_one"
         else
            echo "ERROR : podname argument not found. Please specify proper podname"
            exit 1
         fi

        eval "a1=\${$((OPTIND))}"
         pod_name_two=$a1
         rc=${?}
         if [ "${pod_name_two}" != "" ]; then
           echo "INFO : 2 pods are inconsistent $pod_name_one and  $pod_name_two"
         else
           echo "INFO : Only one pod $pod_name_one is inconsistent"
         fi
      ;;

    *)
        echo "ERROR : Wrong number of Agruments."
        echo "ERROR : Usage fix_Data_Inconsistency.sh -n <Kubernetes_namespace> -p <Inconsistent POD name one> <Inconsistent POD name two>"
        exit 1
      ;;
  esac
done

declare -a pod_names
pod_names=( $pod_name_one $pod_name_two )


#export namespace=$1
echo "INFO : Using namespace $namespace"

# Validate namespace
$KUBECTL get namespace $namespace &>/dev/null

if [ $? != 0 ]; then
        echo "ERROR : The namespace $namespace does not exist. You can use \"kubectl get namespace\" command to verify your namespace"
        exit 1
fi


#Validate inconsistent podname exist in the namespace

for i in ${pod_names[@]};
do
        $KUBECTL get po  -n $namespace | grep $i  &>/dev/null
        if [ $? != 0 ]; then
                echo "ERROR : The pod $i is not part of DCED cluster"
                exit 1
        else
                echo "INFO : POD $i is part of DCED cluster $namespace"
        fi
done

#get sts name from podname
sts_name=${pod_name_one::-2}

#get number of replica
echo "INFO : Get Replica count for namespace $namespace"
replicas=$($KUBECTL get sts $sts_name -n $namespace -o=jsonpath='{.status.replicas}')
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
        #echo "$ready and $status and $restart"
        if [[ "${ready}" -ne "1/1" && "${ready}" -ne  "2/2" && "${ready}" -ne  "3/3" ]] || [[ ${status} != "Running" ]]
        then
                echo "INFO : POD status is incorrect for Member $sts_name-$i. Please check and correct before proceeding"
                exit 1
        else
                echo "INFO : POD status for Member $sts_name-$i is correct."
        fi
done
 echo "INFO : Check POD Status : Completed"



#Get the Leader ID.
echo "INFO : Retrieve leader id"
leader=""
leader=$($KUBECTL exec $sts_name-0 -c dced -n $namespace -- bash -c "export ETCDCTL_ENDPOINTS=https://$sts_name-0.$sts_name-peer.$namespace.svc.cluster.local:2379 ;etcdctl endpoint status --write-out=json | egrep -o '\"leader\":[0-9]*'")
leader_id=`echo "$leader" | cut -d ":" -f2`
leader_id_hex=""
leader_id_hex=$(printf '%x' $leader_id)
echo "INFO : Leader ID is $leader_id_hex"

#Leader id check
if [[ -z  $leader_id_hex ]]
then
        echo "ERROR : Invalid leader ID found. Please check pod state manually"
        exit 1
fi

#Retrieve Member ID
echo "INFO : Retrieve member id."

declare -a member_id=()

for i in $(seq 0 $replica_count)
do
        #Retrieve all the member_id's
         member=$($KUBECTL exec -it $sts_name-$i -c dced -n $namespace -- bash -c "etcdctl member list | grep $sts_name-$i" )&>/dev/null
        if [ $? != 0 ]; then
                echo "ERROR : Unable to fetch member id for $i"
                exit 1
        fi
         member_id[$i]=$(echo $member | cut -d, -f1)
         echo "INFO : Member id for member $i : ${member_id[$i]}"
        if [[ -z ${member_id[$i]} ]]
        then
                echo "INFO : Invalid Member ID found. Please check pod state manually"
                exit 1
        fi

done
now=$(date +"%m%d_%H%M%S")
#make pod 0 consistent
pod_0_consistent(){
        echo "INFO : Steps for POD 0 started"
        echo "INFO : Config map changes for pod-0 : Started"
        $KUBECTL get cm $sts_name -o yaml -n $namespace > Config_pod0_$now.yaml
        sed -i 's/if \[  \${ordinal} \-eq 0 ]/if \[  \${ordinal} \-eq \-1 ]/g' Config_pod0_$now.yaml
        sed -i '0,/ETCD_INITIAL_CLUSTER_STATE=\"new\"/s//ETCD_INITIAL_CLUSTER_STATE=\"existing\"/' Config_pod0_$now.yaml
        old="c=1; c<=\$ordinal; c++"
        new="c=$(($replica_count)); c>\$ordinal; c--"
        sed -i "s/$old/$new/g" Config_pod0_$now.yaml
        $KUBECTL apply -f Config_pod0_$now.yaml -n $namespace
        echo "INFO : Config map changes for pod-0 : completed"
        pod_name="$sts_name-0"
        make_consistent $pod_name ${member_id[0]}
        delete_pod $pod_name
        #get_pod_run_status
                wait_pod_to_come_up $pod_name

        #Check if new cluster has been formed, if yes rectify it before proceeding ahead
        pod0_etcdctl_member_list=`$KUBECTL exec -it $sts_name-0 -c dced -n $namespace -- etcdctl member list `
        pod0_etcdctl_member_count=`echo "$pod0_etcdctl_member_list" | wc -l`
        if [[ $pod0_etcdctl_member_count -eq 1 ]]
        then
                echo "INFO : New cluster has been formed, correcting before proceeding ahead"
                incorrect_pod0_member=`echo "$pod0_etcdctl_member_list" | awk '{print $1 $2}' | cut -d"," -f1`
                incorrect_pod0_status=`echo "$pod0_etcdctl_member_list" | awk '{print $1 $2}' | cut -d"," -f2`
                incorrect_pod0_name=`echo "$pod0_etcdctl_member_list" | awk '{print $1 $2 $3}' | cut -d"," -f3`
                #echo "$incorrect_pod0_member"
                #echo "$incorrect_pod0_status"
                #echo "$incorrect_pod0_name"
                if [[ $incorrect_pod0_name = $pod_name ]]
                then
                unstarted_pod0_member=$incorrect_pod0_member
                fi

        else
                unstarted_pod0_member=`echo "$pod0_etcdctl_member_list" | awk '{print $1 $2}' | grep -i "unstarted" | cut -d"," -f1`

fi

        if [[ ! -z $unstarted_pod0_member ]];
        then
                echo "INFO : Caught unstarted Member for pod-0. Handle unstarted member before proceed further."
                make_consistent "$sts_name-0" $unstarted_pod0_member
                delete_pod $pod_name
                echo "INFO : Manually Add ETCD member : Started"
                #add member manually
                sleep 3
                $KUBECTL exec -it $sts_name-1 -c dced -n $namespace -- etcdctl member add $sts_name-0 --peer-urls=https://$sts_name-0.$sts_name-peer.$namespace.svc.cluster.local:2380 &>/dev/null
                echo "INFO : Manually Add ETCD member : Completed"

                #get_pod_run_status
                                wait_pod_to_come_up $pod_name

        else
                echo "INFO : No unstarted member for pod-0"
        fi

        #revert config map changes now
        echo "INFO : Revert config map changes for pod-0 : started"
        if [[ -f "revert_pod0.yaml" ]];then `rm -f revert_pod0.yaml` ; fi
        $KUBECTL get cm $sts_name -o yaml -n $namespace > revert_pod0_$now.yaml
        sed -i 's/if \[  \${ordinal} \-eq \-1 ]/if \[  \${ordinal} \-eq 0 ]/g'  revert_pod0_$now.yaml
        sed -i '0,/ETCD_INITIAL_CLUSTER_STATE=\"existing\"/s//ETCD_INITIAL_CLUSTER_STATE=\"new\"/'  revert_pod0_$now.yaml
        new="c=1; c<=\$ordinal; c++"
        old="c=$(($replica_count)); c>\$ordinal; c--"
        sed -i "s/$old/$new/g"  revert_pod0_$now.yaml
        $KUBECTL apply -f  revert_pod0_$now.yaml  -n $namespace
        echo "INFO : Revert config map changes for pod-0 : completed"
        pod_zero="$sts_name-0"
        delete_pod $pod_zero
        #get_pod_run_status
        wait_pod_to_come_up $pod_zero
        echo "INFO : Steps for POD 0 Completed"
}

#Get Cluster status, member list, pod status.
kubectl_status(){
        echo "INFO : Get cluster health started"

        echo "INFO : Get pod status "
        $KUBECTL get pod -n $namespace | grep "$sts_name"

        #Get etcdctl member list
         echo -e "\nGet etcdctl member list "
        $KUBECTL exec -it $sts_name-0 -c dced -n $namespace -- etcdctl member list

        #Get endpoint status with cluster details
        echo -e "\nGet endpoint status"
        for i in $(seq 0 $replica_count)
        do
                $KUBECTL -it exec $sts_name-${i} -n ${namespace} -c dced -- bash -c "export ETCDCTL_ENDPOINTS=https://localhost:2379 ; etcdctl endpoint status --insecure-skip-tls-verify=true -w json";
        done;

        echo "INFO : Get cluster health : Completed"
}
#make pod 1 consistency
pod_1_consistent(){
        echo "INFO : Steps for POD 1 Started"
        echo "INFO : Perform config map changes for pod-1 : Started"
        if [[ -f "Config_pod1.yaml" ]];then `rm -f Config_pod1.yaml` ; fi
        $KUBECTL get cm $sts_name -o yaml -n $namespace > Config_pod1_$now.yaml
        old="c=1; c<=\$ordinal; c++"
        new="c=1; c<=\$ordinal+1; c++"
        sed -i "s/$old/$new/g" Config_pod1_$now.yaml
        $KUBECTL apply -f Config_pod1_$now.yaml -n $namespace
        echo "INFO : Perform config map changes for pod-1 : completed"
        pod_name="$sts_name-1"
        make_consistent $pod_name ${member_id[1]}
        delete_pod $pod_name
        #get_pod_run_status
                wait_pod_to_come_up $pod_name

        unstarted_pod1_member=`$KUBECTL exec -it $sts_name-1 -c dced -n $namespace -- etcdctl member list | awk '{print $1 $2}' | grep -i ".unstarted" | cut -d"," -f1`


        if [[ ! -z $unstarted_pod1_member ]];
        then
                echo "INFO : Caught unstarted Member for pod-1. Handle unstarted member before proceed further."
                make_consistent "$sts_name-1" $unstarted_pod1_member
                delete_pod $pod_name
                sleep 3
                #add member manually
                 echo "INFO : Manually Add ETCD member : Started"
                $KUBECTL exec -it $sts_name-0 -c dced -n $namespace -- etcdctl member add $sts_name-1 --peer-urls=https://$sts_name-1.$sts_name-peer.$namespace.svc.cluster.local:2380 &>/dev/null

                 echo "INFO : Manually Add ETCD member : Completed"
                #get_pod_run_status
                                wait_pod_to_come_up $pod_name

        else
                 echo "INFO : No unstarted member for pod-1"
        fi

        #Revert Config map for pod 1 now
        echo "INFO : Revert config map changes for pod-1 : started"
        if [[ -f "revert_pod1.yaml" ]];then `rm -f revert_pod1.yaml` ; fi
        $KUBECTL get cm $sts_name -o yaml -n $namespace > revert_pod1_$now.yaml
        new="c=1; c<=\$ordinal; c++"
        old="c=1; c<=\$ordinal+1; c++"
        sed -i "s/$old/$new/g" revert_pod1_$now.yaml
        $KUBECTL apply -f revert_pod1_$now.yaml  -n $namespace
        echo "INFO : Revert config map changes for pod-1 : completed"
        pod_zero="$sts_name-1"
        delete_pod $pod_zero
        #get_pod_run_status
                wait_pod_to_come_up $pod_zero
        echo "INFO : POD 1 steps : Completed"
}

#Get pod running status
get_pod_run_status(){
         echo "INFO : Get POD status : started"

        while [[ `$KUBECTL get pod <podname > -n $namespace | awk '{print $2}' | grep "0"  | wc -l` -gt 0 ]] ||  [[ `$KUBECTL get pod -n $namespace | awk '{print $3}' | grep -v -i "status\|running"  | wc -l` -gt 0 ]] && [[ `$KUBECTL get pod -n $namespace | awk '{print $4}' | grep -v "0"  | wc -l` -lt 2 ]]
        do

                $KUBECTL get pod -n $namespace | grep "$sts_name"
                                echo -e "\n"
        done;

        $KUBECTL get pod -n $namespace | grep "$sts_name"
                echo -e "\n"
        echo "INFO : Get POD status : completed"
kubectl_status

}


wait_pod_to_come_up() {
        echo "INFO : Get POD status : started"
        status=$($KUBECTL get po $1 -n $namespace | tr "\n" ' ' |tr -s ' ' |cut -d ' ' -f8)
        ready=$($KUBECTL get po $1 -n $namespace |tr "\n" ' ' |tr -s ' ' |cut -d ' ' -f7)
        while [[ "${ready}" -ne "1/1" && "${ready}" -ne  "2/2" && "${ready}" -ne  "3/3" ]] || [[ ${status} != "Running" ]]
        do
                status=$($KUBECTL get po $1 -n $namespace | tr "\n" ' ' |tr -s ' ' |cut -d ' ' -f8)
                ready=$($KUBECTL get po $1 -n $namespace |tr "\n" ' ' |tr -s ' ' |cut -d ' ' -f7)
                $KUBECTL get pod  $1 -n $namespace | grep "$sts_name"
        done
        $KUBECTL get pod -n $namespace | grep "$sts_name"
    echo "INFO : Get POD status : completed"
}




#Clear Inconsistency of pods
clear_inconsistency(){
        pod_name=$1
        member_id=$2
        sleep 5
        echo "INFO : Remove ETCD member"
        $KUBECTL exec -it $pod_name -c dced -n $namespace  -- etcdctl member remove $member_id &>/dev/null

        echo "INFO : Remove snap directory"
        $KUBECTL exec $pod_name -c dced -n $namespace  -- bash -c "rm /data/member/snap/*"&>/dev/null
        if [ $? != 0 ];
        then
                echo "WARNING: Could not remove '/data/member/snap/*'"
        fi

        echo "INFO : Remove wal directory"
        $KUBECTL exec $pod_name -c dced -n $namespace  -- bash -c "rm /data/member/wal/*" &>/dev/null
        if [ $? != 0 ];
        then
                echo "WARNING: Could not remove '/data/member/wal/*'"
        fi

}

#Remove member and data file from pod
make_consistent(){
        echo "INFO : Member and db deletion started "
        pod_name=$1
        member_id=$2
        clear_inconsistency $pod_name $member_id
        echo "INFO : Member and db deletion completed "
}

#Delete pod and wait for getting it in running status
delete_pod(){
        echo "INFO : Pod deletion started"
        pod_name=$1
        $KUBECTL delete pod $pod_name -n $namespace
        echo "INFO : Pod deletion completed"
}

#Get initial cluster health
echo "INFO : Get inital cluster health"
kubectl_status

#Consistent procedure
for i in ${pod_names[@]};
do
    member=`echo $i | cut -d'-' -f6`
    if [[ ${member_id[$member]} ==  $leader_id_hex ]]
    then
        echo "Procedure cannot be performed on Leader POD"
        exit 1
         elif [[ $member == 0 ]]
    then
        echo "INFO : Inconsistent member is pod-0"
        pod_0_consistent
    elif [[ $member == 1 ]]
    then
        echo "INFO : inconsistent member is pod-1"
        pod_1_consistent
    else
        echo "INFO : inconsistent member is pod-$member:"
        make_consistent $i ${member_id[$member]}
        delete_pod $i
        #get_pod_run_status
        wait_pod_to_come_up $i
    fi
done
#Get final Cluster Health
echo "INFO : Get final cluster health"
kubectl_status
