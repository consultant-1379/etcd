"""
This module deploys the DCZK, DCED, MBKF for nmap scans
"""
import os
import datetime
import time
import utilprocs
import helm3procs
import k8sclient
from kubernetes import client

KUBE = k8sclient.KubernetesClient()
NAMESPACE = os.environ.get("kubernetes_namespace")
CLASS_FIXTURE = utilprocs.str2bool(os.environ.get('class_fixture', True))
GS_ALL_HELM_REPO = "https://arm.sero.gic.ericsson.se/artifactory/proj-adp-gs-all-helm"
GS_ALL_HELM_REPO_NAME = "GS-ALL"
DCZK_CHART_NAME = "eric-data-coordinator-zk"
MBKF_CHART_NAME = "eric-data-message-bus-kf"
BRO_CHART_NAME = "eric-ctrl-bro"
DCED_CHART_NAME = "eric-data-distributed-coordinator-ed"
ALL_SECRETS = [
    "eric-ctrl-bro-ca",
    "eric-ctrl-bro-server-cert",
    "eric-ctrl-bro-server-cert-emergency",
    "eric-data-distributed-coordinator-creds",
    "eric-data-distributed-coordinator-ed-ca",
    "eric-data-distributed-coordinator-ed-cert",
    "eric-data-distributed-coordinator-ed-cert-emergency",
    "eric-data-distributed-coordinator-ed-etcdctl-client-cert",
    "eric-data-distributed-coordinator-ed-etcdctl-client-cert-emergency",
    "eric-data-distributed-coordinator-ed-peer-cert",
    "eric-data-distributed-coordinator-ed-peer-cert-emergency",
    "eric-sec-key-management-client-cert",
    "eric-sec-key-management-client-cert-emergency",
    "eric-sec-key-management-kms-cert",
    "eric-sec-key-management-kms-cert-emergency",
    "eric-sec-key-management-shelter-key",
    "eric-sec-key-management-unseal-key",
    "eric-sec-sip-tls-bootstrap-ca-cert",
    "eric-sec-sip-tls-dced-client-cert",
    "eric-sec-sip-tls-dced-client-cert-emergency",
    "eric-sec-sip-tls-trusted-root-cert",
    "eric-sec-sip-tls-wdc-certs",
    "eric-sec-sip-tls-wdc-certs-emergency",
]

def test_remove_k8s_resources():
    """
    Removes all kubernetes resources in the namespace.
    """
    utilprocs.log("Remove all helm releases from namespace")
    helm3procs.helm_cleanup_namespace(NAMESPACE)

    utilprocs.log("Deleting certificate secrets")
    k8s_delete_body = client.V1DeleteOptions()
    for secret in ALL_SECRETS:
        try:
            if len(KUBE.get_namespace_secrets(NAMESPACE, secret)) == 1:
                client.CoreV1Api().delete_namespaced_secret(
                    secret, NAMESPACE, body=k8s_delete_body
                )
                time.sleep(2)
        except Exception as e_obj:
            utilprocs.log(str(e_obj))

    utilprocs.log("get list pods from namespace")
    podlist = KUBE.list_pods_from_namespace(NAMESPACE)
    utilprocs.log("delete all pods from namespace")
    yesterdaydateytime = datetime.datetime.now() - datetime.timedelta(days=1)
    for pod in podlist.items:
        if (pod.metadata.creation_timestamp.replace(tzinfo=None) < yesterdaydateytime
                or pod.metadata.name.startswith("test-nose-nmap")):
            KUBE.delete_pod(pod.metadata.name, NAMESPACE, wait_for_terminating=False)
        else:
            utilprocs.log("skip delete pod " + pod.metadata.name)

    utilprocs.log("Remove all PVCs from namespace")
    KUBE.delete_all_pvc_namespace(NAMESPACE)
