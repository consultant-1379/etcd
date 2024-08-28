/**------------------------------------------------------------------------------
 *******************************************************************************
 * COPYRIGHT Ericsson 2020
 *
 * The copyright to the computer program(s) herein is the property of
 * Ericsson Inc. The programs may be used and/or copied only with written
 * permission from Ericsson Inc. or in accordance with the terms and
 * conditions stipulated in the agreement/contract under which the
 * program(s) have been supplied.
 *******************************************************************************
 *------------------------------------------------------------------------------*/
package com.ericsson.adp.mgmt.dced.bragent.v2;

import java.io.File;
import java.io.IOException;
import java.nio.file.Paths;
import java.util.LinkedHashMap;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Scope;
import org.springframework.stereotype.Component;

import com.ericsson.adp.mgmt.dced.bragent.exception.ClusterException;
import com.ericsson.adp.mgmt.dced.bragent.exception.FileException;
import com.ericsson.adp.mgmt.dced.bragent.v2.client.DcedClient;
import com.ericsson.adp.mgmt.dced.bragent.v2.util.RestorationDataMapper;
import com.fasterxml.jackson.databind.ObjectMapper;

import io.etcd.jetcd.ByteSequence;
import io.etcd.jetcd.KV;
import io.etcd.jetcd.options.PutOption;

/**
 * Handles restore process - Merge/append to existing etcd data.
 */

@Component
@Scope("prototype")
@ConditionalOnProperty(name = "dced.agent.restore.type", havingValue = "merge")
public class DcedRestoreMergeHandler {

    private static final Logger log = LogManager.getLogger(DcedRestoreMergeHandler.class);
    @Autowired
    protected DcedClient dcedClient;
    @Value("${dced.read.timeout.secs}")
    protected int dcedReadTimeoutSecs;
    @Value("${dced.agent.fragment.backup.data.path}")
    protected String backupFilePath;

    /**
     * reads backupfile containing Key Value pairs in JSON format, converts to ByteStream writes to the etcd cluster.
     *
     * @param filepath
     *            - path from where data needs to be read.
     */
    public void restoreFromFile(final String filepath) {
        try {
            setRestorationData(new File(filepath + Paths.get(backupFilePath).getFileName().toString()));
        } catch (final IOException ioException) {
            log.error("IOException occurred while restoring from backup file located at {} : {}", backupFilePath, ioException);
            throw new FileException(ioException);
        }
    }

    /**
     * Converts json to ByteSequence
     *
     * @param file
     *            - json file
     * @throws IOException
     *             - io exception
     */
    void setRestorationData(final File file) throws IOException {
        final ObjectMapper mapper = new ObjectMapper();
        final RestorationDataMapper restorationMapper = mapper.readValue(file, RestorationDataMapper.class);
        putKeyValuePairToEtcd(restorationMapper.getDataToRestore());
    }

    /**
     * writes data from List of keyvalue pairs to etcd
     *
     * @param restorationData
     *            -Linked Hashmap of Keyvalue pairs
     */
    void putKeyValuePairToEtcd(final LinkedHashMap<ByteSequence, ByteSequence> restorationData) {
        final KV kvClient = dcedClient.getClient().getKVClient();
        final PutOption option = PutOption.DEFAULT;
        restorationData.forEach((key, value) -> {
            try {
                kvClient.put(key, value, option).get(dcedReadTimeoutSecs, TimeUnit.SECONDS);
            } catch (final InterruptedException interruptedException) {
                log.error(String.format("InterruptedException occurred while connecting to etcd host: %s", interruptedException.getMessage()));
                Thread.currentThread().interrupt();
                throw new ClusterException(interruptedException);
            } catch (final ExecutionException | TimeoutException exception) {
                log.error(String.format("Exception occurred while writing to etcd host: %s", exception.getCause().getMessage()));
                throw new ClusterException(exception.getCause());
            }
        });

    }

}