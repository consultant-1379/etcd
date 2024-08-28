/**------------------------------------------------------------------------------
 *******************************************************************************
 * COPYRIGHT Ericsson 2019
 *
 * The copyright to the computer program(s) herein is the property of
 * Ericsson Inc. The programs may be used and/or copied only with written
 * permission from Ericsson Inc. or in accordance with the terms and
 * conditions stipulated in the agreement/contract under which the
 * program(s) have been supplied.
 *******************************************************************************
 *------------------------------------------------------------------------------*/
package com.ericsson.adp.mgmt.dced.bragent.v2;

import static org.junit.Assert.assertTrue;

import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ExecutionException;

import org.junit.AfterClass;
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

import com.ericsson.adp.mgmt.dced.bragent.exception.FileException;
import com.ericsson.adp.mgmt.dced.bragent.v2.client.DcedClient;
import com.ericsson.adp.mgmt.dced.bragent.v2.utils.EtcdContainerUtils;
import com.ericsson.adp.mgmt.dced.bragent.v2.utils.EtcdTestUtils;

import io.etcd.jetcd.ByteSequence;
import io.etcd.jetcd.Client;
import io.etcd.jetcd.KV;
import io.etcd.jetcd.KeyValue;

@RunWith(SpringJUnit4ClassRunner.class)
@ContextConfiguration(classes = { DcedClient.class, DcedRestoreMergeHandler.class, EtcdTestUtils.class })
@TestPropertySource(locations = { "classpath:test.properties" }, properties = "dced.agent.restore.type=merge")
public class DcedRestoreMergeHandlerTest {
    @Value("${dced.agent.fragment.backup.data.path}")
    private String backupFilePath;
    @Value("${dced.agent.download.location}")
    private String downloadLocation;
    @Rule
    public ExpectedException expectedException = ExpectedException.none();
    @Autowired
    private DcedRestoreMergeHandler dcedRestoreHandler;
    @Autowired
    private EtcdTestUtils etcdTestUtils;
    @Autowired
    private DcedClient dcedClient;

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

    @Test
    public void restoreFromFileToEtcdAndValidateSuccess() throws Exception {
        etcdTestUtils.createRestoreFolder(downloadLocation, false);
        final String restoredDataTestFilePath = EtcdTestUtils.RESOURCES_FOLDER_PATH + "restoredDataTest.txt";
        Files.deleteIfExists(Paths.get(restoredDataTestFilePath));
        final URI uri = EtcdContainerUtils.etcdContainer.clientEndpoint();
        //connect
        ReflectionTestUtils.setField(dcedClient, "ACL_ROOT_PASSWORD", rootPassword);
        ReflectionTestUtils.setField(dcedClient, "etcdEndpointUrl", (uri.getHost() + ":" + uri.getPort()));
        dcedRestoreHandler.restoreFromFile(downloadLocation);

        final Client client = dcedClient.getClient();
        final KV kvClient = client.getKVClient();
        final String value = getKeyValueInBytes(kvClient).replaceAll("^\"+|\"+$", "");
        assertTrue("sanityCheck".equals(value));

    }

    @Test(expected = FileException.class)
    public void restoreEmptyfileToEtcdAndFail() throws Exception {
        etcdTestUtils.createRestoreFolder(downloadLocation, true);
        final String restoredDataTestFilePath = EtcdTestUtils.RESOURCES_FOLDER_PATH + "restoredDataTest.txt";
        Files.deleteIfExists(Paths.get(restoredDataTestFilePath));
        final URI uri = EtcdContainerUtils.etcdContainer.clientEndpoint();
        //connect
        ReflectionTestUtils.setField(dcedClient, "ACL_ROOT_PASSWORD", rootPassword);
        ReflectionTestUtils.setField(dcedClient, "etcdEndpointUrl", (uri.getHost() + ":" + uri.getPort()));
        dcedRestoreHandler.restoreFromFile(downloadLocation);

    }

    private String getKeyValueInBytes(final KV kvClient) throws InterruptedException, ExecutionException {
        return new String(getKvList(kvClient).get(0).getValue().getBytes());
    }

    private List<KeyValue> getKvList(final KV kvClient) throws InterruptedException, ExecutionException {
        return kvClient.get(ByteSequence.from("extranode".getBytes())).get().getKvs();
    }

}
