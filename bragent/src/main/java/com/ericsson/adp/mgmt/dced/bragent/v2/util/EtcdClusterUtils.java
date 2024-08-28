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
package com.ericsson.adp.mgmt.dced.bragent.v2.util;

import java.util.List;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import com.ericsson.adp.mgmt.dced.bragent.exception.ClusterException;
import com.ericsson.adp.mgmt.dced.bragent.v2.client.DcedClient;

import io.etcd.jetcd.ByteSequence;
import io.etcd.jetcd.KV;
import io.etcd.jetcd.KeyValue;
import io.etcd.jetcd.kv.GetResponse;
import io.etcd.jetcd.options.GetOption;
import io.etcd.jetcd.Client;

/**
 * Handles retrival and deletion of keys in etcd namespace.
 */
@Component
public class EtcdClusterUtils {
    private static final Logger log = LogManager.getLogger(EtcdClusterUtils.class);
    private static final String ALL_KEYS = "\0";

    @Autowired
    protected DcedClient dcedClient;

    private final int dcedReadTimeoutSecs;

    private final List<String> excludedPaths;

    private final List<String> includedPaths;

    /**
     * constructor
     *
     * @param dcedClient
     *            object to establish connection to etcd cluster
     * @param dcedReadTimeoutSecs
     *            timeout for command execution
     * @param includedPaths
     *            - list of paths in etcd host to obtain data from
     * @param excludedPaths
     *            - list of paths in etcd host to skip
     */
    public EtcdClusterUtils(@Autowired final DcedClient dcedClient, @Value("${dced.read.timeout.secs}") final int dcedReadTimeoutSecs,
                            @Value("#{'${dced.included.paths}'.trim().split(',')}") final List<String> includedPaths,
                            @Value("#{'${dced.excluded.paths}'.trim().split(',')}") final List<String> excludedPaths) {
        this.dcedClient = dcedClient;
        this.dcedReadTimeoutSecs = dcedReadTimeoutSecs;

        this.includedPaths = includedPaths;
        this.excludedPaths = excludedPaths;
    }

    /**
     * returns data from configured etcd host starting from paths specified by includedPaths and excluding paths specified by excludedPaths
     *
     * @return data in form of a list of @{@link KeyValue}.
     *
     */
    public List<KeyValue> retrieveDataFromEtcd() {
      Client etcdClient = null;
        try{
            //connect
            etcdClient = dcedClient.getClient();
            final KV kvClient = etcdClient.getKVClient();
            final GetOption option = GetOption.newBuilder().withRange(ByteSequence.from(ALL_KEYS.getBytes())).build();
            final GetResponse response = kvClient.get(ByteSequence.from(ALL_KEYS.getBytes()), option).get(dcedReadTimeoutSecs, TimeUnit.SECONDS);
            return filterBackupData(response.getKvs());
        } catch (final InterruptedException interruptedException) {
            log.error(String.format("InterruptedException occurred while connecting to etcd host: %s", interruptedException.getMessage()));
            Thread.currentThread().interrupt();
            throw new ClusterException(interruptedException);
        } catch (final ExecutionException | TimeoutException exception) {
            log.error(String.format("Exception occurred while reading data from etcd host: %s", exception.getMessage()));
            throw new ClusterException(exception);
        }
       finally{
            try{
              etcdClient.close();
            }catch(Exception e){
                log.error(String.format("Exception occurred while closing connection : %", e.getMessage()));
              }
       }
}

    /**
     * Deletes filtered keys present in the etcd cluster.
     */

    public void deleteKeysfromCluster() {
        final KV kvClient = dcedClient.getClient().getKVClient();
        final List<KeyValue> keyValues = retrieveDataFromEtcd();
        keyValues.forEach(keyvalue -> {
            try {
                kvClient.delete(keyvalue.getKey()).get();
            } catch (final InterruptedException interruptedException) {
                log.error(String.format("InterruptedException occurred while connecting to etcd host: %s", interruptedException.getMessage()));
                Thread.currentThread().interrupt();
                throw new ClusterException(interruptedException);
            } catch (final ExecutionException exception) {
                log.error(String.format("Exception occurred while deleting from etcd host: %s", exception.getCause().getMessage()));
                throw new ClusterException(exception.getCause());
            }
        });

    }

    private List<KeyValue> filterBackupData(final List<KeyValue> keyValues) {
        if ((isEmptyPath(includedPaths)) && (!isEmptyPath(excludedPaths))) {
            keyValues.removeIf(keyValue -> isPathExcluded(new String(keyValue.getKey().getBytes())));

        } else if ((!isEmptyPath(includedPaths))) { //wt incl paths
            keyValues.removeIf(keyValue -> !isPathIncluded(new String(keyValue.getKey().getBytes())));

            if (!isEmptyPath(excludedPaths)) {
                keyValues.removeIf(keyValue -> isPathExcluded(new String(keyValue.getKey().getBytes())));

            }
        }
        return keyValues;
    }

    private boolean isEmptyPath(final List<String> pathList) {
        return pathList.isEmpty() || (pathList.size() == 1 && pathList.get(0).equalsIgnoreCase(""));
    }

    private boolean isPathExcluded(final String path) {
        return excludedPaths.stream().anyMatch(e -> path.startsWith(e.trim()));
    }

    private boolean isPathIncluded(final String path) {
        return includedPaths.stream().anyMatch(e -> path.startsWith(e.trim()));
    }

}
