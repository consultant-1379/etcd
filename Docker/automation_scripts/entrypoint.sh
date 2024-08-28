#!/bin/bash

LOGS=${FIFO_DIR}/etcd.fifo
# Timezone config check
if [ -f /usr/share/zoneinfo/$TZ ]
then
  echo "The current timezone is $TZ"
else
  echo "The configured timezone $TZ does not exist in the host, use UTC instead."
  export TZ="UTC"
fi
# this is used by the liveness probe to check if the pod is alive
echo "alive" > ${ETCD_DATA_DIR}/etcd.liveness
# open a named pipe for etcd_runner.sh. Leave it in read write mode to avoid blocking the script. A pipe is used to avoid filling disk space with logs
if [ ! -e $LOGS ]
then
    mkfifo $LOGS
fi

if [ $? -ne 0 ]; then
     echo "Cannot open logging pipe"
     exit 1
fi

./usr/local/bin/health/httpprobe_main &

# run the script in background
sh /usr/local/bin/scripts/etcd_runner.sh &

# get the pid to check for it later
PIDRUNNER=$!
if [[ ${DEFRAGMENT_ENABLE}=="true" ]]; then
  nohup /usr/local/bin/scripts/defragmentation.sh &
  nohup /usr/local/bin/scripts/monitorAlarm.sh &
fi
fail_count=$ENTRYPOINT_CHECKSNUMBER
restart=$ENTRYPOINT_RESTART_ETCD
restart_count=0
# checking for etcd health
while true; do
  # get the start time so is possible to know the time spent reading the pipe
  start=$(date +"%s")

  IFS=$'\n'
  # read logs from pipe
  read -r -t $ENTRYPOINT_PIPE_TIMEOUT <> $LOGS line
  echo "$line"
  # calculate time spent reading the pipe
  end=$(date +"%s")
  time_spent=$((end-start))

  # if we spent less then 5 seconds, add some sleep. this is useful to avoid too much cpu cycles
  if [[ ${time_spent} -le ${ENTRYPOINT_DCED_PROCESS_INTERVAL} ]]; then
    sleep $((time_spent))
  fi

  #Keep monitoring symlinks when TLS enabled, to prevent unnecessary deletion/modification of symlink
  if [[ "$TLS_ENABLED" = "true" ]];
  then
    sh /usr/local/bin/scripts/create_symlink.sh
  fi

  # if etcd is not running and ENTRYPOINT_RESTART is true, restart etcd, otherwise exit
  kill -0 ${PIDRUNNER}
  cmd_result=$?
  #A non-zero(1-255) exit status indicates failure
  if [[ $cmd_result -gt 0 ]]; then
    if [[ ${restart} == "true" ]]; then
      backupFile=${ETCD_DATA_DIR}/member/snap/backup.db
      if [[ -f "$backupFile" ]]; then
         nohup /usr/local/bin/scripts/etcd_restore.sh
      else
        echo "Killing the ETCD process"
        pkill etcd &
        sleep 0.05
        echo "Restarting ETCD"
        sh /usr/local/bin/scripts/etcd_runner.sh &
        PIDRUNNER=$!
        ((restart_count++))
        if [[ "$restart_count" == 12 ]]; then
           echo "dead" > ${ETCD_DATA_DIR}/etcd.liveness
        fi
      fi
    else
      echo "dead" > ${ETCD_DATA_DIR}/etcd.liveness
    fi
  fi
done
