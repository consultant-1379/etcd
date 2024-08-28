# Distributed Coordinator ED Application Developers Guide

Template Version: 1.2.0

[TOC]

* author: Andrei Gavrisan
* doc-name: Distributed Coordinator ED-Application Developers Guide
* doc-no: 1/198 17-APR 201 59/2
* revnumber: A
* revdate: 2021-03-10
* approved-by-name: Davina McCloskey
* approved-by-department: BDGSBECA

## Introduction

The **Distributed Coordinator ED Application Developers Guide** details
required information regarding -

* Role-based Access Control in etcd.
* Distributed Coordinator ED BrAgent.

### *Revision History*

| Date | Revision | Comment | Author |
|---------------|------------------|--------------------------|--------------------|
| 10-10-2020 | 1.1.0 | Change document name from "Application Developer's Guide" to "Application Developers Guide" Update on "Where to store" and "Where to publish" information. | - |
| 11-08-2022 | 1.2.0 | Update to the latest template | Gaurav Jain |

## General Concept

## Application Integration

## Role-based Access Control

This section of the guide is intended to help users set up basic authentication
and role-based access control in etcd version 3.
For more information see [ETCD_ACL_Documentation](https://github.com/etcd-io/etcd/blob/master/Documentation/op-guide/authentication.md).

## Smart Helm Hook

Smart Helm Hook is a common framework to support pre/post helm hooks to avoid lack
of automation if required during rollback or upgrade from future versions.
Distributed Coordinator ED supports and integrates the Smart Helm Hook framework.
For more information on Smart Helm Hook solution integration guide,
[refer to this link](https://confluence.lmera.ericsson.se/pages/viewpage.action?spaceKey=PDUCDE&title=Smart+Helm+Hook+solution+integration+guide).

## root user and role

The root username is `root`. Root password has to be created before deploying
DCED (see Deployment Guide)

This will give the *root user* full access for administrative purposes: managing
roles and ordinary users.

The *root role* has global read-write access and permission to update the authentication
configuration of the cluster.

Additionally the **root role** can grant privileges for general cluster maintenance,
taking snapshots, modifying cluster membership and defragmenting the store.

### Guidelines for Using ACLs

The following guidelines are recommended when creating ACLs for your microservice:

* Use the microservice Distributed Coordinator ED when
creating *user names*, *roles*, and
*key prefixes*.
* Do not assign the role *root* to any of the created users.
* Ensure that new user roles are granted required permissions for keys prefixed
with the microservice Distributed Coordinator ED.
* When creating prefixed keys use the following format /key

### Decoding K8s Secret to Access etcdpasswd for Use With Root User

To setup new users we need to use the *root user* and the _etcdpasswd_.
In order to use _etcdpasswd_ for testing we need to reveal the kubernetes secret
and decode the _etcdpasswd_.

To reveal the kubernetes secret, run this command:

```yaml

kubectl -n <namespace> get secret eric-data-distributed-coordinator-creds -o yaml

apiVersion: v1
data:
  etcdpasswd: TVdZeVpERmxNbVUyTjJSbQ==
kind: Secret
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"etcdpasswd":"TVdZeVpERmxNbVUyTjJSbQ=="},"kind":"Secret","metadata":{"annotations":{},"name":"eric-data-distributed-coordinator-creds","namespace":"zgvnclp"},"type":"Opaque"}
  creationTimestamp: "2019-06-19T08:42:42Z"
  name: eric-data-distributed-coordinator-creds
  namespace: zgvnclp
  resourceVersion: "98429760"
  selfLink: /api/v1/namespaces/zgvnclp/secrets/eric-data-distributed-coordinator-creds
  uid: 339780df-926e-11e9-8706-005056b0b535
type: Opaque

```

Decode the secret _etcdpasswd_ field.

```bash
echo 'TVdZeVpERmxNbVUyTjJSbQ==' | base64 --decode
MWYyZDFlMmU2N2Rm
```

#### Log Into One of the Pods to Use the etcdctl Commands

```bash
kubectl exec -n <namespace> -it eric-data-distributed-coordinator-ed-0 -- bash
```

#### Create/Remove Users and Roles for Role Based Access

For the *root user* use the _etcdpasswd_ (MWYyZDFlMmU2N2Rm) from the section above.

##### Creating a user

```bash
# etcdctl --user root:MWYyZDFlMmU2N2Rm user add FOO
Password of FOO:
Type password of FOO again for confirmation:
User FOO created
```

##### Creating a role

```bash
# etcdctl --user root:MWYyZDFlMmU2N2Rm role add FOOrole
Role FOOrole created
```

##### Check users

```bash
# etcdctl --user root:MWYyZDFlMmU2N2Rm user list
FOO
root
```

##### Check roles

```bash
# etcdctl --user root:MWYyZDFlMmU2N2Rm role list
FOOrole
root
```

##### Removing a user

```bash
# etcdctl --user root:MWYyZDFlMmU2N2Rm user delete FOO
User FOO deleted
```

##### Removing a role

```bash
# etcdctl --user root:MWYyZDFlMmU2N2Rm role delete FOOrole
Role FOOrole deleted
```

#### Grant or Revoke Roles to a User

##### Grant the user FOO the role FOOrole

```bash
# etcdctl --user root:MWYyZDFlMmU2N2Rm user grant-role FOO FOOrole
Role FOOrole is granted to user FOO
```

##### Check settings for user FOO

```bash
# etcdctl --user root:MWYyZDFlMmU2N2Rm user get FOO
User: FOO
Roles: FOOrole
```

##### Revoke role FOOrole from the user FOO

```bash
# etcdctl --user root:MWYyZDFlMmU2N2Rm user revoke-role FOO FOOrole
Role FOOrole is revoked from user FOO
```

##### Check  settings for user FOO

```bash
# etcdctl --user root:MWYyZDFlMmU2N2Rm user get FOO
User: FOO
Roles:
```

#### Grant or Revoke Access Permissions to a Role

##### Grant the role FOOrole read access to key foo

```bash
# etcdctl --user root:MWYyZDFlMmU2N2Rm role grant-permission FOOrole read foo
Role FOOrole updated
```

##### Grant role FOOrole readwrite access to keys with a prefix /bren

```bash
# etcdctl --user root:MWYyZDFlMmU2N2Rm role grant-permission FOOrole --prefix=true readwrite /bren
Role FOOrole updated
```

##### Check what access permissions the role FOOrole has

```bash
# etcdctl --user root:MWYyZDFlMmU2N2Rm role get FOOrole
Role FOOrole
KV Read:
        [/bren, /breo) (prefix /bren)
        foo
KV Write:
        [/bren, /breo) (prefix /bren)
```

##### Revoke access permissions on role FOOrole for keys prefixed by /bren

```bash
# etcdctl --user root:MWYyZDFlMmU2N2Rm role revoke-permission FOOrole --prefix=true /bren
Permission of range [/bren, /breo) is revoked from role FOOrole
```

##### Confirm that role FOOrole has access permissions for keys prefixed

by /bren is removed

```bash
# etcdctl --user root:MWYyZDFlMmU2N2Rm role get FOOrole
Role FOOrole
KV Read:
        foo
KV Write:
```

### Working ACL Example for New User/Role Using Distributed Coordinator ED

#### Create the user test

```bash
# etcdctl --user root:MWYyZDFlMmU2N2Rm user add test
Password of test:
Type password of test again for confirmation:
User test created
# etcdctl --user root:MWYyZDFlMmU2N2Rm user list
BJH
FOO
test
root
```

#### Create the role testRole

```bash
# etcdctl --user root:MWYyZDFlMmU2N2Rm role add testRole
Role testRole created
# etcdctl --user root:MWYyZDFlMmU2N2Rm role list
BJHrole
FOOrole
testRole
root
```

#### Grant the user test the role testRole

```bash
# etcdctl --user root:MWYyZDFlMmU2N2Rm user grant-role test testRole
Role testRole is granted to user test
# etcdctl --user root:MWYyZDFlMmU2N2Rm user get test
User: test
Roles: testRole
```

#### Give the role testRole readwrite access to a key prefixed with /key

```bash
# etcdctl --user root:MWYyZDFlMmU2N2Rm role grant-permission testRole --prefix=true readwrite /key
Role testRole updated

# etcdctl --user root:MWYyZDFlMmU2N2Rm role get testRole
Role testRole
KV Read:
        [/key, /key2) (prefix /key)
KV Write:
        [/key, /key2) (prefix /key)
```

#### Verify the user can access the keys under test

```bash
etcdctl --user test get /key --endpoints=eric-data-distributed-coordinator-ed:2379
Password:
/key1
100A
```

#### Verify that the user cannot access the key \<foo>

```bash
etcdctl --user service_name get /key2 --endpoints=eric-data-distributed-coordinator-ed:2379
Password:
Error: etcdserver: permission denied
```

#### Verify that the user can write a new key,value pair under

prefix /key

```bash
etcdctl --user test put /key3 200A --endpoints=eric-data-distributed-coordinator-ed:2379
Password:
OK
```

#### Verify that the key is written successfully

```bash
etcdctl --user test get /key3 --endpoints=eric-data-distributed-coordinator-ed:2379
Password:
/key3
200A
```

#### Verify that the user cannot write keys that are not prefixed

with /key

```bash
# etcdctl --user test put /anykey 300A --endpoints=eric-data-distributed-coordinator-ed:2379
Password:
Error: etcdserver: permission denied
```

### ACL User Setup Templates

*The following template will:*

* create a new service user
* create a new service role
* grant the service role to the service user
* grant readwrite permissions to the service role to access
a set of keys prefixed with /key

*It is recommended to create a secret to store your service password.*

The username and password that the job should use, are stored in the files
./username.txt and ./password.txt on your local machine.

Run the following commands to create the files.

```bash
echo -n '<service_username>' > ./username.txt
echo -n '<service_user_password>' > ./password.txt
```

The kubectl create secret command packages these files into a Secret. Replace
the service_name and service_namespace

```bash
kubectl create secret generic <service_name> --from-file=./username.txt --from-file=./password.txt --namespace <service_namespace>
secret/<service_name> created
```

*Create the file create-user-job.yaml using one of the below templates,
replacing the "service_name" and "distributed-coordinator-ed_version".*

* Certificates disabled

```yaml
kind: Job
apiVersion: batch/v1
metadata:
  name: <service_name>
spec:
  template:
    metadata:
      name: <service_name>
    spec:
      restartPolicy: OnFailure
      containers:
      - name: <service_name>
        image:  "armdocker.rnd.ericsson.se/aia_releases/distributed-coordinator-ed-3.3.11:<distributed-coordinator-ed_version>"
        imagePullPolicy: IfNotPresent
        env:
        - name: ETCDCTL_API
          value: "3"
        - name: ETCD_CLIENT_SERVICE_ENDPOINT
          value: eric-data-distributed-coordinator-ed:2379
        - name: ETCD_ACL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: eric-data-distributed-coordinator-creds
              key: etcdpasswd
        - name: SERVICE_USERNAME
          valueFrom:
            secretKeyRef:
              name: <service_name>
              key: username.txt
        - name: SERVICE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: <service_name>
              key: password.txt
        command: ["/bin/sh", "-c"]
        args:
          - /usr/local/bin/etcdctl --user=root:$ETCD_ACL_ROOT_PASSWORD --endpoints=$ETCD_CLIENT_SERVICE_ENDPOINT user add $SERVICE_USERNAME:$SERVICE_PASSWORD;
            /usr/local/bin/etcdctl --user=root:$ETCD_ACL_ROOT_PASSWORD --endpoints=$ETCD_CLIENT_SERVICE_ENDPOINT role add $SERVICE_USERNAME;
            /usr/local/bin/etcdctl --user=root:$ETCD_ACL_ROOT_PASSWORD --endpoints=$ETCD_CLIENT_SERVICE_ENDPOINT user grant-role $SERVICE_USERNAME $SERVICE_USERNAME;
            /usr/local/bin/etcdctl --user=root:$ETCD_ACL_ROOT_PASSWORD --endpoints=$ETCD_CLIENT_SERVICE_ENDPOINT role grant-permission $SERVICE_USERNAME --prefix=true readwrite /$SERVICE_USERNAME;
```

* Certificates enabled

```yaml
kind: Job
apiVersion: batch/v1
metadata:
  name: <service_name>
spec:
  template:
    metadata:
      name: <service_name>
    spec:
      restartPolicy: OnFailure
      containers:
      - name: <service_name>
        image:  "armdocker.rnd.ericsson.se/proj-adp-eric-data-distributed-coordinator-ed-drop/eric-data-distributed-coordinator-ed:<distributed-coordinator-ed_version>"
        imagePullPolicy: IfNotPresent
        env:
        - name: ETCDCTL_API
          value: "3"
        - name: ETCD_CLIENT_SERVICE_ENDPOINT
          value: https://eric-data-distributed-coordinator-ed:2379
        - name: ETCDCTL_CACERT
          value: /data/combinedca/ca.crt
        - name: ETCDCTL_CERT
          value: /run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert/tls.crt
        - name: ETCDCTL_KEY
          value: /run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert/tls.key
        - name: CA_PARENT_DIR
          value: /run/secrets/
        - name: SERVICE_USERNAME
          valueFrom:
            secretKeyRef:
              name: <service_name>
              key: username.txt
        - name: SERVICE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: <service_name>
              key: password.txt
        volumeMounts:
        - name: server-cert
          mountPath: /run/secrets/eric-data-distributed-coordinator-ed-cert/
        - name: client-ca
          mountPath: /run/secrets/eric-data-distributed-coordinator-ed-ca/
        - name: etcdctl-client-cert
          mountPath: /run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert/
        - name: siptls-ca
          mountPath: /run/secrets/eric-sec-sip-tls-trusted-root-cert
        - name: data
          mountPath: /data
        command: ["/bin/sh", "-c"]
        args:
          - mkdir -p /data/combinedca/;
            if [[ ! -f /run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert/tls.crt ]];
            then
              export ETCDCTL_CERT=/run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert/clicert.pem;
              export ETCDCTL_KEY=/run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert/cliprivkey.pem;
            fi;
            awk 1 $CA_PARENT_DIR/*/*ca.crt > $ETCDCTL_CACERT;
            /usr/local/bin/etcdctl --endpoints=$ETCD_CLIENT_SERVICE_ENDPOINT user add $SERVICE_USERNAME:$SERVICE_PASSWORD;
            /usr/local/bin/etcdctl --endpoints=$ETCD_CLIENT_SERVICE_ENDPOINT role add $SERVICE_USERNAME;
            /usr/local/bin/etcdctl --endpoints=$ETCD_CLIENT_SERVICE_ENDPOINT user grant-role $SERVICE_USERNAME $SERVICE_USERNAME;
            /usr/local/bin/etcdctl --endpoints=$ETCD_CLIENT_SERVICE_ENDPOINT role grant-permission $SERVICE_USERNAME --prefix=true readwrite /$SERVICE_USERNAME;
      volumes:
      - name: siptls-ca
        secret:
          secretName: eric-sec-sip-tls-trusted-root-cert
      - name: client-ca
        secret:
          secretName: eric-data-distributed-coordinator-ed-ca
      - name: server-cert
        secret:
          secretName: eric-data-distributed-coordinator-ed-cert
      - name: etcdctl-client-cert
        secret:
          secretName: eric-data-distributed-coordinator-ed-etcdctl-client-cert
      - name: data
        emptyDir: {}
      imagePullSecrets:
      - name: <secret>
```

#### Apply the template, replacing the "service_namespace"

```bash
kubectl apply -f create-user-job.yaml --namespace <service_namespace>
```

## Distributed Coordinator ED BrAgent

This section of the guide is intended to help users set up and configure the
`Distributed Coordinator ED BrAgent` to communicate with `Backup and Restore Orchestrator`
and perform actions like - backup and restore of data.

### Installation

For the operations to succeed seamlessly, `Distributed Coordinator ED` should be
deployed with `brAgent.enabled=true`.

```bash
 helm install <CHART_REFERENCE> --name <RELEASE_NAME> --namespace <NAMESPACE> --set brAgent.enabled=true
```

The following applicationProperties parameters of `Distributed Coordinator ED BrAgent`
are mandatory and should be provided by the agent user.
The default values of these parameters must be changed according to intended use.

| Parameter | Description | Default value |
| --------- | ----------- | ------------- |
|dced.included.paths |A comma separated list of paths in a etcd host that should be stored during a backup operation and/or should be written to during a restore. Only these key-values and their children will be affected during a backup/restore operation.Each path should be a complete path starting from the etcd root.|
|dced.excluded.paths | A comma separated list of paths in a etcd host that should not be stored during a backup operation and/or should not be written to during a restore. Each path should be a complete path starting from the etcd root. This path configuration can be used to exclude children of paths included in **dced.included.paths**. | `empty` |

An example of the configuration - Every key-value excluding
**exclude** will be backed up.

| Parameter | configured value |
| --------- | ---------------- |
| dced.included.paths | "" |
| dced.excluded.paths | /exclude |
| dced.agent. restore.type | The user can choose how the *Distributed CoordinatorED BrAgent*  handles writing of key-value pairs, if present in the prefixes provided during *restore* action.  `overwrite`: *Distributed Coordinator ED BrAgent* will delete all existing key-value  pairs present in the `dced.included.paths` prefixes(except for the prefixes defined in  `dced.excluded.paths`) on *Distributed Coordinator ED* before restoring with the backup data.  `merge`: *Distributed Coordinator ED BrAgent* will push key-value pairs from the backup  to *Distributed Coordinator ED* while leaving untouched any existing key-value pairs  (on *Distributed Coordinator ED*) in the backup.

Note: If `dced.included.paths` and `dced.excluded.paths` are left empty,
all key-value pairs in the cluster are backed up.

The `Distributed Coordinator ED BrAgent` must be registered with an
instance of `Backup and Restore Orchestrator` before any action can commence.

The user should be familiar with performing actions via `Backup and Restore Orchestrator`.
For more information, refer to:

* CMYP_Operations_Guide
* BRO_REST_API_Guide

Note - A single instance of `Distributed Coordinator ED BrAgent` is ideal for use
by a single service.'
Coordination will be required between services to configure key-value prefixes to
be backed up if multiple services wish to use a single instance of
`Distributed Coordinator ED BrAgent` to avoid overlap.

### TLS configuration

`Distributed Coordinator ED BrAgent` supports mTLS between
`Backup and Restore Orchestrator` and `Distributed Coordinator ED`.

TLS can be toggled via the following parameters for enabling and disabling various
interfaces for brAgent.

| Parameter | BrAgent Interface | Default value |
| --------- | ------------------| ------------- |
|`global.security.tls.enabled` | `Backup and Restore Orchestrator` | true |
|`service.endpoints.dced.tls.enforced` | `Distributed Coordinator ED` | required |

### Backup operation

#### Prerequisite Check

It is strongly advised to stop the read/write activities during
a backup/restore action.

* After confirming the registration with `Backup and Restore
Orchestrator, run the command to execute the backup action
within the`Distributed Coordinator ED` pod.
* Please refer to the [CMYP_Operations_Guide] to trigger a backup via BRO REST Endpoint.

### Restore operation

Before beginning the restore operation, following should be confirmed:

* The Backed-up data which has to be restored needs to be present in the
`Backup and Restore Orchestrator`,

* The connection to the `Backup and Restore Orchestrator` is healthy,

* The `Distributed Coordinator ED BrAgent` is registered with the
`Backup and Restore Orchestrator`.

Backups taken with `Distributed Coordinator ED` version 1.4.0
and before are no longer compatible to be restored with
the current *Distributed Coordinator ED BrAgent*. It is
strongly recommended to take a fresh backup once
`Distributed Coordinator ED` is upgraded.
Attempting to restore an incompatible backup will result
in failure of the restore operation.

#### Restore operation steps

The steps below should be followed when performing restore
for `Distributed Coordinator ED`.

* Identify the Backup name, which has to be restored in
the `Backup and Restore Orchestrator`.

* Use the *restore* command with the backupName desired to
perform the restore action in the `Distributed Coordinator ED`.

* Please refer to the [CMYP_Operations_Guide] to trigger a
restore via BRO REST Endpoint.

The `Distributed Coordinator ED` keyspace can be verified
to check if the key value pairs intended to be restored
are present.

```bash
# etcdctl get /<Key-value prefix included in the backup> --prefix --keys-only --namespace <service_namespace>
```

## Interfaces

For Interface information you can refer this [link:](https://adp.ericsson.se/marketplace/distributed-coordinator-ed/documentation/4.7.0/dpi/service-user-guide#Architecture).

## Limitations

None.

## References

* **ETCD_ACL_Documentation** ACL Documentation
[https://github.com/etcd-io/etcd/blob/v3.3.11/Documentation/op-guide/authentication.md](https://github.com/etcd-io/etcd/blob/v3.3.11/Documentation/op-guide/authentication.md)
* **CMYP_Operations_Guide** Backup and Restore Operations Guide for
CM Yang Provider *5/19817-APR 201 40/2*
* **BRO_REST_API_Guide** Backup and Restore Orchestrator Rest API
User Guide *3/19817-APR 201 40/2*
