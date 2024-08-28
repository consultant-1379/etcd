#!/bin/bash

LOG_FILE=/data/logs/watcher.log
DATA_CONFIG_FILE=/data/logs/inconsistentPod.txt
ordinal=${ETCD_NAME##*-}
DCED_POD=`echo $ETCD_NAME | sed "s/-${ordinal}$//g"`
declare leader_revision=""
declare leader_id_hex=""
declare leader_position=""
#Revision count to detect data inconsistency.
REVISION_INCONSISTENT_BARRIER_COUNT=15
#Interval to run detect_Data_Inconsistency script(in minutes)
INCONSISTENCY_PERIODIC_INTERVAL=5
mkdir -p /data/logs/

while true; do
  #Get the Replica count
  replicas=$(bash -c "/usr/local/bin/etcdctl member list | wc -l")
  if [[ $replicas -gt 1 ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: Replica count is  $replicas" >> $LOG_FILE
    (( replica_count = $replicas - 1))
    #Retrieve Leader ID
    echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: Retrieve leader id" >> $LOG_FILE
    leader=""
    leader=$(bash -c "/usr/local/bin/etcdctl endpoint status --write-out=json | egrep -o '\"leader\":[0-9]*'")
    leader_id=$(echo "$leader" | cut -d ":" -f2 )
    leader_id_hex=$(printf '%x' $leader_id)
    echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: Leader ID is $leader_id_hex" >> $LOG_FILE

    echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: Retrieve member id." >> $LOG_FILE
    declare -a member_id
    declare -a revisions
    for i in $(seq 0 $replica_count)
    do
      #Retrieve all the member_id's
      member=$(bash -c "/usr/local/bin/etcdctl member list | grep $DCED_POD-$i" )&>/dev/null
      if [ $? != 0 ]; then
          echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: Unable to fetch member id for $DCED_POD-$i" >> $LOG_FILE
      fi
      member_id[$i]=$(echo $member | cut -d, -f1 | awk '{$1=$1;print}')
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: Member id for $DCED_POD-$i : ${member_id[$i]}" >> $LOG_FILE
      if [[ -z ${member_id[$i]} ]]; then
          echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: Invalid Member ID found. Please check pod state manually" >> $LOG_FILE
      fi

      endpoint_url=`echo "$ETCD_INITIAL_ADVERTISE_PEER_URLS" | sed "s/$ETCD_NAME/$DCED_POD-$i/g"`
      endpoint_url=`echo "$endpoint_url" | sed "s/2380/2379/g"`
      #retrieve the revision for each member
      revision=$(bash -c "export ETCDCTL_ENDPOINTS=$endpoint_url;/usr/local/bin/etcdctl endpoint status --write-out=json --insecure-skip-tls-verify | egrep -o '\"revision\":[0-9]*'" ) &>/dev/null
      if [ $? != 0 ]; then
          echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: Unable to fetch Revision for $DCED_POD-$i" >> $LOG_FILE
      fi
      revisions[$i]=`echo $revision | cut -d: -f2 | awk '{$1=$1;print}'`
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: Revision for $DCED_POD-$i : ${revisions[$i]}" >> $LOG_FILE
    done

    # retreiving the position of leader in member_id Array
    for i in $(seq 0 $replica_count)
    do
      if [[ ${member_id[$i]} = "$leader_id_hex" ]]; then
          leader_position=$i
          leader_revision=${revisions[$i]}
          echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: Leader revision is $leader_revision" >> $LOG_FILE
          break;
      fi
    done

    #comparing the leader revision and member revision
    inconsistent_pod=""
    is_consistent=false
    for i in $(seq 0 $replica_count)
    do
      leader_rev="${leader_revision/$'\r'/}"
      follower_rev="${revisions[i]/$'\r'/}"
      if [[ $leader_position -ne $i ]] && [[ $leader_rev -ne $follower_rev ]]; then
         difference=`expr $leader_rev-$follower_rev`
         (( difference = difference < 0 ? difference * -1 : difference ))
         echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: diff between revisions is $difference" >> $LOG_FILE
         if [[ $difference -ge $REVISION_INCONSISTENT_BARRIER_COUNT ]]; then
            inconsistent_pod="$inconsistent_pod $DCED_POD-$i "
            is_consistent="true"
         fi
      fi
    done

    if [ "$is_consistent" = true ]
    then
      len=${#inconsistent_pod}
      echo "${inconsistent_pod::len-1}" > $DATA_CONFIG_FILE
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: Inconsistent Pod found ${inconsistent_pod::len-1}" >> $LOG_FILE
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: Raising the Alert!!" >> $LOG_FILE
    else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: No inconsistent Pod found" >> $LOG_FILE
      echo "" > $DATA_CONFIG_FILE
    fi
    sleep ${INCONSISTENCY_PERIODIC_INTERVAL}m
  fi
done