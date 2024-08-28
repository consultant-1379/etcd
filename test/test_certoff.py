"""Test ETCD without SIPTLS/KMS."""
# pylint: disable=E0401,W0703,R0201
from base_class import BaseClass

_BASE = BaseClass()
_LOGGER = _BASE.instantiate_log(
    logger_name='certoff',
    filename='/var/log/tests_certoff.log'
)

import subprocess
import utilprocs # pylint: disable=C0413
# this override log function in utilprocs, to use python logging framework
# ------------------------------------------------------
utilprocs.log = _LOGGER.info
# ------------------------------------------------------


def setup_module():
    """Nose setup fixture"""
    _BASE.custom_setup(tls=False)


def teardown_module():
    """Nose teardow fixture"""
    _BASE.custom_teardown()


class TestEtcdCertsOFF(BaseClass):
    """Class to test ETCD without SIPTLS/KMS integration"""

    def test_01_write_read(self):
        """Test to write and read"""
        self.title("Starting ETCD write/read test")
        self.etcd_write_value()
        self.etcd_read_value()

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
        self.restore_pod_name_for_commands()

    def test_04_scale_up(self):
        """Test scale up"""
        self.title("Starting ETCD scale up")
        self.etcd_scale_up(pods_number=5)
        self.etcd_write_value()
        self.etcd_read_value()

    def test_05_scale_down(self):
        """Test scale down"""
        self.title("Starting ETCD scale down")
        self.etcd_scale_down(pods_number=3)
        self.etcd_write_value()
        self.etcd_read_value()

    def test_06_print_pod_status(self):
        """Print Pod Status"""
        res = subprocess.check_output("/usr/local/bin/kubectl get po -n {}".format(BaseClass.namespace), shell = True, encoding='utf-8', universal_newlines=True)
        res = str(res)
        utilprocs.log("POD STATUS OUTPUT:")
        utilprocs.log(res)