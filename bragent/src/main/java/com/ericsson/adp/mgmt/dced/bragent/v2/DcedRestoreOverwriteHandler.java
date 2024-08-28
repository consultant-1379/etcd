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

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Scope;
import org.springframework.stereotype.Component;

import com.ericsson.adp.mgmt.dced.bragent.exception.FileException;
import com.ericsson.adp.mgmt.dced.bragent.v2.util.EtcdClusterUtils;

/**
 * Handles restore process - deletes existing data present in Included paths before a restore.
 */
@Component
@Scope("prototype")
@ConditionalOnProperty(name = "dced.agent.restore.type", havingValue = "overwrite")
public class DcedRestoreOverwriteHandler extends DcedRestoreMergeHandler {
    private static final Logger log = LogManager.getLogger(DcedRestoreOverwriteHandler.class);

    @Autowired
    private final EtcdClusterUtils etcdClusterUtils;

    /**
     * constructor
     *
     * @param etcdClusterUtils
     *            - handles retrival and deletion of keys
     */
    public DcedRestoreOverwriteHandler(@Autowired final EtcdClusterUtils etcdClusterUtils) {
        super();
        this.etcdClusterUtils = etcdClusterUtils;
    }

    @Override
    public void restoreFromFile(final String filepath) {
        try {
            etcdClusterUtils.deleteKeysfromCluster();
            setRestorationData(new File(filepath + Paths.get(backupFilePath).getFileName().toString()));
        } catch (final IOException ioException) {
            log.error("IOException occurred while restoring from backup file located at {} : {}", backupFilePath, ioException);
            throw new FileException(ioException);
        }
    }

}