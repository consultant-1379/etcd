#!/bin/bash
source /bragent/common_logging.sh

CERT_PATH="/run/secrets/eric-data-distributed-coordinator-ed-etcd-bro-client-cert"
renewed_count=0

isFileExist(){
  file=$1
  if [ ! -f $file ]; then
    return 1
  fi
  if [ -L "$file" ] && [ ! -e "$file" ]; then
    return 1
  fi
  return 0
}

certificates_checker(){
  local cert=$1
  local key=$2
  #check for cert files
  isFileExist $cert
  if [[ $? -eq 1 ]]; then
     logFatal "Certificate not Available" "CERTM-Certificate-Issue" "security/authorization messages" "$cert"
     return 1
  fi
  isFileExist $key
  if [[ $? -eq 1 ]]; then
     logFatal "Certificate not Available" "CERTM-Certificate-Issue" "security/authorization messages" "$key"
     return 1
  fi
  #Check if certificate and private key matches
  subject_name=$(echo "$(/usr/bin/openssl x509 -in ${cert} -subject -noout)" | awk -F "=" '{print $3}' | tr -d ' ')
  issuer_name=$(echo "$(/usr/bin/openssl x509 -in ${cert} -issuer -noout)" | awk -F "=" '{print $3}' | tr -d ' ')
  if [ ! "$(/usr/bin/openssl x509 -pubkey -in ${cert} -noout)" = "$(/usr/bin/openssl pkey -pubout -in ${key})" ]; then
    logFatal "Other Certificate Issue" "CERTM-Certificate-Issue" "security/authorization messages" "subject: ${subject_name}" "," "issuer: ${issuer_name}"
    return 1
  fi
  #Checking certs expiry
  expiry_date=$(/usr/bin/openssl x509 -enddate -noout -in ${cert} |cut -d= -f 2)
  life_days=$((($(date -d "$expiry_date" "+%s") - $(date -d "$date" "+%s")) / 86400))
  if [ "$life_days" -le 0 ]; then
     logFatal "Certificate not Valid" "CERTM-Certificate-Issue" "security/authorization messages" "subject: ${subject_name}" "," "issuer: ${issuer_name}"
     renewed_count=0
     return 1
  fi

  #Renewed event logging
  start_date=$(/usr/bin/openssl x509 -startdate -noout -in $cert |cut -d= -f 2)
  renewed_days=$((($(date -d "$date" "+%s") - $(date -d "$start_date" "+%s")) / 86400))
  if [[ $renewed_days -eq 0 ]] && [[ $renewed_count -eq 0 ]]; then
      logInfo "Certificate Issue Cleared" "CERTM-Certificate-Issue" "security/authorization messages" "subject: ${subject_name}" "," "issuer: ${issuer_name}"
      renewed_count=$(expr $renewed_count + 1)
      return 1
  fi
  return 0
}

if [ "$TLS_ENABLED" == "true" ]; then
   while true
   do
        cert_name=$(ls ${CERT_PATH}|grep -i cert|head -n 1)
        key_name=$(ls ${CERT_PATH}|grep -i key|head -n 1)
        certificates_checker "${CERT_PATH}/${cert_name}" "${CERT_PATH}/${key_name}"
        sleep 20
   done
fi