package com.ericsson.adp.mgmt.dced.bragent.v2;

import java.net.URI;
import java.util.UUID;
import java.util.concurrent.ExecutionException;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.junit.AfterClass;
import org.junit.Assert;
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
import com.ericsson.adp.mgmt.dced.bragent.v2.utils.EtcdContainerUtils;

import io.etcd.jetcd.ByteSequence;
import io.etcd.jetcd.Client;
import io.etcd.jetcd.KV;
import io.etcd.jetcd.kv.GetResponse;

@RunWith(SpringJUnit4ClassRunner.class)
@ContextConfiguration(classes = { DcedClient.class })
@TestPropertySource(locations = { "classpath:test.properties" }, properties = "dced.certificates.enabled=false")
public class DcedClientTest {
    private static final Logger log = LogManager.getLogger(DcedClientTest.class);

    @Rule
    public ExpectedException expectedException = ExpectedException.none();
    @Autowired
    private DcedClient dcedClient;
    private static String rootPassword = getRandomString();

    private static String getRandomString() {
        return UUID.randomUUID().toString().replace("-", "").substring(0, 10);
    }

    @BeforeClass
    public static void setup() {
        EtcdContainerUtils.setupWithSsl(false, rootPassword);
    }

    @AfterClass
    public static void tearDown() {
        EtcdContainerUtils.tearDown();
    }

    @Test
    public void connectSuccessfully() throws InterruptedException, ExecutionException {

        //setup
        final URI uri = EtcdContainerUtils.etcdContainer.clientEndpoint();
        ReflectionTestUtils.setField(dcedClient, "ACL_ROOT_PASSWORD", rootPassword);
        ReflectionTestUtils.setField(dcedClient, "etcdEndpointUrl", (uri.getHost() + ":" + uri.getPort()));
        final String keyString = getRandomString();
        final String valueString = getRandomString();
        final ByteSequence key = ByteSequence.from((keyString).getBytes());
        final ByteSequence value = ByteSequence.from(valueString.getBytes());

        //connect
        final Client client = dcedClient.getClient();
        final KV kvClient = client.getKVClient();
        kvClient.put(key, value).get();

        //assert
        final GetResponse response = kvClient.get(ByteSequence.from(keyString.getBytes())).get();
        Assert.assertEquals(valueString, new String(response.getKvs().get(0).getValue().getBytes()));

    }

    @Test
    public void connectWithWrongPasswordAssertException() throws InterruptedException, ExecutionException {

        //expected exception and cause
        expectedException.expect(ExecutionException.class);
        //expectedException.expectCause(is(EtcdException.class));

        //setup
        final URI uri = EtcdContainerUtils.etcdContainer.clientEndpoint();
        ReflectionTestUtils.setField(dcedClient, "ACL_ROOT_PASSWORD", getRandomString()); //different password
        ReflectionTestUtils.setField(dcedClient, "etcdEndpointUrl", (uri.getHost() + ":" + uri.getPort()));
        final String keyString = getRandomString();
        final String valueString = getRandomString();
        final ByteSequence key = ByteSequence.from((keyString).getBytes());
        final ByteSequence value = ByteSequence.from(valueString.getBytes());

        //connect
        final Client client = dcedClient.getClient();
        final KV kvClient = client.getKVClient();
        kvClient.put(key, value).get();
    }
}
