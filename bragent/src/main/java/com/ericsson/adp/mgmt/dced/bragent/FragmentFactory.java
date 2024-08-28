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
package com.ericsson.adp.mgmt.dced.bragent;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import com.ericsson.adp.mgmt.bro.api.fragment.BackupFragmentInformation;
import com.ericsson.adp.mgmt.dced.bragent.exception.FileException;

/**
 * Implements logic to create backup fragments
 */
@Component
public class FragmentFactory {

    private static final int FRAGMENT_NUMBER = 1;
    private static final String FRAGMENT_VERSION = "0.0.0";
    @Value("${dced.agent.id}")
    private String agentId;
    @Value("${dced.agent.fragment.backup.data.path}")
    private String backupFilePath;

    /**
     * implements logic to create backup fragments
     *
     * @return list of backup fragments
     * @throws Exception
     */
    public List<BackupFragmentInformation> getFragmentList() {
        final List<BackupFragmentInformation> fragmentList = new ArrayList<>();

        fragmentList.add(getFragment(FRAGMENT_NUMBER, backupFilePath));

        return fragmentList;
    }

    private BackupFragmentInformation getFragment(final int fragmentNumber, final String backupPath) {

        final String fragmentId = agentId + "_" + fragmentNumber;
        final String sizeInBytes = getFileSizeInBytes(backupPath);

        final BackupFragmentInformation fragmentInformation = new BackupFragmentInformation();

        fragmentInformation.setFragmentId(fragmentId);
        fragmentInformation.setSizeInBytes(sizeInBytes);
        fragmentInformation.setVersion(FRAGMENT_VERSION);

        fragmentInformation.setBackupFilePath(backupPath);
        return fragmentInformation;
    }

    private String getFileSizeInBytes(final String pathString) {
        try {
            final Path path = Paths.get(pathString);
            return Long.toString(Files.size(path));
        } catch (final IOException e) {
            throw new FileException("The file that was created for the backup has encountered a problem: " + pathString);
        }
    }
}
