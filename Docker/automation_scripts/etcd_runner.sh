#!/bin/bash -xe
# get ordinal
ordinal=${ETCD_NAME##*-}
# get service name
base_name=`echo $ETCD_NAME | sed "s/-${ordinal}$//g"`

if [[ "$ordinal" = "0" ]]; then
    export ETCD_INITIAL_CLUSTER_STATE="new"
else
    export ETCD_INITIAL_CLUSTER_STATE="existing"
fi

# create ETCD_INITIAL_CLUSTER:
# for peer 0 this is eric-distributed-coordinator-0=url-0
# for peer 1 this is eric-distributed-coordinator-0=url-0,eric-distributed-coordinator-1=url-1
# for peer 2 this is eric-distributed-coordinator-0=url-0,eric-distributed-coordinator-1=url-1,eric-distributed-coordinator-2=url-2

replace_string="XYZ"
initial_cluster_base="${ETCD_NAME}=${ETCD_INITIAL_ADVERTISE_PEER_URLS}"
initial_cluster_base="${initial_cluster_base//$ETCD_NAME/${replace_string}}"
ETCD_INITIAL_CLUSTER="${initial_cluster_base//${replace_string}/$base_name-0}"

for (( c=1; c<=$ordinal; c++ ))
do
    ETCD_INITIAL_CLUSTER=${ETCD_INITIAL_CLUSTER},${initial_cluster_base//${replace_string}/$base_name-$c}
done

export ETCD_INITIAL_CLUSTER

if [[ "$TLS_ENABLED" = "true" ]];
then
  ETCD_PEER_CERT_FILE=$PEER_CLIENTS_CERTS
  ETCD_PEER_KEY_FILE=$PEER_CLIENT_KEY_FILE
  AUTO_TLS=$PEER_AUTO_TLS_ENABLED
  CA_FILE=$TRUSTED_CA
  /usr/local/bin/scripts/switch_ca_cert.sh  -cs

  echo "Setup peer certs for ${ETCD_NAME} "
  ETCD_LISTEN_PEER_URLS=$LISTEN_PEER_URLS
  export ETCD_LISTEN_PEER_URLS

  while [[ "${AUTO_TLS}" == "false" && ! -s ${ETCD_PEER_CERT_FILE} && ! -s ${ETCD_PEER_KEY_FILE} ]]
  do
    echo "Peer certs empty ${ETCD_PEER_CERT_FILE} ${ETCD_PEER_KEY_FILE},sleep 2 seconds. "
    sleep 2
  done

  if [[ "${AUTO_TLS}" == "false" ]]; then
    echo "Auto TLS disabled , setup SIP-TLS certs for peer communication"
    ETCD_PEER_CLIENT_CERT_AUTH=$PEER_CERT_AUTH_ENABLED
    ETCD_PEER_TRUSTED_CA_FILE=$ETCD_TRUSTED_CA_FILE
    ETCD_PEER_CERT_FILE=$PEER_CLIENTS_CERTS
    ETCD_PEER_KEY_FILE=$PEER_CLIENT_KEY_FILE

    export ETCD_PEER_CLIENT_CERT_AUTH
    export ETCD_PEER_TRUSTED_CA_FILE
    export ETCD_PEER_CERT_FILE
    export ETCD_PEER_KEY_FILE
  else
    echo "Auto TLS enable , using ETCD auto generated certs for peer communication"
  fi
fi


# redirect etcd output to named pipe open by entrypoint.sh so we can continue to stream etcd log to k8s in real time.
/usr/local/bin/etcd > ${FIFO_DIR}/etcd.fifo
