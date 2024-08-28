#!/bin/bash

create_syml(){
    local symlink="$1"
    local path_variable="/run/secrets/$2"
    local old_cert="$3"
    local new_cert="$4"
    local file="$5"

# Delete the link if a broken symlink is found
if [ -L "$file" ] && [ ! -e "$file" ];
then
  rm -rf $file
  echo "Removed a broken Symlink"
fi

# Create Links according to the variables
if [ -f $path_variable/$new_cert ]; then
  ln -s $path_variable/$new_cert $file
else
  ln -s $path_variable/$old_cert $file
fi
}

# Array of all the symlinks
symlinks=("tls-client.crt" "tls-client.key" "tls-srv.crt" "tls-srv.key" "tls-peer.crt" "tls-peer.key")

# Create Certificate folder incase it does not exist
if [[ ! -d /data/certificates ]];
then
  mkdir /data/certificates
fi

for symlink in "${symlinks[@]}"; do
file="/data/certificates/$symlink"
  if [[ ! -f "$file" ]];
  then
    if [[ "$symlink" == "tls-client."* ]];
    then
      variable="eric-data-distributed-coordinator-ed-etcdctl-client-cert"
      [ "$symlink" = "tls-client.crt" ] && new_cert=tls.crt old_cert=clicert.pem || new_cert=tls.key old_cert=cliprivkey.pem
    elif [[ "$symlink" == "tls-srv."* ]];
    then
      variable="eric-data-distributed-coordinator-ed-cert"
      [ "$symlink" = "tls-srv.crt" ] && new_cert=tls.crt old_cert=srvcert.pem || new_cert=tls.key old_cert=srvprivkey.pem
    elif [[ "$symlink" == "tls-peer."* ]];
    then
      variable="eric-data-distributed-coordinator-ed-peer-cert"
      [ "$symlink" = "tls-peer.crt" ] && new_cert=tls.crt old_cert=srvcert.pem || new_cert=tls.key old_cert=srvprivkey.pem
    fi
  create_syml "$symlink" "$variable" "$old_cert" "$new_cert" "$file"
  fi
done