package com.ericsson.adp.mgmt.dced.bragent.v2.utils;

import java.io.IOException;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.List;
import java.util.concurrent.ExecutionException;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.test.util.ReflectionTestUtils;

import com.ericsson.adp.mgmt.dced.bragent.exception.FileException;
import com.ericsson.adp.mgmt.dced.bragent.v2.client.DcedClient;

import io.etcd.jetcd.ByteSequence;
import io.etcd.jetcd.Client;
import io.etcd.jetcd.KV;
import io.etcd.jetcd.KeyValue;
import io.etcd.jetcd.kv.GetResponse;
import io.etcd.jetcd.options.GetOption;

@Component
public class EtcdTestUtils {

    private static final Logger log = LogManager.getLogger(EtcdTestUtils.class);
    public static final String RESOURCES_FOLDER_PATH = "./src/test/resources/";
    @Autowired
    private DcedClient dcedClient;

    public static void setupEtcdHost(final boolean sslEnabled, final String rootPassword) {
        EtcdContainerUtils.setupWithSsl(sslEnabled, rootPassword);
    }

    public void pushDataToEtcd(final String keyString, final byte[] valueBytes, final String rootPassword) {
        try {
            //setup
            final URI uri = EtcdContainerUtils.etcdContainer.clientEndpoint();
            ReflectionTestUtils.setField(dcedClient, "ACL_ROOT_PASSWORD", rootPassword);
            ReflectionTestUtils.setField(dcedClient, "etcdEndpointUrl", (uri.getHost() + ":" + uri.getPort()));
            final ByteSequence key = ByteSequence.from((keyString).getBytes());
            final ByteSequence value = ByteSequence.from(valueBytes);

            //connect
            final Client client = dcedClient.getClient();
            final KV kvClient = client.getKVClient();
            kvClient.put(key, value).get();
        } catch (final ExecutionException | InterruptedException exception) {
            log.error(String.format("Exception occurred while writing to etcd: %s", exception.getMessage()));
        }
    }

    public void createRestoreFolder(final String filepath, final boolean toMakeEmptyFile) {
        final Path restoreBackupFile = Paths.get(filepath + "/backup.txt");
        try {
            if (!restoreBackupFile.getParent().toFile().exists()) {
                Files.createDirectory(restoreBackupFile.getParent());
            }
            Files.deleteIfExists(restoreBackupFile);
            if (toMakeEmptyFile) {
                Files.createFile(restoreBackupFile);
            } else {
                Files.copy(Paths.get(RESOURCES_FOLDER_PATH + "backupfresh.txt"), restoreBackupFile, StandardCopyOption.REPLACE_EXISTING);
            }
        } catch (

        final IOException ioException) {
            throw new FileException(ioException);
        }

    }

    public List<KeyValue> getAllKeys(final String rootPassword) throws InterruptedException, ExecutionException {
        final URI uri = EtcdContainerUtils.etcdContainer.clientEndpoint();
        ReflectionTestUtils.setField(dcedClient, "ACL_ROOT_PASSWORD", rootPassword);
        ReflectionTestUtils.setField(dcedClient, "etcdEndpointUrl", (uri.getHost() + ":" + uri.getPort()));
        final Client client = dcedClient.getClient();
        final KV kvClient = client.getKVClient();
        final GetOption option = GetOption.newBuilder().withRange(ByteSequence.from("\0".getBytes())).build();
        final GetResponse response = kvClient.get(ByteSequence.from("\0".getBytes()), option).get();
        return response.getKvs();
    }

    public static void tearDown() {
        EtcdContainerUtils.tearDown();
    }

}
