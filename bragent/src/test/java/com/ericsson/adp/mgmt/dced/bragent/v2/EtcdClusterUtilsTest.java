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

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.net.URI;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ExecutionException;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.junit.AfterClass;
import org.junit.BeforeClass;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.ExpectedException;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.junit4.SpringJUnit4ClassRunner;
import org.springframework.test.util.ReflectionTestUtils;

import com.ericsson.adp.mgmt.dced.bragent.v2.client.DcedClient;
import com.ericsson.adp.mgmt.dced.bragent.v2.util.EtcdClusterUtils;
import com.ericsson.adp.mgmt.dced.bragent.v2.utils.EtcdContainerUtils;
import com.ericsson.adp.mgmt.dced.bragent.v2.utils.EtcdTestUtils;

import io.etcd.jetcd.ByteSequence;
import io.etcd.jetcd.KeyValue;

@RunWith(SpringJUnit4ClassRunner.class)
@ContextConfiguration(classes = { DcedClient.class, EtcdClusterUtils.class, EtcdTestUtils.class })
@TestPropertySource(locations = { "classpath:test.properties" }, properties = "dced.certificates.enabled=false")
public class EtcdClusterUtilsTest {

    private static final Logger log = LogManager.getLogger(EtcdClusterUtilsTest.class);

    @Rule
    public ExpectedException expectedException = ExpectedException.none();
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

    private void pushData() {
        final URI uri = EtcdContainerUtils.etcdContainer.clientEndpoint();
        ReflectionTestUtils.setField(dcedClient, "ACL_ROOT_PASSWORD", rootPassword);
        ReflectionTestUtils.setField(dcedClient, "etcdEndpointUrl", (uri.getHost() + ":" + uri.getPort()));

        etcdTestUtils.pushDataToEtcd("extranode", "sanityCheck".getBytes(), rootPassword);
        etcdTestUtils.pushDataToEtcd("singlenode", getRandomString().getBytes(), rootPassword);
        etcdTestUtils.pushDataToEtcd("/samplenode/bl", getRandomString().getBytes(), rootPassword);
        etcdTestUtils.pushDataToEtcd("/samplenode/blo", getRandomString().getBytes(), rootPassword);
        etcdTestUtils.pushDataToEtcd("/samplenode/block", getRandomString().getBytes(), rootPassword);
        etcdTestUtils.pushDataToEtcd("/shelter/node1/test1", getRandomString().getBytes(), rootPassword);
        etcdTestUtils.pushDataToEtcd("/shelter/node1/test2", getRandomString().getBytes(), rootPassword);
    }

    @Test
    public void testRetrieveDataFromEtcd() {
        pushData();
        final URI uri = EtcdContainerUtils.etcdContainer.clientEndpoint();
        ReflectionTestUtils.setField(dcedClient, "ACL_ROOT_PASSWORD", rootPassword);
        ReflectionTestUtils.setField(dcedClient, "etcdEndpointUrl", (uri.getHost() + ":" + uri.getPort()));
        final List<KeyValue> kvdata = etcdClusterUtils.retrieveDataFromEtcd();
        assertFalse(kvdata.isEmpty());
        assertTrue(kvdata.stream().noneMatch(keyvalue -> keyvalue.getKey().startsWith(ByteSequence.from("/shelter".getBytes()))));
        assertTrue(kvdata.stream().anyMatch(keyvalue -> keyvalue.getKey().startsWith(ByteSequence.from("/samplenode".getBytes()))));
    }

    @Test
    public void testDeleteKeysfromCluster() {
        pushData();
        final URI uri = EtcdContainerUtils.etcdContainer.clientEndpoint();
        ReflectionTestUtils.setField(dcedClient, "ACL_ROOT_PASSWORD", rootPassword);
        ReflectionTestUtils.setField(dcedClient, "etcdEndpointUrl", (uri.getHost() + ":" + uri.getPort()));
        etcdClusterUtils.deleteKeysfromCluster();
        List<KeyValue> kvdata;
        try {
            kvdata = etcdTestUtils.getAllKeys(rootPassword);
            assertFalse(kvdata.isEmpty());
            assertTrue(kvdata.stream().noneMatch(keyvalue -> keyvalue.getKey().startsWith(ByteSequence.from("/samplenode".getBytes()))));
            assertTrue(kvdata.stream().anyMatch(keyvalue -> keyvalue.getKey().startsWith(ByteSequence.from("/shelter".getBytes()))));

        } catch (InterruptedException | ExecutionException e) {
            log.error(String.format("Exception occurred while reading from  etcd: %s", e.getMessage()));
        }

    }

}
