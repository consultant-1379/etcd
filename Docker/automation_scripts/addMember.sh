#!/bin/bash
set -x

ordinal=${ETCD_NAME##*-}
touch ${ETCD_DATA_DIR}/cert_watcher.txt

if [[ "$TLS_ENABLED" = "true" ]];
then
  OPERATIONAL_CA_CERT_FILE=/run/secrets/eric-data-distributed-coordinator-ed-ca/ca.crt
  SIPTLS_CA_CERT_FILE=/run/secrets/"$SIP_TLS_CA_SECRET"/ca.crt

  OPERATIONAL_CA_CERT_FILE_LEGACY=/run/secrets/eric-data-distributed-coordinator-ed-ca/client-cacertbundle.pem
  SIPTLS_CA_CERT_FILE_LEGACY=/run/secrets/"$SIP_TLS_CA_SECRET"/cacertbundle.pem

  echo "Searching for operational certificates"
  while  ( !( [[ -f "$OPERATIONAL_CA_CERT_FILE" ]] || [[ -f "$OPERATIONAL_CA_CERT_FILE_LEGACY" ]] ) ) || ( !( [[ -f "$SIPTLS_CA_CERT_FILE" ]] || [[ -f "$SIPTLS_CA_CERT_FILE_LEGACY" ]] ) )
  do
    sleep 5
  done
  echo "operational certificates found"

  if [[ -f /data/certificates/tls-client.crt || -f /data/certificates/tls-client.key ]];
  then
    rm -rf /data/certificates/tls-client.crt /data/certificates/tls-client.key /data/certificates/tls-srv.crt /data/certificates/tls-srv.key /data/certificates/tls-peer.crt /data/certificates/tls-peer.key
  fi

  if [ $ordinal -ne 0 ]
  then
    sleep 2
  fi
fi

while true
do
    # enable authentication very first time that etcd-0 is started
    if [  ${ordinal} -eq 0 ] && [ ! -f "${ETCD_DATA_DIR}/auth_successful" ]
    then

      # make sure everything succeeds
      set +e
      # start etcd locally without any cert validation
      ETCDCTL_ENDPOINTS="localhost:${DCED_PORT}"

      unset ETCDCTL_CACERT ETCDCTL_CERT ETCDCTL_KEY
      echo "Configuring authentication!"

      # Create Symlink and monitor them for DCED POD-0
      bash -x /usr/local/bin/scripts/create_symlink.sh
      # etcd will listen on localhost and accept requests on localhost only
      /usr/local/bin/etcd &
      PIDETCD=$!
      unset ETCDCTL_ENDPOINTS
      while ! /usr/local/bin/etcdctl member list ; do sleep 1; done
      # disable command output
      set +x
      if [[ "$TLS_ENABLED" = "true" ]];
      then
        /usr/local/bin/etcdctl user get root  || /usr/local/bin/etcdctl user add root --no-password
        /usr/local/bin/etcdctl auth enable >/dev/null
      else
        /usr/local/bin/etcdctl --user root:${ACL_ROOT_PASSWORD} user get root  || /usr/local/bin/etcdctl user add root:${ACL_ROOT_PASSWORD}
        /usr/local/bin/etcdctl --user root:${ACL_ROOT_PASSWORD} auth enable >/dev/null
      fi
      set -x
      touch ${ETCD_DATA_DIR}/auth_successful
      echo -n "${ETCD_DATA_DIR}/auth_successful return code is$?"
      kill ${PIDETCD}
      echo -n "excecuted kill command with return code:$? exiting with exit0"
      exit 0
    fi

  if [[ "$TLS_ENABLED" = "true" ]];
  then
    /usr/local/bin/scripts/switch_ca_cert.sh  -c
    chown -R 250422:250422 /data/combinedca/
  fi

    # Create Symlink and monitor them for DCED POD-1 and POD-2
    bash -x /usr/local/bin/scripts/create_symlink.sh

    # get all members in the cluster
    member_list=$(/usr/local/bin/etcdctl member list )
    member_list_return_code=$?

    # check if the new node is already in the cluster

    my_member_line=$(/usr/local/bin/etcdctl member list | grep ${ETCD_NAME}. )
    member_line_return_code=$?

    # get member_id
    member_id=$(echo $my_member_line | cut -d, -f1)

    # if the cluster exists
    if [ $member_list_return_code -eq 0 ]
    then
       # disable the output of running commands, because of the the sensitive ACL_ROOT_PASSWORD
       set +x
       # if new node not yet in cluster
       if [ $member_line_return_code -ne 0 ]
       then
           # add node to cluster
           member_add_line=$(/usr/local/bin/etcdctl member add ${ETCD_NAME} --peer-urls=${ETCD_INITIAL_ADVERTISE_PEER_URLS} || /usr/local/bin/etcdctl member add --user root:${ACL_ROOT_PASSWORD} ${ETCD_NAME} --peer-urls=${ETCD_INITIAL_ADVERTISE_PEER_URLS} )
           member_add_line_return_code=$?
       elif [[ -z $(/usr/local/bin/etcdctl member list | grep ${ETCD_INITIAL_ADVERTISE_PEER_URLS}) ]]
       then
          # already in cluster update peer url in case it changed
           member_add_line=$(/usr/local/bin/etcdctl member update $member_id --peer-urls=${ETCD_INITIAL_ADVERTISE_PEER_URLS} || /usr/local/bin/etcdctl member update --user root:${ACL_ROOT_PASSWORD} $member_id --peer-urls=${ETCD_INITIAL_ADVERTISE_PEER_URLS} )
           member_add_line_return_code=$?
       else
           exit 0
       fi
       # enable the output of running commands
       set -x
       # check if new node has been added correctly
       if [ $member_add_line_return_code -eq 0 ]
       then
         exit 0
       fi
    else
      if [ $ordinal -ne 0 ]
      then
        # check if already initialized
        if [ -d "${ETCD_DATA_DIR}/member" ]
        then
            # we were a member previously but we cannot reach the cluster, start with whatever config we have
            exit 0
        else
            echo "cluster id is not 0, but there is not cluster and this instance has not been initialized previously"
        fi
      else
        exit 0
      fi
    fi

    sleep 2
done
