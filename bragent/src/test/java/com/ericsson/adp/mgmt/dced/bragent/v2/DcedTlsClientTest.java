package com.ericsson.adp.mgmt.dced.bragent.v2;

import java.net.URI;
import java.util.UUID;
import java.util.concurrent.ExecutionException;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.junit.AfterClass;
import org.junit.Assert;
import org.junit.BeforeClass;
import org.junit.Ignore;
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
import com.ericsson.adp.mgmt.dced.bragent.v2.client.DcedTlsClient;
import com.ericsson.adp.mgmt.dced.bragent.v2.utils.EtcdContainerUtils;

import io.etcd.jetcd.ByteSequence;
import io.etcd.jetcd.Client;
import io.etcd.jetcd.KV;
import io.etcd.jetcd.kv.GetResponse;

@RunWith(SpringJUnit4ClassRunner.class)
@ContextConfiguration(classes = { DcedTlsClient.class })
@TestPropertySource(locations = { "classpath:test.properties" }, properties = "dced.certificates.enabled=true")
@Ignore
public class DcedTlsClientTest {
    private static final Logger log = LogManager.getLogger(DcedTlsClientTest.class);

    @Rule
    public ExpectedException expectedException = ExpectedException.none();
    @Autowired
    private DcedClient dcedTlsClient;

    private static String rootPassword = getRandomString();

    private static String getRandomString() {
        return UUID.randomUUID().toString().replace("-", "").substring(0, 10);
    }

    @BeforeClass
    public static void setup() {
        EtcdContainerUtils.setupWithSsl(true, rootPassword);
    }

    @AfterClass
    public static void tearDown() {
        EtcdContainerUtils.tearDown();
    }

    @Test
    public void connectSuccessfully() throws InterruptedException, ExecutionException {

        //setup
        final URI uri = EtcdContainerUtils.etcdContainer.clientEndpoint();
        ReflectionTestUtils.setField(dcedTlsClient, "etcdEndpointUrl", (uri.getHost() + ":" + uri.getPort()));
        final String keyString = getRandomString();
        final String valueString = getRandomString();
        final ByteSequence key = ByteSequence.from((keyString).getBytes());
        final ByteSequence value = ByteSequence.from(valueString.getBytes());

        final Client client = dcedTlsClient.getClient();
        final KV kvClient = client.getKVClient();
        kvClient.put(key, value).get();

        //assert
        final GetResponse response = kvClient.get(ByteSequence.from(keyString.getBytes())).get();
        Assert.assertEquals(valueString, new String(response.getKvs().get(0).getValue().getBytes()));
    }

    @Test
    public void connectWithWrongCertsAssertException() throws InterruptedException, ExecutionException {

        //expected exception and cause
        expectedException.expect(ExecutionException.class);

        //setup
        final URI uri = EtcdContainerUtils.etcdContainer.clientEndpoint();
        ReflectionTestUtils.setField(dcedTlsClient, "etcdEndpointUrl", (uri.getHost() + ":" + uri.getPort()));
        ReflectionTestUtils.setField(dcedTlsClient, "clientCertFilePath", "./src/test/resources/etcdctl-cert.pem"); //different cert
        final String keyString = getRandomString();
        final String valueString = getRandomString();
        final ByteSequence key = ByteSequence.from((keyString).getBytes());
        final ByteSequence value = ByteSequence.from(valueString.getBytes());

        final Client client = dcedTlsClient.getClient();
        final KV kvClient = client.getKVClient();
        kvClient.put(key, value).get();
    }
}
