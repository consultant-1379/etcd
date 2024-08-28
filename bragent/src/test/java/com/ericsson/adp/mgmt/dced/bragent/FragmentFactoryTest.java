
/*------------------------------------------------------------------------------
 *******************************************************************************
 * COPYRIGHT Ericsson 2019
 *
 * The copyright to the computer program(s) herein is the property of
 * Ericsson Inc. The programs may be used and/or copied only with written
 * permission from Ericsson Inc. or in accordance with the terms and
 * conditions stipulated in the agreement/contract under which the
 * program(s) have been supplied.
 *******************************************************************************
 *----------------------------------------------------------------------------*/
package com.ericsson.adp.mgmt.dced.bragent;

import static org.junit.Assert.assertEquals;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.junit4.SpringJUnit4ClassRunner;

import com.ericsson.adp.mgmt.bro.api.fragment.BackupFragmentInformation;

@RunWith(SpringJUnit4ClassRunner.class)
@ContextConfiguration(classes = { FragmentFactory.class })
@TestPropertySource(properties = { "dced.agent.id=dced", "dced.agent.fragment.backup.data.path =./src/test/resources/backup2.txt" })
public class FragmentFactoryTest {

    public static final String RESOURCES_FOLDER_PATH = "./src/test/resources/";

    @Autowired
    private FragmentFactory fragmentFactory;

    List<BackupFragmentInformation> fragmentList = new ArrayList<>();

    @Before
    public void setUp() throws IOException {
        Files.createFile(Paths.get(RESOURCES_FOLDER_PATH + "backup2.txt"));
    }

    @After
    public void tearDown() throws IOException {
        Files.deleteIfExists(Paths.get(RESOURCES_FOLDER_PATH + "backup2.txt"));
    }

    @Test
    public void getFragmentList_propertiesFile_backupFragmentInformationList() throws Exception {

        final String version = "0.0.0";

        fragmentList = new ArrayList<>(fragmentFactory.getFragmentList());

        assertEquals("dced_1", fragmentList.get(0).getFragmentId());

        assertEquals(version, fragmentList.get(0).getVersion());

        assertEquals(RESOURCES_FOLDER_PATH + "backup2.txt", fragmentList.get(0).getBackupFilePath());
    }

}
