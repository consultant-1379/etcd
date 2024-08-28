<!-- Document Template information:
Prepared:Jenny Schulze
Approved:Davina McCloskey
Document Name:user-guide-template
Revision: {!../../.bob/var.version!}
Date: {!../../.bob/var.date!}
-->

# *Distributed Coordinator ED* User Guide

[TOC]

## Overview

This document provides an overview of the *Distributed Coordinator ED* (DCED)
Service. It gives a brief description of its main features and its
interfaces.

The *Distributed Coordinator ED* Service is a distributed key value store that
provides a reliable way to store data across a cluster of machines.
It gracefully handles leader elections during network partitions and will
 tolerate machine failure, including the leader.
*Distributed Coordinator ED* is written in Go and uses the Raft consensus
algorithm to manage a highly-available replicated log.

Using the [API][etcdapi] your application can do the following operations:

* Creates, updates, fetches, and deletes key-value pairs.
* Monitors changes to keys.
* Primitives for consuming client keep-alive messages.

![Overview](DistributedCoordinatorED_deployment_overview.png)

Figure 1 Overview of *Distributed Coordinator ED*

### Supported Use Cases

This chapter gives an overview of the supported use cases.

| Use Case ID     | Use Case Title                     | Compliance      |Maturity|
|-----------------|------------------------------------|-----------------|--------|
| [UC.DM.DC.DL.001][lock_case_1] | create distributed lock             | Fully supported | Stable |
| [UC.DM.DC.DL.002][lock_case_2] | acquire distributed lock            | Fully supported | Stable |
| [UC.DM.DC.DL.003][lock_case_3] | release distributed lock            | Fully supported | Stable |
| [UC.DM.DC.DL.004][lock_case_4] | remove distributed lock             | Fully supported | Stable |
| [UC.DM.DC.EL.001][leader_case_1] | elect leader                       | Fully supported | Stable |
| [UC.DM.DC.EL.002][leader_case_2] | query leader                       | Fully supported | Stable |
| [UC.DM.DC.EL.003][leader_case_3] | remove leader                      | Fully supported | Stable |
| [UC.DM.DC.EL.004][leader_case_4] | subscribe on leader changes        | Fully supported | Stable |
| [UC.DM.DC.EL.005][leader_case_5] | remove leader changes notification | Fully supported | Stable |

### Architecture

The *Distributed Coordinator ED* service involves interaction between their
clients of a distributed application and the *Distributed Coordinator ED*
Service, as shown in the figure below:

![Architecture](DistributedCoordinatorED_architecture_overview.png)

Figure 2 Architecture view of *Distributed Coordinator ED*

| Interface Logical Name | Interface Realization | Description | Interface Maturity |
| ---------------------- | --------------------- | ----------- | ------------------ |
| INT.DM.DC.LOCK         | see [API][etcdapi]    | Native interface of the *Distributed Coordinator ED* implementation for distributed lock. TLS is used for encryption and server authentication using certificates acquired from SIP-TLS. Clients are authenticated using client certificates.  | Stable |
| INT.DM.DC.ELECT        | see [API][etcdapi]    | Native interface of the *Distributed Coordinator ED* implementation for leader election operation. TLS is used for encryption and server authentication using certificates acquired from SIP-TLS. Clients are authenticated using client certificates. | Stable |
| INT.DM.DC.ADMIN        | see [API][etcdapi]    | Native interface of the *Distributed Coordinator ED* implementation for admin to config and manage the distributed coordinator service. TLS is used for encryption and server authentication using certificates acquired from SIP-TLS. Clients are authenticated using client certificates. | Stable |

#### Application Programming Interfaces (APIs)

This service does not provide any APIs.

#### API Key Performance Indicators (LCM KPIs)

This service does not provide any APIs.

### Deployment View

*Distributed Coordinator ED* is packaged as a Docker container. It supports
deployment in Kubernetes using Helm. It is dependent on SIP-TLS and KMS, when
installing with certificates (default).

The *Distributed Coordinator ED* Service is realized in a StatefulSet. It
 supports one or more replicas. At least three replicas should be used for high
availability.

The *Distributed Coordinator ED* provides two Kubernetes services:

* A client service that provides a gRPC/REST interface for client interaction.
* An internal peer service used for peer communication and leader election.

![Deployment](DistributedCoordinatorED_deployment.png)

Figure 3 Deployment view of Distributed Coordinator ED

