"""Test ETCD with SIPTLS/KMS"""
# pylint: disable=E0401,W0703,R0201
from base_class import BaseClass, TestcaseMethods

_BASE = BaseClass()
_LOGGER = _BASE.instantiate_log(
    filename='/var/log/tests_certon.log'
)
_TESTM = TestcaseMethods()

import re
import time
import helm3procs
import utilprocs  # pylint: disable=C0413
# this override log function in utilprocs, to use python logging framework
# ------------------------------------------------------
utilprocs.log = _LOGGER.info
# ------------------------------------------------------

import subprocess
import k8sclient
kube = k8sclient.KubernetesClient()

def setup_module():
    """Nose setup fixture"""
    _BASE.custom_setup(tls=True)


def teardown_module():
    """Nose teardown fixture"""
    _BASE.custom_teardown(tls=True)


class TestEtcdCertsON(BaseClass):
    """Class to test ETCD with SIPTLS/KMS integration"""

    def test_01_write_read(self):
        """Test to write and read"""
        self.title("Starting ETCD write/read test")
        self.etcd_write_value()
        self.etcd_read_value()
        self.log.info('Check SIPTLS can create certificates')
        cert_name = self.siptls_create_cert_request()
        self.wait_for_certificate(cert_name=cert_name)

    def test_02_write_read_no_permissions(self):
        """Test to write and read without permissions"""
        self.title("Starting ETCD write/read test without permissions")
        self.etcd_write_value_no_permissions()
        self.etcd_read_value_no_permissions()

    def test_03_pod_deletion(self):
        """Test kill pod"""
        self.title("Starting ETCD pod deletion test")
        self.etcd_kill_pod()
        self.etcd_write_value()
        self.etcd_read_value()
        self.log.info('Check SIPTLS can create certificates')
        cert_name = self.siptls_create_cert_request()
        self.wait_for_certificate(cert_name=cert_name)
        self.restore_pod_name_for_commands()

    def test_04_scale_up(self):
        """Test scale up"""
        self.title("Starting ETCD scale up")
        self.etcd_scale_up(pods_number=5)
        self.etcd_write_value()
        self.etcd_read_value()
        self.log.info('Check SIPTLS can create certificates')
        cert_name = self.siptls_create_cert_request()
        self.wait_for_certificate(cert_name=cert_name)

    def test_05_scale_down(self):
        """Test scale down"""
        self.title("Starting ETCD scale down")
        self.etcd_scale_down(pods_number=3,tls=True)
        self.etcd_write_value()
        self.etcd_read_value()
        self.log.info('Check SIPTLS can create certificates')
        cert_name = self.siptls_create_cert_request()
        self.wait_for_certificate(cert_name=cert_name)

    def test_06_defragmentation(self):
        """Test to check Defragmentation is working fine or not"""
        utilprocs.log("Running Defragmentation test case")
        res = subprocess.check_output("/usr/local/bin/kubectl exec eric-data-distributed-coordinator-ed-0 -c dced -n {} -- bash -c 'unset ETCDCTL_ENDPOINTS; /usr/local/bin/etcdctl defrag --endpoints=:2379 --insecure-skip-tls-verify || true'".format(BaseClass.namespace), shell = True, encoding='utf-8', universal_newlines=True)
        res = str(res)
        utilprocs.log("Output of defragmentation etcdctl command:")
        utilprocs.log(res[1:])
        f1 = open("/var/log/defragmentationCmd.txt", 'w')
        f1.write(res)
        f1.close()

        with open("/var/log/defragmentationCmd.txt", 'r') as fil_1:
            content = fil_1.read()
            if "Finished defragmenting" in content:
                utilprocs.log("Defragmentation Working Successfully!")
            else:
                raise Exception("Error: Defragmentation NOT working!")

    def test_07_zombieProcess(self):
        utilprocs.log("Checking for zombie process")
        temp_str = "/usr/local/bin/kubectl exec -it eric-data-distributed-coordinator-ed-0 -n {0} -c dced  -- bash -c \"ps aux | awk {{'print \$8'}}\""
        op = subprocess.check_output(temp_str.format(BaseClass.namespace), shell = True, encoding='utf-8', universal_newlines=True)
        op = str(op)
        utilprocs.log("Output for zombie process command :"+op)
        utilprocs.log("Len of variable op ="+str(len(op)))
        utilprocs.log("Type of op ="+str(type(op)))
        if 'Z' in op:
            raise Exception("Zombie Process Found!")
        else:
            utilprocs.log("Zombie Process Count = 0")

    def test_08_brAgent_deployment(self):

        GS_ALL_HELM_REPO = "https://arm.sero.gic.ericsson.se/artifactory/proj-adp-gs-all-helm"

        """Deploy PM Server"""
        PM_SERVER_CHART_NAME = "eric-pm-server"
        helm_settings_pm_server = {"global.pullSecret": "armdocker"}
        helm3procs.add_helm_repo(helm_repo=GS_ALL_HELM_REPO)

        utilprocs.log("Starting PM Server Installation")

        helm3procs.helm_install_chart_from_repo_with_dict(
            chart_name=PM_SERVER_CHART_NAME,
            release_name="{}-{}".format(PM_SERVER_CHART_NAME, BaseClass.release_name_random_string),
            helm_repo_name="GS-ALL",
            target_namespace_name=BaseClass.namespace,
            settings_dict=helm_settings_pm_server,
            development_version=False,
        )
        utilprocs.log("PM Server DEPLOYED")

        """Deploys the BRO Service."""
        helm_settings_bro = {"global.pullSecret": "armdocker"}
        BRO_CHART_NAME = "eric-ctrl-bro"

        utilprocs.log('Starting BRO installation')

        helm3procs.add_helm_repo(helm_repo=GS_ALL_HELM_REPO)

        helm3procs.helm_install_chart_from_repo_with_dict(
            chart_name=BRO_CHART_NAME,
            release_name="{}-{}".format(BRO_CHART_NAME, BaseClass.release_name_random_string),
            helm_repo_name="GS-ALL",
            target_namespace_name=BaseClass.namespace,
            settings_dict=helm_settings_bro,
            development_version=False,
        )
        utilprocs.log("BRO DEPLOYED")

        helm3procs.add_helm_repo(helm_repo=BaseClass.ed_helm_repo)

        """Deploying DCED with brAgent enabled"""
        self.upgrade_chart(settings_dict={"global.security.tls.enabled":"true", "brAgent.enabled": "true","global.pullSecret": "armdocker", "appArmorProfile.type": "unconfined", "appArmorProfile.dced.type": "runtime/default", "metricsexporter.enabled": "true"})
        utilprocs.log("brAgent deployed")

    def test_09_print_pod_status(self):
        """Print Pod Status"""
        res = subprocess.check_output("/usr/local/bin/kubectl get po -n {}".format(BaseClass.namespace), shell = True, encoding='utf-8', universal_newlines=True)
        res = str(res)
        utilprocs.log("POD STATUS OUTPUT:")
        utilprocs.log(res)

    def test_10_LabelsAndAnnotations(self):
        """ Test case for checking labels and annotations for DCED and brAgent pod.
            Please Note: DCED should be deployed with below setting with PM server and BRO for this test case:
            settings_dict={"global.security.tls.enabled":"true", "brAgent.enabled": "true","global.pullSecret": "armdocker", "appArmorProfile.type": "unconfined", "appArmorProfile.dced.type": "runtime/default", "metricsexporter.enabled": "true"}
            settings already applied in test_08*
        """

        #Check Lists for Labels and Annotations
        label_check_list_dced = ["app.kubernetes.io/name", "app.kubernetes.io/version", "app.kubernetes.io/instance", "app.kubernetes.io/managed-by"]
        annotations_check_list_dced = ["ericsson.com/product-name", "ericsson.com/product-number", "ericsson.com/product-revision", "container.apparmor.security.beta.kubernetes.io/dced", "container.apparmor.security.beta.kubernetes.io/init", "container.apparmor.security.beta.kubernetes.io/metricsexporter", "prometheus.io/port", "prometheus.io/scrape", "prometheus.io/scheme"]

        label_check_list_brAgent = ["app.kubernetes.io/name", "app.kubernetes.io/version", "app.kubernetes.io/instance", "app.kubernetes.io/managed-by"]
        annotations_check_list_brAgent = ["ericsson.com/product-name", "ericsson.com/product-number", "ericsson.com/product-revision", "container.apparmor.security.beta.kubernetes.io/eric-data-distributed-coordinator-ed-agent"]

        #getting list of pods using k8sclient
        pods = kube.list_pods_from_namespace(BaseClass.namespace)

        """Retrieving brAgent pod name"""
        temp_opt = subprocess.check_output("/usr/local/bin/kubectl get po -n {}".format(BaseClass.namespace), shell = True, encoding='utf-8', universal_newlines=True)
        temp_opt = str(temp_opt).split()
        brAgent_pod_name = list(filter((lambda x: 'eric-data-distributed-coordinator-ed-agent' in x), temp_opt))[0]
        utilprocs.log(brAgent_pod_name)

        # Retrieving labels and annotations for DCED and brAgent pod
        for pod in pods.items:
            pod_name = pod.metadata.name
            if pod_name == "eric-data-distributed-coordinator-ed-0":
                retrieved_label_list_dced = list(pod.metadata.labels)
                retrieved_annotations_list_dced = list(pod.metadata.annotations)
            elif pod_name == brAgent_pod_name:
                retrieved_label_list_brAgent = list(pod.metadata.labels)
                retrieved_annotations_list_brAgent = list(pod.metadata.annotations)

        utilprocs.log("DCED Labels List:")
        utilprocs.log(retrieved_label_list_dced)
        utilprocs.log("DCED Annotations List:")
        utilprocs.log(retrieved_annotations_list_dced)

        utilprocs.log("brAgent Labels List:")
        utilprocs.log(retrieved_label_list_brAgent)
        utilprocs.log("brAgent Annotations List:")
        utilprocs.log(retrieved_annotations_list_brAgent)

        utilprocs.log("Comparing Labels lists for DCED pod")
        _TESTM.compare_lists(label_check_list_dced, retrieved_label_list_dced, "Label")
        utilprocs.log("Comparing Annotations lists for DCED pod")
        _TESTM.compare_lists(annotations_check_list_dced, retrieved_annotations_list_dced, "Annotation")

        utilprocs.log("Comparing Labels lists for brAgent pod")
        _TESTM.compare_lists(label_check_list_brAgent, retrieved_label_list_brAgent, "Label")
        utilprocs.log("Comparing Annotations lists for brAgent pod")
        _TESTM.compare_lists(annotations_check_list_brAgent, retrieved_annotations_list_brAgent, "Annotation")


    def test_11_restart_pod(self):
        op_before_restart = kube.exec_cmd_on_pod(name="eric-data-distributed-coordinator-ed-0", namespace=BaseClass.namespace, command=["ls", "-lart", "/run/secrets/eric-data-distributed-coordinator-ed-ca"], container='dced')
        op1_before_restart = kube.exec_cmd_on_pod(name="eric-data-distributed-coordinator-ed-0", namespace=BaseClass.namespace, command=["ls", "-lart", "/run/secrets/client"], container='dced')

        utilprocs.log("output for ls -lart /run/secrets/eric-data-distributed-coordinator-ed-ca")
        utilprocs.log(op_before_restart)
        utilprocs.log("output for ls -lart /run/secrets/client")
        utilprocs.log(op1_before_restart)
        utilprocs.log("Restarting pod-0")

        """Restarting etcd pod-0"""
        restart_pod = "eric-data-distributed-coordinator-ed-0"
        _TESTM.delete_pod(restart_pod, self.namespace, wait_for_terminating=True)
        self.kube.wait_for_pod_to_start(restart_pod, self.namespace)

        utilprocs.log("Pod-0 Restarted Successfully!")

        op_after_restart = kube.exec_cmd_on_pod(name="eric-data-distributed-coordinator-ed-0", namespace=BaseClass.namespace, command=["ls", "-lart", "/run/secrets/eric-data-distributed-coordinator-ed-ca"], container='dced')
        op1_after_restart = kube.exec_cmd_on_pod(name="eric-data-distributed-coordinator-ed-0", namespace=BaseClass.namespace, command=["ls", "-lart", "/run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert"], container='dced')

        utilprocs.log("output for ls -lart /run/secrets/eric-data-distributed-coordinator-ed-ca")
        utilprocs.log(op_after_restart)
        utilprocs.log("output for ls -lart /run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert")
        utilprocs.log(op1_after_restart)

    def test_12_livenessProbeTest(self):
        """This testcase checks if liveness and readiness probes are working fine or not"""

        utilprocs.log("Executing Readiness Probe Test")

        # Killing entrypoint.sh and etcd process in pod-0
        utilprocs.log("Killing etcd and entrypoint.sh process in pod-0")
        kill_command_1 = "/usr/local/bin/kubectl exec -it eric-data-distributed-coordinator-ed-0 -n {} -c dced -- bash -c \"pkill -9 entrypoint.sh\""
        kill_command_2 = "/usr/local/bin/kubectl exec -it eric-data-distributed-coordinator-ed-0 -n {} -c dced -- bash -c \"pkill -9 etcd\""
        subprocess.check_output(kill_command_1.format(BaseClass.namespace), shell = True, encoding='utf-8', universal_newlines=True)
        subprocess.check_output(kill_command_2.format(BaseClass.namespace), shell = True, encoding='utf-8', universal_newlines=True)
        time.sleep(240)

        subprocess.check_output("/usr/local/bin/kubectl logs eric-data-distributed-coordinator-ed-0 -c dced -n {} > dced_readiness_pod0_logs.txt".format(BaseClass.namespace), shell = True, encoding='utf-8', universal_newlines=True)
        probe_status=0
        with open("dced_readiness_pod0_logs.txt", "r", encoding="utf-8") as my_file:
            for line in my_file:
                if "Readiness probe failed" in line:
                    utilprocs.log("Readiness probe working fine! eric-data-distributed-coordinator-ed-0 pod not accepting traffic.")
                    probe_status = 1
                    break

        if probe_status != 1:
            raise Exception("Readiness Probe Check Failed!!!")

        #Restarting pod-0 for restarting killed processes.
        _TESTM.delete_pod("eric-data-distributed-coordinator-ed-0", BaseClass.namespace, wait_for_terminating=True)
        self.kube.wait_for_pod_to_start("eric-data-distributed-coordinator-ed-0", BaseClass.namespace)

        utilprocs.log("Executing Liveness Probe Test")
        cmd = "/usr/local/bin/kubectl exec -it eric-data-distributed-coordinator-ed-0 -n {0} -c dced  -- bash -c \"echo 'dead' > /data/etcd.liveness\""
        subprocess.check_output(cmd.format(BaseClass.namespace), shell = True, encoding='utf-8', universal_newlines=True)
        op = kube.exec_cmd_on_pod(name="eric-data-distributed-coordinator-ed-0", namespace=BaseClass.namespace, command=["cat", "/data/etcd.liveness"], container='dced')
        utilprocs.log(op)
        time.sleep(120)
        try:
            kube.wait_for_pod_to_start("eric-data-distributed-coordinator-ed-0", BaseClass.namespace)
            self.test_09_print_pod_status()
            utilprocs.log("Liveness Probe Working!")
        except Exception:
            utilprocs.log("Liveness Probe Check Failed!")

    def test_13_validate_log_timestamps(self):
        """Test case for checking if timestamp format is complaint to
           logging schema in DCED and brAgent pod logs."""

        #Checking timestamp in DCED pod log
        subprocess.check_output("/usr/local/bin/kubectl logs eric-data-distributed-coordinator-ed-0 -c dced -n {} > dced_pod_logs.txt".format(BaseClass.namespace), shell = True, encoding='utf-8', universal_newlines=True)
        _TESTM.validate_timestamps("dced_pod_logs.txt", "eric-data-distributed-coordinator-ed-0")

        """Retrieving brAgent pod name"""
        cmd = subprocess.check_output("/usr/local/bin/kubectl get po -n {}".format(BaseClass.namespace), shell = True, encoding='utf-8', universal_newlines=True)
        cmd = str(cmd).split()
        brAgent_pod_name = list(filter((lambda x: 'eric-data-distributed-coordinator-ed-agent' in x), cmd))[0]
        utilprocs.log(brAgent_pod_name)

        # Checking timestamp in brAgent pod log
        subprocess.check_output("/usr/local/bin/kubectl logs {0} -n {1} > brAgent_pod_logs.txt".format(brAgent_pod_name, BaseClass.namespace), shell = True, encoding='utf-8', universal_newlines=True)
        _TESTM.validate_timestamps("brAgent_pod_logs.txt", brAgent_pod_name)

    def test_14_sigKillTest(self):
        # We are already complaint with SIGTERM handling
        cmd = "/usr/local/bin/kubectl delete pods eric-data-distributed-coordinator-ed-0 eric-data-distributed-coordinator-ed-1 eric-data-distributed-coordinator-ed-2 --force --grace-period=0 -n {}"
        utilprocs.log("Sending SIGKILL command...")
        subprocess.check_output(cmd.format(BaseClass.namespace), shell = True, encoding='utf-8', universal_newlines=True)
        time.sleep(6)
        kube.wait_for_pod_to_start("eric-data-distributed-coordinator-ed-0", BaseClass.namespace)
        kube.wait_for_pod_to_start("eric-data-distributed-coordinator-ed-1", BaseClass.namespace)
        kube.wait_for_pod_to_start("eric-data-distributed-coordinator-ed-2", BaseClass.namespace)
        utilprocs.log("SIGKILL COMMAND HANDLED SUCCESSFULLY!")

    # def test_13_multiple_upgrade(self):
    #     utilprocs.log("Upgrading chart to PRA version")
    #     self.etcd_upgrade(pra=True)
    #     utilprocs.log("Performing upgrade to latest development version: 1st time")
    #     self.etcd_upgrade()
    #     utilprocs.log("Performing upgrade to latest development version: 2nd time")
    #     self.etcd_upgrade()
    #     utilprocs.log("Multiple upgrades to same version Successfull!")

    def test_15_delete_dependency_pod(self):
        # Delete Pod with dependencies
        siptls_pods_list1 = _TESTM.get_siptls_pod_name()

        utilprocs.log("Deleting SIP-TLS Pod-1: " + siptls_pods_list1[0])
        self.kube.delete_pod(siptls_pods_list1[0], BaseClass.namespace, wait_for_terminating=False)

        utilprocs.log("Deleting SIP-TLS Pod-2: " + siptls_pods_list1[1])
        self.kube.delete_pod(siptls_pods_list1[1], BaseClass.namespace, wait_for_terminating=False)

        utilprocs.log("Deleting KMS Pod: eric-sec-key-management-main-0")
        kms_pod="eric-sec-key-management-main-0"
        self.kube.delete_pod(kms_pod, BaseClass.namespace, wait_for_terminating=False)

        time.sleep(10)
        siptls_pods_list2 = _TESTM.get_siptls_pod_name()
        kube.wait_for_pod_to_start(siptls_pods_list2[0],BaseClass.namespace)
        kube.wait_for_pod_to_start(siptls_pods_list2[1],BaseClass.namespace)
        kube.wait_for_pod_to_start(kms_pod,BaseClass.namespace)

        utilprocs.log("DEPENDENCY POD DELETION IS SUCCESSFULLY!")

    def test_16_graceful_pod_deletion(self):
        # Simultaneously graceful pod deletion of all workloads of an ADP service
        cmd = "/usr/local/bin/kubectl delete pods eric-data-distributed-coordinator-ed-0 eric-data-distributed-coordinator-ed-1 eric-data-distributed-coordinator-ed-2 -n {}"
        utilprocs.log("deleting all pods by default grace period of 30s")
        subprocess.check_output(cmd.format(BaseClass.namespace), shell = True, encoding='utf-8', universal_newlines=True)

        kube.wait_for_pod_to_start("eric-data-distributed-coordinator-ed-0", BaseClass.namespace)
        kube.wait_for_pod_to_start("eric-data-distributed-coordinator-ed-1", BaseClass.namespace)
        kube.wait_for_pod_to_start("eric-data-distributed-coordinator-ed-2", BaseClass.namespace)
        utilprocs.log("GRACEFUL POD DELETION IS SUCCESSFULLY!")