# pylint: disable=C0330,C0111,R0912,W0104,W0631,E0401,R0913,R0914
"""BaseClass for running ETCD tests"""
import logging
import random
import os
import time
import json
import re
import string  # pylint: disable=W0402
import ast
import base64
from base64 import b64encode
from uuid import uuid4

import yaml
from kubernetes import client
from kubernetes.client import Configuration
from kubernetes.client.rest import ApiException
from kubernetes import config
from kubernetes.config import ConfigException

import utilprocs
import helm3procs
import subprocess
import k8sclient
import siptls_helm3


class BaseClass:
    """Utility class for ETCD tests"""

    revision_number = 1
    k8s_conf = Configuration()
    k8s_conf.assert_hostname = False
    Configuration.set_default(k8s_conf)
    kube = k8sclient.KubernetesClient()
    k8s_delete_body = client.V1DeleteOptions()

    namespace = os.environ.get("kubernetes_namespace")

    ed_helm_repo = os.environ.get("helm_repo")
    ed_chart_name = "eric-data-distributed-coordinator-ed"
    release_name_random_string = str(uuid4()).split("-")[0]
    ed_release_name = "{}-{}".format(ed_chart_name, release_name_random_string)
    ed_chart_archive = os.environ.get("chart_archive")
    ed_secret_name = "eric-data-distributed-coordinator-creds"

    ed_helm_server = os.environ.get("etcd_helm_server")
    ed_global_path = os.environ.get("etcd_helm_global_path")
    ed_helm_repo_global = "{}/{}".format(ed_helm_server, ed_global_path)
    ed_baseline_chart_version = os.environ.get("baseline_chart_version")
    ed_pod_name_for_commands = "eric-data-distributed-coordinator-ed-0"
    ed_command_line = "/usr/local/bin/etcdctl"
    ed_user_service_username = "etcd-cicd"
    ed_user_service_password = "etcd-cicd-pass"
    ed_user_test_username = "test-user"
    ed_user_test_password = "test-user-pass"
    ed_root_password_key = "etcdpasswd"

    helm_settings = {"global.registry.pullSecret": "armdocker","global.pullSecret": "armdocker"}

    ed_certoff_set_options = {
        "service.endpoints.dced.tls.verifyClientCertificate": "optional",
        "global.security.tls.enabled": "false",
        "service.endpoints.dced.tls.enforced": "optional",
        "env.dced.ETCDCTL_DEBUG": "false",
        "global.pullSecret": "armdocker",
        **helm_settings,
    }

    ed_certoff_pra_set_options = {
        "service.endpoints.dced.tls.verifyClientCertificate": "optional",
        "global.security.tls.enabled": "false",
        "service.endpoints.dced.tls.enforced": "optional",
        "env.dced.ETCDCTL_DEBUG": "false",
        "global.pullSecret": "armdocker",
        **helm_settings,
    }

    ed_certon_set_options = {
        "service.endpoints.dced.tls.verifyClientCertificate": "required",
        "global.security.tls.enabled": "true",
        "service.endpoints.dced.tls.enforced": "required",
        "env.dced.ETCDCTL_DEBUG": "false",
        "global.pullSecret": "armdocker",
        **helm_settings,
    }

    ed_certon_pra_set_options = {
        "service.endpoints.dced.tls.verifyClientCertificate": "required",
        "global.security.tls.enabled": "true",
        "service.endpoints.dced.tls.enforced": "required",
        "env.dced.ETCDCTL_DEBUG": "false",
        "global.pullSecret": "armdocker",
        **helm_settings,
    }


    test_cert_name = 'test-cert-'
    test_cert_name_incr = 0
    log = logging.getLogger(__name__)

    @classmethod
    def helm_upgrade_with_chart_archive_with_options(
        cls,
        baseline_release_name,
        chart_archive,
        pod_number=3,
        pod_rep_string="pods.dced.replicaCount",
        tls: bool = False,
    ):
        # get the release name that needs to be upgraded
        try:
            release_names = utilprocs.execute_command(
                "helm ls"
                + " --namespace="
                + cls.namespace
                + " -q"
            ).rstrip()
        except Exception as e_obj:
            cls.log.error(str(e_obj))
            raise
        if not release_names or baseline_release_name not in release_names:
            raise ValueError(
                "Unable to find expected baseline release: " + baseline_release_name
            )
        # define the command for upgrade
        upgrade_command = (
            "helm upgrade --wait %s %s "
            "--timeout 20000s --reuse-values --set %s=%d"
            % (
                baseline_release_name,
                chart_archive,
                pod_rep_string,
                pod_number,
            )
        )

        if tls:
            upgrade_command += (
            " --set service.endpoints.etcd.tls.verifyClientCertificate=required")

        try:
            utilprocs.execute_command(upgrade_command)
            time.sleep(30)
        except Exception as e_obj:
            cls.log.error(str(e_obj))
            raise

   # method added to switch helm parameters between pra/devel and RC versions.
   # To be modified and and eventually removed when devel version has
   # changed parameters in place (1.4.0 ).
    @classmethod
    def helm_tls_switch_pra_dev(cls, pra, devel, tls):
        if not pra and not devel:
            if tls:
                set_tls_options = cls.ed_certon_set_options
            else:
                set_tls_options = cls.ed_certoff_set_options
        else:
            if tls:
                set_tls_options = cls.ed_certon_pra_set_options
            else:
                set_tls_options = cls.ed_certoff_pra_set_options
        return set_tls_options

    @classmethod
    def etcd_install(cls, pra: bool = False, devel: bool = False, tls: bool = False):
        """Install ETCD with different options
        Args:
            pra: use PRA version
            devel: use DEVEL version
            tls: install using options for integration with SIPTLS/KMS
        """
        chart_version = cls.ed_baseline_chart_version
        helm_repo = cls.ed_helm_repo
        development_version = False
        if pra:
            chart_version = None
            helm_repo = cls.ed_helm_repo_global
        if devel:
            development_version = True
            chart_version = None
            helm_repo = cls.ed_helm_repo_global

        set_options = cls.helm_tls_switch_pra_dev(pra=pra, devel=devel, tls=tls)
        #set_options = cls.ed_certoff_set_options
        #if tls:
        #    set_options = cls.ed_certon_set_options

        cls.log.info("Add BASELINE helm repo")
        helm3procs.add_helm_repo(helm_repo=helm_repo)
        chart_version_log = cls.ed_baseline_chart_version
        if pra:
            chart_version_log = helm3procs.get_latest_chart_version(
                helm_chart_name=cls.ed_chart_name, development_version=False
            )
        if devel:
            chart_version_log = helm3procs.get_latest_chart_version(
                helm_chart_name=cls.ed_chart_name, development_version=True
            )

        if not pra and not devel:
            cls.log.info("Download chart from repo")
            try:
                helm3procs.helm_get_chart_from_repo(
                    chart_name=cls.ed_chart_name,
                    chart_version=chart_version,
                    debug_boolean=False,
                )
            except Exception as e_obj:
                cls.log.error(str(e_obj))
                raise

        cls.log.info("Install - ETCD version: {}".format(chart_version_log))

        try:
            helm3procs.helm_install_chart_from_repo_with_dict(
                chart_name=cls.ed_chart_name,
                release_name=cls.ed_release_name,
                target_namespace_name=cls.namespace,
                chart_version=chart_version,
                settings_dict=set_options,
                debug_boolean=False,
                development_version=development_version,
            )
            time.sleep(30)
        except Exception as e_obj:
            cls.log.error(str(e_obj))
            raise

        cls.log.info("Wait for all resources to be up")
        try:
            helm3procs.helm_wait_for_deployed_release_to_appear(
                expected_release_name=cls.ed_release_name,
                target_namespace_name=cls.namespace
            )
        except Exception as e_obj:
            cls.log.error(str(e_obj))
            raise
        time.sleep(25)

    @classmethod
    def etcd_upgrade(cls, pra: bool = False, devel: bool = False, tls: bool = False):
        """Upgrade ETCD with different options
        Args:
            pra: use PRA version
            devel: use DEVEL version
            tls: upgrade using options for integration with SIPTLS/KMS
        """
        chart_version = cls.ed_baseline_chart_version
        helm_repo = cls.ed_helm_repo
        development_version = False
        if pra:
            chart_version = None
            helm_repo = cls.ed_helm_repo_global
        if devel:
            development_version = True
            chart_version = None
            helm_repo = cls.ed_helm_repo_global

        set_options = cls.helm_tls_switch_pra_dev(pra=pra, devel=devel, tls=tls)
        #set_options = cls.ed_certoff_set_options
        #if tls:
            #set_options = cls.ed_certon_set_options

        cls.log.info("Add BASELINE helm repo")
        helm3procs.add_helm_repo(helm_repo=helm_repo)
        chart_version_log = cls.ed_baseline_chart_version
        if pra:
            chart_version_log = helm3procs.get_latest_chart_version(
                helm_chart_name=cls.ed_chart_name, development_version=False
            )
        if devel:
            chart_version_log = helm3procs.get_latest_chart_version(
                helm_chart_name=cls.ed_chart_name, development_version=True
            )

        cls.log.info("Upgrade - ETCD version: {}".format(chart_version_log))

        try:
            helm3procs.helm_upgrade_with_chart_repo_with_dict(
                helm_chart_name=cls.ed_chart_name,
                helm_release_name=cls.ed_release_name,
                target_namespace_name=cls.namespace,
                chart_version=chart_version,
                settings_dict=set_options,
                debug_boolean=False,
                development_version=development_version,
            )
            time.sleep(30)
        except Exception as e_obj:
            cls.log.error(str(e_obj))
            raise

        cls.log.info("Wait for all resources to be up")
        try:
            helm3procs.helm_wait_for_deployed_release_to_appear(
                expected_release_name=cls.ed_release_name,
                target_namespace_name=cls.namespace
            )
        except Exception as e_obj:
            cls.log.error(str(e_obj))
            raise
        time.sleep(25)

    @classmethod
    def get_root_password(cls):
        secrets = cls.kube.get_namespace_secrets(cls.namespace, [cls.ed_secret_name])
        cls.log.info("Secrets: {}".format(secrets))
        root_password = base64.b64decode(
            secrets[0].data[cls.ed_root_password_key]
        ).decode("UTF-8")

        return root_password

    @classmethod
    def create_users(cls, tls: bool = False):
        cls.log.info("Create user and grant permissions")

        root_password = cls.get_root_password()

        if tls:
            root_user_arg = "--user=root:"
        else:
            root_user_arg = "--user=root:{}".format(root_password)

        cmds = [
            [
                cls.ed_command_line,
                root_user_arg,
                "user",
                "add",
                "{}:{}".format(
                    cls.ed_user_service_username, cls.ed_user_service_password
                ),
            ],
            [
                cls.ed_command_line,
                root_user_arg,
                "role",
                "add",
                "{}".format(cls.ed_user_service_username),
            ],
            [
                cls.ed_command_line,
                root_user_arg,
                "user",
                "grant-role",
                "{}".format(cls.ed_user_service_username),
                "{}".format(cls.ed_user_service_username),
            ],
            [
                cls.ed_command_line,
                root_user_arg,
                "role",
                "grant-permission",
                "{}".format(cls.ed_user_service_username),
                "--prefix=true",
                "readwrite",
                "/{}".format(cls.ed_user_service_username),
            ],
            [
                cls.ed_command_line,
                root_user_arg,
                "user",
                "add",
                "{}:{}".format(cls.ed_user_test_username, cls.ed_user_test_password),
            ],
        ]

        try:
            for cmd in cmds:
                cls.kube.exec_cmd_on_pod(
                    cls.ed_pod_name_for_commands, cls.namespace, cmd
                )
        except Exception as e_obj:
            cls.log.error(str(e_obj))
            cls.kube.get_pod_logs(cls.namespace)
            raise

    @classmethod
    def etcd_write_value(cls):
        cls.log.info("Create key value pairs")
        # processing key value pair write
        write = [
            cls.ed_command_line,
            "--user={}:{}".format(cls.ed_user_service_username,cls.ed_user_service_password),
            "put",
            "/{}".format(cls.ed_user_service_username),
            "HelloWorld",
        ]

        try:
            cls.kube.exec_cmd_on_pod(cls.ed_pod_name_for_commands, cls.namespace, write)
        except Exception as e_obj:
            cls.log.error(str(e_obj))
            cls.kube.get_pod_logs(cls.namespace)
            raise

    @classmethod
    def etcd_read_value(cls):
        read = [
            cls.ed_command_line,
            "--user={}:{}".format(cls.ed_user_service_username,cls.ed_user_service_password),
            "get",
            "/{}".format(cls.ed_user_service_username),
        ]

        try:
            values = cls.kube.exec_cmd_on_pod(
                cls.ed_pod_name_for_commands, cls.namespace, read
            ).split()
        except Exception as e_obj:
            cls.log.error(str(e_obj))
            cls.kube.get_pod_logs(cls.namespace)
            raise

        cls.log.info("Gathering test results")
        if all(
            x in values
            for x in ["/{}".format(cls.ed_user_service_username), "HelloWorld"]
        ):
            cls.log.info("Test passed with key value pair {}".format(values[-2:]))
        else:
            cls.log.info("Test not getting desired result")

        try:
            assert all(
                x in values
                for x in ["/{}".format(cls.ed_user_service_username), "HelloWorld"]
            )
        except AssertionError:
            cls.kube.get_pod_logs(cls.namespace)
            raise

    @classmethod
    def etcd_read_value_no_permissions(cls):
        cls.log.info("Test if key is accessible without permissions")
        cmd = [
            cls.ed_command_line,
            "--user={}:{}".format(cls.ed_user_test_username, cls.ed_user_test_password),
            "get",
            "/{}".format(cls.ed_user_service_username),
        ]

        try:
            values = cls.kube.exec_cmd_on_pod(
                cls.ed_pod_name_for_commands, cls.namespace, cmd
            ).split()
        except Exception as e_obj:
            cls.log.error(str(e_obj))
            cls.kube.get_pod_logs(cls.namespace)
            raise

        if not all(
            y in values
            for y in ["/{}".format(cls.ed_user_service_username), "HelloWorld"]
        ):
            cls.log.info("No permissions, key is not accesible")
        else:
            cls.log.info("Key retrived without having permissions on it")

        try:
            assert not all(
                y in values
                for y in ["/{}".format(cls.ed_user_service_username), "HelloWorld"]
            )
        except AssertionError:
            cls.kube.get_pod_logs(cls.namespace)
            raise

    @classmethod
    def etcd_write_value_no_permissions(cls):
        cls.log.info("Write to a key that a user cannot access")
        cmd = [
            cls.ed_command_line,
            "--user={}:{}".format(cls.ed_user_service_username, cls.ed_user_service_password),
            "put",
            "/etcd",
            "HelloWorld",
        ]

        try:
            res5 = cls.kube.exec_cmd_on_pod(
                cls.ed_pod_name_for_commands, cls.namespace, cmd
            ).split()
        except Exception as e_obj:
            cls.log.error(str(e_obj))
            cls.kube.get_pod_logs(cls.namespace)
            raise

        if all(z in res5[-2:] for z in ["permission", "denied"]):
            cls.log.info("User cannot write to a key without access")
        else:
            cls.log.info("User wrote to a key without access")

        try:
            assert all(z in res5[-2:] for z in ["permission", "denied"])
        except AssertionError:
            cls.kube.get_pod_logs(cls.namespace)
            raise

    @classmethod
    def etcd_delete_value(cls,tls: bool = False):
        cls.log.info("Deleting key value pair")
        if tls:
            root_user_arg = "--user=root:"
        else:
            root_user_arg = "--user={}:{}".format( cls.ed_user_service_username, cls.ed_user_service_password)
        delete = [
            cls.ed_command_line,
            root_user_arg,
            "del",
            "/{}".format(cls.ed_user_service_username),
        ]

        try:
            values = cls.kube.exec_cmd_on_pod(
                cls.ed_pod_name_for_commands, cls.namespace, delete
            ).split()
        except Exception as e_obj:
            cls.log.error(str(e_obj))
            cls.kube.get_pod_logs(cls.namespace)
            raise

        if values[-1] == "1":
            cls.log.info("Key value pair has been deleted")
        else:
            cls.log.info("Key value pair has NOT been deleted")

        try:
            assert values[-1] == "1"
        except AssertionError:
            cls.kube.get_pod_logs(cls.namespace)
            raise

    @classmethod
    def etcd_kill_pod(cls):
        cmd = "helm list -q --namespace {}".format(cls.namespace)
        deployments = utilprocs.execute_command(cmd)
        for i in deployments.splitlines(False):
            if cls.ed_chart_name == i:
                break

        cmd = "helm status {}".format(cls.ed_release_name)
        utilprocs.execute_command(cmd)

        cls.log.info("Test Pod Delete get stateful set")
        pods = cls.kube.get_statefulset_pods(cls.ed_chart_name, cls.namespace)
        pods_index = random.randint(0, len(pods) - 1)

        if pods_index == 0:
            cls.ed_pod_name_for_commands = "eric-data-distributed-coordinator-ed-1"

        pod = pods[pods_index]

        cls.kube.delete_pod(pod, cls.namespace, wait_for_terminating=False)
        cls.kube.wait_for_pod_status(pod, cls.namespace, ready=False)
        cls.kube.wait_for_pod_to_start(pod, cls.namespace)

    @classmethod
    def restore_pod_name_for_commands(cls):
        cls.ed_pod_name_for_commands = "eric-data-distributed-coordinator-ed-0"

    @classmethod
    def get_etcd_member_with_max_id(cls,tls: bool = False):
        ed_root_password = cls.get_root_password()
        if tls:
            root_user_arg = "--user=root:"
        else:
            root_user_arg = "--user=root:{}".format(ed_root_password)
        cmd = [
            cls.ed_command_line,
            root_user_arg,
            "member",
            "list",
            "--write-out=json",
        ]

        retry_count = 5
        while retry_count > 0:
            try:
                values = cls.kube.exec_cmd_on_pod(
                    cls.ed_pod_name_for_commands, cls.namespace, cmd
                )
                values = ast.literal_eval(values)

            except Exception as e_obj:
                cls.log.error(str(e_obj))
                time.sleep(5)
                retry_count -= 1
                continue
            break

        members = [int(member["name"].split("-")[-1]) for member in values["members"]]
        members.remove(int(cls.ed_pod_name_for_commands.split('-')[-1]))

        member_name = values["members"][0]["name"][0:-2]
        member_max_id = max(members)

        member_name = "{}-{}".format(member_name, member_max_id)
        cls.log.info("Returning member name {}".format(member_name))
        member_id = [
            member["ID"]
            for member in values["members"]
            if member["name"] == member_name
        ][0]

        return member_id

    @classmethod
    def etcd_scale_down(cls, pods_number: int,tls: bool = False):
        cls.log.info("Remove member from etcd cluster")

        ed_root_password = cls.get_root_password()
        if tls:
            root_user_arg = "--user=root:"
        else:
            root_user_arg = "--user=root:{}".format(ed_root_password)
        pod_list = cls.kube.list_pods_from_namespace(cls.namespace)
        pods = [
            pod.metadata.name
            for pod in pod_list.items
            if pod.metadata.name.startswith("eric-data-distributed-coordinator-ed")
        ]

        pods_deployed = len(pods)
        if pods_deployed <= pods_number:
            raise AssertionError(
                (
                    "Deployed pods are less or equal to the number of pods requested. "
                    "Requested: {} Deployed: {}".format(pods_number, pods_deployed)
                )
            )

        pods_to_delete = pods_deployed - pods_number
        # First remove the member from the cluster because helm upgrade will
        # not remove it, leaving the cluster in a inconsistent status
        for i in range(pods_to_delete):  # pylint: disable=W0612
            member_id = cls.get_etcd_member_with_max_id(tls)
            member_id = hex(member_id)[2:]
            cls.log.info("Remove member id {}".format(member_id))
            cmd = [
                cls.ed_command_line,
                root_user_arg,
                "member",
                "remove",
                member_id,
            ]

            try:
                cls.kube.exec_cmd_on_pod(
                    cls.ed_pod_name_for_commands, cls.namespace, cmd
                )
                time.sleep(2)
            except Exception as e_obj:
                cls.log.error(str(e_obj))
                raise

        cls.log.info("Perform downscale to 4 pods from previous upscale to 5 nods")

        try:
            cls.helm_upgrade_with_chart_archive_with_options(
                cls.ed_release_name, cls.ed_chart_archive, pod_number=pods_number
            )
        except Exception as e_obj:
            cls.log.error(str(e_obj))
            raise

        cls.log.info("Wait for all resources to be up")

        try:
            helm3procs.helm_wait_for_deployed_release_to_appear(
                expected_release_name=cls.ed_release_name,
                target_namespace_name=cls.namespace
            )
        except Exception as e_obj:
            cls.log.error(str(e_obj))
            raise

        time.sleep(30)

    @classmethod
    def etcd_rollback(cls):
        cls.log.info("Chart rollback")
        try:
        #Force pod recreation on rollback.
            helm3procs.helm_rollback(cls.ed_release_name, cls.namespace)
        except Exception as e_obj:
            cls.log.error(str(e_obj))
            raise
        try:
            helm3procs.helm_wait_for_deployed_release_to_appear(
                expected_release_name=cls.ed_release_name,
                target_namespace_name=cls.namespace
            )
        except Exception as e_obj:
            cls.log.error(str(e_obj))
            raise
        time.sleep(5)

    @classmethod
    def etcd_scale_up(cls, pods_number: int):
        cls.log.info("Perform upscale to {} pods".format(pods_number))

        pod_list = cls.kube.list_pods_from_namespace(cls.namespace)
        pods = [
            pod.metadata.name
            for pod in pod_list.items
            if pod.metadata.name.startswith("eric-data-distributed-coordinator-ed")
        ]
        pods_deployed = len(pods)

        if pods_deployed >= pods_number:
            raise AssertionError(
                (
                    "Deployed pods are more or equal to the number of pods requested. "
                    "Requested: {} Deployed: {}".format(pods_number, pods_deployed)
                )
            )

        try:
            cls.helm_upgrade_with_chart_archive_with_options(
                cls.ed_release_name, cls.ed_chart_archive, pod_number=pods_number
            )
            time.sleep(5)
        except Exception as e_obj:
            cls.log.error(str(e_obj))
            raise

        cls.log.info("Waiting for scale to complete")
        try:
            helm3procs.helm_wait_for_deployed_release_to_appear(
                expected_release_name=cls.ed_release_name,
                target_namespace_name=cls.namespace
            )
        except Exception as e_obj:
            cls.log.error(str(e_obj))
            raise

    @classmethod
    def create_root_secret(
        cls, namespace: str, password: str = None, pass_length: int = 20
    ):
        if password is None:
            letters_digits = string.ascii_letters + string.digits
            password = "".join(
                random.choice(letters_digits) for i in range(pass_length)
            )

        try:
            b64_password = b64encode(password.encode("utf-8")).decode("utf-8")
        except Exception as e_obj:
            cls.log.error("Error converting password to bytes: {}".format(e_obj))
            raise

        try:
            cls.kube.create_namespace_secret(
                cls.ed_secret_name,
                namespace,
                "Opaque",
                {cls.ed_root_password_key: b64_password},
            )
            cls.log.info("Created root password {}".format(password))
        except Exception as e_obj:
            cls.log.error("Error creating secret: {}".format(e_obj))
            raise

    @classmethod
    def wait_for_secret(cls, namespace: str, secret_name: str):
        cls.log.info(
            "Search for secret {} in namespace {}".format(secret_name, namespace)
        )
        loop_count = 60
        while True:
            api_response = client.CoreV1Api().list_namespaced_secret(namespace)

            for secret in api_response.items:
                if secret.metadata.name == secret_name:
                    cls.log.info("Secret {} found".format(secret_name))
                    return

            cls.log.info("Secret {} not found".format(secret_name))
            loop_count -= 1
            if loop_count <= 0:
                raise RuntimeError(
                    "Timeout waiting for secret {} to appear".format(secret_name)
                )

            time.sleep(5)

    @classmethod
    def title(cls, message: str):
        """Write to stdout a nice title with the message specified
        Args:
            message: string to print
        """
        cls.log.info(
            "------------------------------------------------------------------"
        )
        cls.log.info(message)
        cls.log.info(
            "------------------------------------------------------------------"
        )

    @classmethod
    def instantiate_log(
        cls, logger_name: str = None, filename: str = None, logger_level: str = "INFO"
    ):
        handler_console = logging.StreamHandler()
        formatter_base = logging.Formatter(
            "%(asctime)s|%(levelname)s|%(module)s|%(funcName)s|%(message)s"
        )
        handler_console.setFormatter(formatter_base)

        if logger_name is not None:
            logger = logging.getLogger(logger_name)
        else:
            logger = logging.getLogger()

        level = logging.getLevelName(logger_level)
        logger.setLevel(level)
        logger.addHandler(handler_console)

        if filename is not None:
            handler_file = logging.FileHandler(filename)
            handler_file.setFormatter(formatter_base)
            logger.addHandler(handler_file)

        return logger

    @classmethod
    def custom_setup(cls, tls: bool = False, development_version: bool = True):
        """Run each time the module is called"""
        cls.title("Setup")
        # cleanup all charts in namespace before start
        cls.log.info("Cleanup namespace {}".format(cls.namespace))
        try:
            helm3procs.helm_cleanup_namespace(cls.namespace)
            time.sleep(10)
        except Exception as e_obj:
            cls.log.error(str(e_obj))

        cls.log.info(
            "All helm charts were removed from namespace {}".format(cls.namespace)
        )
        # cleanup PVC if they exists
        cls.log.info("Cleanup PVCs from namespace {}".format(cls.namespace))
        try:
            cls.kube.delete_all_pvc_namespace(cls.namespace)
            time.sleep(10)
        except Exception as e_obj:
            cls.log.error(str(e_obj))

        cls.log.info("PVCs removed from namespace {}".format(cls.namespace))

        time.sleep(5)

        cls.create_root_secret(cls.namespace)

        if tls:
            siptls_helm3.setup_security(
                target_namespace_name=cls.namespace,
                with_dced=False,
                development_version=development_version,
                settings_dict=cls.helm_settings)
            cls.etcd_install(tls=True, pra=not development_version)
            cls.wait_for_secret(
                cls.namespace, "eric-data-distributed-coordinator-ed-ca"
                )
            cls.log.info("Wait for synchronization between all pods")
            time.sleep(100)
            cls.create_users(tls=True)
        else:
            cls.etcd_install(pra=not development_version)
            cls.create_users()

    @classmethod
    def custom_teardown(cls, tls: bool = False):
        """Run each time the test is end if setup_module exit with 0"""
        cls.title("Teardown")

        cls.log.info("Retrieve log from pods")
        cls.kube.get_pod_logs(cls.namespace)

        cls.log.info("Cleanup ed secrets from namespace {}".format(cls.namespace))
        if tls:
            secrets = [
                cls.ed_secret_name,
                "eric-data-distributed-coordinator-ed-cert",
                "eric-sec-key-management-kms-cert",
                "eric-sec-sip-tls-bootstrap-ca-cert",
                "eric-sec-sip-tls-trusted-root-cert",
                "eric-data-distributed-coordinator-ed-etcdctl-client-cert",
                "eric-sec-key-management-client-cert",
                "eric-data-distributed-coordinator-ed-ca",
                "eric-data-distributed-coordinator-ed-peer-cert",
            ]
        else:
            secrets = [cls.ed_secret_name]

        for secret in secrets:
            try:
                cls.delete_secret(secret)
                time.sleep(2)
            except Exception as e_obj:
                utilprocs.log(str(e_obj))

        cls.log.info("Cleanup namespace {}".format(cls.namespace))
        try:
            helm3procs.helm_cleanup_namespace(cls.namespace)
        except Exception as e_obj:
            cls.log.error(str(e_obj))

        cls.log.info(
            "ALl helm charts were removed from namespace {}".format(cls.namespace)
        )

        cls.log.info("Cleanup PVCs from namespace {}".format(cls.namespace))
        try:
            cls.kube.delete_all_pvc_namespace(cls.namespace)
            time.sleep(20)
        except Exception as e_obj:
            cls.log.error(str(e_obj))

        cls.log.info("PVCs removed from namespace {}".format(cls.namespace))

        # wait for the resources to be removed
        time.sleep(35)

    @classmethod
    def siptls_create_cert_request(cls, name: str = None):
        cert_body = ""

        if name is None:
            name = '{}{}'.format(cls.test_cert_name, cls.test_cert_name_incr)
            cls.test_cert_name_incr += 1

        with open("test-cert.yaml.txt", "r") as cert_tpl:
            cert_body = cert_tpl.read()

        cert_body = cert_body.replace("{name}", name)
        cert_body = yaml.safe_load(cert_body)

        group = "siptls.sec.ericsson.com"
        version = "v1"
        namespace = cls.namespace
        plural = "internalcertificates"
        body = cert_body

        try:
            client.CustomObjectsApi().create_namespaced_custom_object(
                group=group,
                version=version,
                namespace=namespace,
                plural=plural,
                body=body,
            )
        except ApiException as e_obj:
            cls.log.error(
                "Exception when calling create_namespaced_custom_object: {}\n".format(
                    e_obj
                )
            )
            raise

        return name

    @classmethod
    def wait_for_certificate(cls, cert_name: str):
        cls.log.info(
            "Search for certificate {} in namespace {}".format(cert_name, cls.namespace)
        )
        loop_count = 60
        while True:
            try:
                secret = cls.kube.get_namespace_secrets(cls.namespace, [cert_name])
            except Exception:
                # no need to do anything
                pass

            if not secret:
                cls.log.info("Certificate {} not found".format(cert_name))
                loop_count -= 1
                if loop_count <= 0:
                    raise RuntimeError(
                        "Timeout waiting for certificate {} to appear".format(cert_name)
                    )
            else:
                cls.delete_secret(secret_name=cert_name)
                cls.delete_cert_request(name=cert_name)
                return

            time.sleep(5)

    @classmethod
    def delete_secret(cls, secret_name: str):
        cls.log.info(
            "Delete secret {} from namespace {}".format(secret_name, cls.namespace)
        )

        try:
            client.CoreV1Api().delete_namespaced_secret(
                name=secret_name,
                namespace=cls.namespace,
                body=cls.k8s_delete_body,
            )
        except ApiException as e_obj:
            cls.log.error(
                "Exception when calling delete_namespaced_secret: {}\n".format(
                    e_obj
                )
            )

    @classmethod
    def delete_cert_request(cls, name: str):
        group = "siptls.sec.ericsson.com"
        version = "v1"
        namespace = cls.namespace
        plural = "internalcertificates"
        body = cls.k8s_delete_body

        try:
            client.CustomObjectsApi().delete_namespaced_custom_object(
                group=group,
                version=version,
                namespace=namespace,
                plural=plural,
                name=name,
                body=body,
                grace_period_seconds=0,
            )
        except ApiException as e_obj:
            cls.log.error(
                "Exception when calling delete_namespaced_custom_object: {}\n".format(
                    e_obj
                )
            )

    def upgrade_chart(self, settings_dict=None, helm_chart_version=ed_baseline_chart_version, repo_name="BASELINE"):
        """Upgrades the chart using the specified dict
        Args:
          settings_dict: additional helm chart parameters
          helm_chart_version: chart version to upgrade
          repo_name: repo name
        """
        if not settings_dict.get("global.security.tls.enabled"):
            settings_dict["global.security.tls.enabled"] = "false"
        utilprocs.log("Upgrading chart with {}".format(str(settings_dict)))
        helm3procs.helm_upgrade_with_chart_repo_with_dict(
                helm_release_name=self.ed_release_name,
                helm_chart_name=self.ed_chart_name,
                target_namespace_name=self.namespace,
                helm_repo_name=repo_name,
                chart_version=helm_chart_version,
                settings_dict=settings_dict)

        helm3procs.helm_wait_for_deployed_release_to_appear(
                expected_release_name=self.ed_release_name,
                target_namespace_name=self.namespace)

