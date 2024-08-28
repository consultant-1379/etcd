# Distributed Coordinator ED Test Specification

## Abstract

This document describes the test cases used to verify the Distributed
Coordinator ED:

- Dockerfile
- Docker Image
- Helm chart
- Backup and Restore Agent

## Unit tests

- Test Environment: Jenkins Slave.

- Test Object: Distributed Coordinator ED Dockerfile, Distributed Coordinator
ED Helm chart files and Distributed Coordinator ED BrAgent

### Junit

- Verify the functionality of individual classes within the Distributed
Coordinator ED BrAgent Java codebase.

#### Backup

Below are the various scenarios considered while testing backup action:

- Verify backup file is created.
- Verify backup fails with incorrect credentials.
- Verify that backup action is complete and successful with default configuration
- Verify that backup action is complete and successful modified configuration.
- Verify backup file is deleted after transfer to Backup and Restore Orchestrator

#### Restore

Below are the various scenarios considered while testing restore action:

- Verify that restore action is complete and successful with default configuration
- Verify that restore action is complete and successful if existing data is to
be overwritten
- Verify that restore action is complete and successful if existing data is to
 be kept
- Verify a restore will not succeed if the corresponding backup does not
exist.

### Helm lint

- Verify that the Distributed Coordinator ED Helm chart is well formed.

### Docker build

- Verify that the Distributed Coordinator ED Dockerfile and the Distributed
Coordinator ED
BrAgent Dockerfile builds successfully.

### Container Structure Tests

#### Metadata Tests

Verify that the container has the correct:

- ETCD version
- entrypoint

#### File Tests

- Verify that the files required to run the container are present and executable.
- Verify that the container is based on Common Base OS.

### System Tests

- Test Environment: ADP Sandbox with Distributed Coordinator ED Helm chart
deployed.
- Test Object: Distributed Coordinator ED Helm chart.

#### Installation

- Verify that the Distributed Coordinator ED Helm chart can be installed using
**helm install**.
- Verify that key-value pairs can be created, read and deleted.
- Verify that Distributed Coordinator ED can be installed without certificates.
- Verify that Distributed Coordinator ED can be installed with certificates.

#### Service Identity Provider TLS Installation

- Verify that the Service Identity Provider TLS Helm chart can be installed using
**helm install**, the certificates are generated and the key-value pairs can be
created, read and deleted.

#### Key Management Service Installation

- Verify that the Key Management Service Helm chart can be installed using
**helm install**, the certificates are provisioned and the key-value pairs can
be created, read and deleted.

#### Authentication Enabled

- Verify if the key-value pairs can be created, read and deleted.
- Verify that keys can only be accessed by authenticated users.

#### Upgrade

- Verify that the Distributed Coordinator ED Helm chart can be upgraded using
**helm upgrade**.
- Verify that key-value pairs can be created, read and deleted.

#### Rollback

- Verify that the Distributed Coordinator ED Helm chart can be rolled back after
an Upgrade using **helm rollback**.
- Verify that key-value pairs can be created,
read and deleted.

#### Scaling

- Verify that the Distributed Coordinator ED Service can be scaled out and
scaled in while key-value pairs are being sent.
- Verify that no key-value pairs
are lost.

#### Robustness

- Verify that when Distributed Coordinator ED pods are deleted, Kubernetes
automatically recreates the pods and the ETCD processes in the Distributed
Coordinator ED containers start up successfully.
- Verify that key-value pairs
can be created and read during this operation and that no key-value pairs are
lost.

#### Verify metrics available

 - Verify that the Distributed Coordinator ED Service metrics can be accessed
on the exposed port using the curl command.

#### Uninstall

- Verify that the Distributed Coordinator ED Service can be uninstalled using
the **helm delete** command.

#### Logs verification (log shipper)

Services deployed with LS Sidecar, Log Transformer, and Search Engine

- Verify that service logs (includes all container logs) can be
fetched from Log Shipper Search Engine in following scenarios:

    - Log verification in TLS deployment
    - Log verification in a non-TLS deployment
    - Multiline log verification
    - Filter pattern log verification
    - Console logging captured when the sidecar is disabled.

#### OWASP Zed Attack Proxy

- Verify that security vulnerabilities are not present in the REST API.

### Characteristics

Measure the following characteristics on an empty default ADP environment:

- **Deployment time** for the Distributed Coordinator ED using:
    - default values (3 replicas) in the helm chart
    - Docker image is already pulled
- Time required to **restart** one Distributed Coordinator ED pod gracefully
- **Size of the Docker image** for Distributed Coordinator ED
- **Maximum stable throughput** for a Distributed Coordinator ED
Kubernetes deployment using:
    - default deployment values
    - a Distributed Coordinator ED test pod
    - the **etcdctl check perf --load="s"**
