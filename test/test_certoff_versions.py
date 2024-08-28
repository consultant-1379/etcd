"""Test ETCD without SIPTLS/KMS"""
# pylint: disable=E0401,W0703,R0201,C0111
from base_class import BaseClass

_BASE = BaseClass()
_LOGGER = _BASE.instantiate_log(
    filename='/var/log/tests_certoff_versions.log'
)

import utilprocs  # pylint: disable=C0413
# this override log function in utilprocs, to use python logging framework
# ------------------------------------------------------
utilprocs.log = _LOGGER.info
# ------------------------------------------------------

class TestEtcdCertsOff01PraToRc(BaseClass):
    """Class to test ETCD upgarde from PRA to RC"""

    @classmethod
    def setup_class(cls):
        cls.custom_setup(tls=False, development_version=False)

    @classmethod
    def teardown_class(cls):
        cls.custom_teardown()

    def test_01_install_etcd_pra(self):
        """Install ETCD, PRA version"""
        self.title("Install ETCD PRA version")
        self.etcd_write_value()
        self.etcd_read_value()

    def test_02_upgrade_to_rc(self):
        """Upgrade ETCD from PRA to RC version"""
        self.title("Upgrade ETCD to RC version")
        self.etcd_upgrade()
        self.etcd_write_value()
        self.etcd_read_value()

    def test_03_rollback_to_pra(self):
        """Rollback ETCD from RC to PRA version"""
        self.title("Rollback ETCD to PRA version")
        self.etcd_rollback()
        self.etcd_write_value()
        self.etcd_read_value()


class TestEtcdCertsOff02DevelToRc(BaseClass):
    """Class to test ETCD upgarde from devel to RC"""

    @classmethod
    def setup_class(cls):
        cls.custom_setup(tls=False, development_version=True)

    def test_01_install_etcd_devel(self):
        """Install ETCD, Devel version"""
        self.title("Install ETCD Devel version")
        self.create_users()
        self.etcd_write_value()
        self.etcd_read_value()#

    def test_02_upgrade_to_rc(self):
        """Upgrade ETCD to from Devel to RC version"""
        self.title("Upgrade ETCD to RC version")
        self.etcd_upgrade()
        self.etcd_write_value()
        self.etcd_read_value()

    def test_03_rollback_to_devel(self):
        """Rollback ETCD from RC to Devel version"""
        self.title("Rollback ETCD to Devel version")
        self.etcd_rollback()
        self.etcd_write_value()
        self.etcd_read_value()
