# pylint: disable=R0903,C0301
"""Configuration for bootsrtap.py"""


class TestBase:
    """configuration base class"""

    BASELINE_DEPLOYMENT_TYPE = "deployment"
    # KUBERNETES_NAMESPACE = "zgvnclp"
    TEST_PARAMS = ["KOOPA_num1=4", "KOOPA_num2=2"]
    COPY_ALL_POD_LOGS = True
    ETCD_HELM_SERVER = "https://arm.sero.gic.ericsson.se/artifactory"
    ETCD_HELM_GLOBAL_PATH = "proj-adp-gs-all-helm"
    ETCD_HELM_INTERNAL_PATH = "proj-adp-eric-data-dc-ed-internal-helm"
    SIPTLS_HELM_SERVER = "https://arm.sero.gic.ericsson.se/artifactory"
    SIPTLS_HELM_STAGING_PATH = "proj-adp-sec-staging-helm"
    KMS_HELM_SERVER = "https://arm.sero.gic.ericsson.se/artifactory"
    KMS_HELM_STAGING_PATH = "proj-adp-sec-staging-helm"
    K8S_SECRETS = "armdocker|.dockerconfigjson|armdocker-config.json|kubernetes.io/dockerconfigjson"


class TestCertOff(TestBase):
    """configuration for tests without SIPTLS/KMS"""

    NOSE_FAIL_FIRST = True
    NOSE_TEST = "test_certoff.py"
    OUTPUT_HTML = "output_certoff.html"


class TestCertOn(TestBase):
    """configuration for tests with SIPTLS/KMS"""

    NOSE_FAIL_FIRST = True
    NOSE_TEST = "test_certon.py"
    OUTPUT_HTML = "output_certon.html"


class TestCertOffVersions(TestBase):
    """configuration for upgrade/rollback from PRA and Devel without SIPTLS/KMS"""

    NOSE_FAIL_FIRST = True
    NOSE_TEST = "test_certoff_versions.py"
    OUTPUT_HTML = "output_certoff_versions.html"


class TestCertOnVersions(TestBase):
    """configuration for upgrade/rollback from PRA and Devel with SIPTLS/KMS"""

    NOSE_FAIL_FIRST = True
    NOSE_TEST = "test_certon_versions.py"
    OUTPUT_HTML = "output_certon_versions.html"

class TestCharacteristics(TestBase):
    NOSE_FAIL_FIRST = True
    NOSE_TEST = "nose_char.py"
    OUTPUT_HTML = "characteristics_tests.html"

class TestNoseNmap(TestBase):
    NOSE_FAIL_FIRST = True
    NOSE_TEST = "nose_nmap.py"
    OUTPUT_HTML = "nose_nmap_test.html"
