"""Python file to define the Test cases"""
import time
import utilprocs
import helm3procs
from etcd import Client
from base_class import BaseClass
from base_class import Span
import k8sclient
import subprocess
# from base_char import Connect_ETCD

kube = k8sclient.KubernetesClient()

_BASE = BaseClass()
_LOGGER = _BASE.instantiate_log(filename='/var/log/testdeploy.log')

utilprocs.log = _LOGGER.info

def root_secret_cleanup():
    try:
        _BASE.delete_secret(_BASE.ed_secret_name)
    except Exception:
        # no need to do anything
        utilprocs.log("Secret {} deleted".format(_BASE.ed_secret_name))
        pass

def setup_module():
    """Nose setup fixture"""
    root_secret_cleanup()
    _BASE.custom_setup(tls=True)


def teardown_module():
    """Nose teardown fixture"""
    _BASE.custom_teardown(tls=True)

"""Class for implementing charateristics test cases"""
class TestFunctional(BaseClass):

    """Function to calculate the deployment time"""
    def test_01_deployment_time(self):
        desc = "Pod Deployment"
        startup_span = Span("Startup-dced", {"phase": "restart", "description": desc})
        #etcd_install
        restart_pod = "eric-data-distributed-coordinator-ed-0"
        self.kube.delete_pod(restart_pod, self.namespace, wait_for_terminating=True)
        self.kube.wait_for_pod_to_start(restart_pod, self.namespace)

        end = int(time.time())
        startup_span.tags = {"phase": "deploy", "description": "Time from the point where the service is allowed to start to the point all workloads are ready.", "labels": ["LCM"] }
        utilprocs.log(startup_span.finish())

    """Function to calculate the restart time"""
    def test_02_restart_time(self):

        desc = "Restart a DCED pod"

        restart_span = Span("PodEviction-dced", {"phase": "restart", "description": desc})

        restart_pod = "eric-data-distributed-coordinator-ed-0"
        self.kube.delete_pod(restart_pod, self.namespace, wait_for_terminating=True)
        self.kube.wait_for_pod_to_start(restart_pod, self.namespace)

        end = int(time.time())
        restart_span.tags = {"phase": "restart", "description": "Time taken from the point where a pod is evicted until the service instance is fully ready : " + str(end - restart_span.start) + " seconds", "labels": ["LCM"] }
        utilprocs.log(restart_span.finish())


    """Funtion to calculate upgrade time"""
    def test_03_upgrade_time(self):

        desc = "upgrade DCED"

        cmd_curl = [
            "curl",
            "-vv",
            "--cacert",
            "/data/combinedca/ca.crt",
            "--cert",
            "/run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert/tls.crt",
            "--key",
            "/run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert/tls.key",
            "https://eric-data-distributed-coordinator-ed:2379/metrics"
        ]

        #Getting PreUpgrade Latency
        op = kube.exec_cmd_on_pod(name="eric-data-distributed-coordinator-ed-0", namespace=BaseClass.namespace, command=cmd_curl)
        f1 = open("/var/log/metrics.txt", 'w')
        f1.write(op)
        f1.close()

        utilprocs.log("Printing value of variable op:")
        utilprocs.log(op)
        utilprocs.log(type(op))

        wal_sync = subprocess.check_output('grep etcd_disk_wal_fsync_duration_seconds_bucket /var/log/metrics.txt|tail -1|cut -d" " -f2', shell = True, encoding='utf-8', universal_newlines=True)

        utilprocs.log("Printing wal_sync")
        utilprocs.log(wal_sync)
        wal_fsync_p99 = (int(wal_sync) * 99) /100
        utilprocs.log("wal_fsync_p99:")
        utilprocs.log(wal_fsync_p99)

        for line in reversed(list(open('/var/log/metrics.txt', 'r'))):
            if 'etcd_disk_wal_fsync_duration_seconds_bucket' in line:
                value = line.split(' ')[1]
                if int(value) <= wal_fsync_p99:
                    pre_upgrade_latency=int(float(line.split('"')[1]))
                    utilprocs.log("wal_fsync p99 duration is")
                    utilprocs.log(pre_upgrade_latency)
                    break

        upgrade_span = Span("upgrade-dced", {"phase": "upgrade", "description": desc})
        #Upgrade
        self.upgrade_chart(settings_dict={"global.security.tls.enabled":"true","global.pullSecret": "armdocker"})
        end = int(time.time())

        #Getting PostUpgrade Latency
        op = kube.exec_cmd_on_pod(name="eric-data-distributed-coordinator-ed-0", namespace=BaseClass.namespace, command=cmd_curl)
        f2 = open("/var/log/metrics.txt", 'w')
        f2.write(op)
        f2.close()

        utilprocs.log("Printing value of variable op:")
        utilprocs.log(op)
        utilprocs.log(type(op))

        wal_sync = subprocess.check_output('grep etcd_disk_wal_fsync_duration_seconds_bucket /var/log/metrics.txt|tail -1|cut -d" " -f2', shell = True, encoding='utf-8', universal_newlines=True)


        utilprocs.log("Printing wal_sync")
        utilprocs.log(wal_sync)
        wal_fsync_p99 = (int(wal_sync) * 99) /100
        utilprocs.log("wal_fsync_p99:")
        utilprocs.log(wal_fsync_p99)

        for line in reversed(list(open('/var/log/metrics.txt', 'r'))):
            if 'etcd_disk_wal_fsync_duration_seconds_bucket' in line:
                value = line.split(' ')[1]
                if int(value) <= wal_fsync_p99:
                    post_upgrade_latency=int(float(line.split('"')[1]))
                    utilprocs.log("wal_fsync p99 duration is")
                    utilprocs.log(post_upgrade_latency)
                    break

        #Latency increase %
        latency_increase = 0
        if pre_upgrade_latency < post_upgrade_latency and pre_upgrade_latency!=0:
            latency_increase = ((post_upgrade_latency-pre_upgrade_latency)/pre_upgrade_latency)*100

        packets_sent = subprocess.check_output('grep ^etcd_network_client_grpc_sent_bytes_total /var/log/metrics.txt|cut -d" " -f2', shell = True, encoding='utf-8', universal_newlines=True)
        packets_received = subprocess.check_output('grep ^etcd_network_client_grpc_received_bytes_total /var/log/metrics.txt|cut -d" " -f2', shell = True, encoding='utf-8', universal_newlines=True)
        packets_sent = int(packets_sent)
        packets_received = int(packets_received)

        utilprocs.log("packets_sent")
        utilprocs.log(packets_sent)
        utilprocs.log("packets_received")
        utilprocs.log(packets_received)

        #Calculating packet loss %
        packet_loss = 0
        if packets_received > packets_sent:
            packet_loss = ((packets_received-packets_sent)/packets_received)*100

        desc = "Time from the point 'helm upgrade' is executed until the upgrade is completed and service instance is fully ready."
        upgrade_span.tags = {"phase": "upgrade", "description": desc, "labels": ["LCM"], "traffic": {"service-down": str(0)+"s","traffic-loss": str(packet_loss)+"%","traffic-latency": str(latency_increase)+"%"} }
        utilprocs.log(upgrade_span.finish())


    """Funtion to calculate rollback time"""
    def test_04_rollback(self):

        desc = "rollback DCED"

        #get last PRA version
        pra_version = helm3procs.get_latest_chart_version(self.ed_chart_name,helm_repo_name='GS-ALL')

        cmd_curl = [
            "curl",
            "-vv",
            "--cacert",
            "/data/combinedca/ca.crt",
            "--cert",
            "/run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert/tls.crt",
            "--key",
            "/run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert/tls.key",
            "https://eric-data-distributed-coordinator-ed:2379/metrics"
        ]

        #Getting PreRollback Latency
        op = kube.exec_cmd_on_pod(name="eric-data-distributed-coordinator-ed-0", namespace=BaseClass.namespace, command=cmd_curl)
        f1 = open("/var/log/metrics.txt", 'w')
        f1.write(op)
        f1.close()

        utilprocs.log("Printing value of variable op:")
        utilprocs.log(op)
        utilprocs.log(type(op))

        wal_sync = subprocess.check_output('grep etcd_disk_wal_fsync_duration_seconds_bucket /var/log/metrics.txt|tail -1|cut -d" " -f2', shell = True, encoding='utf-8', universal_newlines=True)


        utilprocs.log("Printing wal_sync")
        utilprocs.log(wal_sync)
        wal_fsync_p99 = (int(wal_sync) * 99) /100
        utilprocs.log("wal_fsync_p99:")
        utilprocs.log(wal_fsync_p99)

        for line in reversed(list(open('/var/log/metrics.txt', 'r'))):
            if 'etcd_disk_wal_fsync_duration_seconds_bucket' in line:
                value = line.split(' ')[1]
                if int(value) <= wal_fsync_p99:
                    pre_rollback_latency=int(float(line.split('"')[1]))
                    utilprocs.log("wal_fsync p99 duration is")
                    utilprocs.log(pre_rollback_latency)
                    break

        rollback_span = Span("Downgrade-dced", {"phase": "rollback", "description": desc})
        #Rollback
        self.upgrade_chart(settings_dict={"global.security.tls.enabled":"true","global.pullSecret": "armdocker"},helm_chart_version=pra_version, repo_name='GS-ALL')
        end = int(time.time())

        #Getting PostRollback Latency
        op = kube.exec_cmd_on_pod(name="eric-data-distributed-coordinator-ed-0", namespace=BaseClass.namespace, command=cmd_curl)
        f2 = open("/var/log/metrics.txt", 'w')
        f2.write(op)
        f2.close()

        utilprocs.log("Printing value of variable op:")
        utilprocs.log(op)
        utilprocs.log(type(op))

        wal_sync = subprocess.check_output('grep etcd_disk_wal_fsync_duration_seconds_bucket /var/log/metrics.txt|tail -1|cut -d" " -f2', shell = True, encoding='utf-8', universal_newlines=True)


        utilprocs.log("Printing wal_sync")
        utilprocs.log(wal_sync)
        wal_fsync_p99 = (int(wal_sync) * 99) /100
        utilprocs.log("wal_fsync_p99:")
        utilprocs.log(wal_fsync_p99)

        for line in reversed(list(open('/var/log/metrics.txt', 'r'))):
            if 'etcd_disk_wal_fsync_duration_seconds_bucket' in line:
                value = line.split(' ')[1]
                if int(value) <= wal_fsync_p99:
                    post_rollback_latency=int(float(line.split('"')[1]))
                    utilprocs.log("wal_fsync p99 duration is")
                    utilprocs.log(post_rollback_latency)
                    break

        latency_increase = 0
        if pre_rollback_latency < post_rollback_latency and pre_rollback_latency!=0:
            latency_increase = ((post_rollback_latency-pre_rollback_latency)/pre_rollback_latency)*100

        packets_sent = subprocess.check_output('grep ^etcd_network_client_grpc_sent_bytes_total /var/log/metrics.txt|cut -d" " -f2', shell = True, encoding='utf-8', universal_newlines=True)
        packets_received = subprocess.check_output('grep ^etcd_network_client_grpc_received_bytes_total /var/log/metrics.txt|cut -d" " -f2', shell = True, encoding='utf-8', universal_newlines=True)
        packets_sent = int(packets_sent)
        packets_received = int(packets_received)

        utilprocs.log("packets_sent")
        utilprocs.log(packets_sent)
        utilprocs.log("packets_received")
        utilprocs.log(packets_received)

        #Calculating packet loss %
        packet_loss = 0
        if packets_received > packets_sent:
            packet_loss = ((packets_received-packets_sent)/packets_received)*100

        desc = "Time from the point 'helm upgrade' is executed until the downgrade is completed and service instance is fully ready."
        rollback_span.tags = {"phase": "rollback", "description": desc, "labels": ["LCM"], "traffic": {"service-downtime": str(0)+"s","traffic-loss": str(packet_loss)+"%","traffic-latency": str(latency_increase)+"%"}}
        utilprocs.log(rollback_span.finish())


    """Funtion to calculate duration of pods scaling up and down"""
    def test_05_scalability_duration(self):

        """Scale up to 5 pods"""
        desc = "Scale up pods"
        scaleup_span = Span("scaleOut-dced", {"phase": "scale up", "description": desc})
        self.upgrade_chart(settings_dict={"global.security.tls.enabled":"true","replicaCount":5,"global.pullSecret": "armdocker"})
        end = int(time.time())
        utilprocs.log("Pods scaled to 5")
        scaleup_span.tags = {"phase": "scale up", "description": "Time to increase the number of instances of the minimum possible capacity increase to a higher number : " + str(end - scaleup_span.start) + " seconds", "labels": ["LCM"] }
        utilprocs.log(scaleup_span.finish())

        """Scale down to 3 pods"""
        desc = "Scale down pods"
        scaledown_span = Span("scaleIn-dced", {"phase": "scale down", "description": desc})
        utilprocs.log("Scaling down pods to 3")
        self.upgrade_chart(settings_dict = {"global.security.tls.enabled":"true","replicaCount":3,"global.pullSecret": "armdocker"})
        end = int(time.time())
        utilprocs.log("Pods scaled back to 3")
        scaledown_span.tags = {"phase": "scale down", "description": "Time to decrease number of instances of the minimum possible capacity decrease: " + str(end - scaledown_span.start) + " seconds", "labels": ["LCM"] }
        utilprocs.log(scaledown_span.finish())