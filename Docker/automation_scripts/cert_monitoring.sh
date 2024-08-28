#!/bin/bash
source /usr/local/bin/scripts/common_logging.sh

SYMBOLIC_LINK_PATH="/data/certificates"
OPERATIONAL_CA_CERT_FILE=/run/secrets/eric-data-distributed-coordinator-ed-ca
SIPTLS_CA_CERT_FILE=/run/secrets/"$SIP_TLS_CA_SECRET"

renewed_count=0
tls_certs_logging() {

 #DCED client certificates
 certificates_checker ${SYMBOLIC_LINK_PATH}/tls-client.crt ${SYMBOLIC_LINK_PATH}/tls-client.key
 #Server certificates
 certificates_checker ${SYMBOLIC_LINK_PATH}/tls-srv.crt ${SYMBOLIC_LINK_PATH}/tls-srv.key
 #Peer Certificates
 certificates_checker ${SYMBOLIC_LINK_PATH}/tls-peer.crt ${SYMBOLIC_LINK_PATH}/tls-peer.key
 #DCED CA
 ca_cert_reader ${OPERATIONAL_CA_CERT_FILE}
 #SIP-TLS CA
 ca_cert_reader ${SIPTLS_CA_CERT_FILE}
}

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

ca_cert_reader(){
  cert_path=$1
  param=$(ls $1 |head -n 1)
  ca_cert_checker "${cert_path}/${param}"
}

ca_cert_checker(){
  local cert=$1
  isFileExist $cert
  if [[ $? -eq 1 ]]; then
    logFatal "Certificate not Available" "CERTM-Certificate-Issue" "security/authorization messages" "$cert"
    return 1
  fi
  #Checking CAs expiry
  subject_name=$(echo "$(/usr/bin/openssl x509 -in ${cert} -subject -noout)" | awk -F "=" '{print $3}' | tr -d ' ')
  issuer_name=$(echo "$(/usr/bin/openssl x509 -in ${cert} -issuer -noout)" | awk -F "=" '{print $3}' | tr -d ' ')
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

while true
do
  tls_certs_logging
  sleep 20
done