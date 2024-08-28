#!/bin/bash

# options
# -c check if ca cert does not exist, exit
# -s restart pod if certs change
# -w wait for at least one of the ca cert files to exist


# concat all potential locations of the ca certs
OPERATIONAL_CA_CERT_FILE=/run/secrets/eric-data-distributed-coordinator-ed-ca/ca.crt
SIPTLS_CA_CERT_FILE=/run/secrets/"$SIP_TLS_CA_SECRET"/ca.crt

OPERATIONAL_CA_CERT_FILE_LEGACY=/run/secrets/eric-data-distributed-coordinator-ed-ca/client-cacertbundle.pem
SIPTLS_CA_CERT_FILE_LEGACY=/run/secrets/"$SIP_TLS_CA_SECRET"/cacertbundle.pem

CA_FILE=$TRUSTED_CA
CA_CERT_FILE_NAME=cacertbundle.pem
set -x
while getopts cs option
do
    case "${option}"
    in
    c) CHECK=true;;
    s) SUICIDE=true;;
    esac
done
mkdir -p /data/combinedca/

if [[ -v SUICIDE ]]
then
  # etcd automatically reloads the server and client certs
  # but it does not reload the CA
  # we need to restart etcd to make this happen
  # if an exisiting watch_cert process is detected, skip step.
  if [[ -z $(ps -ef | grep watch_cert | grep -v grep) ]]
  then
   nohup /usr/local/bin/scripts/watch_cert.sh /run/secrets/*ca /run/secrets/*"$SIP_TLS_CA_SECRET" &
   nohup /usr/local/bin/scripts/cert_monitoring.sh &
  fi
fi

# put all CAs in one file, ensure CA is not empty
rm -f $CA_FILE
while [[ ! -s $CA_FILE ]]
do
  if  [[ -f "$OPERATIONAL_CA_CERT_FILE" ]] && [[ -f "$SIPTLS_CA_CERT_FILE" ]];
  then
    CA_CERT_FILE_NAME=ca.crt
  fi
awk 1 /run/secrets/*/*"$CA_CERT_FILE_NAME" > $CA_FILE
  if [[ ! -s $CA_FILE ]];
  then
    sleep 2
  fi
done

# exit if ca file does not exist (if -c is given as argument)
if [[ -v CHECK && ! -f "$CA_FILE" ]]
then
  echo "No content in $CA_FILE"
  exit 1
fi