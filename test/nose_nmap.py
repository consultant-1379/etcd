"""
This module deploys the DCZK, DCED, MBKF for nmap scans
"""
import os
import datetime
import time
import utilprocs
import helm3procs
import k8sclient
import siptls_helm3
from kubernetes import client

KUBE = k8sclient.KubernetesClient()
NAMESPACE = os.environ.get("kubernetes_namespace")
CLASS_FIXTURE = utilprocs.str2bool(os.environ.get('class_fixture', True))
GS_ALL_HELM_REPO = "https://arm.sero.gic.ericsson.se/artifactory/proj-adp-gs-all-helm"
GS_ALL_HELM_REPO_NAME = "GS-ALL"
BRO_CHART_NAME = "eric-ctrl-bro"
DCED_CHART_NAME = "eric-data-distributed-coordinator-ed"
PM_SERVER_CHART_NAME = "eric-pm-server"
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
    "eric-pm-server-ca",
    "eric-pm-server-cert",
    "eric-pm-server-cert-emergency",
    "eric-pm-server-client-cert",
    "eric-pm-server-client-cert-emergency",
    "eric-pm-server-int-rw-ca",
    "eric-pm-server-int-rw-client-cert",
    "eric-pm-server-int-rw-client-cert-emergency",
    "eric-pm-server-query-ca"
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
    yesterdaydatetime = datetime.datetime.now() - datetime.timedelta(days=1)
    for pod in podlist.items:
        if pod.metadata.creation_timestamp.replace(tzinfo=None) < yesterdaydatetime:
            KUBE.delete_pod(pod.metadata.name, NAMESPACE, wait_for_terminating=False)
        else:
            utilprocs.log("skip delete pod " + pod.metadata.name)

    utilprocs.log("Remove all PVCs from namespace")
    KUBE.delete_all_pvc_namespace(NAMESPACE)

def test_deploy_bro():
    """
    Deploys the BRO Service.
    """
    helm_settings_bro = {"global.pullSecret": "armdocker"}

    test_case = "test_deploy_bro_service"
    utilprocs.log("Test Case: {}".format(test_case))

    utilprocs.log('Starting BRO installation')

    helm3procs.add_helm_repo(helm_repo=GS_ALL_HELM_REPO,
                             helm_repo_name=GS_ALL_HELM_REPO_NAME)
    helm3procs.helm_install_chart_from_repo_with_dict(
        chart_name=BRO_CHART_NAME,
        release_name="{}-{}".format(
            BRO_CHART_NAME, NAMESPACE),
        helm_repo_name=GS_ALL_HELM_REPO_NAME,
        target_namespace_name=NAMESPACE,
        settings_dict=helm_settings_bro,
        development_version=True,
        should_wait=False,
    )

    # Collect console logs
    KUBE.get_pod_logs(NAMESPACE, "{}-0".format(BRO_CHART_NAME), test_case)

def test_deploy_pm_server():
    """
    Deploys the PM Server Service.
    """
    helm_settings_pm_server = {"global.pullSecret": "armdocker"}

    test_case = "test_deploy_pm_server_service"
    utilprocs.log("Test Case: {}".format(test_case))

    utilprocs.log('Starting PM Server installation')

    helm3procs.add_helm_repo(helm_repo=GS_ALL_HELM_REPO,
                             helm_repo_name=GS_ALL_HELM_REPO_NAME)
    helm3procs.helm_install_chart_from_repo_with_dict(
        chart_name=PM_SERVER_CHART_NAME,
        release_name="{}-{}".format(
            PM_SERVER_CHART_NAME, NAMESPACE),
        helm_repo_name=GS_ALL_HELM_REPO_NAME,
        target_namespace_name=NAMESPACE,
        settings_dict=helm_settings_pm_server,
        development_version=True,
        should_wait=False,
    )

    # Collect console logs
    KUBE.get_pod_logs(NAMESPACE, "{}-0".format(PM_SERVER_CHART_NAME), test_case)

def test_deploy_dced_with_kms_siptls():
    """
    Deploys the DCED Service with KMS & SIP-TLS
    """
    helm_settings_dced = {
        "global.registry.pullSecret": "armdocker",
        "global.pullSecret": "armdocker",
        "brAgent.enabled": True,
        "metricsexporter.enabled": True,
        "pods.dced.replicaCount": 1,}
    ssl_cafile_value = "client.truststore.pem"

    test_case = "test_deploy_dced_service"
    utilprocs.log("Test Case: {}".format(test_case))

    utilprocs.log('Starting DCED installation')

    siptls_helm3.setup_security(
        target_namespace_name=NAMESPACE,
        development_version=True,
        settings_dict=helm_settings_dced)
    time.sleep(100)
    siptls_helm3.retrieve_sip_tls_root_cert(
        namespace=NAMESPACE,
        filename=ssl_cafile_value)

    # Collect console logs
    KUBE.get_pod_logs(NAMESPACE, "{}-0".format(DCED_CHART_NAME), test_case)