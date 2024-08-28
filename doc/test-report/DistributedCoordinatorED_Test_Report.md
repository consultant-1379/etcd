# Distributed Coordinator ED Test Report

Abstract

This document lists the test results for Distributed Coordinator ED.

## Target Audience

* ADP development team
* ADP CICD
* Application

## Unit tests

### Unit Test Environment

|   Name | Value         |
|--------|---------------|
|   HW   | Jenkins Slave |
|   OS   | CentOS 7      |

### Unit Test Object

Distributed Coordinator ED Dockerfile, Distributed Coordinator ED BrAgent
Dockerfile, and Distributed Coordinator ED Helm chart files.

### Unit Test Execution

As a Jenkins job on every code review.

### Unit Test Results

| **Test Case ID**      | **Test Case Header**                                                                             | **Test Result** |
|-----------------------|--------------------------------------------------------------------------------------------------|-----------------|
| Helm_lint             | Verify that the Distributed Coordinator ED Helm chart is well formed                             | 1/1             |
| Docker_build          | Verify that the build is successful for: Distributed Coordinator ED Dockerfile.                  | 1/1             |
| Docker_build          | Verify that the build is successful for: Distributed Coordinator ED BrAgent Dockerfile.          | 1/1             |
| Junit Tests - BrAgent | Verify the functionality of individual classes in Data Coordinator ZK BrAgent codebase.          | 24/24           |
| CST_Metadata_Test     | Metadata tests                                                                                   | 1/1             |
| CST_File_Test         | File Tests                                                                                       | 3/3             |

## System Tests

### System Test Environment

| Name        | Value                            |
|-------------|----------------------------------|
| HW          | ADP Development Environment      |
| SW          | 1.21.1-kaas.1 / ECCD 2.18.0      |
| K8S version | V1.21.1                          |
| K8S Cluster | 3 Master nodes + 16 Worker nodes |
| Capacity    | 4 vCPUs per Worker node          |

### System Test Object

Distributed Coordinator ED Helm chart.

### System Test Execution

Automated via Bob framework

Tested with chart eric-distributed-coordinator-ed:11.0.0-14

### System Test Results

Tests without certificates:

| **Test Case ID**       | **Test Result** |
|------------------------|-----------------|
| Installation           | 1/1             |
| Authentication Enabled | 1/1             |
| OWAZP ZAP              | 1/1             |
| Upgrade                | 1/1             |
| Rollback               | 1/1             |
| Scaling                | 1/1             |
| Robustness             | 1/1             |
| Uninstall              | 1/1             |

Tests with certificates:

| **Test Case ID**       | **Test Result** |
|------------------------|-----------------|
| SIP-TLS Installation   | 1/1             |
| KMS Installation       | 1/1             |
| Installation           | 1/1             |
| Authentication Enabled | 1/1             |
| Upgrade                | 1/1             |
| Rollback               | 1/1             |
| Scaling                | 1/1             |
| Robustness             | 1/1             |
| Uninstall              | 1/1             |

## Characteristics

| **Test Case ID**                                         | **Test Result** |
|----------------------------------------------------------|-----------------|
| Deployment time without certificates                     | 78 seconds     |
| Deployment time with certificates                        | 2m37s           |
| Restart time for a single pod                            | 33 seconds      |
| Docker image size for DC ED                              | 183 MB          |
| Docker image size for DC ED BrAgent                      | 335 MB          |
| Maximum Stable throughput                                | 150 writes/s    |
| Docker image size for DC ED metrics-exporter             | 93.7 MB         |

## Appendix

### Junit Test

[Surefire Report](surefire-report.html)
