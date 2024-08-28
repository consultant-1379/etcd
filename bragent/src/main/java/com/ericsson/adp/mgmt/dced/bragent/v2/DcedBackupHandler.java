package com.ericsson.adp.mgmt.dced.bragent.v2;

import java.io.File;
import java.io.IOException;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Scope;
import org.springframework.stereotype.Component;

import com.ericsson.adp.mgmt.dced.bragent.exception.FileException;
import com.ericsson.adp.mgmt.dced.bragent.v2.exception.JsonException;
import com.ericsson.adp.mgmt.dced.bragent.v2.util.EtcdClusterUtils;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * Handles backup process
 */

@Component
@Scope("prototype")
public class DcedBackupHandler {

    private static final Logger log = LogManager.getLogger(DcedBackupHandler.class);
    @Value("${dced.agent.fragment.backup.data.path}")
    private final String backupFilePath;
    @Autowired
    private final EtcdClusterUtils etcdClusterUtils;

    /**
     * constructor
     *
     * @param backupFilePath
     *            - name of backup file
     * @param etcdClusterUtils
     *            - handles retrival and deletion of keys
     *
     */
    public DcedBackupHandler(@Value("${dced.agent.fragment.backup.data.path}") final String backupFilePath,
                             @Autowired final EtcdClusterUtils etcdClusterUtils) {
        this.backupFilePath = backupFilePath;
        this.etcdClusterUtils = etcdClusterUtils;
    }

    /**
     * retrieves data from etcd host and backups to file
     *
     */
    public void backupToFile() {

        try {
            final ObjectMapper objectMapper = new ObjectMapper();
            final ObjectNode rootNode = JsonNodeFactory.instance.objectNode();
            etcdClusterUtils.retrieveDataFromEtcd().forEach(keyValue -> {
                try {
                    rootNode.put(new String(keyValue.getKey().getBytes()), objectMapper.writeValueAsString(keyValue.getValue().getBytes()));
                } catch (final JsonProcessingException jsonProcessingException) {
                    log.error(String.format("JsonProcessingException occurred while writing key: %s to backup file: %s",
                            new String(keyValue.getKey().getBytes()), jsonProcessingException.getMessage()));
                    throw new JsonException(jsonProcessingException);
                }
            });

            objectMapper.writerWithDefaultPrettyPrinter().writeValue(new File(backupFilePath), rootNode);

        } catch (final IOException ioException) {
            log.error(
                    String.format("IOException occurred while writing to backup file located at %s : %s", backupFilePath, ioException.getMessage()));
            throw new FileException(ioException);
        }
    }

}