To deploy the Service, refer to the [Deployment Section](#deployment), which:

* explains how to get started using the Distributed Coordinator ED Service in
 the supported environments.
* specifies configuration options for starting the Distributed Coordinator ED
 docker container.

If problems occur when using the service, refer to the
[Troubleshooting section](#troubleshooting).

### Dimensioning and Characteristics

#### Dimensioning

To handle dimensioning configuration at deployment time,
refer to the [Deployment section](#deployment).

#### Scaling

The *Distributed Coordinator ED* Service supports manual scaling.

It is recommended to have an odd number of replicas in the
*Distributed Coordinator ED* cluster.
An odd-size cluster tolerates the same number of failures as an even-size
cluster but with fewer nodes.
While larger cluster provides better fault tolerance the write performance
reduces since data needs
to be replicated to more machines.

| Scaling Supported (Yes/No) | Minimum number of instances | Maximum number of recommended instances |
| -------------------------- | --------------------------- | --------------------------------------- |
| Yes                        | 1                           | 7                                       |

#### Resilience

When fewer than half of the followers fail, the *Distributed Coordinator ED*
cluster can still accept requests and make progress without any major
disruption. For example, two follower failures will not affect the operations
of a five member *Distributed Coordinator ED* cluster.

When a leader fails, the *Distributed Coordinator ED* cluster automatically
elects a new leader. The election does not happen instantly once the leader
 fails. It takes about an election timeout to elect a new
leader since the failure detection model is timeout based.

During the leader election the cluster cannot process any writes. Write
 requests sent during the election are
queued for processing until a new leader is elected.

When the majority members of the cluster fail, the *Distributed Coordinator ED*
cluster fails and cannot accept more writes. The *Distributed Coordinator ED*
cluster can only recover from a majority
failure once the majority of members become available.

#### Upgrade - In Service Software Upgrade

The *Distributed Coordinator ED* Service supports upgrade without loss of data
or service downtime.
This is achieved by:

* Using Persistent Volumes
* Having multiple Replicates
* Rolling Upgrade

#### Characteristics Compliance

This chapter gives an overview of the supported characteristics.

| Characteristics| Slogan                 | Component Description | Compliance |
| -------------- | ---------------------- | --------------------- | ---------- |
| CHAR.DM.DC.001 | Start Up time          | The component shall be able to start up and provide service within 60 seconds.  | Compliant |
| CHAR.DM.DC.002 | In-Service Upgrade     | The component shall support in-service upgrade to minimize the impact on any ongoing traffic toward the component.  | Compliant |
| CHAR.DM.DC.003 | Upgrade time           | The component shall be able to do an upgrade of an instance within 20 seconds.  | Partly Compliant, upgrading a single instance can take up to 60 seconds. |
| CHAR.DM.DC.004 | Rollback Time          | The component shall be able to do a rollback of an instance within 20 seconds.  | Partly Compliant, rolling back a single instance can take up to 60 seconds. |
| CHAR.DM.DC.005 | High Availability      | The component shall support high availability through multiple instances.  | Compliant |
| CHAR.DM.DC.006 | Scaling                | Scaling more instances can only increase the resiliency and read performance. Scale too many component instances(more than 5) may impact the write performance due to the difficult on reach consensus.  | Compliant
| CHAR.DM.DC.007 | Throughput             | The component shall be able to handle 100 acquire/release distributed lock requests per second.  The component shall be able to handle 100 leader election requests per second. | Compliant |
| CHAR.DM.DC.008 | Latency                | One component instance shall be able to handle a acquire/release distributed lock requests within 0.1 seconds in 95% cases without consider the network latency between client and the component.  One component instance shall be able to handle a leader election requests within 3 seconds in 95% cases without consider the network latency between client and the component. Note: It is based on the sequential consistency as different consistency level can impact the performance result. | Compliant |
| CHAR.DM.DC.009 | Failure recovery       | One component instance shall be able recover from failure within 20 seconds.  | Compliant |
| CHAR.DM.DC.010 | Atomicity              | The component shall be able to guarantee the atomicity of distributed lock or leader update. Update of them either succeed or fail, there is no partial result.  | Compliant |
| CHAR.DM.DC.011 | Sequential Consistency | The component shall be able to guarantee the updates from one client shall be applied in the order as they were sent.  | Compliant |
| CHAR.DM.DC.012 | Reliability            | The component shall be able to persist the update when it has been applied.  | Compliant |

## Deployment

This section describes the operational procedures for how to deploy and upgrade
the *Distributed Coordinator ED* Service in a Kubernetes environment with Helm.
It also covers hardening guidelines to consider when deploying this service.

This document describes the operational procedures for how to deploy, upgrade
and scale the *Distributed Coordinator ED* Service in a Kubernetes environment
with Helm. It also covers security guidelines to consider when deploying this
service.

For a *Distributed Coordinator ED* function overview and deployment overview,
refer to the [Service Overview](#overview).

### Prerequisites

* A running Kubernetes environment
* Some knowledge of the Kubernetes environment, including the networking details
* Access rights to deploy and manage workloads
* Availability of the `kubectl` CLI tool with correct authentication details.
  Contact the Kubernetes System Admin if needed.
* Availability of the `helm` package
* It is recommended to have the same version for both the client and the server
  (tiller)
* Availability of Helm charts and Docker images for the service and all
  dependent services
* The service supports Block based storage (*erikube-rbd*, *erikube-cinder*,
  *rook-block* and *network-block* storage classes). The service does not
  support File based storage (NFS). The Storage class should satisfy the
  performance recommendations mentioned in "ETCD Disk and network latency".

### Custom Resource Definition (CRD) Deployment

Custom Resource Definitions (CRD) are cluster-wide resources which must be
installed prior to the Generic Service deployment.  The service that requires
the latest CRD charts version set which CRD charts version to use in the
deployment.

>Note! The release name chosen for the CRD charts in the K8s deployment must be
kept and cannot be changed later.

Helm ALWAYS requires a namespace to deploy a chart and the namespace to be used
for the same per-service CRDs chart must be created before the CRDs charts are
loaded.

>Note! The upgrade of the CRDs must be done before deploying a service that
requires additional CRDs or a CRD version newer than the one already deployed on
the K8s cluster.

The CRD chart are deployed as follows:

1. Download the latest applicable CRD charts files from the helm charts
repository.

1. Create the `namespace` where CRD charts will be deployed in case it doesn't
already exist. This step is only done once on the K8s cluster.

    ```
    kubectl create namespace <NAMESPACE-FOR-CRDs>
    ```

1. Deploy the CRD using `helm upgrade` command:

    ```
    helm upgrade --install <release name> <CRD chart with version> --namespace <NAMESPACE-FOR-CRDs>
    ```

1. Validate the CRD installation with the `helm ls` command:

    ```
    helm ls -a
    ```

In the table locate the entry for the `<release name>`,  validate the
`NAMESPACE` value and check that the STATUS is set to `deployed`.
When the output is validated continue with the installation of the helm charts.

### Deployment in a Kubernetes Environment Using Helm

This section describes how to deploy the service in Kubernetes using Helm and
the `kubectl` CLI client.  Helm is a package manager for Kubernetes that
streamlines the installation and management of Kubernetes applications.

#### Preparation

##### Ensure Helm Chart and Docker Image Access

Use the following helm chart repository link:

[https://arm.sero.gic.ericsson.se/artifactory/proj-adp-gs-released-helm](https://arm.sero.gic.ericsson.se/artifactory/proj-adp-gs-released-helm)

### Pre-Deployment Checks for *Distributed Coordinator ED*

Ensure the following:

* The `<release name>` is not used already in the corresponding cluster.  Use
  `helm list` command to list the existing deployments (and delete previous
deployment with the corresponding `<release name>` if needed).

* The same namespace is used for all deployments.

* A secret named `eric-data-distributed-coordinator-creds` exists in the
  namespace and has a key named `etcdpasswd` with the root password for etcd
(base64 encoded)(Note: applicable for only non-TLS deployment)

#### Helm Chart Installations of Dependent Services

*Distributed Coordinator ED* depends on *Key Management Service* and *Service
Identity Provider TLS*.

For instructions on how to install *Key Management Service* see the [*Key
Management Service* -Deployment Guide][KMS].

*Note:* The *Key Management Service* needs to be installed with `--set
persistence.type=etcd` in order to persist its data in *Distributed Coordinator
ED*.

For instructions on how to install *Service Identity Provider for TLS* see the
[*Service Identity Provider for TLS* - Deployment Guide][SIP-TLS].

Optionally, you can choose to deploy *Distributed Coordinator ED BrAgent* that
will, alongside an instance of *Backup and Restore Orchestrator* Service, be
responsible for data recovery on *Distributed Coordinator ED*.

Refer to the [Backup and Restore Operations Guide for CM Yang Provider][CMYP]
for more information.

*Log Transformer* needs to be installed if log streaming feature
is enabled so that Log Shipper side car container can stream the logs.
See `log.streamingMethod` parameter.

### Helm Chart Installation of the Distributed Coordinator ED Service

Users can override the default values provided in the values.yaml template of
the helm chart.  The recommended parameters to override are listed in the
following section: [Configuration Parameters](#configuration-parameters).

#### Deploy the Distributed Coordinator ED Service

1. Create a Kubernetes secret containing the *Distributed Coordinator ED* root
password.(Note: applicable for only non-TLS deployment)

    ```
    kubectl create secret generic eric-data-distributed-coordinator-creds --namespace <NAMESPACE> --from-literal=etcdpasswd=$(echo -n "<PASSWORD>" | base64)
    ```

1. Deploy the *Distributed Coordinator ED* Service by issuing the following
`helm` command.

    ```
    helm install <RELEASE_NAME> <CHART_REFERENCE> --namespace <NAMESPACE>
    ```

    The variables specified in the command are as follows:

    `<CHART_REFERENCE>`: A path to a packaged chart, a path to an unpacked chart
directory or a URL.

    `<RELEASE_NAME>`: String value, a name to identify and manage your helm
chart.

    `<NAMESPACE>`: String value, a name to be used dedicated by the user for
deploying own helm charts.

Here is an example of the `helm install` command:

  ```
  helm install eric-data-distributed-coordinator-ed https://arm.sero.gic.ericsson.se/artifactory/proj-adp-gs-all-helm/eric-data-distributed-coordinator-ed/eric-data-distributed-coordinator-ed-1.0.0-999.tgz  --namespace test-deployment-namespace
  ```

#### Verify the Availability of the Distributed Coordinator ED Service

To check for a successful deployment of the *Distributed Coordinator ED*
Service, do the following:

1. Check if the helm chart is installed with the provided release name and in
   the related namespace using the `helm ls` command.

    ```
    helm ls <RELEASE_NAME>
    ```

    Output:

    ```
    NAME        eric-data-distributed-coordinator-ed
    REVISION    1
    UPDATED     Thu Jan 31 15:33:28 2019
    STATUS      DEPLOYED
    CHART       eric-data-distributed-coordinator-ed-1.0.0-999
    NAMESPACE   test-deployment-namespace
    ```

    The chart status should be `DEPLOYED`.

1. Get the status of the installed helm chart to ensure that it is deployed and
   that its pods are running:

    ```
    helm status <RELEASE_NAME>
    ```

    Output:

    ```
    ==> v1/Pod(related)
    NAME                                    READY  STATUS   RESTARTS
    eric-data-distributed-coordinator-ed-0  1/1    Running  0
    eric-data-distributed-coordinator-ed-1  1/1    Running  0
    eric-data-distributed-coordinator-ed-2  1/1    Running  0
    ```

    The chart status should be `DEPLOYED` and each of the  pods should be in
status `Running`.

1. Verify that all the *Distributed Coordinator ED* pods have joined the
   cluster.

    ```
    kubectl exec -it eric-data-distributed-coordinator-ed-0 -c dced -n test-deployment-namespace -- etcdctl member list
    ```

    Example Output:

    ```
    2ffce4809b3a49, started, eric-data-distributed-coordinator-ed-1, https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed-peer.test-deployment-namespace:2380, https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed.test-deployment-namespace:2379
    3a9f9f910e30d13e, started, eric-data-distributed-coordinator-ed-0, https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed-peer.test-deployment-namespace:2380, https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed.test-deployment-namespace:2379
    da1700a56b1bcb33, started, eric-data-distributed-coordinator-ed-2, https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed-peer.test-deployment-namespace:2380, https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed.test-deployment-namespace:2379
    ```

    Each replica should be listed in the output and the status should be
`started`.

1. Create an example key `myKey` with value `myValue`.

    ```
    kubectl exec -it eric-data-distributed-coordinator-ed-0 -c dced -n test-deployment-namespace --  etcdctl put myKey myValue
    ```

    Example Output:

    ```
    OK
    ```

1. Read the value of key `myKey`.

    ```
    kubectl exec -it eric-data-distributed-coordinator-ed-0 -c dced -n test-deployment-namespace --  etcdctl get myKey
    ```

    Example Output:

    ```
    myKey
    myValue
    ```

### Configuration Parameters

The *Distributed Coordinator ED* Service uses a configuration interface based on
environment variables that are defined in the helm chart.  You can set these
variables during the deployment of the helm chart (using the --set argument).
Parameters mandatory to set at deployment time are separately listed below as
well as the optional parameters.

#### Mandatory Configuration Parameters

*Distributed Coordinator ED* has no mandatory parameters.

### Optional Configuration Parameters

These parameters are not mandatory. If not explicitly set
(using the --set argument), the default values provided
in the helm chart are used.

| Parameter | Description | Default value |
| --------- | ----------- | ------------- |
| global.registry.url | Global image registry.  | "armdocker.rnd.ericsson.se" |
| global.registry.repoPath | Sets the repository path relative to the registry url not including the image name and tag. | "" |
| global.internalIPFamily | Used to specify which IP address family the `Service` belongs to in dual-stack cluster. Valid values: `IPv4`, `IPv6`. Specifying IP Family (as `IPv4` or `IPv6`) will set `ipFamilyPolicy` as `SingleStack`. Not specifying the IP Family will set `ipFamilyPolicy` as `PreferDualStack`. **NOTE**: Upgrade and Rollback considerations should be followed as per the guidelines: [Internal services exposed within K8s cluster (Dual stack design rules considerations)](https://eteamspace.internal.ericsson.com/display/AA/Connectivity+Considerations+and+Guidelines#ConnectivityConsiderationsandGuidelines-Internalservices(exposedwithinK8scluster)). | "" |
| global.pullSecret | The Secret resource name to use for authenticating towards docker registry when pulling the image.  | "" |
| global.timezone | Timezone setting.  | UTC |
| global.nodeSelector.dced |Global setting for *nodeSelector* .*nodeSelector* is a map of key-value pairs to schedule pods on labeled nodes. For example use label disktype=ssd to assign pods to nodes with this label.  | empty |
| global.nodeSelector.brAgent | Global setting for *nodeSelector* . *nodeSelector* is a map of key-value pairs to schedule pods on labeled nodes. For example use label disktype=ssd to assign pods to nodes with this label.  | empty |
| global.fsGroup.manual | The fsGroup creates a new group, assigns the service as part of the group, sets the new group as the owner of the shared data, and finally sets read/write group access to the data. | 10000 |
| global.networkPolicy.enabled | Global configuration parameter to enable/disable Network Policy | false |
| global.fsGroup.namespace | The namespace default fsGroup can be used | "" |
| global.podSecurityContext.supplementalGroups | Sets the GID value(s) for volume data that is used by the services (Note. The values are ammended to the local values) | null |
| podSecurityContext.supplementalGroups | Sets the GID value(s) for volume data that is used by the services | null |
| global.securityPolicy.rolekind | RoleRef kind for the eric-data-distributed-coordinator-ed-security-policy RoleBinding resource. Possible values are: "ClusterRole", "Role" and "". Defaults to "", which means this RoleBinding resource is not created. | "" |
| global.adpBR.broServiceName | Back up orchestrator service config that agent communicates with | eric-ctrl-bro |
| global.hooklauncher.executor|If set to `service`, hooks for handling upgrades and rollbacks will be executed by this chart. If set to `integration`, all hooks for handling upgrades and rollbacks will be executed by Hooklauncher(s) in the defined integration chart(s) (see `executorCharts`). | service |
| global.hooklauncher.executorCharts | If `global.hooklauncher.executor` is set to `integration`, the integration chart names can be set in this parameter as an array that should run the Hooklauncher jobs rendering their subchart trees and taking care of all subchart hook execution. | [] |
| global.security.tls.enabled | Enable tls communication by using certificates from SIP-TLS, has the higher precedence and overrides local. | "true" |
| global.security.tls.trustedInternalRootCa.secret | The secret holding the public certificate bundle of the root CA | eric-sec-sip-tls-trusted-root-cert |
| global.tolerations |  Tolerations to influence scheduling decisions made by Kubernetes scheduler for pods | [] |
| global.logShipper.deployment.model | Global parameter for choosing logshipper deployment model. Set to "static" for static deployment model. Possible values are: "static" and "". | "" |
| productInfo.rstate | R-State of the product. R State should match helm chart version (For example: 3.1.0 has the minor version 1, thus the R-State is R2A) | _the RState of this release_ |
| pods.dced.replicas | The number of pods in the *Distributed Coordinator ED*. **Deprecated**, would be removed soon  | 3 |
| pods.dced.replicaCount | The number of pods in the *Distributed Coordinator ED*.  | 3 |
| labels | Additional labels allow a list of key/values to be appended to the list of labels of the resource object. | empty |
| topologySpreadConstraints.dced | Specifies how DCED pods should be spread among the given topology | [] |
| tolerations.dced | Tolerations to influence scheduling decisions made by kubernetes scheduler for main application pods | [] |
| tolerations.brAgent | Tolerations to influence scheduling decisions made by kubernetes scheduler for brAgent pod | See _Note_ ^(1)^ below |
| tolerations.hooklauncher | Tolerations to influence scheduling decisions made by kubernetes scheduler for hooklauncher job. | [] |
| terminationGracePeriodSeconds.dced | Wait time after sending the shutdown signal to the dced pod before it is force deleted. This should never be set to zero. | 30 |
| terminationGracePeriodSeconds.brAgent | Wait time after sending the shutdown signal to the brAgent pod before it is force deleted. This should never be set to zero. | 30 |
| networkPolicy.enabled | Service level parameter to enable/disable Network Policy. `networkPolicy.enabled` is only applicable when `global.networkPolicy.enabled` is `true` | true |
| podDisruptionBudget | Pod Disruption Budget configuration required during voluntary disruption. See [Configure PodDisruptionBudget](#configure-poddisruptionbudget). | minAvailable: "51%" |
| updateStrategy.type | Update Strategy.  | "RollingUpdate" |
| updateStrategy.rollingUpdate.maxUnavailable | Specifies the maximum number of Pods that can be unavailable during the update process | 25% |
| updateStrategy.rollingUpdate.maxSurge | Specifies the maximum number of Pods that can be created over the desired number of Pod | 25% |
| imageCredentials.dced.registry.url | *Distributed Coordinator ED* Docker registry url. Overrides global.registry.url.  | "" |
| imageCredentials.dced.repoPath | *Distributed Coordinator ED* Docker repository path.  | _The docker repository path_ |
| imageCredentials.dced. registry. imagePullPolicy | *Distributed Coordinator ED* container images pull Policy. | "IfNotPresent" |
| imageCredentials.brAgent.registry.url | *Distributed Coordinator ED brAgent* Docker registry url. Overrides global.registry.url.  | "" |
| imageCredentials.brAgent.repoPath | *Distributed Coordinator ED brAgent* Docker repository path.  | _The docker repository path_ |
| imageCredentials.brAgent. registry. imagePullPolicy | *Distributed Coordinator ED brAgent* container images pull Policy. | "IfNotPresent" |
| imageCredentials.pullSecret | Image pull secret. Overrides global.pullSecret.  | "" |
| imageCredentials.metricsexporter.registry.imagePullPolicy | *Distributed Coordinator ED metricsexporter* container images pull Policy. | "IfNotPresent" |
| imageCredentials.metricsexporter.registry.url | Docker registry url for metricsexporter. Overrides global.registry.url. | "" |
| imageCredentials.metricsexporter.repoPath | Docker repository path for metricsexporter. | aia_releases |
| imageCredentials.hooklauncher.registry.url | Docker registry url for hooklauncher job. Overrides global pullSecret. | "" |
| imageCredentials.hooklauncher.registry.imagePullPolicy | *Distributed Coordinator ED hooklauncher* images pull Policy. | "" |
| imageCredentials.hooklauncher.repoPath | Docker repository path for hooklauncher job. | "" |
| imageCredentials.repoPath | Overrides the default repository path and global.registry.repoPath if set. | "" |
| images.dced.name | Docker image name. **Deprecated**, will be removed soon. | "eric-data-distributed-coordinator-ed" |
| images.dced.tag | Docker image tag. **Deprecated**, will be removed soon. | _The current image tag generated at release, e.g. 1.0.0-999_ |
| images.brAgent.name | Docker image name of the BrAgent image. **Deprecated**, will be removed soon. | eric-data-distributed-coordinator-ed-bragent |
| images.brAgent.tag | Docker image tag. **Deprecated**, will be removed soon. | The current image tag generated at release, e.g. 1.0.0-999 |
| resources.init.requests.cpu | This is the min CPU setting at startup | "200m" |
| resources.init.requests.memory | This is the min Memory setting at startup | "200Mi" |
| resources.init.requests.ephemeral-storage | This is the min Ephemeral-storage setting at startup. . By default, no ephemeral-storage value will be specified. | "" |
| resources.init.limits.cpu | This is the maximum CPU setting that can be requested | "500m" |
| resources.init.limits.memory | This is the max Memory setting that can be requested | "500Mi" |
| resources.init.limits.ephemeral-storage | This is the max Ephemeral-storage setting at startup. By default, no ephemeral-storage value will be specified. **Note:** Please notice that incorrect ephemeral-storage may cause unexpected pod evictions. | "" |
| resources.dced.requests.cpu | This is the min CPU setting at startup | "400m" |
| resources.dced.requests.memory | This is the min Memory setting at startup | "400Mi" |
| resources.dced.requests.ephemeral-storage | This is the min Ephemeral-storage setting at startup. By default, no ephemeral-storage value will be specified. | "" |
| resources.dced.limits.cpu | This the maximum CPU setting that can be requested | "1" |
| resources.dced.limits.memory | This is the max Memory setting that can be requested | "1Gi" |
| resources.dced.limits.ephemeral-storage | This is the max Ephemeral-storage setting that can be requested. By default, no ephemeral-storage value will be specified. **Note:** Please notice that incorrect ephemeral-storage may cause unexpected pod evictions. | "" |
| resources.brAgent.requests.cpu | This is the min CPU setting at startup | "400m" |
| resources.brAgent.requests.memory | This is the min Memory setting at startup | "400Mi" |
| resources.brAgent.requests.ephemeral-storage | This is the min Memory setting at startup. By default, no ephemeral-storage value will be specified. | "" |
| resources.brAgent.limits.cpu | This the maximum CPU setting that can be requested | "1" |
| resources.brAgent.limits.memory | This is the max Memory setting that can be requested | "2Gi" |
| resources.brAgent.jvm.initialMemoryAllocationPercentage | Sets the initial amount of memory that the JVM heap can use in relation to the container memory limit | `50` |
| resources.brAgent.jvm.smallMemoryAllocationMaxPercentage | Sets the maximum amount of memory that the JVM heap can use in relation to the container memory limit when the container memory limit is less than 1.3 GB | `70` |
| resources.brAgent.jvm.largeMemoryAllocationMaxPercentage | Sets the maximum amount of memory that the JVM heap can use in relation to the container memory limit when the container memory limit is more than 1.3 GB | `50` |
| resources.brAgent.limits.ephemeral-storage | This is the max Memory setting that can be requested. By default, no ephemeral-storage value will be specified. **Note:** Please notice that incorrect ephemeral-storage may cause unexpected pod evictions. | "" |
| resources.metricsexporter.requests.cpu | Minimum cpu required at startup for Distributed Coordinator ED metricsexporter container | "100m" |
| resources.metricsexporter.limits.cpu | Maximum cpu that can be requested for Distributed Coordinator ED metricsexporter container | "200m" |
| resources.metricsexporter.requests.memory | Minimum memory required at startup for Distributed Coordinator ED metricsexporter container | "8Mi" |
| resources.metricsexporter.limits.memory | Maximum memory that can be requested for Distributed Coordinator ED metricsexporter container | "32Mi" |
| resources.metricsexporter.requests.ephemeral-storage | This is the min Memory setting at startup. By default, no ephemeral-storage value will be specified. | "" |
| resources.metricsexporter.limits.ephemeral-storage | This is the max Memory setting that can be requested. By default, no ephemeral-storage value will be specified. **Note:** Please notice that incorrect ephemeral-storage may cause unexpected pod evictions. | "" |
| resources.hooklauncher.requests.memory | Minimum memory required at startup for Distributed Coordinator ED hooklauncher job | "50Mi" |
| resources.hooklauncher.requests.cpu | Minimum cpu required at startup for Distributed Coordinator ED hooklauncher job | "20m" |
| resources.hooklauncher.requests.ephemeral-storage | This is the min Memory setting at startup. By default, no ephemeral-storage value will be specified. | "100Mi" |
| resources.hooklauncher.limits.memory | Maximum memory that can be requested for Distributed Coordinator ED hooklauncher job | "100Mi" |
| resources.hooklauncher.limits.cpu | Maximum cpu that can be requested for Distributed Coordinator ED hooklauncher job | "50m" |
| resources.hooklauncher.limits.ephemeral-storage | This is the max Memory setting that can be requested. By default, no ephemeral-storage value will be specified. **Note:** Please notice that incorrect ephemeral-storage may cause unexpected pod evictions. | "100Mi" |
| resources.logshipper.requests.cpu | This is the min CPU setting at startup | "50m" |
| resources.logshipper.requests.memory | This is the min Memory setting at startup | "50Mi" |
| resources.logshipper.requests.ephemeral-storage | This is the min Memory setting at startup. By default, no ephemeral-storage value will be specified. | "" |
| resources.logshipper.limits.cpu | This the maximum CPU setting that can be requested | "100m" |
| resources.logshipper.limits.memory | This is the max Memory setting that can be requested | "100Mi" |
| resources.logshipper.limits.ephemeral-storage | This is the max Memory setting that can be requested. By default, no ephemeral-storage value will be specified. **Note:** Please notice that incorrect ephemeral-storage may cause unexpected pod evictions. | "" |
| probes.dced.livenessProbe.initialDelaySeconds | The number of seconds that kubelet waits before performing the first health check probe. | 0 |
| probes.dced.livenessProbe.timeoutSeconds | The timeout for the health check. | 15 |
| probes.dced.livenessProbe.periodSeconds | The periodSeconds field specifies that the kubelet should perform a liveness probe every 10 seconds. **Note:** If this parameter probes.dced.livenessProbe.StrictLivenessProbe is set to true then set this parameter probes.dced.livenessProbe.periodSeconds to 45 seconds. | 10 |
| probes.dced.livenessProbe.failureThreshold | Liveness probe failure limit | 3 |
| probes.dced.livenessProbe.StrictLivenessProbe | Make it true to use strict logic for livenessprobe, supported values are [true,false] | false |
| probes.dced.readinessProbe.initialDelaySeconds | Number of seconds that kubelet waits before performing the first service availability check probe. | 0 |
| probes.dced.readinessProbe.timeoutSeconds | Timeout for the service availability check. | 15 |
| probes.dced.readinessProbe.periodSeconds | The periodSeconds field specifies that the kubelet should perform a readiness probe every 10 seconds | 10 |
| probes.dced.readinessProbe.failureThreshold | Readiness probe failure limit | 3 |
| probes.dced.readinessProbe.successThreshold | Readiness probe success limit | 1 |
| probes.dced.livenessProbe. EntrypointChecksNumber | Number of time entrypoint.sh will check for etcd process | 60 |
| probes.dced.livenessProbe. EntrypointRestartEtcd | True to restart etcd each time it dies. **Note:** If EntrypointRestartEtcd is set to false, restart of DCED pod is expected to reload the renewed or updated certificate and DCED pod should be running after the restart. | "true" |
| probes.dced.livenessProbe. EntrypointPipeTimeout | Timeout (seconds) for read function while reading the pipe | 5 |
| probes.dced.livenessProbe. EntrypointEtcdProcessInterval | Min time (seconds) before checking for etcd process | 5 |
| probes.dced.startupProbe. initialDelaySeconds | Number of seconds that kubelet waits before performing the first service availability check probe. The kubelet uses startup probes to know when a container application has started,it disables liveness and readiness checks until it succeeds, making sure those probes don't interfere with the application startup. *Note:* Available Kubernetes v1.20 onwards only. | 5 |
| probes.dced.startupProbe.timeoutSeconds | Timeout for the service availability check. *Note:* Available Kubernetes v1.20 onwards only | 15 |
| probes.dced.startupProbe.failureThreshold | When a probe fails, no of times before giving up. The container will have a maximum of `FailureThreshold` *`PeriodSeconds` to finish its startup.*Note:* Available Kubernetes v1.20 onwards only | 12 |
| probes.dced.startupProbe.periodSeconds | How often (in seconds) to perform the probe. *Note:* Available Kubernetes v1.20 onwards only | 10 |
| probes.metricsxporter.livenessProbe.initialDelaySeconds | The number of seconds that kubelet waits before performing the first health check probe.| 15 |
| probes.metricsexporter.livenessProbe.periodSeconds | The periodSeconds field specifies that the kubelet should perform a liveness probe every 15 seconds. | 15 |
| probes.metricsexporter.livenessProbe.timeoutSeconds | The timeout for the health check. (This is deprecated and will be removed in a future release.) | 15 |
| probes.metricsexporter.livenessProbe.failureThreshold | Liveness probe failure limit | 3 |
| probes.brAgent.livenessProbe.initialDelaySeconds | The number of seconds that kubelet waits before performing the first health check probe. | 15 |
| probes.brAgent.livenessProbe.timeoutSeconds | The timeout for the health check. | 15 |
| probes.brAgent.livenessProbe.periodSeconds | The periodSeconds field specifies that the kubelet should perform a liveness probe every 10 seconds | 10 |
| probes.brAgent.livenessProbe.failureThreshold | Liveness probe failure limit | 3 |
| pmServer.pmServiceName | Configure server name for mTLS communication between *Distributed Coordinator ED* and *PMServer*,It will be used to derive CA name by appending -ca | eric-pm-server |
| nodeSelector.dced | *nodeSelector* is a map of key-value pairs to schedule pods on labeled nodes. For example use label disktype=ssd to assign pods to nodes with this label.  | empty |
| nodeSelector.brAgent | *nodeSelector* is a map of key-value pairs to schedule pods on labeled nodes. For example use label disktype=ssd to assign pods to nodes with this label.  | empty |
| affinity.podAntiAffinity | sets inter-pod anti-affinity , values supported "soft" or "hard". | "hard" |
| service.endpoints.dced.tls.enforced | Enables either TLS or Plaintext communication. Values supported - "required" to enable TLS or "optional" to disable TLS i.e. enable Plaintext. (Note: For DCED to communicate with KMS, TLS must be enabled.) | required
| service.endpoints.dced.tls. verifyClientCertificate | Enable client cert authentication. Values supported - required & optional. (Note: This parameter is not completely supported. to disable client certificates on service level use service.endpoints.dced.certificates. client.clientCertAuth) | required
| service.endpoints.dced.metrics.enabled | Enables 'prometheus.io/scrape' annotation, if set to false, this annotation will exclude the pod from the scraping process. | true |
| enableNewScrapePattern | Enable new Prometheus scraping pattern. This parameter will be deprecated when support for the old pattern is dropped, Refer [enableNewScrapePattern](#enabling-new-scraping-pattern) | false |
| service.endpoints.dced.acls.adminSecret | Kubernetes secret resource that contains etcd root password data | eric-data-distributed-coordinator-creds |
| service.endpoints.dced.acls.rootPassword | Key inside kubernetes secret (see above) tha contains etcd root password | etcdpasswd |
| service.endpoints.dced.certificates.peer.autoTls | To use self-signed peer certificates or SIP-TLS CA signed certificates for TLS peer communications. Note: false value for this flag is not supported by KMS from KMS 7.0.0 to KMS 7.6.0. | "true" |
| service.endpoints.dced.certificates.client.clientCertAuth | enable client cert auth | "true" |
| service.endpoints.dced.certificates.client.commonName | the common name of the etcdctl-client-cert, *In case of a single TLS DCED deployment CN name to be left default - root.* - Due to dependency on SIP-TLS startup procedure, changing the CN from default root in case of a single DCED deployment is not supported. | root |
| service.endpoints.dced.certificates. peer.peerCertAuth | enable peer cert auth | "true" |
| service.endpoints.pm.tls. enforced | Enforce tls only communication or enable Plaintext. Values supported - required & optional. (Note: "optional" doesn't support Plaintext and TLS in parallel.It supports only Plaintext) | required
| service.endpoints.pm.tls. verifyClientCertificate | Enable client cert authentication. Values supported - required & optional. (Note: This parameter is not completely supported. To disable/enabled TLS on service level use - service.endpoints.pm.tls.enforced) | required
| service.endpoints.pm.tls.caSecretName |  Optional parameter to configure CA secret name from *PM Server* | "eric-pm-server-ca"
| securityPolicy.dced.rolename | RoleRef name of the eric-data-distributed-coordinator-ed-security-policy RoleBinding resource. | "eric-data-distributed-coordinator-ed" |
| securityPolicy.hooklauncher.rolename | Name of the security policy role that is bound to the service account for hooklauncher. An empty value will result in using the default value "eric-lcm-smart-helm-hooks". | "eric-lcm-smart-helm-hooks" |
| persistence.persistentVolumeClaim.size | Size of the persistent volume for each *Distributed Coordinator ED* and *Distributed Coordinator ED BrAgent*pod.  | "1Gi" |
| persistence.persistentVolumeClaim.storageClassName# | The storage class to use for the persistent volume. The Storage class should satisfy the performance recommendations mentioned in "ETCD Disk and network latency" | "network-block" |
| persistence.persistentVolumeClaim.enabled | Persistent Volume enable/disable switch.If set to false (disabled), pod uses ephemeral storage to store the data. | true |
| persistence.persistentVolumeClaim.mountPath | Mount path.  | "/data" |
| env.dced |Overwrites the default *Distributed Coordinator ED* broker configuration values. For examples, see next section. | See section below.
| broClientCA | Client CA Certificate provided by BRO for mTLS communication between *Distributed Coordinator ED* and BRO. |
| brAgent.replicas | The number of *Distributed Coordinator ED BrAgent* instances deployed. **Deprecated**, would be removed soon | 1 |
| brAgent.replicaCount | The number of *Distributed Coordinator ED BrAgent* instances deployed. | 1 |
| brAgent.brLabelValue |Name of the DCED Server Backup and Resore agent.  |"" |
| brAgent.backupTypeList |List of backup types (scope) that the agent participates in. Refer to BRO documentation for more details |"" |
| brAgent.maxInboundMessageSize | Sets the maximum message size allowed for a single gRPC frame for the bragent in bytes.  | 262144000 |
| brAgent.logLevel | log level for BrAgent.  | "INFO" |
| annotations | Annotations is a map of key-value pairs which allows users to add custom annotations to the existing list. For example, --set annotations.infoKey1=value1,annotations.infoKey2=value2  | empty |
| bandwidth.maxEgressRate | The maximum rate in megabit-per-second at which traffic can leave the DCED pod (Example: bandwidth.maxEgressRate: 10M for 10Mbps), default not set | empty |
| metricsexporter.enabled | Switch to enable/disable the metricsexporter.metricsexporter exports storage KPI related metrics and it will only be enabled if metrics.enabled is true and metricsexporter.enabled is also true | false |
| metricsexporter.port | metricsexporter port | 9087 |
| clusterDomain | The Kubernetes cluster domain that gets populated to Subject Alternative Name. | "cluster.local" |
| appArmorProfile.type | The AppArmor type for all containers ("unconfined", "runtime/default", "localhost", "") | "" |
| appArmorProfile.localhostProfile | Localhost profile name for all containers if type is localhost | "" |
| appArmorProfile.dced.type | The AppArmor type for dced container ("unconfined", "runtime/default", "localhost", "") | "" |
| appArmorProfile.dced.localhostProfile | Localhost profile name for dced container if type is localhost | "" |
| appArmorProfile.init.type | The AppArmor type for init container ("unconfined", "runtime/default", "localhost", "") | "" |
| appArmorProfile.init.localhostProfile | Localhost profile name for init container if type is localhost | "" |
| appArmorProfile.metricsexporter.type | The AppArmor type for metricsexporter container ("unconfined", "runtime/default", "localhost", "") | "" |
| appArmorProfile.metricsexporter.localhostProfile | Localhost profile name for metricsexporter container if type is localhost | "" |
| appArmorProfile.brAgent.type | The AppArmor type for brAgent container ("unconfined", "runtime/default", "localhost", "") | "" |
| appArmorProfile.brAgent.localhostProfile | Localhost profile name for brAgent container if type is localhost | "" |
| seccompProfile.type | The seccomp type for all containers ("Unconfined", "RuntimeDefault", "Localhost", "") | "" |
| seccompProfile.localhostProfile | Localhost profile name for all containers if type is Localhost | "" |
| seccompProfile.dced.type | The seccomp type for dced container ("Unconfined", "RuntimeDefault", "localhost", "") | "" |
| seccompProfile.dced.localhostProfile | Localhost profile name for dced container if type is localhost | "" |
| seccompProfile.init.type | The seccomp type for init container ("Unconfined", "RuntimeDefault", "localhost", "") | "" |
| seccompProfile.init.localhostProfile | Localhost profile name for init container if type is localhost | "" |
| seccompProfile.metricsexporter.type | The seccomp type for metricsexporter container ("Unconfined", "RuntimeDefault", "Localhost", "") | "" |
| seccompProfile.metricsexporter.localhostProfile | Localhost profile name for metricsexporter container if type is Localhost | "" |
| seccompProfile.brAgent.type | The seccomp type for brAgent container ("Unconfined", "RuntimeDefault", "localhost", "") | "" |
| seccompProfile.brAgent.localhostProfile | Localhost profile name for brAgent container if type is Localhost | "" |
| podPriority.eric-data-distributed-coordinator-ed.priorityClassName | PodPriority for eric-data-distributed-coordinator-ed pod (No priority is set by default). Fore more information, refer [Kubernetes Pod Priority and Preemption][PodPriority] | "" |
| podPriority.eric-data-distributed-coordinator-ed-agent.priorityClassName | PodPriority for eric-data-distributed-coordinator-ed-agent pod (No priority is set by default). Fore more information, refer [Kubernetes Pod Priority and Preemption][PodPriority] | "" |
| podPriority.hooklauncher.priorityClassName | PodPriority for hooklauncher job (No priority is set by default). Fore more information, refer [Kubernetes Pod Priority and Preemption][PodPriority] | "" |
| hooklauncher.cleanup | Hooklauncher to delete jobs and its pods after execution.Possible values are true, false and onSuccess | false |

(1): The default tolerations value for the BR agent pod:

```yaml
- key: node.kubernetes.io/not-ready
  operator: Exists
  effect: NoExecute
  tolerationSeconds: 0
- key: node.kubernetes.io/unreachable
  operator: Exists
  effect: NoExecute
  tolerationSeconds: 0
```

#### Configuration Parameters for applicationProperties

| Parameter              | Description                                                 | Default value |
| ---------------------- | ----------------------------------------------------------- | ------------- |
| brAgent.enabled        | Switch to enable/disable the agent.                         | false         |
| brAgent.backupFileName | Filename for the backup archive.                            | /sharedData/snapshot.txt   |
| dced.excluded.paths    | A comma separated list of key-value prefixes in a etcd host  that should not be stored during a backup operation and/or should not be written to during a restore.  Each list of key prefixes should be a complete/full path starting from the etcd root.  | `empty`       |
| dced.included.paths  | A comma separated list of key-value prefixes in a etcd host that should be stored during a backup operation and/or should be written to during a restore.  Each list of key prefixes should be a complete/full path starting from the etcd root.  |   `empty`      |
| dced.agent. restore.type | The user can choose how the *Distributed CoordinatorED BrAgent*  handles writing of key-value pairs, if present in the prefixes provided during *restore* action.  `overwrite`: *Distributed Coordinator ED BrAgent* will delete all existing key-value  pairs present in the `dced.included.paths` prefixes(except for the prefixes defined in  `dced.excluded.paths`) on *Distributed Coordinator ED* before restoring with the backup data.  `merge`: *Distributed Coordinator ED BrAgent* will push key-value pairs from the backup  to *Distributed Coordinator ED* while leaving untouched any existing key-value pairs  (on *Distributed Coordinator ED*) in the backup.  |  overwrite  |
| brAgent.dcedReadTimeout| Etcd read timeout value for brAgent in seconds.             | 50            |

#### Configure PodDisruptionBudget

The `podDisruptionBudget` parameter specifies the behavior of *Distributed CoordinatorED*
during voluntary disruption. *Distributed CoordinatorED* supports all available forms
of this parameter as what provided by Kubernetes, however only one of them
should be used. It is recommended to always keep more than half of Pods up and
running at any time so that the quorum can be maintained.

`podDisruptionBudget.minAvailable`: minimum available Pods that required to be
available during administration activities.

   ```
   podDisruptionBudget:
     minAvailable: "51%"
   ```

`podDisruptionBudget.maxUnavailable`: maximum unavailable Pods that can be
evicted during administration activities.

   ```
   podDisruptionBudget:
     maxUnavailable: 1
   ```

>Note! The PodDisruptionBudget object is not being generated if the
replicas is set to 1.

For further reference visit the [Kubernetes PodDisruptionBudget][PDB].

#### Configuration Parameters for LogShipper

These parameters are not mandatory, if not explicitly set,
the default values provided in the Helm chart are used.

Parameters defined by Distributed Coordinator ED that can be changed
(although it is not recommended to change them):

| Parameter | Description | Default |
|---|---|---|
| `logShipper.logLevel` | Override Helm chart's logLevel value for Fluent Bit. Supports `debug`, `info`, `warning`, `error`, and `critical`. | `info` |
| `logShipper.storage.path` | Path to mount volume for writing and reading logs. | `/logs` |
| `logShipper.storage.size` | Storage limit for shared volume. | `500Mi` |
| `logShipper.storage.medium` | Storage medium to be used. Options available: Memory or Ephemeral. When the value is set as Ephemeral, emptyDir volumes will be selected to setup tmpfs (RAM-backed filesystem), this will impact log producer memory dimensioning. Therefore proper dimensioning shall be done according to [Developer Guide Log Shipper Sidecar - sidecar dimensioning recommendations][logshipper-sidecar-dimensioning-recommendations] before changing the default value. | Ephemeral |
| `logShipper.output.logTransformer.host` | Kubernetes service name for accessing the Logstash host. This is used as an IP address and must be the same as the name given to the Logstash service in that Helm chart. | `eric-log-transformer` |
| `log.streamingMethod` | Sets the log streaming method. Supported values are "direct", "indirect", "dual". "indirect" sends stdout to infrastructure framework (e.g., kubernetes), while "direct" initializes a Log Shipper sidecar with direct log streaming to Log Transformer service, and dual performs both. (See separate table for all 'Log Shipper' parameters.) | null |
| `resources.logshipper.requests.cpu` | This is the min CPU required at startup, for `logshipper` container | "50m" |
| `resources.logshipper.requests.memory` | This is the min Memory required at startup, for `logshipper` container | "50Mi" |
| `resources.logshipper.requests.ephemeral-storage` | This is the min ephemeral-storage required at startup, for `logshipper` container. By default, no ephemeral-storage value will be specified. Please refer to [Low Footprint Sidecar Developer's Guide - Experimental Configuration Parameters][logshipper] | "" |
| `resources.logshipper.limits.cpu` | This the max CPU that can be requested, for `logshipper` container | "100m" |
| `resources.logshipper.limits.memory` | This is the max Memory that can be requested, for `logshipper` container | "100Mi" |
| `resources.logshipper.limits.ephemeral-storage` | This is the max ephemeral-storage that can be requested, for `logshipper` container. By default, no ephemeral-storage value will be specified. **Note:** Please notice that incorrect ephemeral-storage may cause unexpected pod evictions. Please refer to [Low Footprint Sidecar Developer's Guide - Experimental Configuration Parameters][logshipper] | "" |

For the complete list of Log Shipper's optional configuration parameters,
visit the [Low Footprint Sidecar Developer's Guide](logshipper).

##### Deployment of Distributed Coordinator ED with Log Shipper Sidecar

Log Shipper sidecar can be deployed either statically using DCED helm
chart or dynamically by using integration helm chart.

>**Note:**
>To deploy DCED with dynamic logshipper sidecar, please refer to
[Dynamic sidecar application integration guide](https://adp.ericsson.se/marketplace/log-shipper/documentation)
>To deploy DCED with static logshipper sidecar, set the parameter
`global.logShipper.deployment.model` as `static`.

`log.streamingMethod` or `global.log.streamingMethod` decides where
the logs should be sent to. `log.streamingMethod` will override the
value set in `global.log.streamingMethod`

Add `direct` or `dual` option to the `global.log.streamingMethod`
field in `values.yaml` of the interation helm chart(IHC)/helm chart
file to deploy with Log Shipper sidecar.

#### Environment variables

The `env.dced` value allows the overwriting of *Distributed Coordinator ED*
service environment variables. Further information about environment variables
can be found in the [CoreOS ETCD documentation][etcdconfig].
Note: `env.dced` is deprecated.

|Attribute Name |Description|Default value |
| --------------| ---------- | ---------------|
| ETCD_INITIAL_CLUSTER_TOKEN , ETCD_NAME , ETCDCTL_API , ETCD_DATA_DIR , ETCD_LISTEN_PEER_URLS , ETCD_LISTEN_CLIENT_URLS , ETCD_ADVERTISE_CLIENT_URLS , ETCD_INITIAL_ADVERTISE_PEER_URLS , ETCD_INITIAL_CLUSTER_STATE , ETCD_INITIAL_CLUSTER , ETCD_PEER_AUTO_TLS , ETCD_CLIENT_CERT_AUTH , ETCD_CERT_FILE , ETCD_TRUSTED_CA_FILE , ETCD_KEY_FILE | Do **NOT** specify any of these parameters in this section. These are internal parameters used by the chart. |
| env.dced.ETCD_LOG_LEVEL | Configures log level. Only supports debug, info, warn, error, panic, or fatal.  | "info" |
| env.dced.ETCD_LOGGER| Set to support for structured logging.  | "zap" |
| env.dced.ETCD_METRICS | Set level of detail for exported metrics, specify 'extensive' to include histogram metric.  | "basic" |
| env.dced.ETCD_MAX_SNAPSHOTS | Maximum number of snapshot files to retain (0 is unlimited) | 3 |
| env.dced.ETCD_MAX_WALS | Maximum number of wal files to retain (0 is unlimited) | 3 |
| env.dced.ETCD_QUOTA_BACKEND_BYTES | Raise alarm when backend size exceeds the given quota, give 256 MiB by default. see [Adjusting backend database size](#adjusting-backend-database-size) | 268435456 |
| env.dced.ETCD_AUTO_COMPACTION_MODE | Interpret 'auto-compaction-retention' one of: 'periodic', 'revision'. 'periodic' for duration based retention. 'revision' for revision number based retention.  | "revision" |
| env.dced.ETCD_AUTO_COMPACTION_RETENTION | Auto compaction retention for mvcc key value store in hour/or based on retention. 0 means disable auto compaction.  | 100 |
| env.dced.ETCD_HEARTBEAT_INTERVAL | The frequency in milliseconds with which the leader will notify followers that it is still the leader (For best practices should be set around round-trip time between members). | 100 |
| env.dced.ETCD_ELECTION_TIMEOUT | How long in milliseconds a follower node will go without hearing a heartbeat before attempting to become leader itself (For best practices should be set as 10 times the round-trip time between members). | 1000 |
| env.dced.ETCD_TLS_MIN | Sets the minimum TLS version supported by etcd. | TLS1.2 |
| env.dced.ETCD_TLS_MAX | Sets the maximum TLS version supported by etcd. If not set, the maximum version supported by Go will be used. | TLS1.3 |
| env.dced.DEFRAGMENT_ENABLE | Enable periodic defragmentation of storage space.  | "true" |
| env.dced.DEFRAGMENT_PERIODIC_INTERVAL | Defragments every set interval (minutes) if defragmentation is enabled .(default 60 min).  | 60 |
| env.dced.MONITOR_ALARM_INTERVAL | Delay between defragment and remove alarm (in minutes) once the NOSPACE alarm been handled.  | 5 |
| env.dced.DISARM_ALARM_PEER_INTERVAL | Monitor alarm list every set interval (in minutes).  | 6 |
| env.dced.ETCD_SNAPSHOT_COUNT | Number of committed transactions to trigger a snapshot to disk. This can be reduced if there are memory and/or disk constraints | 5000 |
| env.dced.GODEBUG | To enable TLSv1.3 support in ETCD-3.4.16, 3.5.3 and 3.5.5 by adding the GODEBUG environment variable. | tls13 = 1 |
| env.dced.DB_THRESHOLD_PERCENTAGE | Threshold percentage value of ETCD DB size to trigger compaction and defragmentation automatically. | 70 |

#### Adjusting backend database size

If the `persistence.persistentVolumeClaim.size` storage is changed from default
values, then the parameter `env.dced.ETCD_QUOTA_BACKEND_BYTES`
should be adjusted accordingly.
Ideally `env.dced.ETCD_QUOTA_BACKEND_BYTES` is set to 25% of the PVC Size,
50 % is reserved for internal backups (Snapshots) and remaining 25% is
left for defragmentation to occur.

This ratio for the backend size can be adjusted to be increased from 256 Mb to
a value suited to the use case, if PVC size cannot be adjusted.

This would raise the data base size threshold limit for the alarm to be raised
see - *Error:  etcdserver: mvcc: database space exceeded* under [Known-Issues](#known-issues)

Parameters should be set using the command :

```

helm install <RELEASE_NAME> <CHART_REFERENCE> --namespace <NAMESPACE> --set persistence.persistentVolumeClaim.size="4Gi" --set env.dced.ETCD_QUOTA_BACKEND_BYTES="1073741824"
```
>Note! The large integers like "1073741842" (value of ETCD_QUOTA_BACKEND_BYTES)
will get converted to scientific notation if not in quotes.
For eg:"1.073741824e+09" Always, wrap the value in quotes.

To avoid swapping or running out of memory, the machine should have at least as
much RAM to cover the quota. Also, the memory request and limits must be
adjusted accordingly. Please refer [Service-Dimensioning](#service-dimensioning)

### Anti Affinity

Pod anti-affinity policy is used to minimize the impact of individual node
failures on a service through a more even distribution of pods across nodes.
For DCED this feature is applicable per node type, meaning that 2 of the
same pod type such as "master" pods are prevented from being deployed together.
It is still perfectly fine for Kubernetes to schedule
e.g. a "master" and an "ingest" pod on the same worker node.

By default affinity.podAntiAffinity is set to hard which tells Kubernetes
not to deploy the same DCED pod type to the same Kubernetes worker node and an
application must ensure that enough eligible workers exist for any deployment.

If affinity.podAntiAffinity is set to soft, Kubernetes will not deploy the same
DCED pod type on the same Kubernetes worker node if possible, but will still
deploy e.g. 2 data pods on the same worker if no other
eligible workers are available.

### Service Dimensioning

The service provides by default resource request values and resource limit
values as part of the Helm chart.  These values correspond to a default size for
deployment of an instance.

This chapter gives guidance in how to do service dimensioning and how to change
the default values when needed.

### Override Default Dimensioning Configuration

If other values than the default resource request and default resource limit
values are preferred,they must be overridden at deployment time.

```
helm install <RELEASE_NAME> <CHART_REFERENCE> --namespace <NAMESPACE> --set <PARAMETER_NAME>=<PARAMETER_VALUE>
```

Here is an example of the `helm install`
command where resource requests and resource limits are set:

```
helm install eric-data-distributed-coordinator-ed adp_repo/eric-data-distributed-coordinator-ed --namespace test-deployment-namespace --set resources.dced.requests.memory=2Gi
```

#### Use Minimum Configuration per Service Instance

This chapter specifies the minimum recommended configuration per service
instance. If log shipper sidecar is enabled, the log shipper container will use
the default resources configuration.

| Resource(Kubernetes Workload) | Resource Request Memory | Resource Request CPU | Resource Limit Memory | Resource Limit CPU | Special Configurations |
|-------------------------------|-------------------------|----------------------|-----------------------|--------------------|------------------------|
| *init*                        | 150Mi                   | 100m                 | 250Mi                 | 200m               |                        |
| *dced*                        | 150Mi                   | 150m                 | 250Mi                 | 300m               |                        |
| *brAgent*                     | 400Mi                   | 100m                 | 400Mi                 | 200m               |resources.brAgent.jvm.initialMemoryAllocationPercentage: 50, resources.brAgent.jvm.smallMemoryAllocationMaxPercentage: 70, resources.brAgent.jvm.largeMemoryAllocationMaxPercentage: 50.|

To use minimum configuration, override the default values for resource requests
and resource limits in the helm chart at deployment time.

##### Traffic capacity for the minimum configuration

This table below shows the "supported traffic capacity for the recommended
minimum configuration".

>Note! The reference minimum configuration (traffic capacity and the resource
settings) depends on the target cluster characteristics.

| Interface Logical Name | Traffic Profile Description                                | Traffic Capacity                                        |
|------------------------|------------------------------------------------------------|---------------------------------------------------------|
| INT.DM.DC.LOCK         | Approximately request per second: (17.3 Put, 19 Range, 1.99 TXN, 8.93 Delete Range.) | Approximate avg latency time: (fsync called by WAL is about 3ms, commit called by backend is about 6ms, save called by snapshot is about 6ms.) |

Additional information:

1. Enabled features: TLS enabled.

1. Replica count: Single replica.

#### Use Maximum (Default) Configuration per Service Instance

The maximum recommended configuration per instance is provided as default in the
Helm chart.  Both Resource Request values and Resource Limit values are included
in the helm charts.

#### Hardware requirements as per the 3pp etcd

CPU and memory for DCED pods should be based on the estimated peak memory usage
and any additional overhead and differ from environment to environment.
This is the general approach, and we need to decide by adjusting the values and
repeating the testing until we achieve the desired stability and performance.
There are some recommendations regarding the CPU and memory configuration
based on the 3pp etcd documentation guidelines to follow:
[Hardware requirements tuning][HardwareGuide]
[HardwareGuide]: <https://etcd.io/docs/v3.5/op-guide/hardware/>

#### Ephemeral-Storage Dimensioning Configuration

Some application need additional storage
but don't care whether that data is stored persistently across restarts.
Ephemeral volumes are designed for these use cases.
Because volumes follow the Pod's lifetime
and get created and deleted along with the Pod,
Pods can be stopped and restarted
without being limited to where some persistent volume is available.
Under normal circumstances, we recommend
the following configuration.
We did not
provide a default value
, but we support the use of ephemeral volumes.
If you need to use it, please enable it in values.yaml.

 Resource Type (Kubernetes Service) | Recommendation Request Ephemeral-storage| Recommendation Limit Ephemeral-storage |
---|---|---|
*init* | 200Mi | 500Mi |
*dced* | 400Mi | 2Gi |
*brAgent* | 400Mi | 4Gi |

### Hardening

#### Hardening during product development

The service is by default pre-hardened. No additional hardening is required.
The following pre-hardening actions have been made:

* The service is built on a minimalistic container image with small footprint.
  Only the required libraries are included.
* The service utilizes a container optimized operating system (Common Base OS)
  and latest security patches are applied.
* The container goes through vulnerability scanning.
* The service is not exposed outside of the cluster.
* The internal interfaces are secured by default (TLS).
* Minimum Kubernetes privileges are given to the containers.
* The service is configured to the strict minimum of services and ports to
  minimize the attack surface.

#### Hardening during service delivery

The service is by default pre-hardened. No additional hardening is required.

#### Automated procedures and hardening scripts

The service is by default pre-hardened. No additional hardening is required.

#### References

[Kubernetes Security Design Rules][Security]
[Security]: <https://confluence.lmera.ericsson.se/pages/viewpage.action?spaceKey=AA&title=Kubernetes+Security+Design+Rules>

### Upgrade Procedure

**Note:** If any chart value is customized at upgrade time through the "--set"
option of the "helm upgrade" command, all other previously customized values
will be replaced with the ones included in the new version of the chart. To make
sure that any customized values are carried forward as part of the upgrade,
consider keeping a versioned list of such values. That list could be provided as
input to the upgrade command in order to be able to use the "--set" option
without side effects.

To upgrade the *Distributed Coordinator ED* Service after a new version becomes
available, run the `helm upgrade` command using the following syntax:

```
helm upgrade <NAMESPACE> <CHART_REFERENCE>
```

An upgrade can also be initiated by running an upgrade command
and specifying a deploymentTimestamp value:

```
helm upgrade <RELEASE_NAME> <CHART_REFERENCE> --set deploymentTimestamp=
<AN INTEGER VALUE>
```

This has the effect of forcing an upgrade to the specified version of
the chart.

While upgrading DCED from a version lower than 2.9.0 with "custom labels"
set to a higher version, manual intervention is required. Following steps
need to be performed manually.

Note: This manual intervention is only needed if DCED version is lower than
2.9.0 and custom labels are set during installation.

1. Delete a statefulset  (statefulset.apps/eric-data-distributed-coordinator-ed)
using following command.

    ```
    kubectl delete statefulsets <DCED statefulset name> -n <NAMESPACE> --cascade=false
    ```

1. Perform upgrade to DCED version 2.9.0 or higher.

    ```
    helm upgrade <RELEASE_NAME> <CHART_REFERENCE> -n <NAMESPACE>
    ```

### Rollback Procedure

To rollback The *Distributed Coordinator ED* Service to a previous version, run
the `helm rollback` command using the following syntax:

```
helm rollback <RELEASE> <REVISION>
```

### Rollback Procedure with Non-Rollbackable Change

**Note:**  In DCED version 3.0.0, its internal 3pp "etcd" is uplifted from
version 3.3.11 to 3.4.16, which introduces a non rollbackable change (NRC).
In DCED version 4.0.0, its internal 3pp "etcd" is uplifted from version 3.4.16
to 3.5.3, which introduces a non rollbackable change (NRC). During rollback from
any DCED version 3.0.0/4.0.0 or higher to any DCED version older than DCED
3.0.0/4.0.0, any 1 of the below procedures should be followed
otherwise DCED pods will not come up.

#### 1. Automated script for Rollback Procedure

1. Download the automated Rollback script onto the cluster.

    ```
    ~$ wget https://arm.sero.gic.ericsson.se/artifactory/proj-adp-eric-data-dced-scripts-generic-local/rollback.sh
    ```

1. Change the script from DOS to Unix and change mode of the script.

    ```
    ~$ dos2unix rollback.sh
    ~$ chmod 755 rollback.sh
    ```

1. -rev in the next command would be derived from this command.(i.e. -rev is 3)

    ```
    ~$ helm ls | grep distributed
    dc-etcd    dced         3               2022-07-26 17:39:20.112983566 +0530 +0530       deployed        eric-data-distributed-coordinator-ed-3.0.0+9
    ```

1. -rev should be the revision to which you want to rollback. Refer to above command.

    ```
    ~$ sh rollback.sh -n <NAMESPACE> -rn <RELEASE_NAME> -rev <REVISION>
    ```

#### 2. Manual Rollback procedure using "helm upgrade" command

The manual rollback procedure can be performed using "helm upgrade"
command. The following steps can be followed to
achieve the manual rollback.

Step 1: Scale down to one pod.

Execute steps 1.1 to 1.3 for n time(s),
where n = Total number of DCED replicas - 1.
e.g. If there are 3 DCED replicas then execute steps 1.1 to 1.3 for 2 times.

Step 1.1: Remove the last member from the Distributed Coordinator ED cluster

```
NAMESPACE=<your namespace>
kubectl exec -it eric-data-distributed-coordinator-ed-0 -c dced -n $NAMESPACE -- bash -c 'etcdctl member remove $(etcdctl member list | sort -Vk3 | tail -n 1 | cut -d, -f1 )'

```
Step 1.2: Scale down the DCED StatefulSet.

```
kubectl scale statefulset.apps/eric-data-distributed-coordinator-ed -n $NAMESPACE --replicas=<current replicas less 1>
```

Step 1.3: Delete corresponding PVC

```
kubectl delete pvc `kubectl get pvc -n $NAMESPACE --sort-by='{.metadata.name}' | grep data-eric-data-distributed-coordinator-ed | tail -n1 | cut -d' ' -f 1` -n $NAMESPACE

```
Step 2: Take the snapshot in DCED pod-0.

```

kubectl exec eric-data-distributed-coordinator-ed-0 -c dced -n $NAMESPACE  -- mkdir -p /data/snapshot

kubectl exec eric-data-distributed-coordinator-ed-0 -c dced -n $NAMESPACE  -- etcdctl snapshot save /data/snapshot/backup.db
```

Step 3: Rollback to previous DCED version with 1 replica

If doing rollback to DCED version 2.3.0 or higher then use below property

```
pods.dced.replicas=1
```

If doing rollback to DCED version older than 2.3.0 then use below property

```
pods.etcd.replicas=1
```

```
helm upgrade <RELEASE_NAME> <OLDER_CHART_REFERENCE> -n <NAMESPACE> --set PROPERTY

Note: PROPERTY should be either pods.etcd.replicas=1 OR pods.dced.replicas=1 as explained above.
OLDER_CHART_REFERENCE - This refers to the Helm chart of the older DCED version to which user wants to rollback.
After executing Step 3, in DCED pod logs we can see below message

etcdserver/membership: cluster cannot be downgraded (current version: 3.3.11 is lower than determined cluster version: 3.4).

This message is expected in DCED logs at the time of downgrading DCED from 3.0.0 or higher to any DCED version older than DCED 3.0.0.
```
Step 4: Restore snapshot

```
#Get inside DCED container
kubectl exec -it eric-data-distributed-coordinator-ed-0 -c `kubectl get pods eric-data-distributed-coordinator-ed-0 -o jsonpath='{.spec.containers[*].name}' -n $NAMESPACE | tr " " "\n" | egrep "etcd|dced"` -n $NAMESPACE -- bash

rm -rf ${ETCD_DATA_DIR}/restore_data
mkdir -p ${ETCD_DATA_DIR}/member/snap

#Run snapshot restore command
/usr/local/bin/etcdctl snapshot restore ${ETCD_DATA_DIR}/snapshot/backup.db --name ${HOSTNAME} --initial-cluster ${HOSTNAME}=${ETCD_INITIAL_ADVERTISE_PEER_URLS} --initial-advertise-peer-urls ${ETCD_INITIAL_ADVERTISE_PEER_URLS} --data-dir=${ETCD_DATA_DIR}/restore_data

#Kill etcd process and then wait for 2 seconds
pkill --exact etcd
#Note: After executing the above command, if the control comes out of the container, then re-login into the container.
sleep 2

#Delete older wal and snap file
rm -f ${ETCD_DATA_DIR}/member/wal/*.wal
rm -f ${ETCD_DATA_DIR}/member/snap/*snap

#Copy member directory from backup to /data
cp -Rf ${ETCD_DATA_DIR}/restore_data/member ${ETCD_DATA_DIR}
rm ${ETCD_DATA_DIR}/snapshot/backup.db
exit

```

Step 5: Delete DCED POD-0

```
kubectl delete pod eric-data-distributed-coordinator-ed-0 -n $NAMESPACE
```

Step 6: Rollback again to previous DCED version with expected replicas.

If doing rollback to version DCED 2.3.0 or higher then use below property

```
pods.dced.replicas=<expected replicas>
```

If doing rollback to DCED version older than 2.3.0 then use below property

```
pods.etcd.replicas=<expected replicas>
```

```
helm upgrade <RELEASE_NAME> <OLDER_CHART_REFERENCE> -n <NAMESPACE> --set PROPERTY

Note: PROPERTY should be either pods.etcd.replicas=<expected replicas> OR pods.dced.replicas=<expected replicas> as explained above.
OLDER_CHART_REFERENCE - This refers to the Helm chart of the older DCED version to which user wants to rollback.
```
Note: The above manual rollback procedure would take around 10 minutes.
For this duration DCED service would be unavailable to serve the traffic.

#### 3.Automated Rollback procedure using "helm upgrade" command

1. Download pre_rollback and post_rollback_upg scripts onto the cluster.

    ```
    ~$ wget https://arm.sero.gic.ericsson.se/artifactory/proj-adp-eric-data-dced-scripts-generic-local/pre_rollback.sh https://arm.sero.gic.ericsson.se/artifactory/proj-adp-eric-data-dced-scripts-generic-local/post_rollback_upg.sh
    ```

1. Change the scripts from DOS to Unix and change mode of the scripts.

    ```
    ~$ dos2unix pre_rollback.sh post_rollback_upg.sh
    ~$ chmod 755 pre_rollback.sh post_rollback_upg.sh
    ```

1. Run the pre_rollback script by using the below command:

    ```
    ~$ sh pre_rollback.sh -n <NAMESPACE> -rn <RELEASE_NAME>
    ```

1. After running the pre_rollback script, open a new terminal
   and monitor the DCED pod until it is in running state
   by using below command. It is visible after triggering
   Helm upgrade or upgrade in EVNFM. Once it has rolled
   back to major version 3.x.x or 2.x.x, go to step 6
   to run post_rollback_upg script.

    ```
    ~$ watch -n 2 "kubectl get pod eric-data-distributed-coordinator-ed-1 --namespace=<NAMESPACE> -o=jsonpath='{.metadata.labels.app\.kubernetes\.io/version}' 2>&1 | tr -d '\"'"
    ```

1. Start the application rollback or deployment rollback through EVNFM.

    ```
    ~$ helm upgrade <RELEASE_NAME> <OLDER_CHART_REFERENCE> --timeout <time> -n <NAMESPACE> --set PROPERTY
    ```
    If doing rollback to version DCED 2.3.0 or higher then use below property

    ```
    pods.dced.replicas=<expected replicas>
    ```

    If doing rollback to DCED version older than 2.3.0 then use below property

    ```
    pods.etcd.replicas=<expected replicas>
    ```

    ```
    OLDER_CHART_REFERENCE - This refers to the Helm chart of the older DCED version to which user wants to rollback.
    ```

1. Once it has rolled back to major version 3.x.x or 2.x.x,
run the post_rollback_upg script by using below command:

    ```
    ~$ sh post_rollback_upg.sh -n <NAMESPACE> -rn <RELEASE_NAME>
    ```

1. After running the post_rollback_upg script run the below command
with expected replicas.

    ```
    ~$ helm upgrade <RELEASE_NAME> <OLDER_CHART_REFERENCE> --timeout <time> -n <NAMESPACE> --set PROPERTY
    ```

    If doing rollback to version DCED 2.3.0 or higher then use below property

    ```
    pods.dced.replicas=<expected replicas>
    ```

    If doing rollback to DCED version older than 2.3.0 then use below property

    ```
    pods.etcd.replicas=<expected replicas>
    ```

    ```
    OLDER_CHART_REFERENCE - This refers to the Helm chart of the older DCED version to which user wants to rollback.
    ```

#### 4. Manual Rollback procedure using "helm rollback" command

Step 1: Scale down to one pod.

Execute steps 1.1 to 1.3 for n time(s),
where n = Total number of DCED replicas - 1.
e.g. If there are 3 DCED replicas then execute steps 1.1 to 1.3 for 2 times.

Step 1.1: Remove the last member from the Distributed Coordinator ED cluster

```
NAMESPACE=<your namespace>
kubectl exec -it eric-data-distributed-coordinator-ed-0 -c dced -n $NAMESPACE -- bash -c 'etcdctl member remove $(etcdctl member list | sort -Vk3 | tail -n 1 | cut -d, -f1 )'

```
Step 1.2: Scale down the DCED StatefulSet.

```
#After executing below command , wait for some time till pod terminates completely.
kubectl scale statefulset.apps/eric-data-distributed-coordinator-ed -n $NAMESPACE --replicas=<current replicas less 1>
```

Step 1.3: Delete corresponding PVC

```
kubectl delete pvc `kubectl get pvc -n $NAMESPACE --sort-by='{.metadata.name}' | grep data-eric-data-distributed-coordinator-ed | tail -n1 | cut -d' ' -f 1` -n $NAMESPACE

```
Step 2: Take the snapshot in DCED pod-0.

```
kubectl exec eric-data-distributed-coordinator-ed-0 -c dced -n $NAMESPACE -- mkdir -p /data/snapshot
kubectl exec eric-data-distributed-coordinator-ed-0 -c dced -n $NAMESPACE -- etcdctl snapshot save /data/snapshot/backup.db
```
Step 3: Rollback to previous DCED version

```
helm rollback <RELEASE-NAME> -n $NAMESPACE <REVISION>

#After Successful rollback run the command mentioned below
kubectl scale statefulset.apps/eric-data-distributed-coordinator-ed --replicas=0 -n $NAMESPACE

#Once All DCED pods terminated run the command mentioned below
kubectl scale statefulset.apps/eric-data-distributed-coordinator-ed --replicas=1 -n $NAMESPACE

Note: After executing Step 3, in DCED pod logs we can see below critical(C) message
etcdserver/membership: cluster cannot be downgraded (current version: 3.4.16 is lower than determined cluster version: 3.5).

This message is expected in DCED logs at the time of downgrading DCED from 4.0.0 or higher to any DCED version older than 4.0.0. This message can be ignored.

```

Step 4: Restore snapshot

```
#Get inside DCED container
kubectl exec -it eric-data-distributed-coordinator-ed-0 -c `kubectl get pods eric-data-distributed-coordinator-ed-0 -o jsonpath='{.spec.containers[*].name}' -n $NAMESPACE | tr " " "\n" | egrep "etcd|dced"` -n $NAMESPACE -- bash

rm -rf ${ETCD_DATA_DIR}/restore_data
mkdir -p ${ETCD_DATA_DIR}/member/snap

#Run snapshot restore command
/usr/local/bin/etcdctl snapshot restore ${ETCD_DATA_DIR}/snapshot/backup.db --name ${HOSTNAME} --initial-cluster ${HOSTNAME}=${ETCD_INITIAL_ADVERTISE_PEER_URLS} --initial-advertise-peer-urls ${ETCD_INITIAL_ADVERTISE_PEER_URLS} --data-dir=${ETCD_DATA_DIR}/restore_data

#Kill etcd process and then wait for 2 seconds
pkill --exact etcd
#Note: After executing the above command, if the control comes out of the container, then re-login into the container.
sleep 2

#Delete older wal and snap file
rm -f ${ETCD_DATA_DIR}/member/wal/*.wal
rm -f ${ETCD_DATA_DIR}/member/snap/*snap

#Copy member directory from backup to /data
cp -Rf ${ETCD_DATA_DIR}/restore_data/member ${ETCD_DATA_DIR}
exit
```

Step 5: Delete DCED POD-0

```
kubectl delete pod eric-data-distributed-coordinator-ed-0 -n $NAMESPACE

```
Step 6: Scale back to expected replicas.

```
kubectl scale statefulset.apps/eric-data-distributed-coordinator-ed --replicas=<expected replicas> -n $NAMESPACE
```
Note: The above manual rollback procedure would take around 10 minutes.
For this duration DCED service would be unavailable to serve the traffic.

#### 5. Automated Rollback procedure using "helm rollback" command

1. Download pre_rollback and post_rollback scripts onto the cluster.

    ```
    ~$ wget https://arm.sero.gic.ericsson.se/artifactory/proj-adp-eric-data-dced-scripts-generic-local/pre_rollback.sh https://arm.sero.gic.ericsson.se/artifactory/proj-adp-eric-data-dced-scripts-generic-local/post_rollback.sh
    ```

1. Change the scripts from DOS to Unix and change mode of the scripts.

    ```
    ~$ dos2unix pre_rollback.sh post_rollback.sh
    ~$ chmod 755 pre_rollback.sh post_rollback.sh
    ```

1. Run the pre_rollback script by using the below command:

    ```
    ~$ sh pre_rollback.sh -n <NAMESPACE> -rn <RELEASE_NAME>
    ```

1. Run the post_rollback script by using below command:

    ```
    ~$ sh post_rollback.sh -n <NAMESPACE> -rn <RELEASE_NAME>
    ```
    Note: Keep post_rollback script running in one terminal, and perform
below step in another terminal.
(post_rollback script is dependent on the completion of the helm rollback)

1. After running the pre_rollback and post_rollback scripts, start the application
   rollback or deployment rollback through EVNFM.

    ```
    ~$ helm rollback <deployment name> <revision> --timeout <time> -n <NAMESPACE>
    ```

Note : After rollback, if the critical message "etcdmain: walpb: crc mismatch" is
encountered in any of the DCED pod logs and pods restart, then run the below
command for that particular DCED pod. DCED Pod(s) will come up.

```
kubectl exec -it eric-data-distributed-coordinator-ed-0 -c `kubectl get pods eric-data-distributed-coordinator-ed-0 -o jsonpath='{.spec.containers[*].name}' -n $NAMESPACE | tr " " "\n" | egrep "etcd|dced"` -n $NAMESPACE -- rm -f ${ETCD_DATA_DIR}/member/wal/*.wal
```

### Smart Helm Hook

Smart Helm Hook is a common framework to support pre/post helm hooks to avoid
lack of automation if required during rollback or upgrade from future
versions. Distributed Coordinator ED supports and integrates the Smart
Helm Hook framework. For more information on Smart Helm Hook, refer to
below link:
[https://eteamspace.internal.ericsson.com/display/AA/Smart+Helm+hooks](https://eteamspace.internal.ericsson.com/display/AA/Smart+Helm+hooks)

## Security Guidelines

### Operative Tasks

*Distributed Coordinator ED* utilizes role-based access control for interaction
with the service.

Service users are required to create their own users and roles using the
*Distributed Coordinator ED* root user.

1. Using username/password.(Note: applicable for only non-TLS deployment)

    The root username is `root`. Root password has to be created before
deploying DCED, see [Deploy the Distributed Coordinator ED Service](#deploy-the-distributed-coordinator-ed-service).

1. (*Preferred* if SIP-TLS is deployed in the namespace) Using the root
certificate.(Note: applicable for only TLS deployment)

    The *Distributed Coordinator ED* root certificate is stored in the
`eric-data-distributed-coordinator-ed-etcdctl-client-cert` Kubernetes secret.

    Refer to the [*Distributed Coordinator ED* Application Developer
Guide][DevelopersGuide] for more details on how to create users and roles.

{!fragments/.generated/service_ports.md!}

### Security Events that can be logged

List of security events for which logging is supported by the product:

1. Receiving new certificates.
1. Successful/unsuccessful reloading of Internal certificates due to renewal of certificates.

There is no configuration possibility for security-related logging. Just
the place of the log and the debug level can be configured. For the place of
the log, the supported methods for streamingMethod parameter are "direct",
"indirect" or "dual". "indirect" is the normal kubernetes behavior,
while "direct" initializes a Log Shipper sidecar with direct log streaming
to Log Transformer service. The log level can be configured to error,
info or debug. By default, it is configured to info.

## Privacy User Guidelines

The service does not collect, store or process personal data on its own.

## Operation and Maintenance

### Manual Scaling

The *Distributed Coordinator ED* Service supports manual scaling.

After you deploy the *Distributed Coordinator ED* Helm chart, you can increase
or decrease the number of replicas (pods in the `StatefulSet`).  It can take a
few minutes for Kubernetes to deploy the new set of pods and to start them
running.

It is recommended to have an odd number of replicas in the *Distributed
Coordinator ED* cluster.  An odd-size cluster tolerates the same number of
failures as an even-size cluster but with fewer nodes.

#### Backup and Restore

This chapter gives an overview of the supported Backup and Restore
functionality.

| Functionality                     | Supported |
| --------------------------------- | --------- |
| Service Discovery                 | Yes       |
| Support for Multiple Backup Types | Yes       |
| Selective Backup                  | Yes        |
| SIP-TLS                           | Yes       |

Note: Backups taken with *Distributed Coordinator ED* version 1.4.0 and before
are no longer compatible to be restored with the current
*Distributed Coordinator ED BrAgent*. It is strongly recommended to take a
fresh backup once *Distributed Coordinator ED* is upgraded.
Refer to the [*Distributed Coordinator ED* Application Developer
Guide][DevelopersGuide] for more details.

Note: BRO 2.7.0 and newer versions enable Mutual TLS for the connection made
from Backup and Restore Agents. *Distributed Coordinator ED BrAgent*
supports Mutual TLS connections.

#### DCED Snapshot Save and Restore procedure

##### Save DCED Snapshot

Run below command on each DCED POD to save Snapshot.

```
~$ kubectl exec eric-data-distributed-coordinator-ed-<i> -c dced -n <NAMESPACE> -- etcdctl snapshot save /data/backup.db
```

##### Restore DCED Snapshot

Refer to the section "Restoring a cluster" of below ETCD documentation:
[https://etcd.io/docs/v3.5/op-guide/recovery/](https://etcd.io/docs/v3.5/op-guide/recovery/)

#### Scaling Prerequisites

All of the *Distributed Coordinator ED* pods are in *Ready* state.

#### Scaling Out

Scaling Out is achieved using the helm upgrade command, for example:

```
helm upgrade <RELEASE_NAME> <CHART_REFERENCE> --set replicas=<NUMBER OF
REPLICAS>
```

The variables specified in the command are as follows:

`<RELEASE_NAME>`: String value, a name to identify and manage your helm chart.

`<CHART_REFERENCE>`: A path to a packaged chart, a path to an unpacked chart
directory or a URL.

`<NUMBER OF REPLICAS>`: An integer value, denoting the number of replicas in the
*Distributed Coordinator ED*.

Example output.

```
Release "eric-data-distributed-coordinator-ed" has been upgraded. Happy Helming!
LAST DEPLOYED: Wed Mar  6 09:47:26 2019
NAMESPACE: test-deployment-namespace
STATUS: DEPLOYED

RESOURCES:

==> v1/Pod(related)
NAME                                    READY  STATUS   RESTARTS  AGE
eric-data-distributed-coordinator-ed-0  1/1    Running  0         4d17h
eric-data-distributed-coordinator-ed-1  1/1    Running  0         4d17h
eric-data-distributed-coordinator-ed-2  1/1    Running  0         4d17h
eric-data-distributed-coordinator-ed-3  0/1    Pending  0         4d17h
```

#### Scaling In (If PVC deletion required)

Scaling In is a two phase process:

1. Remove a member from the *Distributed Coordinator ED* cluster.

1. Scale down the *Distributed Coordinator ED* `statefulset`.

*Note:* You can only scale down by one pod at a time.

Steps:

1. Enter the main container of the first pod of the *Distributed Coordinator ED*
   service.

    ```
    kubectl exec -it eric-data-distributed-coordinator-ed-0 -c dced --namespace <NAMESPACE> -- bash
    ```

1. Get the *Distributed Coordinator ED* member id for the newest member in the
   *Distributed Coordinator ED* cluster.

    ```
    etcdctl member list | sort -Vk3 | tail -n 1 | cut -d, -f1
    ```

    Example output:

    ```
    e7da78bea4fbb376
    ```

1. Remove the newest member.

    ```
    etcdctl member remove <Member ID>
    ```

    `<Member ID>`: The *Distributed Coordinator ED* member id obtained in the
previous step.

    Example command:

    ```
    etcdctl member remove e7da78bea4fbb376
    ```

    Example output:

    ```
    Member e7da78bea4fbb376 removed from cluster 1da7c7fd5804055e
    ```

1. Verify that the *Distributed Coordinator ED* pod with the highest ordinal
   number is in state `Terminating` or `CrashLoopBackOff` using the following
command.

    ```
    kubectl get pod -n <NAMESPACE>
    ```

    Example Output:

    ```
    NAME                                    READY  STATUS
    eric-data-distributed-coordinator-ed-0  1/1    Running
    eric-data-distributed-coordinator-ed-1  1/1    Running
    eric-data-distributed-coordinator-ed-2  1/1    Terminating
    ```

1. Identify the current number of pods in the *Distributed Coordinator ED*
   `statefulset`.

    ```
    kubectl get statefulset -n <NAMESPACE>
    ```

    Example Output:

    ```
    NAME                                   DESIRED   CURRENT   AGE
    eric-data-distributed-coordinator-ed   3         3         1m
    ```

    This *Distributed Coordinator ED* `statefulset` has 3 replicas.

1. Run the `helm upgrade` command to scale down.

    ```
    helm upgrade <RELEASE_NAME> <CHART_REFERENCE> --set replicas=<current replicas-1>
    ```

    The variables specified in the command are as follows:

    `<RELEASE_NAME>`: String value, a name to identify and manage your helm
chart.

    `<CHART_REFERENCE>`: A path to a packaged chart, a path to an unpacked chart
directory or a URL.

    `<NUMBER OF REPLICAS>`: An integer value, denoting the number of replicas in
the *Distributed Coordinator ED*.

    Example output:

    ```
    ==> v1/Pod(related)
    NAME                                    READY  STATUS
    eric-data-distributed-coordinator-ed-0  1/1    Running
    eric-data-distributed-coordinator-ed-1  1/1    Running
    eric-data-distributed-coordinator-ed-2  1/1    Terminating
    ```

1. Get the name of the `persistent volume claim` for the removed pod.

    ```
    kubectl get pvc -n <NAMESPACE>  --sort-by='{.metadata.name}' | tail -n1 | cut -d' ' -f 1
    ```

    Example Output.

    ```
    data-eric-data-distributed-coordinator-ed-2
    ```

    Ensure this matches the name of the pod that has been removed in the
previous step.

    In the example  pod `eric-data-distributed-coordinator-ed-2` has been
removed.  The corresponding `persistent volume claim` is
`data-eric-data-distributed-coordinator-ed-2`.

1. Delete the `persistent volume claim` for the removed pod.

    ```
    kubectl delete pvc <persistent volume claim name> -n <NAMESPACE>
    ```

    Example output.

    ```
       persistentvolumeclaim "data-eric-data-distributed-coordinator-ed-2" deleted
    ```

1. Ensure the `persistent volume` associated with the `persistent volume claim`
   has been removed.

    ```
    kubectl get pv | grep <persistent volume claim name>
    ```

    This command should not return any output related to the removed pod.

1. (Optional) Repeat all steps for any additional *Distributed Coordinator ED*
   pods that you want to remove.

1. Check and adapt the value in the Pod Disruption Budget if needed to reflect
     the expected behaviour.
     This is especially needed in case the value configured for `minAvailable`
     equal or larger than the number of replicas.
     If it is the case, it will prevent the draining of the nodes where PODs are
     running.

#### Snapshot Tuning

The 3pp etcd is designed to handle small key value pairs typical for metadata.
Larger requests will work, but may increase the latency of other requests.
With that kept in mind Based on the memory usage and disk usage seen in
*Distributed Coordinator ED*, the snapshot threshold can be lowered by changing
listed parameters.
see more [ETCD Tuning][Tuning].

`env.dced.ETCD_SNAPSHOT_COUNT`configures the number of applied Raft entries
to hold in-memory before compaction. When number of entries reaches configured
value, server first persists snapshot data onto disk, and then
truncates old entries.
Higher `env.dced.ETCD_SNAPSHOT_COUNT` holds more Raft entries in memory
until snapshot, thus causing recurrent higher memory usage[ETCD Maintenance][Maintenance].

`env.dced.ETCD_MAX_WALS` is a count of raft WAL logs retained by the server,
WAL (Write Ahead Log) pre-write log, record the entire process of data changes.
All data modifications must be written to the WAL before submission.
When the content of the data item in the WAL file is too large to reach the
`env.dced.ETCD_SNAPSHOT_COUNT`, the WAL will be segmented and the snapshot
operation will be performed at the same time. By default,
*Distributed Coordinator ED* keeps 5 historical files each.

`env.dced.ETCD_MAX_SNAPSHOTS`is the count of historical snapshots
retained by *Distributed Coordinator ED*. The snapshots are created by the
service when `env.dced.ETCD_SNAPSHOT_COUNT`is hit.

```
helm upgrade <RELEASE_NAME> <CHART_REFERENCE> --set env.dced.ETCD_SNAPSHOT_COUNT=5000 --set env.dced.ETCD_MAX_WALS=3 --set env.dced.ETCD_MAX_SNAPSHOTS=3
```

### Collect etcd data dump

To collect the current data held by etcd,
below command can be used to dump the data into a json file and store it in
PVC.

```
etcdctl get / --prefix --write-out="json" >> /<path_to_pvc>/<dump_filename>.json
```

For example,

```
~$ kubectl exec -it eric-data-distributed-coordinator-ed-0 -c dced -n <namespace> -- bash
bash-4.4$ etcdctl get / --prefix --write-out="json" >> /data/dump.json
```

Here, /data is the PVC location and dump.json is the file where dump is stored.
Filename is configurable.

*Note*: Ensure that PVC has enough space to store the dump file.

The json file can be zipped to save space. Below command can be used to dump
the data into a zipped json file.

```
~$ kubectl exec -it eric-data-distributed-coordinator-ed-0 -c dced -n <namespace> -- etcdctl get / --prefix --write-out="json" | tee | gzip --stdout > <dump_filename>.zip
```

## ETCD Disk and network latency

A request should normally take fewer than 50 milliseconds. If the average
apply duration exceeds 100 milliseconds, etcd will warn that entries as
"took too long(...s) to execute". Refer to below link for more details
<https://etcd.io/docs/v3.5/faq/#how-should-i-benchmark-etcd>.

If there is an issue of slow disk,the disk could be experiencing contention
among etcd and other applications.
To rule out a slow disk from causing this warning, monitor
backend_commit_duration_seconds (p99 or 99 percentile duration should be less
than 25 milliseconds) to confirm the disk is reasonably fast.

Histogram_quantile(0.99,
rate(etcd_network_peer_round_trip_time_seconds_bucket)) reports the round
trip time for etcd to finish replicating the client requests between the
members; it should be less than 50 milliseconds.

<!-- Troubleshooting new section -->

## Troubleshooting

This section describes the troubleshooting functions and procedures for the
*Distributed Coordinator ED* Service.  It provides the following information:

* Simple verification and possible recovery.
* The required information when writing a TR or a support case, including all
  files and system logs that are needed.
* How to retrieve the above information from the system.

### Prerequisites

* `kubectl` CLI tool properly configured

### Known Issues and Limitations

#### Rejected Connection from [IP] Error in Logs

##### Description

DCED has mTLS enabled by default, if a etcd client tries to connect/monitor/scrape
etc. it needs to be authenticated by the server, the health check from these
monitoring services, load balancer services originating from the k8 cluster
need access to the health endpoint.
Every 10 seconds errors similar to the ones listed below will show in the log
output.

Note: This error message won't be observed after DCED version 2.5.0.

##### Error Message

Below error messages can be seen in the logs:

```
2019-06-12 13:07:20.791260 I | embed: rejected connection from "10.210.174.83:53678" (error "EOF", ServerName "")
2019-06-12 13:07:30.791344 I | embed: rejected connection from "10.210.174.83:53722" (error "EOF", ServerName "")
2019-06-12 13:07:40.791308 I | embed: rejected connection from "10.210.174.83:53766" (error "EOF", ServerName "")
2019-06-12 13:07:50.791315 I | embed: rejected connection from "10.210.174.83:53810" (error "EOF", ServerName "")
```

##### Cause

An unauthenticated health check fires every 10s using a tcpSocket for
readinessProbe, that results in above error message.

##### Remedy

The fix was introduced in DCED version 2.5.0, and later versions
showed no flooding of the aforementioned error messages.

Note: This error message can be ignored if observed prior to DCED version
2.5.0. *Distributed Coordinator ED* periodically checks the health of its
endpoint by connecting to the service port.

#### DCED POD-1 failed with error 'failed to open database'

##### Description

DCED POD-1 is continuously restarting and throwing the error.

##### Error Message

Below error message is seen in logs:

```
{"level":"panic","ts":"2023-04-18T08:29:23.577Z","caller":"backend/backend.go:189","msg":"failed to open database","path":"/data/mem ber/snap/db","error":"invalid database","stacktrace":"go.etcd.io/etcd/server/v3/mvcc/backend.newBackend\n\t/tmp/etcd-release-3.5.5/e tcd/release/etcd/server/mvcc/backend/backend.go:189\ngo.etcd.io/etcd/server/v3/mvcc/backend.New\n\t/tmp/etcd-release-3.5.5/etcd/rele ase/etcd/server/mvcc/backend/backend.go:163\ngo.etcd.io/etcd/server/v3/etcdserver.newBackend\n\t/tmp/etcd-release-3.5.5/etcd/release /etcd/server/etcdserver/backend.go:55\ngo.etcd.io/etcd/server/v3/etcdserver.openBackend.func1\n\t/tmp/etcd-release-3.5.5/etcd/releas e/etcd/server/etcdserver/backend.go:76"}
panic: failed to open database
```

##### Cause

The etcd database file might have become corrupted due to unexpected
termination or hardware issues. In this case, etcd will be unable to
open the database. Resulting into crashloop for dced POD-1.

##### Remedy

Run the below procedure to fix the issue:

Step 1:

1.1 Go inside DCED pod-0 using following command:

```
~$ kubectl exec -it eric-data-distributed-coordinator-ed-0 -c dced -n <NAMESPACE> -- bash

```
1.2 List etcd members using following command:

```
~$ etcdctl member list

```

Example output:

```
2deb52ebf69466d4, started, eric-data-distributed-coordinator-ed-1, https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed-peer.namespace.svc.cluster.local:2380, https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed.namespace:2379, false
97688bd9a4106fdd, started, eric-data-distributed-coordinator-ed-2, https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed-peer.namespace.svc.cluster.local:2380, https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed.namespace:2379, false
d711b56b01a0feec, started, eric-data-distributed-coordinator-ed-0, https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed-peer.namespace.svc.cluster.local:2380, https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed.namespace:2379, false

```

1.3 Find out member id of DCED pod-2 from listed members and use it to remove
from the cluster as follows (in above case 97688bd9a4106fdd is the member id for
DCED pod-2)

```
~$ etcdctl member remove 97688bd9a4106fdd

```

1.4 Find out member id of DCED pod-1 from listed members and use it to remove
from the cluster as follows (in above case 2deb52ebf69466d4 is the member id for
DCED pod-1)

```
~$ etcdctl member remove 2deb52ebf69466d4

```

1.5  Exit from container using following command:

```
~$ exit

```

Step 2:

2.1 Scale down the dced statefulset to 1 replica:

```
 kubectl scale statefulset.apps/eric-data-distributed-coordinator-ed --replicas=1 -n <namespace>
```
Note: Wait for DCED pod-2 & DCED pod-1 pods to terminate completely.

Step 3:

3.1 Delete pvc of DCED pod-2 and DCED pod-1:

```
 kubectl delete pvc data-eric-data-distributed-coordinator-ed-2
 kubectl delete pvc data-eric-data-distributed-coordinator-ed-1
```
Note: Wait for DCED pod-2 & DCED pod-1 pvc to terminate completely.

Step 4:

4.1 Scale Up the DCED statefulset to 3 replicas:

```
 kubectl scale statefulset.apps/eric-data-distributed-coordinator-ed --replicas=3 -n <namespace>
```

#### Error:  etcdserver: mvcc: database space exceeded

##### Description

DCED database space is exceeded, no further writes can be made to the
database and an alarm is raised.

##### Error Message

The following error message will appear in the logs.

```
etcdserver: mvcc: database space exceeded
```

##### Cause

The issue is observed when the disk space quota is exceeded.

##### Remedy

Follow the below steps to compact the database & free up space:

1. Go inside one of the *Distributed Coordinator ED* pods:

    ```
    kubectl exec <<POD_NAME>> -c dced -it --namespace=<<NAMESPACE>> -- bash
    ```

1. Check the size of the database:

    ```
    bash-4.4$ ls /data/member/snap -lh
    ```

    ```
    total 65M
    -rw-r--r-- 1 250422 10000 13K Jun 24 17:49 0000000000000005-000000000000afd1.snap
    -rw-r--r-- 1 250422 10000 13K Jun 24 17:49 0000000000000005-000000000000c35a.snap
    -rw-r--r-- 1 250422 10000 13K Jun 24 17:52 0000000000000005-000000000000d6e3.snap
    -rw------- 1 250422 10000 265M Jun 24 18:31 db
    ```

1. Get the latest revision id.

    ```
    etcdctl endpoint status --write-out="json" | egrep -o '"revision":[0-9]*' | egrep -o '[0-9].*'
    ```

    Example output.

    ```
    251
    ```

1. Compact the database to the latest revision.

    ```
    etcdctl compact <revision id -1>
    ```

    Example command.

    ```
    etcdctl compact 250
    ```

    Example output.

    ```
    compacted revision 250
    ```

1. Exit the pod.

1. Run the following command on each *Distributed Coordinator ED*.

    ```
     kubectl exec  <<POD_NAME>> -c dced -it --namespace=<<NAMESPACE>> -- bash -c 'unset ETCDCTL_ENDPOINTS; etcdctl defrag  --endpoints=:2379 --insecure-skip-tls-verify --command-timeout=300s'
    ```

    Example commands.

    ```
    kubectl exec eric-data-distributed-coordinator-ed-0 -c dced -it --namespace=mynamespace -- bash -c 'unset ETCDCTL_ENDPOINTS; etcdctl defrag --insecure-skip-tls-verify --command-timeout=300s'
    kubectl exec eric-data-distributed-coordinator-ed-1 -c dced -it --namespace=mynamespace  -- bash -c 'unset ETCDCTL_ENDPOINTS; etcdctl defrag --insecure-skip-tls-verify --command-timeout=300s'
    kubectl exec eric-data-distributed-coordinator-ed-2 -c dced -it --namespace=mynamespace  -- bash -c 'unset ETCDCTL_ENDPOINTS; etcdctl defrag --insecure-skip-tls-verify --command-timeout=300s'
    ```

    Example output.

    ```
    Finished defragmenting etcd member[eric-data-distributed-coordinator-ed-0:2379]
    ```

1. The alarm needs to be removed manually

    ```
    kubectl exec <<POD_NAME>> -c dced -it --namespace=<<NAMESPACE>> -- etcdctl alarm list
    kubectl exec <<POD_NAME>> -c dced -it --namespace=<<NAMESPACE>> -- etcdctl alarm disarm
    ```

    Example output.

    ```
    memberID:13803658152347727308 alarm:NOSPACE
    ```
    Note: Follow the step 8 if the issue is observed frequently even
    after successful executinon the above procedure,
    *Distributed Coordinator ED* should be tuned, and the disk space quota
    can also be increased.

1. Expand PVC by referring [Distributed Coordinator ED CPI][cpi] docuemnt
and adjust the "env.dced.ETCD_QUOTA_BACKEND_BYTES" parameter according to the
section [Adjusting backend database size](#adjusting-backend-database-size)
and [Snapshot Tuning](#snapshot-tuning).

*Distributed Coordinator ED* provides following configurable parameters

`env.dced.DEFRAGMENT_PERIODIC_INTERVAL`
`env.dced.ETCD_AUTO_COMPACTION_MODE`
`env.dced.ETCD_AUTO_COMPACTION_RETENTION`

which helps perform compaction process every 5 minutes with defragmentation
activity periodically executing at
intervals set through `env.dced.DEFRAGMENT_PERIODIC_INTERVAL`.

If this automatic routine activity occurs after the alarm is raised, the
database size decreases
but writes cannot be made to the service until the alarm is manually removed.
This means that no further writes can be made to the database.

Reducing `env.dced.DEFRAGMENT_PERIODIC_INTERVAL` would increase the frequency
of defragmentation process taking place, however during this period the cluster
is unavailable and client requests fail until the process is completed, which takes
a few seconds based on the cluster load.

The parameters can be updated using the following command -

```
helm upgrade <RELEASE_NAME> <CHART_REFERENCE> --set env.dced.DEFRAGMENT_PERIODIC_INTERVAL=30 --set env.dced.ETCD_AUTO_COMPACTION_MODE=periodic --set env.dced.ETCD_AUTO_COMPACTION_RETENTION=30m
```

This example sets the defragmentation interval at every 30 minutes and
compaction happens for every 30-minute but with a 30-minute revision
retention window.
see [ETCD Maintenance][Maintenance].

Metrics can be observed by setting up *PM Server Service* which be useful
to tune them.

1. [Deploy & configure PM Metrics](#Metrics).
*PM Server Service* is enabled by default.

1. ETCD metrics can be found under Prometheus UI.

    e.g.

    * etcd_debugging_mvcc_keys_total
    * etcd_debugging_store_expires_total
    * etcd_server_quota_backend_bytes
    * etcd_mvcc_db_total_size_in_bytes

Enabling New Scraping Pattern

Currently PM Service supports collecting metrics from DCED using two methods,

1. New scraping pattern.
1. Old scraping pattern.

In the old scraping pattern metrics are collected using the scrape jobs:

* kubernetes-pods: Collects metrics over HTTP
* tls-targets: Collects metrics over HTTPS

PVC related metrics are collected using the scrape jobs:

* kubernetes-service-pods: Collects PVC related metrics over HTTP
* tls-pod-targets: Collects PVC related metrics over HTTPS

For the new scraping pattern the scrape jobs used are:

* k8s-endpoint-15s-http: Collects PVC releated metrics  over HTTP
* k8s-endpoint-15s-https: Collects PVC related metrics over HTTPS
* k8s-service-15s-http: Collects metrics over HTTP
* k8s-service-15s-https: Collects metrics over HTTPS

The old scraping pattern is to be deprecated, for more information please
check [PM Service User Guide](https://adp.ericsson.se/marketplace/pm-server/documentation/11.3.0/dpi/service-user-guide)
for details.

When adopting new scrape patterns, set the `enableNewScrapePattern`
parameter to true and ensure PM Server deployment is configured with the
appropriate scrape job. To support proper life-cycle management of the
service (upgrade, downgrade, and rollback), ensure that the PM Server
deployment is configured with both the old and new scrape jobs, as
mentioned in the above documentation.

#### Potential issue: /data/member/wal folder taking a lot of space

##### Description

This issue is the result of wal folder consuming significant amount of
storage space.

In a case where the number of transactions are high and key/value data is
consistently small ( 1kb~ ) based on the `env.dced.ETCD_SNAPSHOT_COUNT`
it is seen that snapshots are taken frequently but the wal file
currently in use would be consistent at a certain size (62 to 64 MB) until the
data item entered is too large to segment. However if the data values are
consistently large and frequent they fill up wal files quicker before the
snapshot are taken, this along with `env.dced.ETCD_MAX_WALS` which retains
historical wal ends up storing segmented files for which a snapshot
is not taken.

*Note:*
Wal(Write Ahead Log) files are stored /data/member/wal/.
For details see the [wal package documentation](https://pkg.go.dev/github.com/keob/etcd/wal)

##### Error Message

Potential error message could be:

```
Error:  etcdserver: mvcc: database space exceeded
```

In additional to above error message, defragmentation process starts to fail.

##### Cause

If the wal file accounts for the majority of the space used in
*Distributed Coordinator ED* then the service could become unstable
or even crash.

##### Remedy

In this case older wal files must be deleted to free up space.
Snapshot and WAL files stored in path /data/member/snap &
/data/member/wal.

It is advised to monitor the /wal folder especially in the case
when alarm has to be removed manually.
See section [Snapshot Tuning](#snapshot-tuning)

#### Failure on restore due to Grpc maximum message size

##### Description

Backup and restore fails due to insufficient gRPC maximum inbound message size
for the brAgent.

##### Error Message

Below error message can be observed:

```
com.ericsson.adp.mgmt.dced.bragent.exception.ClusterException: java.util.concurrent.ExecutionException: io.grpc.StatusRuntimeException: RESOURCE_EXHAUSTED: gRPC message exceeds maximum size
```

##### Cause

brAgent is getting a message response size from DCED that is
more than the limit set in the Grpc client.

##### Remedy

The issue can be resolved by increasing this limit by setting the
`brAgent.maxInboundMessageSize` to a suitable one.

#### Recursive call to appender Appender error message in brAgent log

##### Description

This error happens when DCED tries to log, the event is routed to an appender,
the appender tries to log and that event is routed back to the same appender.
This could end up in an endless loop that may cause a stack overflow
exception. Log4j detects this, prevents it and prints the below
error message.

##### Error Message

Below error message appears in brAgent log:

```
grpc-default-executor-8 ERROR Recursive call to appender Appender
```

##### Cause

It's produced by log4j to prevent recursive call of logger.

*Note*: It does not impact functionality of DCED.

##### Remedy

User should ignore this error message.

#### Failed to send out heartbeat on time

##### Description

ETCD uses a leader-based consensus protocol for consistent data replication
and log execution. The elected leader must periodically send heartbeats to
its followers to maintain its leadership. Followers infer leader failure
if no heartbeats are received within an election interval and triggers
an election. If the leader skips two heartbeat intervals, etcd will
warn it failed to send a heartbeat on time.

##### Error Message

The following error message will appear in the log:

```
etcdserver: failed to send out heartbeat on time (exceeded the 100ms timeout for 2.115707ms)
etcdserver: server is likely overloaded
```

##### Cause

Usually, this issue is caused by a slow disk. The second most common cause is
CPU starvation. Another cause is slow network.

##### Remedy

*Distributed Coordinator ED* provides two configurable parameters to configure
 its heartbeat interval and election timeout, respectively
  `env.dced.ETCD_HEARTBEAT_INTERVAL` and `env.dced.ETCD_ELECTION_TIMEOUT`.
For best practices `env.dced.ETCD_HEARTBEAT_INTERVAL` should be set around
 round-trip time between members, and `env.dced.ETCD_ELECTION_TIMEOUT`
 should be set as 10 times the round-trip time between members.

Please refer to [etcd Frequently Ased Questions][etcdfaq_heartbeat] and
[etcd Tuning Guide][Tuning] for a detailed explanation and how to solve the
issue.

For monitoring details kindly refer to [PM Server Service User Guide][PMServer].

#### Failure on backup due to etcd read timeout

##### Description

Backup fails in Distributed Coordinator ED due to request timeout.

##### Error Message

Below error is observed during a backup inside brAgent pod logs:

```
Coordinator ED","severity":"ERROR","message":"java.lang.NullPointerException
at com.ericsson.adp.mgmt.dced.bragent.v2.util.EtcdClusterUtils.retrieveDataFromEtcd(EtcdClusterUtils.java:91)
at com.ericsson.adp.mgmt.dced.bragent.v2.DcedBackupHandler.backupToFile(DcedBackupHandler.java:59)
at com.ericsson.adp.mgmt.dced.bragent.DCEDAgentBehaviour.createBackup(DCEDAgentBehaviour.java:174)
at com.ericsson.adp.mgmt.dced.bragent.DCEDAgentBehaviour.executeBackup(DCEDAgentBehaviour.java:95)
at com.ericsson.adp.mgmt.bro.api.agent.Agent.lambda$executeBackup$0(Agent.java:109)
at com.ericsson.adp.mgmt.bro.api.agent.Agent.safelyExecuteAgentBehavior(Agent.java:222)
at com.ericsson.adp.mgmt.bro.api.agent.Agent.executeBackup(Agent.java:109)
at com.ericsson.adp.mgmt.bro.api.agent.BackupExecutionState.trigger(BackupExecutionState.java:56)
at com.ericsson.adp.mgmt.bro.api.agent.Agent.changeState(Agent.java:217)
at com.ericsson.adp.mgmt.bro.api.agent.Agent.process(Agent.java:86)
at com.ericsson.adp.mgmt.bro.api.agent.OrchestratorStreamObserver.onNext(OrchestratorStreamObserver.java:58)
```

##### Cause

brAgent is unable to take backup due to timeout failure. The parameter
`brAgent.dcedReadTimeout` value was not sufficient inside brAgent when trying
to take backup.

##### Remedy

The issue can be resolved by increasing this timeout value by setting the
parameter `brAgent.dcedReadTimeout` to a suitable one.

#### Manual POD Eviction Procedure

##### Description

Disrupted communication stems from network or disk related issue
specifically within the worker node.

##### Error Message

N/A

##### Cause

Due to network or disk related issue on worker node,
Distributed Coordinator ED pods fails to communicate with cluster.

##### Diagnostics

Step 1: Get the total number of worker nodes available.
```
kubectl get nodes
```
Note: Total number of worker nodes, which are in ready state should
be more than (<DCED-replicas\>/2)+1.

Step 2: Identify the pod which is having delayed DCED operations by
 inspecting instrumentation data based on the below three conditions/metrics.
  Metrics can be retrieved by executing below command on each DCED pod.
```
NS=<NAMESPACE>
for i in {0..<n>}; do echo DCED-${i}: ;kubectl exec -n ${NS} eric-data-distributed-coordinator-ed-${i} -c dced -- bash -c "sh /usr/local/bin/scripts/etcd_metrics_evaluation.sh"; done  ;
```
<n\> is the pod number from 0 to 2 with replicas count as 3.
Collect the p99 duration of below metrics from above command's output for
all DCED pods and use that p99 duration in step-2.1 to step-2.3.

2.1. Defragmentation metrics
(p99 of etcd_disk_backend_defrag_duration_seconds_bucket)
&nbsp;&nbsp;   p99 duration  < 6 seconds (Good)
&nbsp;&nbsp;   p99 duration > 6 seconds (Bad)

2.2. Disk read/write metrics(p99 of etcd_disk_wal_fsync_duration_seconds_bucket
 and p99 of etcd_disk_backend_commit_duration_seconds_bucket)
      etcd_disk_wal_fsync_duration_seconds_bucket :
      &nbsp;&nbsp;   p99 duration  <10 ms (Good)
      &nbsp;&nbsp;   p99 duration  >10 ms (Bad)
     etcd_disk_backend_commit_duration_seconds_bucket :
      &nbsp;&nbsp;   p99 duration  < 25 ms (Good)
      &nbsp;&nbsp;   p99 duration > 25 ms (Bad)

2.3. Network metrics (p99 of etcd_network_peer_round_trip_time_seconds_bucket)
        &nbsp;&nbsp;   p99 duration < 50 ms (Good)
        &nbsp;&nbsp;   p99 duration > 50 ms (Bad)

If above three metrics are bad Note the pod name and proceed further
to 'Issue resolution' section.

##### Remedy

Step 1: Find the node that the identified pod(s) from the 'Issue Detection'
 section are running on
```
 kubectl get pods <pod-name> -n <namespace> -o jsonpath='{.spec.nodeName}{"\n"}'
```
Step 2: Using the node name identified in the previous step,
 run the below command to add taint temporarily.
```
kubectl taint nodes <node-name> ericsson.com/dced-disk-latency=true:NoSchedule
```
Step 3: Delete the DCED pod which is running on the identified node.
```
kubectl delete pod <Pod-Name-of-Faulty-Node> -n <namespace>
```
Step 4: Run the below command and wait for some time until
deleted DCED pod is recreated and scheduled.
```
kubectl get pod -w -n <namespace> |grep "eric-data-distributed-coordinator-ed"
```
Step 5: Delete the temporary taint from the node.
```
kubectl taint nodes <node-name> ericsson.com/dced-disk-latency:NoSchedule-
```

#### Recovery procedure to resolve the 'member count is unequal' error

##### Description

DCED PODs are failing with error 'member count is unequal' in the logs and
PODs are not coming up

##### Error Message

Below error message can be seen in DCED pod logs:

```
"level":"fatal","ts":"2023-05-29T08:55:26.671+0100","caller":"etcdmain/etcd.go:204","msg":"discovery failed","error":"error validating peerURLs {ClusterID:fa4445b7e3cc6147 Members:[&{ID:c438b5dbcb2cfa2f RaftAttributes:{PeerURLs:[https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed-peer.eric-pccgr02.svc.cluster.local:2380] IsLearner:false} Attributes:{Name:eric-data-distributed-coordinator-ed-1 ClientURLs:[https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed.eric-pccgr02:2379]}} &{ID:2c1f36cdd8b36f50 RaftAttributes:{PeerURLs:[https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed-peer.eric-pccgr02.svc.cluster.local:2380] IsLearner:false} Attributes:{Name:eric-data-distributed-coordinator-ed-2 ClientURLs:[https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed.eric-pccgr02:2379]}} &{ID:b8827bfd286fa8a8 RaftAttributes:{PeerURLs:[https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed-peer.eric-pccgr02.svc.cluster.local:2380] IsLearner:false} Attributes:{Name:eric-data-distributed-coordinator-ed-0 ClientURLs:[https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed.eric-pccgr02:2379]}}] RemovedMemberIDs:[]}: member count is unequal","stacktrace":"go.etcd.io/etcd/server/v3/etcdmain.startEtcdOrProxyV2\n\t/tmp/etcd-release-3.5.5/etcd/release/etcd/server/etcdmain/etcd.go:204\ngo.etcd.io/etcd/server/v3/etcdmain.Main\n\t/tmp/etcd-release-3.5.5/etcd/release/etcd/server/etcdmain/main.go:40\nmain.main\n\t/tmp/etcd-release-3.5.5/etcd/release/etcd/server/main.go:32\nruntime.main\n\t/usr/local/google/home/siarkowicz/.gvm/gos/go1.16.15/src/runtime/proc.go:225"}
```

##### Cause

Due to incorrect/redundant execution of the recovery procedure on the
same deployment the data was corrupted.

##### Remedy

Recovery steps

1. Execute below command on DCED POD-2.If command is failing due to POD restart
   move ahead to step-2

    ```
    kubectl exec -it eric-data-distributed-coordinator-ed-2 -c dced -n <NAMESPACE> --  rm -rf /data/member/wal
    ```

1. Execute below command on DCED POD-1. If command is failing due to POD restart
   move ahead to step-3

    ```
    kubectl exec -it eric-data-distributed-coordinator-ed-1 -c dced -n <NAMESPACE> --  rm -rf /data/member/wal
    ```

1. Go inside DCED POD-0 and execute the commands below

    3.1. Run below command to go inside DCED container of POD-0
    ```
    ~$ kubectl exec -it eric-data-distributed-coordinator-ed-0 -c dced -n <NAMESPACE> -- bash
    ```

    3.2. List out all the etcd members using following command
    ```
    ~$ etcdctl member list
    ```
    Example output:
    ```
    3deb53ebf69466e4, started, eric-data-distributed-coordinator-ed-1, https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed-peer.<NAMESPACE>.svc.cluster.local:2380, https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed.<NAMESPACE>:2379, false
    97688bd9a4106fdd, started, eric-data-distributed-coordinator-ed-2, https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed-peer.<NAMESPACE>.svc.cluster.local:2380, https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed.<NAMESPACE>:2379, false
    d711b56b01a0feec, started, eric-data-distributed-coordinator-ed-0, https://eric-data-distributed-coordinator-0.eric-data-distributed-coordinator-ed-peer.<NAMESPACE>.svc.cluster.local:2380, https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed.<NAMESPACE>:2379, false
    ```

    3.3. find out member id of DCED pod-2 from listed members and use it to
    remove the etcd member from the cluster as follows (97688bd9a4106fdd is
    the member id for DCED pod-2 in above result )
    ```
    ~$ etcdctl member remove <member-id>
    ```
    Example:
    ```
    ~$ etcdctl member remove 97688bd9a4106fdd
    ```
    3.4. find out member id of DCED pod-1 from listed members and use it
    to remove the etcd member from the cluster as follows (3deb53ebf69466e4 is
    the member id for DCED pod-1 in above result )
    ```
    ~$ etcdctl member remove <member-id>
    ```
    Example:
    ```
    ~$ etcdctl member remove 3deb53ebf69466e4
    ```

1. scale down the DCED statefulset to 0 replica with following command

    ```
    ~$ kubectl scale statefulset.apps/eric-data-distributed-coordinator-ed --replicas=0 -n <NAMESPACE>
    ```

1. Scale up the DCED statefulset to original number of replicas with following command

    ```
    ~$ kubectl scale statefulset.apps/eric-data-distributed-coordinator-ed --replicas=<replicas-count> -n <NAMESPACE>
    ```

#### DCED PVC crash recovery

##### DCED POD-0 Recovery

###### *Description*

Due to crashing of DCED Pod-0's PVC, cluster is being disturbed, resulting in
unhealthy cluster.

###### *Cause*

PVC failure associated with DCED Pod-0 resulted in it's inability to join the existing
cluster.

###### *Remedy*

1. Go inside DCED pod-0 and run below command, if command fails with
'context deadline exceeded' error, then delete /data/member/wal folder
and delete DCED pod-0

    ```
    kubectl exec -it eric-data-distributed-coordinator-ed-0 -c dced -n <NAMESPACE> -- bash

    bash-4.4$  etcdctl member list
    {"level":"warn","ts":"2023-08-16T07:12:10.036Z","logger":"etcd-client","caller":"v3@v3.5.7/retry_interceptor.go:62","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0xc00052e000/eric-data-distributed-coordinator-ed.dced-namespace:2379","attempt":0,"error":"rpc error: code = DeadlineExceeded desc = latest balancer error: last connection error: connection error: desc = \"transport: Error while dialing dial tcp: lookup eric-data-distributed-coordinator-ed.dced-namespace on 10.96.0.10:53: dial udp 10.96.0.10:53: connect: network is unreachable\""}
    Error: context deadline exceeded
    bash-4.4$ rm -rf /data/member/wal
    bash-4.4$ exit
    exit

    kubectl delete pod eric-data-distributed-coordinator-ed-0  --force --grace-period=0 -n <NAMESPACE>
    ```

1. Delete DCED pod-0 again by using following command

    ```
    kubectl delete pod eric-data-distributed-coordinator-ed-0  --force --grace-period=0 -n <NAMESPACE>
    ```

1. List etcd members using following command from inside DCED pod-0 dced
container

    ```
    kubectl exec -it eric-data-distributed-coordinator-ed-0 -c dced -n <NAMESPACE> -- bash
    bash-4.4$ etcdctl member list
    ```

    Example output

    ```
    2deb52ebf69466d4, started, eric-data-distributed-coordinator-ed-1, https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed-peer.dced-namespace.svc.cluster.local:2380, https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed.dced-namespace:2379, false
    97688bd9a4106fdd, started, eric-data-distributed-coordinator-ed-2, https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed-peer.dced-namespace.svc.cluster.local:2380, https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed.dced-namespace:2379, false
    d711b56b01a0feec, started, eric-data-distributed-coordinator-ed-0, https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed-peer.dced-namespace.svc.cluster.local:2380, https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed.dced-namespace:2379, false
    ```

1. Find out member id of DCED pod-0 from listed members in above command
and use it to remove from the cluster as follows (in above case
d711b56b01a0feec is the member id for DCED pod-0)

    ```
    bash-4.4$ etcdctl member remove d711b56b01a0feec
    ```

1. Kill entrypoint.sh and etcd process inside DCED pod-0 dced container
using below command

    ```
    bash-4.4$ pkill -f /usr/local/bin/scripts/entrypoint.sh
    bash-4.4$ pkill -f /usr/local/bin/etcd
    ```

1. Delete /data/member folder inside DCED pod-0 dced container

    ```
    bash-4.4$  rm -rf /data/member
    ```

1. Run below commands inside DCED pod-0 dced container
Note: Replace <*NAMESPACE*> in below commands with your namespace name.

    ```
    bash-4.4$ etcdctl member add eric-data-distributed-coordinator-ed-0 --peer-urls=https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed-peer.<NAMESPACE>.svc.cluster.local:2380
    bash-4.4$ export ETCD_INITIAL_CLUSTER="eric-data-distributed-coordinator-ed-0=https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed-peer.<NAMESPACE>.svc.cluster.local:2380,eric-data-distributed-coordinator-ed-1=https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed-peer.<NAMESPACE>.svc.cluster.local:2380,eric-data-distributed-coordinator-ed-2=https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed-peer.<NAMESPACE>.svc.cluster.local:2380"
    bash-4.4$ export ETCD_INITIAL_CLUSTER_STATE=existing
    bash-4.4$ etcd &
    bash-4.4$ exit
    ```

1. Scale-down eric-data-distributed-coordinator-ed statefulset
to replicas=0 using below command

    ```
    kubectl scale sts eric-data-distributed-coordinator-ed --replicas=0 -n <NAMESPACE>
    statefulset.apps/eric-data-distributed-coordinator-ed scaled
    ```

1. Scale-up eric-data-distributed-coordinator-ed statefulset
to replicas=3 using below command

    ```
    kubectl scale sts eric-data-distributed-coordinator-ed --replicas=3 -n <NAMESPACE>
    statefulset.apps/eric-data-distributed-coordinator-ed scaled
    ```

Note: Check the revision field values are same across all DCED pods by
executing below command inside all DCED pods to ensure etcd cluster
recovered successfully.

Replace <*i*> with 0,1,2 etc.

```
kubectl exec -it eric-data-distributed-coordinator-ed-<i> -c dced -n <NAMESPACE> -- bash
bash-4.4$ export ETCDCTL_ENDPOINTS=https://localhost:2379 ; etcdctl endpoint status -w json --insecure-skip-tls-verify=true
```

Example output

```
[{"Endpoint":"https://localhost:2379","Status":{"header":{"cluster_id":14128240836959017575,"member_id":1918676518113849204,"revision":215,"raft_term":7},"version":"3.5.7","dbSize":225280,"leader":9937771374252207723,"raftIndex":318,"raftTerm":7,"raftAppliedIndex":318,"dbSizeInUse":217088}}]
```

In above example, revision is 215 which should be same across all DCED pods.

##### DCED POD-1 Recovery

###### *Description*

Due to crashing of DCED Pod-1's PVC, cluster is being disturbed, resulting in
unhealthy cluster.

###### *Cause*

PVC failure associated with DCED Pod-1 resulted in it's inability to join the
existing cluster.

###### *Remedy*

1. List etcd members using following command from inside DCED pod-2 dced
container

    ```
    kubectl exec -it eric-data-distributed-coordinator-ed-2 -c dced -n <NAMESPACE> -- bash
    bash-4.4$ etcdctl member list
    ```

    Example output

    ```
    2deb52ebf69466d4, started, eric-data-distributed-coordinator-ed-1, https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed-peer.dced-namespace.svc.cluster.local:2380, https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed.dced-namespace:2379, false
    97688bd9a4106fdd, started, eric-data-distributed-coordinator-ed-2, https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed-peer.dced-namespace.svc.cluster.local:2380, https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed.dced-namespace:2379, false
    d711b56b01a0feec, started, eric-data-distributed-coordinator-ed-0, https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed-peer.dced-namespace.svc.cluster.local:2380, https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed.dced-namespace:2379, false
    ```

1. Find out member id of DCED pod-1 and pod-2 from listed members in above
command and use it to remove from the cluster as follows (in above case
2deb52ebf69466d4 is the member id for DCED pod-1 and 97688bd9a4106fdd is
the member id for DCED pod-2). Remove DCED pod-1 member id first and then
DCED pod-2 member id from inside DCED pod-2 dced container

    ```
    bash-4.4$ etcdctl member remove 2deb52ebf69466d4
    bash-4.4$ etcdctl member remove 97688bd9a4106fdd
    ```

1. Delete /data/member folder inside DCED pod-2 dced container

    ```
    bash-4.4$  rm -rf /data/member
    bash-4.4$ exit
    ```

1. Scale-down eric-data-distributed-coordinator-ed statefulset
to replicas=2 using below command

    ```
    kubectl scale sts eric-data-distributed-coordinator-ed --replicas=2 -n <NAMESPACE>
    statefulset.apps/eric-data-distributed-coordinator-ed scaled
    ```

1. Delete /data/member folder inside DCED pod-1 dced container

    ```
    kubectl exec -it eric-data-distributed-coordinator-ed-1 -c dced -n <NAMESPACE> -- bash
    bash-4.4$  rm -rf /data/member
    bash-4.4$ exit
    ```

1. Scale-down eric-data-distributed-coordinator-ed statefulset
to replicas=0 using below command

    ```
    kubectl scale sts eric-data-distributed-coordinator-ed --replicas=0 -n <NAMESPACE>
    statefulset.apps/eric-data-distributed-coordinator-ed scaled
    ```

1. Scale-up eric-data-distributed-coordinator-ed statefulset
to replicas=3 using below command

    ```
    kubectl scale sts eric-data-distributed-coordinator-ed --replicas=3 -n <NAMESPACE>
    statefulset.apps/eric-data-distributed-coordinator-ed scaled
    ```

Note: Check the revision field values are same across all DCED pods by
executing below command inside all DCED pods to ensure etcd cluster
recovered successfully.

Replace <*i*> with 0,1,2 etc.

```
kubectl exec -it eric-data-distributed-coordinator-ed-<i> -c dced -n <NAMESPACE> -- bash
bash-4.4$ export ETCDCTL_ENDPOINTS=https://localhost:2379 ; etcdctl endpoint status -w json --insecure-skip-tls-verify=true
```

Example output

```
[{"Endpoint":"https://localhost:2379","Status":{"header":{"cluster_id":14128240836959017575,"member_id":1918676518113849204,"revision":215,"raft_term":7},"version":"3.5.7","dbSize":225280,"leader":9937771374252207723,"raftIndex":318,"raftTerm":7,"raftAppliedIndex":318,"dbSizeInUse":217088}}]
```

In above example, revision is 215 which should be same across all DCED pods.

##### DCED POD-2 Recovery

###### *Description*

Due to crashing of DCED Pod-2's PVC, cluster is being disturbed, resulting in
unhealthy cluster.

###### *Cause*

PVC failure associated with DCED Pod-2 resulted in its inability to join the
existing cluster.

###### *Remedy*

1. List etcd members using following command from inside DCED pod-0 dced
container

    ```
    kubectl exec -it eric-data-distributed-coordinator-ed-0 -c dced -n <NAMESPACE> -- bash
    bash-4.4$ etcdctl member list
    ```

    Example output

    ```
    2deb52ebf69466d4, started, eric-data-distributed-coordinator-ed-1, https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed-peer.dced-namespace.svc.cluster.local:2380, https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed.dced-namespace:2379, false
    97688bd9a4106fdd, started, eric-data-distributed-coordinator-ed-2, https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed-peer.dced-namespace.svc.cluster.local:2380, https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed.dced-namespace:2379, false
    d711b56b01a0feec, started, eric-data-distributed-coordinator-ed-0, https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed-peer.dced-namespace.svc.cluster.local:2380, https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed.dced-namespace:2379, false
    ```

1. Find out member id of DCED pod-2 from listed members in above command
and use it to remove from the cluster as follows (in above case
97688bd9a4106fdd is the member id for DCED pod-2). Remove DCED pod-2 member id
from inside DCED pod-0 DCED container

    ```
    bash-4.4$ etcdctl member remove 97688bd9a4106fdd
    ```

1. Delete /data/member folder inside DCED pod-2 dced container

    ```
    kubectl exec -it eric-data-distributed-coordinator-ed-2 -c dced -n <NAMESPACE> -- bash
    bash-4.4$  rm -rf /data/member
    bash-4.4$ exit
    ```

1. Scale-down eric-data-distributed-coordinator-ed statefulset
to replicas=0 using below command

    ```
    kubectl scale sts eric-data-distributed-coordinator-ed --replicas=0 -n <NAMESPACE>
    statefulset.apps/eric-data-distributed-coordinator-ed scaled
    ```

1. Scale-up eric-data-distributed-coordinator-ed statefulset
to replicas=3 using below command

    ```
    kubectl scale sts eric-data-distributed-coordinator-ed --replicas=3 -n <NAMESPACE>
    statefulset.apps/eric-data-distributed-coordinator-ed scaled
    ```

Note: Check the revision field values are same across all DCED pods by
executing below command inside all DCED pods to ensure etcd cluster
recovered successfully.

Replace <*i*> with 0,1,2 etc.

```
kubectl exec -it eric-data-distributed-coordinator-ed-<i> -c dced -n <NAMESPACE> -- bash
bash-4.4$ export ETCDCTL_ENDPOINTS=https://localhost:2379 ; etcdctl endpoint status -w json --insecure-skip-tls-verify=true
```

Example output

```
[{"Endpoint":"https://localhost:2379","Status":{"header":{"cluster_id":14128240836959017575,"member_id":1918676518113849204,"revision":215,"raft_term":7},"version":"3.5.7","dbSize":225280,"leader":9937771374252207723,"raftIndex":318,"raftTerm":7,"raftAppliedIndex":318,"dbSizeInUse":217088}}]
```

In above example, revision is 215 which should be same across all DCED pods.

### Application Integration Failures

None.

### Service Deployment and Upgrade/Rollback Failures

#### PSP and SCC configuration to work in OpenShift

##### Description

DCED cannot be deployed out of the box on openshift platform due to missing
specification specific to platform.

##### Diagnostics

Run the following command:
```
kubectl get events -n <namespace> | grep "FailedCreate"
```

Similar error message as mentioned below can be observed:

```
Error creating: pods "eric-data-distributed-coordinator-ed-agent-6d4d6b4769-" is forbidden: unable to validate against any security context constraint: [provider restricted: .spec.securityContext.fsGroup: Invalid value: []int64{10000}: 10000 is not an allowed group, provider "nonroot": Forbidden: not usable by user or serviceaccount, provider "noobaa": Forbidden: not usable by user or serviceaccount, provider "noobaa-endpoint": Forbidden: not usable by user or serviceaccount, provider "anyuid": Forbidden: not usable by user or serviceaccount, provider "hostmount-anyuid": Forbidden: not usable by user or serviceaccount, provider "machine-api-termination-handler": Forbidden: not usable by user or serviceaccount, provider "hostnetwork": Forbidden: not usable by user or serviceaccount, provider "hostaccess": Forbidden: not usable by user or serviceaccount, provider "rook-ceph": Forbidden: not usable by user or serviceaccount, provider "node-exporter": Forbidden: not usable by user or serviceaccount, provider "privileged": Forbidden: not usable by user or serviceaccount, provider "rook-ceph-csi": Forbidden: not usable by user or serviceaccount]
```

##### Cause

Platform specific configuration missing, resulting in failure of DCED
deployment.

##### Consequences of the solution

The solution has no additional effects.

##### Solution

To successfully deploy it on openshift, below configuration needs to be
changed in psp-enforcement repo scc.yaml files.

```
fsGroup:
  type: RunAsAny
runAsUser:
  type: RunAsAny
allowHostDirVolumePlugin: true
```

##### Verification

1. Verify that the pods are running by getting the status for
eric-data-distributed-coordinator-ed pods.

    ```
    kubectl get pods -n <NAMESPACE>
    ```

    All eric-data-distributed-coordinator-ed pods status should be reported
    as "Running" and the numbers in Ready should be equal e.g. 1/1.

    ```
    k get po -n namespace | grep eric-data-distributed-coordinator-ed
    NAME                                                          READY     STATUS    RESTARTS       AGE
    eric-data-distributed-coordinator-ed-0                        1/1       Running   0              2d22h
    eric-data-distributed-coordinator-ed-1                        1/1       Running   0              2d22h
    eric-data-distributed-coordinator-ed-2                        1/1       Running   0              2d22h
    ```

#### DCED container intermittently does not come up after upgrade

##### Description

There is an intermittent issue observed, where DCED container does not come
up post upgrade.

##### Diagnostics

N/A

##### Cause

This is an intermittent issue which is observered due to missing .pem file.

A similar below error message can be observed:
```
Error: open /data/combinedca/cacertbundle.pem: no such file or directory
```

##### Consequences of the solution

The solution has no additional effects.

##### Solution

Perform below scale-in and scale-out steps to bring up the
DCED container.

Run the below commands to scale-in replicas:

```
~$ kubectl scale statefulset.apps/eric-data-distributed-coordinator-ed --replicas=0 -n <namespace>
```

Wait for all the pods to terminate and then run the below command to scale-out:

```
~$ kubectl scale statefulset.apps/eric-data-distributed-coordinator-ed --replicas=<original count of replicas> -n <namespace>
```

##### Verification

1. Verify that the pods are running by getting the status for
eric-data-distributed-coordinator-ed pods.

    ```
    kubectl get pods -n <NAMESPACE>
    ```

    All eric-data-distributed-coordinator-ed pods status should be
    reported as "Running" and the numbers in Ready should be equal e.g. 1/1.

    ```
    k get po -n namespace | grep eric-data-distributed-coordinator-ed
    NAME                                                          READY     STATUS    RESTARTS       AGE
    eric-data-distributed-coordinator-ed-0                        1/1       Running   0              2d22h
    eric-data-distributed-coordinator-ed-1                        1/1       Running   0              2d22h
    eric-data-distributed-coordinator-ed-2                        1/1       Running   0              2d22h
    ```

#### Downgrade fails from DCED 2.11.0 or higher to 2.7.0 or lower versions

##### Description

While downgrading DCED from a version 2.11.0 or higher to 2.7.0 or lower
versions, downgrade fails with the error mentioned in diagnostics.

##### Diagnostics

Run the below command to get the pod logs:

```
kubectl logs eric-data-distributed-coordinator-ed-<i> -c dced --namespace <NAMESPACE>
```

Below error message is observed in eric-data-distributed-coordinator-ed-0
pod logs:

```
/usr/local/bin/scripts/entrypoint.sh: line 5: /home/dced/etcd.liveness: Read-only file system
mkfifo: cannot create fifo '/home/dced/etcd.fifo': Read-only file system
Cannot open logging pipe.
```

##### Cause

'/home/dced/' is a read only file system. Thus, no files can be created that
caused the issue.

##### Consequences of the solution

The solution has no additional effects.

##### Solution

To overcome the issue, below steps should be followed otherwise
DCED-0 pod will not come up.

Option 1: After performing rollback Delete the DCED pod-0
using the command mentioned below

```
~$ kubectl delete pod eric-data-distributed-coordinator-ed-0 -n <NAMESPACE>
```

OR

Option 2: Before performing rollback run the command mentioned below

```
~$ kubectl patch statefulset eric-data-distributed-coordinator-ed -n <NAMESPACE> --patch '{"spec":{"template":{"spec":{"containers":[{"livenessProbe":{"exec":{"command":["echo","0"]}},"name":"dced","startupProbe":{"exec":{"command":["echo","0"]}}}]}}}}'
```
Once all pods are restarted successfully then
Rollback to actual expected Distributed Coordinator ED version.

**Note:** Follow either Option-1 or Option-2 to resolve this issue.

##### Verification

1. Verify that the pods are running by getting the status for
eric-data-distributed-coordinator-ed pods.

    ```
    kubectl get pods -n <NAMESPACE>
    ```

    All eric-data-distributed-coordinator-ed pods status should be reported as
    "Running" and the numbers in Ready should be equal e.g. 1/1.

    ```
    k get po -n namespace | grep eric-data-distributed-coordinator-ed
    NAME                                                          READY     STATUS    RESTARTS       AGE
    eric-data-distributed-coordinator-ed-0                        1/1       Running   0              2d22h
    eric-data-distributed-coordinator-ed-1                        1/1       Running   0              2d22h
    eric-data-distributed-coordinator-ed-2                        1/1       Running   0              2d22h
    ```

#### Rollback fails when upgrade from lower than DCED 4.2.0 with "atomic" flag fails

##### Description

DCED internal rollback may fail in case helm upgrade using "--atomic" flag
from a DCED version less than 4.2.0 to 4.2.0 or higher fails.

##### Diagnostics

Internal rollback fails with below error message:

```
rollback.go:166: [debug] warning: Rollback "<NAMESPACE>" failed: no ConfigMap with the name "eric-data-distributed-coordinator-ed" found Error: UPGRADE FAILED: an error occurred while rolling back the release. original upgrade error: cannot patch "eric-data-search-engine-data" with kind StatefulSet: StatefulSet.apps "eric-data-search-engine-data" is invalid: spec: Forbidden: updates to statefulset spec for fields other than 'replicas', 'template', and 'updateStrategy' are forbidden: no ConfigMap with the name "eric-data-distributed-coordinator-ed" found
helm.go:84: [debug] no ConfigMap with the name "eric-data-distributed-coordinator-ed" found
```

##### Cause

Limitation of Helm utility while using the atomic flag.

##### Consequences of the solution

The solution has no additional effects.

##### Solution

Proactive workaround to avoid this issue:

Before execution of helm upgrade, execute below steps.

1. Delete eric-data-distributed-coordinator-ed configmap using following command.

    ```
    kubectl delete configmap eric-data-distributed-coordinator-ed -n <NAMESPACE>
    ```

1. Delete eric-data-distributed-coordinator-ed-logshipper-cfg configmap using
   following command.

    ```
    kubectl delete configmap eric-data-distributed-coordinator-ed-logshipper-cfg -n <NAMESPACE>
    ```

**Note:** This issue won't appear when upgrading from DCED version 4.2.0 or higher.

##### Verification

After executing solution steps and performing helm upgrade:

1. Check if the chart is installed with the provided release name and in related
namespace by using the following command:

    ```
    helm ls -n <NAMESPACE>
    ```

1. Check the output and collect the App Version. Status should be "deployed".

1. Lastly, wait for all the pods to be up and running. All pods status
should be reported as "Running" and the numbers in Ready column should be
equal.

#### Rollback fails when upgrade from lower than DCED 8.0.0 with "atomic" flag fails

##### Description

DCED internal rollback may fail in case helm upgrade using "--atomic" flag
from a DCED version less than or equal to 7.0.0 to 8.0.0 or higher fails.

##### Diagnostics

Internal rollback fails with below error message:
```
rollback.go:176: [debug] warning: Rollback "<NAMESPACE>" failed: no ServiceAccount with the name "eric-data-distributed-coordinator-ed-sa" found
Error: UPGRADE FAILED: an error occurred while rolling back the release. original upgrade error: cannot patch "eric-pm-server" with kind StatefulSet: StatefulSet.apps "eric-pm-server" is invalid: spec: Forbidden: updates to statefulset spec for fields other than 'replicas', 'template', 'updateStrategy', 'persistentVolumeClaimRetentionPolicy' and 'minReadySeconds' are forbidden: no ServiceAccount with the name "eric-data-distributed-coordinator-ed-sa" found
helm.go:84: [debug] no ServiceAccount with the name "eric-data-distributed-coordinator-ed-sa" found
```

##### Cause

Limitation of Helm utility while using the atomic flag.

##### Consequences of the solution

The solution has no additional effects.

##### Solution

Proactive workaround to avoid this issue:

Before execution of helm upgrade, execute below steps.

1. Delete eric-data-distributed-coordinator-ed-sa service account using
following command.

    ```
    kubectl delete sa eric-data-distributed-coordinator-ed-sa -n <NAMESPACE>
    ```

##### Verification

After executing solution steps and performing helm upgrade:

1. Check if the chart is installed with the provided release name and in related
namespace by using the following command:

    ```
    helm ls -n <NAMESPACE>
    ```

1. Check the output and collect the App Version. Status should be "deployed".

1. Lastly, wait for all the pods to be up and running. All pods status
should be reported as "Running" and the numbers in Ready column should be
equal.

#### Rollback fails when DCED downgraded from 8.0.0 & higher to less than 8.0.0

##### Description

DCED rollback or upgrade may fail in case of downgrading
from a DCED version 8.0.0 or higher to less than version 8.0.0.

##### Diagnostics

Internal rollback fails with below error message:
```
rollback.go:176: [debug] warning: Rollback "<NAMESPACE>" failed: no ServiceAccount with the name "eric-data-distributed-coordinator-ed-sa" found
```

##### Cause

Limitation of Helm utility to identify service account names after renaming them.

##### Consequences of the solution

The solution has no additional effects.

##### Solution

Proactive workaround to avoid this issue:

Before execution of helm rollback or upgrade, execute below steps.

1. Delete eric-data-distributed-coordinator-ed-sa service account using
following command.

    ```
    kubectl delete sa eric-data-distributed-coordinator-ed-sa -n <NAMESPACE>
    ```

##### Verification

After executing solution steps and performing helm rollback/upgrade:

1. Check if the chart is installed with the provided release name and in related
namespace by using the following command:

    ```
    helm ls -n <NAMESPACE>
    ```

1. Check the output and collect the App Version. Status should be "deployed".

1. Lastly, wait for all the pods to be up and running. All pods status
should be reported as "Running" and the numbers in Ready column should be
equal.

#### Unhealthy cluster due to failure of rollback to a previous PRA version

##### Description

If a rollback to an older PRA version is initiated, with the following command,

```
helm rollback <RELEASE> <REVISION>
```

It is observed that one of the pods will not revert to the older PRA version,
leading to a unhealthy cluster state.

##### Diagnostics

Check the status of all 3 replicas of DCED by using the following command:

```
kubectl describe pod eric-data-distributed-coordinator-ed-<i> --namespace <NAMESPACE> | grep version
```

Check and note cluster health status, by executing the below command:

```
kubectl exec eric-data-distributed-coordinator-ed-<i> -c dced --namespace <NAMESPACE> -- bash -c 'etcdctl endpoint health'
```

##### Cause

N/A

##### Consequences of the solution

The solution has no additional effects.

##### Solution

It is recommended to manually delete the errant pod or issue an upgrade
command while specifying a deploymentTimestamp value:

```
helm upgrade <RELEASE_NAME> <CHART_REFERENCE> --set deploymentTimestamp=<AN INTEGER VALUE>
```

##### Verification

1. Verify that the pods are running by getting the status for your pods:

    ```
    kubectl get pods -n <NAMESPACE>
    ```

    All pods status should be reported as "Running" and the numbers in Ready
    column should be equal, e.g. 1/1.

    ```
    k get po -n namespace | grep eric-data-distributed-coordinator-ed
    NAME                                                          READY     STATUS    RESTARTS       AGE
    eric-data-distributed-coordinator-ed-0                        1/1       Running   0              2d22h
    eric-data-distributed-coordinator-ed-1                        1/1       Running   0              2d22h
    eric-data-distributed-coordinator-ed-2                        1/1       Running   0              2d22h
    ```

1. Verify the health of DCED Service:

    ```
    kubectl exec eric-data-distributed-coordinator-ed-<i> -c dced --namespace <NAMESPACE> -- bash -c 'etcdctl endpoint health'
    ```

    Similar output is expected:

    ```
    eric-data-distributed-coordinator-ed.namespace:2379 is healthy: successfully committed proposal: took = 11.043188ms
    ```

### Running System Failures

Please refer to the [Distributed Coordinator ED CPI][cpi] document.

### Health Checks

#### Helm Chart Check

Check if the chart is installed with the provided release name and in related
namespace by using the following command:

```
helm ls -n <NAMESPACE>
```

Check the output and collect the App Version. Status should be "deployed".

#### Pods Check

Verify that the pods are running by getting the status for your pods.

```
kubectl get pods -n <NAMESPACE>
```

All pods status should be reported as "Running" and the numbers in Ready
column should be equal, e.g. 1/1.

```
k get po -n namespace | grep eric-data-distributed-coordinator-ed
NAME                                                          READY     STATUS    RESTARTS       AGE
eric-data-distributed-coordinator-ed-0                        1/1       Running   0              2d22h
eric-data-distributed-coordinator-ed-1                        1/1       Running   0              2d22h
eric-data-distributed-coordinator-ed-2                        1/1       Running   0              2d22h
```

#### Logs Check

How to check/collect the logs:

```
kubectl logs --namespace <NAMESPACE> <POD> -c <CONTAINER>
```

Collect the pod's logs to determine the root cause of the error.

#### API Checks

Below command helps to check the health of Distributed Coordinator ED
endpoint:

```
kubectl -n <namespace> exec -it eric-data-distributed-coordinator-ed-0 -c dced -- bash

bash-4.4$ curl -i --cacert /run/secrets/"$SIP_TLS_CA_SECRET"/ca.crt --cert "$ETCDCTL_CERT" --key "$ETCDCTL_KEY" https://eric-data-distributed-coordinator-ed:2379/health
```

The service should respond with a HTTP 200 OK and as result of the above
command.
"health" parameter in the output should be "true". Refer to the example
output.

Example output:

```
HTTP/2 200
access-control-allow-headers: accept, content-type, authorization
access-control-allow-methods: POST, GET, OPTIONS, PUT, DELETE
access-control-allow-origin: *
content-type: text/plain; charset=utf-8
content-length: 29
date: Fri, 04 Aug 2023 11:32:56 GMT

{"health":"true","reason":""}
```

#### Metrics Check

##### Helm Chart Installation of PM Service

PM Metrics port can be configured using ports.dced.pm
For information related to PM Service installation,
see [PM Server Service User Guide][PMServer]

Note: ADP PM Server service should be running with the configuration of
global.security.tls.enabled="true" and
service.endpoints.pm.tls.enforced="required".

##### Get Metrics from DCED on Terminal

Prerequisite: metricsexporter container should be enabled inside Distributed
Coordinator ED.
Metricsexporter container is  enabled by setting the parameter
"metricsexporter.enabled=true"
while deployment.

Retrieve the service metrics using the below command:

```
kubectl -n <namespace> exec -it eric-data-distributed-coordinator-ed-0 -c dced -- bash

bash-4.4$ curl --cacert /run/secrets/"$SIP_TLS_CA_SECRET"/ca.crt --cert "$ETCDCTL_CERT" --key "$ETCDCTL_KEY" https://eric-data-distributed-coordinator-ed:2379/metrics
```

##### View Metrics on Prometheus UI using PM Server

1. **Prerequisite**: PM Server should be installed.
[Deploy & configure PM Metrics](#Metrics)
1. Metricsexporter container should be enabled inside Distributed Coordinator
ED. Metricsexporter container is enabled by setting the parameter
"metricsexporter.enabled=true" while deployment.

ETCD metrics can be found under Prometheus UI.
e.g.

* etcd_debugging_mvcc_keys_total
* etcd_debugging_store_expires_total
* etcd_server_quota_backend_bytes
* etcd_mvcc_db_total_size_in_bytes

#### Service specific health check support utilities

##### List all Members in the Cluster

The following command will list all the members in the cluster and their
endpoint details.

```
kubectl exec <POD_NAME> -c dced --namespace <NAMESPACE> -- etcdctl member list -w fields
```

Example output.

```
"ClusterID" : 2957485969347199328
"MemberID" : 963205705128695455
"Revision" : 0
"RaftTerm" : 13
"ID" : 963205705128695455
"Name" : "eric-data-distributed-coordinator-ed-1"
"PeerURL" : "https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed-peer.mynamespace.svc.cluster.local:2380"
"ClientURL" : "https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed.mynamespace:2379"

"ID" : 4588155877694094578
"Name" : "eric-data-distributed-coordinator-ed-2"
"PeerURL" : "https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed-peer.mynamespace.svc.cluster.local:2380"
"ClientURL" : "https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed.mynamespace:2379"

"ID" : 7767581235147248004
"Name" : "eric-data-distributed-coordinator-ed-0"
"PeerURL" : "https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed-peer.mynamespace.svc.cluster.local:2380"
"ClientURL" : "https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed.mynamespace:2379"
```

##### Get Information about a Specific Distributed Coordinator ED Endpoint

```
kubectl exec -it <POD_NAME -c dced --namespace=<NAMESPACE> -- bash -c 'unset ETCDCTL_ENDPOINTS; etcdctl endpoint status --endpoints=:2379 --insecure-skip-tls-verify=true -w fields'
```

Example output.

```
"ClusterID" : 2957485969347199328
"MemberID" : 963205705128695455
"Revision" : 203677
"RaftTerm" : 13
"Version" : "3.3.11"
"DBSize" : 497512448
"Leader" : 7767581235147248004
"RaftIndex" : 203717
"RaftTerm" : 13
"Endpoint" : "127.0.0.1:2379"
```

##### Debug Certificate Issues

*Distributed Coordinator ED* by default installs with client and server
certificates.  The following commands can help you to identify potential
certificate issues.

###### Verify Certificate

The following command establishes a connection to the *Distributed Coordinator
ED* using the supplied certificates.

```
kubectl exec -it <<POD_NAME>> -c dced --namespace=<<NAMESPACE>> -- env -S 'openssl s_client -connect eric-data-distributed-coordinator-ed:2379 -key ${ETCDCTL_KEY} -CAfile ${TRUSTED_CA} -cert ${ETCDCTL_CERT}'
```

Example output.

```
Protocol  : TLSv1.2
Cipher    : ECDHE-ECDSA-AES256-GCM-SHA384
Session-ID: 8759BC25115D8B1F0A74D4585A99E5...
Session-ID-ctx:
Master-Key: 49E9A328AB0CF2980CE8A60F2434A4...
PSK identity: None
PSK identity hint: None
SRP username: None
TLS session ticket:
0000 - be e1 b7 a3 45 e0 4b e2-38 ...

Start Time: 1560337087
Timeout   : 7200 (sec)
Verify return code: 0 (ok)
Extended master secret: no

```

###### Read Private Key

The command below prints information about the private key.

```
kubectl exec -it <<POD_NAME>> -c dced --namespace=<<NAMESPACE>> -- env -S 'openssl pkey -text -in ${ETCDCTL_KEY}'
```

Example output.

```
-----BEGIN PRIVATE KEY-----
MIGHAgE...

-----END PRIVATE KEY-----
Private-Key: (256 bit)
priv:
    67:55:1d:1c:be:a1:cf:4f:87:92:59:fa:d0:fc:24:
    85:0c:8b:80:c0:88:81:a2:7b:30:3f:ef:cf:32:d7:
    93:a3
pub:
    04:a0:90:49:bc:d1:4e:60:94:52:90:4b:8b:8c:80:
    ...
ASN1 OID: prime256v1
NIST CURVE: P-256
```

###### Read Certificate

The command below prints information about the specified certificate.

```
kubectl exec -it <<POD_NAME>> -c dced --namespace=<<NAMESPACE>> -- env -S 'openssl x509 -text -in ${ETCDCTL_CERT}'
```

Example output.

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            58:00:3c:d5:ac:a2:4e:72:34:31:2d:a0:f5:d8:6a:86:47:09:f3:e8
    Signature Algorithm: ecdsa-with-SHA256
        Issuer: CN=eric-data-distributed-coordinator-ed Internal Client CA
        Validity
            Not Before: Jun 14 10:00:51 2019 GMT
            Not After : Jun 14 11:01:21 2019 GMT
        Subject: CN = root
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub:
                    04:9f:1b:7a:01:6e:09:ee:58:ed:83:bc:d5:bc:97:
                    61:f1:0d:a6:3f:32:e3:1e:03:2d:31:5f:f3:13:10:
                    47:db:ff:7f:2c:ee:6a:9b:38:b3:7e:b2:86:cb:64:
                    6a:89:c3:c5:0e:70:59:31:d7:92:64:2b:5d:91:5d:
                    16:57:cf:70:82
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage:
                TLS Web Client Authentication
            X509v3 Subject Key Identifier:
                08:BE:4D:D3:91:CF:E2:7C:78:58:DF:E8:83:1B:2C:A0:FA:75:23:D5
            X509v3 Authority Key Identifier:
                keyid:A4:76:B8:FC:55:0A:12:...

            Authority Information Access:
                CA Issuers - URI:https://eric-sec-key-management:8200/v1/eric-sec-sip-tls-client-ca/eric-data-distributed-coordinator-ed-ca/ca

            X509v3 Subject Alternative Name:
                DNS:root
    Signature Algorithm: ecdsa-with-SHA256
         30:45:02:21:00:ff:e2:3f:75:92:c8:7e:9d:cd:01:55:d8:29:
         ff:c2:7b:65:bc:21:1f:68:25:5e:0a:14:34:fe:ee:c2:ff:85:
         ba:02:20:04:cd:cd:95:79:4f:d0:d8:3a:5e:79:df:c5:3c:74:
         39:1b:e9:48:a3:df:27:92:ff:54:2d:70:32:0c:6c:07:ab
-----BEGIN CERTIFICATE-----
MIICWzCCAgGgAwIBAgIUWAA81ayiTnI0MS2g9dhqhkcJ8+gwCgYIKoZIzj0EAwIw
...
-----END CERTIFICATE-----
```

#### Check Persistent Volume Storage Usage

*Distributed Coordinator ED* supports below exclusive metrics on storage usage:

* **dced_volume_stats_used_bytes**: PVC Used volume (in Bytes)
* **dced_volume_stats_capacity_bytes**: PVC Capacity volume (in Bytes)
* **dced_volume_stats_available_bytes**: PVC Available volume (in Bytes)

These exclusive metrics on storage usage can be enabled by
setting `metricsexporter.enabled=true` to check the *used*, *capacity*
and *available* bytes of the PVC. Refer
[Optional Configuration Parameters](#optional-configuration-parameters) for
more information.

If the PVC Storage usage exceeds threshold level,
follow the below remedy to free up some space.

### Enable Debug Logging

Enabling debug logging is achieved using the helm upgrade command, for example:

```
helm upgrade <RELEASE_NAME> <CHART_REFERENCE> --set env.dced.ETCD_LOG_LEVEL=debug
```

The variables specified in the command are as follows:

* `<RELEASE_NAME>`: String value, a name to identify and manage your helm chart.
* `<CHART_REFERENCE>`: A path to a packaged chart, a path to an unpacked chart
  directory or a URL.

### Log Analysis

None

### Bug Reporting and Additional Support

Issues can be handled in different ways, as listed below:

*   For questions, support or hot requesting, see section
    [Additional Support](#Additional-Support).
*   For reporting of faults, see section [Bug Reporting](#Bug-Reporting).

#### Data Collection

* The logs are collected from each pod using command:

    ```
    kubectl logs <POD_NAME> --namespace=<NAMESPACE>
    ```

* The detailed information about the pod are collected using command:

    ```
    kubectl describe pod <POD_NAME> --namespace=<NAMESPACE>
    kubectl exec <POD_NAME> -c dced -it --namespace=<NAMESPACE> env
    ```

#### Bug Reporting

If there is a suspected fault, raise a bug. The bug report must contain specific
*Distributed Coordinator ED* Service information and all applicable
troubleshooting information highlighted in the
[Troubleshooting](#troubleshooting)

Note: if the suspected fault can be resolved by restarting the pod.

When reporting a bug for the *Distributed Coordinator ED* Service, specify the
following in the JIRA issue:

* Issue type: Bug
* Component: *Distributed Coordinator ED*
* Reported from: the level at which the issue was originally detected (ADP
  Program, Application, Customer, etc.)
* Application: identity of the application where the issue was observed (if
  applicable)
* Business Impact: the business impact caused by the issue for the affected
  users

#### Additional Support

If there are *Distributed Coordinator ED* Service support issues, use the
[JIRA][jira].

### Recovery Procedure

This section describes how to recover the service in case of malfunction.

#### Restarting the pod

Deleting the pod will restart the service.

Run the following command:

```
kubectl delete pod <POD_NAME> --namespace=<NAMESPACE>
```

The relevant output is similar to the following.

```
pod "eric-data-distributed-coordinator-ed-0" deleted
```

#### Data Recovery

The *Distributed Coordinator ED* Service can be recovered with the Backup and
Restore agent. Further details on how to deploy and use the agent can be found
in the [Deployment section](#deployment).

#### Scale down and Scale up procedures for DCED replicas

There is limitation in DCED related to scale down and scale up of DCED
replicas. Few of the etcd commands do not work post scale down/scale up.
Please follow below steps to scale down/scale up of DCED replicas.

##### Steps to scale down DCED deployment from 3 replicas to 1 replica

Step 1:

1.1 Go inside DCED pod-0 using following command

```
~$ kubectl exec -it eric-data-distributed-coordinator-ed-0 -c dced -n <NAMESPACE> -- bash

```
1.2 List etcd members using following command

```
~$ etcdctl member list

```

Example output:

```
2deb52ebf69466d4, started, eric-data-distributed-coordinator-ed-1, https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed-peer.dced-namespace.svc.cluster.local:2380, https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed.dced-namespace:2379, false
97688bd9a4106fdd, started, eric-data-distributed-coordinator-ed-2, https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed-peer.dced-namespace.svc.cluster.local:2380, https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed.dced-namespace:2379, false
d711b56b01a0feec, started, eric-data-distributed-coordinator-ed-0, https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed-peer.dced-namespace.svc.cluster.local:2380, https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed.dced-namespace:2379, false
```

1.3 find out member id of DCED pod-2 from listed members and use it to remove from
the cluster as follows
(in above case 97688bd9a4106fdd is the member id for DCED pod-2)

```
~$ etcdctl member remove 97688bd9a4106fdd

```

1.4  Exit from container using following command

```
~$ exit

```

1.5 scale down statefulset to 2 replicas with following command

```
~$ kubectl scale statefulset.apps/eric-data-distributed-coordinator-ed --replicas=2 -n <NAMESPACE>

```

Step 2:

2.1 Go inside DCED pod-0 using following command

```
~$ kubectl exec -it eric-data-distributed-coordinator-ed-0 -c dced -n <NAMESPACE>  -- bash

```

2.2 List etcd members using following command

```
~$ etcdctl member list
```

Example output:

```
2deb52ebf69466d4, started, eric-data-distributed-coordinator-ed-1, https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed-peer.dced-namespace.svc.cluster.local:2380, https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed.dced-namespace:2379, false
d711b56b01a0feec, started, eric-data-distributed-coordinator-ed-0, https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed-peer.dced-namespace.svc.cluster.local:2380, https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed.dced-namespace:2379, false
```

2.3 find out member id of DCED pod-1 from listed members and use it to remove from
the cluster as follows
(in above case 2deb52ebf69466d4 is the member id for DCED pod-1)

```
~$ etcdctl member remove 2deb52ebf69466d4

```

2.4  Exit from container using following command

```
~$ exit

```

2.5 scale down statefulset to 1 replica with following command

```
~$ kubectl scale statefulset.apps/eric-data-distributed-coordinator-ed --replicas=1 -n <NAMESPACE>

```

##### Steps to scale up DCED deployment from 1 replica to 3 replicas

Note: These steps need to be performed only when scale down has been
performed using "Steps to scale down DCED deployment from 3 replicas
to 1 replica" section in user guide.

Execute below steps to scale up DCED from 1 replica to 3 replicas

1. Scale up DCED from 1 replica to replicas 3 using below command

    ```
    kubectl scale statefulset.apps/eric-data-distributed-coordinator-ed -n <NAMESPACE> --replicas=3
    ```

1. Once DCED pod-1 comes up and status of pod is Running, execute below command

    ```
    kubectl exec -it eric-data-distributed-coordinator-ed-1 -c dced -n <NAMESPACE> --  rm -rf /data/member/wal
    ```

1. Once DCED pod-2 comes up and status of pod is Running, execute below command

    ```
    kubectl exec -it eric-data-distributed-coordinator-ed-2 -c dced -n <NAMESPACE> --  rm -rf /data/member/wal
    ```

#### DCED POD-0 Recovery (Cluster ID mismatch error)

##### Description

The error is about peer member ID, that tries to join cluster with same name
as another member (probably old instance) that already exists in cluster
(with same peer name, but another ID).

##### Error Message

Below error message is observed:

```
{"level":"info","ts":"2023-03-06T13:07:12.235-0500","caller":"rafthttp/stream.go:274","msg":"established TCP streaming connection with remote peer","stream-writer-type":"stream Message","local-member-id":"1c192aed65dd7938","remote-peer-id":"f92d0a91a53265ea"}
panic: tocommit(587192) is out of range [lastIndex(587189)]. Was the raft log corrupted, truncated, or lost?

goroutine 77 [running]:
go.uber.org/zap/zapcore.(*CheckedEntry).Write(0xc000884000, 0x0, 0x0, 0x0)
/go/pkg/mod/go.uber.org/zap@v1.17.0/zapcore/entry.go:234 +0x58d
go.uber.org/zap.(*SugaredLogger).log(0xc000b120b8, 0x9696db4a832504, 0x124ecb9, 0x5d, 0xc0025a4080, 0x2, 0x2, 0x0, 0x0, 0x0)
/go/pkg/mod/go.uber.org/zap@v1.17.0/sugar.go:227 +0x111
go.uber.org/zap.(*SugaredLogger).Panicf(...)
/go/pkg/mod/go.uber.org/zap@v1.17.0/sugar.go:159
go.etcd.io/etcd/server/v3/etcdserver.(*zapRaftLogger).Panicf(0xc00003c110, 0x124ecb9, 0x5d, 0xc0025a4080, 0x2, 0x2)
/go/src/go.etcd.io/etcd/release/etcd/server/etcdserver/zap_raft.go:101 +0x7d
go.etcd.io/etcd/raft/v3.(*raftLog).commitTo(0xc000802c40, 0x8f5b8)
/go/src/go.etcd.io/etcd/release/etcd/raft/log.go:237 +0x135
go.etcd.io/etcd/raft/v3.(*raft).handleHeartbeat(0xc0004be2c0, 0x8, 0x1c192aed65dd7938, 0x9f7835abc7c54201, 0xa, 0x0, 0x0, 0x0, 0x0, 0x0, ...)
/go/src/go.etcd.io/etcd/release/etcd/raft/raft.go:1508 +0x54
go.etcd.io/etcd/raft/v3.stepFollower(0xc0004be2c0, 0x8, 0x1c192aed65dd7938, 0x9f7835abc7c54201, 0xa, 0x0, 0x0, 0x0, 0x0, 0x0, ...)
/go/src/go.etcd.io/etcd/release/etcd/raft/raft.go:1434 +0x478
go.etcd.io/etcd/raft/v3.(*raft).Step(0xc0004be2c0, 0x8, 0x1c192aed65dd7938, 0x9f7835abc7c54201, 0xa, 0x0, 0x0, 0x0, 0x0, 0x0, ...)
/go/src/go.etcd.io/etcd/release/etcd/raft/raft.go:975 +0xa55
go.etcd.io/etcd/raft/v3.(*node).run(0xc00081b080)
/go/src/go.etcd.io/etcd/release/etcd/raft/node.go:356 +0x798
created by go.etcd.io/etcd/raft/v3.RestartNode
/go/src/go.etcd.io/etcd/release/etcd/raft/node.go:244 +0x330
```

##### Cause

There was the issue with which was forming the new cluster and
throwing the 'clusterID mismatch' error.

##### Remedy

DCED developed the recovery procedure to make the pod-0 to join the existing
cluster instead forming new cluster. Follow the below recovery procedure:

1. Assign the namespace into namespace variable.

    ```
   namespace=<NAMESPACE>
    ```

1. Run the Below commands for all the DCED pods/replicas

    ```
    kubectl exec -it eric-data-distributed-coordinator-ed-<n>  -c dced -n $namespace -- bash
    mkdir -p /data/testwa/
    cd /data/testwa/
    cp /usr/local/bin/scripts/etcd_runner.sh /data/testwa/.
    cp /usr/local/bin/scripts/entrypoint.sh /data/testwa/entrypoint.sh
    sed -i 's/usr\/local\/bin\/scripts\/etcd_runner/data\/testwa\/etcd_runner/g' entrypoint.sh
    sed -i 's/ETCD_INITIAL_CLUSTER_STATE="new"/ETCD_INITIAL_CLUSTER_STATE="existing"/g' etcd_runner.sh
    sed -i 's/for (( c=1; c<=$ordinal; c++ ))/for (( c=2; c>$ordinal; c-- ))/g' etcd_runner.sh
    chmod 755 entrypoint.sh
    chmod 755 etcd_runner.sh
    sed -i 's/\r$//' entrypoint.sh
    sed -i 's/\r$//' etcd_runner.sh
    exit
    ```

1. Edit the statefulset and update path of entrypoint.sh file
   (From /usr/local/bin/scripts/entrypoint.sh to /data/testwa/entrypoint.sh)

    ```
    kubectl edit sts eric-data-distributed-coordinator-ed -n $namespace
    ```

1. Wait for all the DCED pods to come up
1. Check the logs of DCED POD-0 , if it's still throwing the clusterID mismatch
   error or unstarted member error as given in below command's output.

    ```
    ~$ kubectl exec -it eric-data-distributed-coordinator-ed-1 -n <namespace> -- etcdctl member list

    7fd74ce0e03911f1, started, eric-data-distributed-coordinator-ed-2, [https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed-peer.<namespace>.svc.cluster.local:2380]https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed-peer.<namespace>.svc.cluster.local:2380, [https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed.<namespace>:2379]https://eric-data-distributed-coordinator-ed-2.eric-data-distributed-coordinator-ed.<namespace>:2379

    a39945b582320a8e, unstarted, , [https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed-peer.<namespace>.svc.cluster.local:2380]https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed-peer.<namespace>.svc.cluster.local:2380,

    fc92ae7d7f69f8d0, started, eric-data-distributed-coordinator-ed-1, [https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed-peer.<namespace>.svc.cluster.local:2380]https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed-peer.<namespace>.svc.cluster.local:2380, [https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed.<namespace>:2379]https://eric-data-distributed-coordinator-ed-1.eric-data-distributed-coordinator-ed.<namespace>:2379
    ```

    Run the below steps if facing above issue of unstarted member.

    ```
    kubectl exec -it eric-data-distributed-coordinator-ed-1 -c dced -n $namespace -- bash -c "etcdctl member list"
    kubectl exec -it eric-data-distributed-coordinator-ed-1 -c dced -n $namespace -- bash -c "etcdctl member remove <pod-0-member-id>"
    kubectl exec -it eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- bash -c 'pkill etcd'
    kubectl exec -it eric-data-distributed-coordinator-ed-0 -c dced -n $namespace -- bash -c 'rm -rf /data/member/*'
    kubectl delete pod eric-data-distributed-coordinator-ed-0 -n $namespace
    kubectl exec -it eric-data-distributed-coordinator-ed-1 -c dced -n $namespace -- bash -c "etcdctl member add eric-data-distributed-coordinator-ed-0 --peer-urls=https://eric-data-distributed-coordinator-ed-0.eric-data-distributed-coordinator-ed-peer.$namespace.svc.cluster.local:2380"
    kubectl exec -it eric-data-distributed-coordinator-ed-1 -c dced -n $namespace -- bash -c "etcdctl member list"
    ```

1. Revert the changes made in step-2.

### Alarm Handling

N/A

## References

[Distributed Coordinator ED CPI][cpi]

[ADP Generic Services Support JIRA][jira]

[CoreOS ETCD API][etcdapi]

[Service Identity Provider for TLS Service Deployment Guide][SIP-TLS]

[Key Management Service Deployment Guide][KMS]

[Backup and Restore Operations Guide for CM Yang Provider][CMYP]

[PM Server Service User Guide][PMServer]

[Persistent Volume expansion Guide][pvexpansion]

[ETCD Frequently Asked Questions][etcdfaq]

[ETCD Tuning][Tuning]

[ETCD Maintenance][Maintenance]

[Low Footprint Sidecar Developer's Guide - Experimental Configuration Parameters][logshipper]

[Low Footprint Sidecar Developer's Guide - Optional Helm Chart Parameters][logshipper]

[cpi]: https://calstore.internal.ericsson.com/elex?LI=EN/LZN7950007*&FB=0_1_0_0&ST=DTITLE&PA=Managing+Distributed+Coordinator+ED
[jira]: https://eteamproject.internal.ericsson.com/projects/GSSUPP/
[etcdapi]: https://etcd.io/docs/v3.5/
[SIP-TLS]: https://adp.ericsson.se/marketplace/service-identity-provider-tls/documentation/development/dpi/service-user-guide#deployment
[KMS]: https://adp.ericsson.se/marketplace/key-management/documentation/development/dpi/service-user-guide#deployment
[CMYP]: https://adp.ericsson.se/marketplace/backup-and-restore-orchestrator/documentation/development/additional-documents/operations-guide-for-bro-with-cm-yp
[etcdconfig]: https://etcd.io/docs/v3.5/op-guide/configuration/
[DevelopersGuide]: https://adp.ericsson.se/marketplace/distributed-coordinator-ed/documentation/development/dpi/application-developers-guide
[PMServer]: https://adp.ericsson.se/marketplace/pm-server/documentation/development/dpi/service-user-guide
[pvexpansion]: https://kubernetes.io/blog/2022/05/05/volume-expansion-ga/
[PDB]: <https://kubernetes.io/docs/tasks/run-application/configure-pdb/>
[Tuning]: <https://etcd.io/docs/v3.5/tuning/#snapshots>
[Maintenance]: <https://etcd.io/docs/v3.5/op-guide/maintenance/#raft-log-retention>
[etcdfaq]: <https://etcd.io/docs/v3.5/faq/>
[etcdfaq_heartbeat]: <https://etcd.io/docs/v3.5/faq/#what-does-the-etcd-warning-failed-to-send-out-heartbeat-on-time-mean>
[lock_case_1]: <https://eteamspace.internal.ericsson.com/display/AA/UC.DM.DC.DL.001+-+create+distributed+lock>
[lock_case_2]: <https://eteamspace.internal.ericsson.com/display/AA/UC.DM.DC.DL.002+-+acquire+distributed+lock>
[lock_case_3]: <https://eteamspace.internal.ericsson.com/display/AA/UC.DM.DC.DL.003+-+release+distributed+lock>
[lock_case_4]: <https://eteamspace.internal.ericsson.com/display/AA/UC.DM.DC.DL.004+-+remove+distributed+lock>
[leader_case_1]: <https://eteamspace.internal.ericsson.com/display/AA/UC.DM.DC.EL.001+-+elect+leader>
[leader_case_2]: <https://eteamspace.internal.ericsson.com/display/AA/UC.DM.DC.EL.002+-+query+leader>
[leader_case_3]: <https://eteamspace.internal.ericsson.com/display/AA/UC.DM.DC.EL.003+-+remove+leader>
[leader_case_4]: <https://eteamspace.internal.ericsson.com/display/AA/UC.DM.DC.EL.004+-+subscribe+on+leader+changes>
[leader_case_5]: <https://eteamspace.internal.ericsson.com/display/AA/UC.DM.DC.EL.005+-+receive+leader+changes+notification>
[PodPriority]: <https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/>
[logshipper]: <https://adp.ericsson.se/marketplace/log-shipper/documentation/10.2.0/additional-documents/low-footprint-sidecar-application-developers-guide>
[logshipper-sidecar-dimensioning-recommendations]: <https://adp.ericsson.se/marketplace/log-shipper/documentation/12.0.0/additional-documents/low-footprint-sidecar-application-developers-guide#sidecar-dimensioning-recommendations>
