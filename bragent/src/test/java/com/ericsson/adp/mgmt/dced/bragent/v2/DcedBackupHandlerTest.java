package com.ericsson.adp.mgmt.dced.bragent.v2;

import static org.hamcrest.Matchers.containsString;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertThat;
import static org.junit.Assert.assertTrue;

import java.io.File;
import java.io.IOException;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Arrays;
import java.util.UUID;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.junit.AfterClass;
import org.junit.Assert;
import org.junit.Before;
import org.junit.BeforeClass;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.ExpectedException;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.junit4.SpringJUnit4ClassRunner;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.util.Base64Utils;

import com.ericsson.adp.mgmt.dced.bragent.exception.ClusterException;
import com.ericsson.adp.mgmt.dced.bragent.exception.FileException;
import com.ericsson.adp.mgmt.dced.bragent.v2.client.DcedClient;
import com.ericsson.adp.mgmt.dced.bragent.v2.util.EtcdClusterUtils;
import com.ericsson.adp.mgmt.dced.bragent.v2.utils.EtcdContainerUtils;
import com.ericsson.adp.mgmt.dced.bragent.v2.utils.EtcdTestUtils;

@RunWith(SpringJUnit4ClassRunner.class)
@ContextConfiguration(classes = { DcedClient.class, DcedBackupHandler.class, EtcdTestUtils.class, EtcdClusterUtils.class })
@TestPropertySource(locations = { "classpath:test.properties" }, properties = "dced.certificates.enabled=false")
public class DcedBackupHandlerTest {

    private static final Logger log = LogManager.getLogger(DcedBackupHandlerTest.class);

    @Value("${dced.agent.fragment.backup.data.path}")
    private String backupFilePath;
    @Rule
    public ExpectedException expectedException = ExpectedException.none();
    @Autowired
    private DcedBackupHandler dcedBackupHandler;
    @Autowired
    private DcedClient dcedClient;
    @Autowired
    private EtcdTestUtils etcdTestUtils;
    @Autowired
    private EtcdClusterUtils etcdClusterUtils;
    private static String rootPassword = getRandomString();

    private static String getRandomString() {
        return UUID.randomUUID().toString().replace("-", "").substring(0, 10);
    }

    @BeforeClass
    public static void setup() {
        EtcdTestUtils.setupEtcdHost(false, rootPassword);
    }

    @AfterClass
    public static void tearDown() {
        EtcdTestUtils.tearDown();
    }

    @Before
    public void pushData() {
        final URI uri = EtcdContainerUtils.etcdContainer.clientEndpoint();
        ReflectionTestUtils.setField(dcedClient, "ACL_ROOT_PASSWORD", rootPassword);
        ReflectionTestUtils.setField(dcedClient, "etcdEndpointUrl", (uri.getHost() + ":" + uri.getPort()));

        etcdTestUtils.pushDataToEtcd("extranode", "sanityCheck".getBytes(), rootPassword);
        etcdTestUtils.pushDataToEtcd("singlenode", getRandomString().getBytes(), rootPassword);
        etcdTestUtils.pushDataToEtcd("samplenode", getRandomString().getBytes(), rootPassword);
        etcdTestUtils.pushDataToEtcd("samplenode/test", getRandomString().getBytes(), rootPassword);
        etcdTestUtils.pushDataToEtcd("samplenode/bl", getRandomString().getBytes(), rootPassword);
        etcdTestUtils.pushDataToEtcd("samplenode/blo", getRandomString().getBytes(), rootPassword);
        etcdTestUtils.pushDataToEtcd("samplenode/block", getRandomString().getBytes(), rootPassword);
    }

    @Test
    public void backupDataEtcdAssertValue() throws Exception {

        final String key = "Backup";
        final String value = "Value";
        etcdTestUtils.pushDataToEtcd(key, value.getBytes(), rootPassword);
        dcedBackupHandler.backupToFile();
        final String content = new String(Files.readAllBytes(Paths.get(backupFilePath)));
        System.out.println(content);
        assertThat(content, containsString(key));
        assertThat(content, containsString(Base64Utils.encodeToString(value.getBytes())));
    }

    @Test
    public void backupDataEtcdWithIncludedPathsNoExcludedPaths() throws Exception {

        ReflectionTestUtils.setField(etcdClusterUtils, "excludedPaths", Arrays.asList(""));
        ReflectionTestUtils.setField(etcdClusterUtils, "includedPaths", Arrays.asList("samplenode/blo"));

        dcedBackupHandler.backupToFile();
        final String content = new String(Files.readAllBytes(Paths.get(backupFilePath)));
        assertThat(content, containsString("samplenode/block"));
        Assert.assertFalse(content.contains("samplenode/test"));
    }

    @Test
    public void backupDataEtcdNoIncludedPathsWithExcludedPaths() throws Exception {

        ReflectionTestUtils.setField(etcdClusterUtils, "includedPaths", Arrays.asList(""));
        ReflectionTestUtils.setField(etcdClusterUtils, "excludedPaths", Arrays.asList("samplenode/blo"));

        dcedBackupHandler.backupToFile();
        final String content = new String(Files.readAllBytes(Paths.get(backupFilePath)));
        assertThat(content, containsString("samplenode/bl"));
        assertThat(content, containsString("samplenode/test"));
        Assert.assertFalse(content.contains("samplenode/block"));
    }

    @Test
    public void backupDataEtcdWithIncludedPathsWithExcludedPaths() throws Exception {

        ReflectionTestUtils.setField(etcdClusterUtils, "includedPaths", Arrays.asList("samplenode/b"));
        ReflectionTestUtils.setField(etcdClusterUtils, "excludedPaths", Arrays.asList("samplenode/block"));

        dcedBackupHandler.backupToFile();
        final String content = new String(Files.readAllBytes(Paths.get(backupFilePath)));
        assertThat(content, containsString("samplenode/blo"));
        Assert.assertFalse(content.contains("singlenode"));
        Assert.assertFalse(content.contains("samplenode/block"));
    }

    @Test
    public void backupDataFromEtcdToFilePathSuccess() throws IOException {
        final File file = new File(backupFilePath);
        Files.deleteIfExists(Paths.get(backupFilePath));
        assertFalse(file.exists());
        dcedBackupHandler.backupToFile();
        assertTrue(file.exists());
    }

    @Test(expected = FileException.class)
    public void backupThrowsFileExceptionOnInvalidBackupFilePath() {
        ReflectionTestUtils.setField(dcedBackupHandler, "backupFilePath", "/");
        dcedBackupHandler.backupToFile();
    }

    @Test(expected = ClusterException.class)
    public void connectToNonExistentEtcdThrowException() {
        final URI uri = EtcdContainerUtils.etcdContainer.clientEndpoint();
        ReflectionTestUtils.setField(dcedClient, "etcdEndpointUrl", (uri.getHost() + ":" + 1234));
        dcedBackupHandler.backupToFile();
    }
}