class Span:
    """
    Span: used to track how long something takes, and produce a
    string designed to be easy to filter log files for containing
    a name, start time, end time and set of tags
    Log looks like:
    SPAN;{"name":"<name>","start":<time>,"end":<time>,"tags":<map>}
    """

    def __init__(self, name, tags=None):
        if tags is None:
            tags = {}
        self.name = name
        self.start = int(time.time())
        self.tags = tags
        self.end = 0


    def finish(self):
        """
        Ends a span
        """
        self.end = int(time.time())
        return "SPAN;" + self.get_log()


    def get_log(self):
        """
        Gets a json repr of a span
        """
        span = {
            "name": self.name,
            "start": self.start,
            "end": self.end,
            "tags": self.tags
        }
        return json.dumps(span)

class TestcaseMethods(BaseClass):
    #Class for defining extra significant methods used during testcases to avoid redundancy in code.
    def __init__(self):
        """
        This is the constructor of the class.

        :param self: self is an instance of the class\
        and also binds the attributes with the given arguments.
        :param test_pod_prefix: fixed part of the test pod name
        """
        try:
            # config from inside k8s cluster
            config.load_incluster_config()
        except ConfigException:
            # config from outside k8s cluster
            config.load_kube_config()
        self.core_v1 = client.CoreV1Api()

    def validate_timestamps(self, file_name, pod_name):
        """This function compares the timestamp fields in DCED and brAgent pod logs
           to the format defined in log schema (DR).
        """

        with open(file_name, "r", encoding="utf-8") as my_file:
            valid_ts_count = 0
            invalid_ts_count = 0
            total_ts_count = 0

            for line in my_file:
                try:
                    log = json.loads(line)
                    ts = log.get('timestamp')
                    total_ts_count += 1
                    #regex expression as provided in the schema itself.
                    required_format = r"^\d{4}-\d\d-\d\d[T][\d:.]+([zZ]|([+\-])(\d\d):?(\d\d))?$"
                    # Matching retrieved timestamp to required timestamp format
                    if re.match(required_format, str(ts)):
                        valid_ts_count += 1
                        pass
                    else:
                        invalid_ts_count += 1
                        utilprocs.log("INVALID Timestamp format: {} !!!".format(ts))
                except json.JSONDecodeError:
                    pass

        utilprocs.log("valid timestamp: {}".format(valid_ts_count))
        utilprocs.log("invalid timestamp: {}".format(invalid_ts_count))
        utilprocs.log("Total timestamp: {}".format(total_ts_count))

        if invalid_ts_count > 0:
            raise Exception("Timestamp Schema Status for {} pod: NON COMPLAINT!!!".format(pod_name))
        else:
            utilprocs.log("Timestamps format : valid for {} pod.".format(pod_name))

    def get_siptls_pod_name(self):
        result = subprocess.check_output("/usr/local/bin/kubectl get po -n {}".format(BaseClass.namespace), shell = True, encoding='utf-8', universal_newlines=True)
        result = result.split()
        sip_tls_pods = []
        try:
            for i in result:
                if "eric-sec-sip-tls-main" in i:
                    sip_tls_pods.append(i)

            utilprocs.log("SIP-TLS Pod List: {}".format(sip_tls_pods))
            return sip_tls_pods

        except Exception as e:
            utilprocs.log("Cannot retrieve siptls pod:{}".format(e))

    #function to compare labels and annotations for test case in test_certon.py
    def compare_lists(self, check_list, retrived_list, type_):
        for i in check_list:
            if i in retrived_list:
                utilprocs.log("{} {}: present".format(i, type_))
            else:
                raise Exception("{} : Missing {} ! ".format(i, type_))

    def delete_pod(
            self, name, namespace, counter=60, wait_for_terminating=True):
        """
        Deletes the pod and by default waits for the pod to reach
        terminating state.

        :param self: self is an instance of the class.
        :param name: name of the pod to be deleted.
        :param namespace: namespace.
        :param counter: counter for timer with interval of 10's.
        :param wait_for_terminating: if true (default) waits for pod to reach
            terminating state, if False only runs the API call
        """
        utilprocs.log('Deleting pod: {}'.format(name))
        exception_count = 3
        while True:
            try:
                self.core_v1.delete_namespaced_pod(name, namespace,
                                                   grace_period_seconds=0,
                                                   body=client.
                                                   V1DeleteOptions())
            except ApiException as e_obj:
                utilprocs.log(
                    (
                        "Exception when trying to delete "
                        "pod in namespace: {}".format(e_obj)
                    )
                )
                exception_count -= 1
                if exception_count <= 0:
                    raise
                continue

            if wait_for_terminating:
                self.wait_for_pod_status(name, namespace,
                                         counter, ready=False, interval=2)
            return

    def wait_for_pod_status(self, name, namespace, counter=60, ready=True,
                            interval=10):
        """
        Waits till all the containers of the pod are ready,
        or all are not ready.

        :param self: self is an instance of the class.
        :param name: name of the pod we are checking.
        :param namespace: The namespace that the pod is in.
        :param counter: counter for timer with interval of [interval]'s
        :param ready: if True (default) wait for container ready,
             otherwise wait for container to fail readiness probe
        :param interval: interval to wait between checks in seconds, default 10
        """

        utilprocs.log('Waiting for Pod: {}'.format(name))
        exception_count = 5
        while True:
            try:
                api_response = \
                    self.core_v1.read_namespaced_pod(name, namespace)
            except Exception as e_obj:
                utilprocs.log(
                    (
                        "Exception when trying to find "
                        "pod in namespace: {}".format(e_obj)
                    )
                )
                exception_count -= 1
                if exception_count <= 0:
                    raise
                time.sleep(1)
                continue

            if ready:
                if api_response.status.phase == 'Running' \
                        and all(container_status.ready for
                                container_status in
                                api_response.status.container_statuses):
                    utilprocs.log('Pod ready: {}'.format(name))
                    return
            else:
                if api_response.metadata.deletion_timestamp is None:
                    utilprocs.log('Pod ready: {}'.format(name))
                    return

            if counter > 0:
                counter = counter - 1
                time.sleep(interval)
            else:
                raise ValueError('Timeout waiting for pod to reach '
                                 'Ready & Running')