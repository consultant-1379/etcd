#!/bin/bash

echo "Restarting ETCD while reloading certificates"
  OPERATIONAL_CA_CERT_FILE=/run/secrets/eric-data-distributed-coordinator-ed-ca/ca.crt
  SIPTLS_CA_CERT_FILE=/run/secrets/"$SIP_TLS_CA_SECRET"/ca.crt

  OPERATIONAL_CA_CERT_FILE_LEGACY=/run/secrets/eric-data-distributed-coordinator-ed-ca/client-cacertbundle.pem
  SIPTLS_CA_CERT_FILE_LEGACY=/run/secrets/"$SIP_TLS_CA_SECRET"/cacertbundle.pem
if [[ "${ETCD_NAME: -1}" == 0 && ( -f "$OPERATIONAL_CA_CERT_FILE" || -f "$OPERATIONAL_CA_CERT_FILE_LEGACY" ) && ( -f "$SIPTLS_CA_CERT_FILE" || -f "$SIPTLS_CA_CERT_FILE_LEGACY" )]]
then
  echo "Killing ETCD process"
  pkill --exact etcd
elif [[ ! "${ETCD_NAME: -1}" == 0 ]]
then
    echo "Killing ETCD process"
    pkill --exact etcd
fi