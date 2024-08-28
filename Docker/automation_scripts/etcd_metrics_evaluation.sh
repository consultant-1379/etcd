unset ETCDCTL_ENDPOINTS;
curl --cacert /run/secrets/"$SIP_TLS_CA_SECRET"/ca.crt --cert "$ETCDCTL_CERT"  --key "$ETCDCTL_KEY" https://eric-data-distributed-coordinator-ed:2379/metrics > /data/etcd-metrics.txt

#etcd_disk_backend_defrag_duration_seconds_bucket
backend_defrag=$(grep etcd_disk_backend_defrag_duration_seconds_bucket /data/etcd-metrics.txt|tail -1|cut -d" " -f2)
backend_defrag_p99=$(((backend_defrag*99)/100))
tac /data/etcd-metrics.txt | grep etcd_disk_backend_defrag_duration_seconds_bucket | while read -r line ;
do
  value=$(echo $line |cut -d' ' -f2)
  if [[ $value -le $backend_defrag_p99 ]]
  then
    output=$(echo $line |cut -d'"' -f2)
    echo "backend_defrag p99 duration is $output"
    break
  fi
done

#etcd_disk_wal_fsync_duration_seconds_bucket
wal_fsync=$(grep etcd_disk_wal_fsync_duration_seconds_bucket /data/etcd-metrics.txt|tail -1|cut -d" " -f2)
wal_fsync_p99=$(((wal_fsync*99)/100))
tac /data/etcd-metrics.txt | grep etcd_disk_wal_fsync_duration_seconds_bucket | while read -r line ;
do
  value=$(echo $line |cut -d' ' -f2)
  if [[ $value -le $wal_fsync_p99 ]]
  then
    output=$(echo $line |cut -d'"' -f2)
    echo "wal_fsync p99 duration is $output"
    break
  fi
done


#etcd_disk_backend_commit_duration_seconds_bucket
back_commit=$(grep etcd_disk_backend_commit_duration_seconds_bucket /data/etcd-metrics.txt|tail -1|cut -d" " -f2)
back_commit_p99=$(((back_commit*99)/100))
tac /data/etcd-metrics.txt | grep etcd_disk_backend_commit_duration_seconds_bucket | while read -r line ;
do
   value=$(echo $line |cut -d' ' -f2)
   if [[ $value -le $back_commit_p99 ]]
   then
      output=$(echo $line |cut -d'"' -f2)
      echo "back_commit p99 duration is $output"
      break
   fi
done

#etcd_network_peer_round_trip_time_seconds_bucket
round_trip=$(grep etcd_network_peer_round_trip_time_seconds_bucket /data/etcd-metrics.txt|tail -1|cut -d" " -f2)
round_trip_p99=$(((round_trip*99)/100))
tac /data/etcd-metrics.txt | grep etcd_network_peer_round_trip_time_seconds_bucket | while read -r line ;
do
  value=$(echo $line |cut -d' ' -f2)
  if [[ $value -le $round_trip_p99 ]]
    then
    output=$(echo $line |cut -d'"' -f4)
    echo "round_trip p99 round_trip_time is $output"
    break
  fi
done