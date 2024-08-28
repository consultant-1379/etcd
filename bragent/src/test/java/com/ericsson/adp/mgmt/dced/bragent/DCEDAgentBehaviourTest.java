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
import static org.junit.Assert.assertFalse;

import java.net.URI;
import java.nio.file.Paths;
import java.util.UUID;

import org.junit.AfterClass;
import org.junit.Before;
import org.junit.BeforeClass;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.junit4.SpringJUnit4ClassRunner;
import org.springframework.test.util.ReflectionTestUtils;

import com.ericsson.adp.mgmt.bro.api.agent.BackupExecutionActions;
import com.ericsson.adp.mgmt.bro.api.agent.RestoreExecutionActions;
import com.ericsson.adp.mgmt.bro.api.fragment.BackupFragmentInformation;
import com.ericsson.adp.mgmt.bro.api.registration.RegistrationInformation;
import com.ericsson.adp.mgmt.bro.api.registration.SoftwareVersion;
import com.ericsson.adp.mgmt.dced.bragent.v2.DcedBackupHandler;
import com.ericsson.adp.mgmt.dced.bragent.v2.client.DcedClient;
import com.ericsson.adp.mgmt.dced.bragent.v2.utils.EtcdContainerUtils;
import com.ericsson.adp.mgmt.dced.bragent.v2.utils.EtcdTestUtils;

@RunWith(SpringJUnit4ClassRunner.class)
@ContextConfiguration(classes = { DCEDAgent.class, DcedClient.class, DcedBackupHandler.class, EtcdTestUtils.class })
@TestPropertySource(locations = { "classpath:test.properties" }, properties = "dced.certificates.enabled=false")
public class DCEDAgentBehaviourTest {

    @Autowired
    private DCEDAgentBehaviour dcedAgentBehaviour;
    @Autowired
    private EtcdTestUtils etcdTestUtils;
    @Value("${dced.agent.download.location}")
    private String downloadLocation;
    @Value("${dced.agent.fragment.backup.data.path}")
    private String backupFilePath;
    @Autowired
    private DcedBackupHandler dcedBackupHandler;
    @Autowired
    private DcedClient dcedClient;
    private static String rootPassword = getRandomString();

    @Value("${dced.agent.softwareVersion.semanticVersion}")
    private String softwareSemanticVersion;
    @Value("${dced.agent.softwareVersion.commercialVersion}")
    private String sofwareCommercialVersion;

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

    @Before
    public void pushData() {
        final URI uri = EtcdContainerUtils.etcdContainer.clientEndpoint();
        ReflectionTestUtils.setField(dcedClient, "ACL_ROOT_PASSWORD", rootPassword);
        ReflectionTestUtils.setField(dcedClient, "etcdEndpointUrl", (uri.getHost() + ":" + uri.getPort()));
        etcdTestUtils.pushDataToEtcd("extranode", "sanityCheck".getBytes(), rootPassword);
        etcdTestUtils.pushDataToEtcd("singlenode", getRandomString().getBytes(), rootPassword);
        etcdTestUtils.pushDataToEtcd("samplenode", getRandomString().getBytes(), rootPassword);
        etcdTestUtils.pushDataToEtcd("samplenode/test", getRandomString().getBytes(), rootPassword);
        etcdTestUtils.pushDataToEtcd("samplenode/bl", getRandomString().getBytes(), rootPassword);
        etcdTestUtils.pushDataToEtcd("samplenode/blo", getRandomString().getBytes(), rootPassword);
        etcdTestUtils.pushDataToEtcd("samplenode/block", getRandomString().getBytes(), rootPassword);
    }

    @Test
    public void getRegistrationInformation_propertiesFile_registrationInformationFilledFromProperties() {

        final RegistrationInformation registrationInformation = dcedAgentBehaviour.getRegistrationInformation();

        assertEquals("dcedAgent", registrationInformation.getAgentId());
        assertEquals("5.8.0", registrationInformation.getApiVersion());
        assertEquals("alpha", registrationInformation.getScope());
        assertEquals("Agent for Distributed Coordinator ED", registrationInformation.getSoftwareVersion().getDescription());
        assertEquals("date", registrationInformation.getSoftwareVersion().getProductionDate());
        assertEquals("distributed-coordinator-ed-brAgent", registrationInformation.getSoftwareVersion().getProductName());
        assertEquals("CXC 201 2039/1", registrationInformation.getSoftwareVersion().getProductNumber());
        assertEquals("Database", registrationInformation.getSoftwareVersion().getType());
        assertEquals("2", registrationInformation.getSoftwareVersion().getRevision());
    }

    @Test
    public void createBackup_successful_methodCalls() throws Exception {
        final String backupName = "myTestBackup";
        final String message = "The DCED service has completed a backup for " + backupName + " and the data has been sent to the orchestrator";
        final BackupExecutionActions backupExecutionActionsMocked = Mockito.mock(BackupExecutionActions.class);

        Mockito.when(backupExecutionActionsMocked.getBackupName()).thenReturn(backupName);
        dcedAgentBehaviour.executeBackup(backupExecutionActionsMocked);

        Mockito.verify(backupExecutionActionsMocked, Mockito.times(1)).backupComplete(true, message);
        Mockito.verify(backupExecutionActionsMocked, Mockito.times(1)).sendBackup(Mockito.any(BackupFragmentInformation.class));
    }

    @Test
    public void createBackup_successful_tempBackupFileDeleted() throws Exception {
        final String fileBackupPath = "./src/test/resources/backuptobedeleted.txt";
        ReflectionTestUtils.setField(dcedAgentBehaviour, "backupFilePath", fileBackupPath);
        final BackupExecutionActions backupExecutionActionsMocked = Mockito.mock(BackupExecutionActions.class);
        Mockito.when(backupExecutionActionsMocked.getBackupName()).thenReturn("backuptobedeleted.txt");
        dcedAgentBehaviour.executeBackup(backupExecutionActionsMocked);
        dcedBackupHandler.backupToFile();
        assertFalse(Paths.get(fileBackupPath).toFile().exists());
        ReflectionTestUtils.setField(dcedAgentBehaviour, "backupFilePath", backupFilePath);
    }

    @Test
    public void executeRestore_successful_methodCall() {
        final String backupName = "myTestBackup";
        final String message = "The DCED service has completed restore of backup: myTestBackup";
        final RestoreExecutionActions restoreExecutionActionsMocked = Mockito.mock(RestoreExecutionActions.class);
        Mockito.when(restoreExecutionActionsMocked.getSoftwareVersion()).thenReturn(new SoftwareVersion("distributed-coordinator-ed-brAgent",
                "CXC 201 2039/1", "2", "date", "Agent for Distributed Coordinator ED", "Database", softwareSemanticVersion, sofwareCommercialVersion));
        Mockito.when(restoreExecutionActionsMocked.getBackupName()).thenReturn(backupName);
        dcedAgentBehaviour.executeRestore(restoreExecutionActionsMocked);
        Mockito.verify(restoreExecutionActionsMocked, Mockito.times(1)).restoreComplete(true, message);
        assertFalse(Paths.get(downloadLocation).toFile().exists());
    }

    @Test
    public void trim_softwareVersion_successful_methodCall() {
        final String backupName = "myTestBackup";
        final String message = "The DCED service has completed restore of backup: myTestBackup";
        final RestoreExecutionActions restoreExecutionActionsMocked = Mockito.mock(RestoreExecutionActions.class);
        Mockito.when(restoreExecutionActionsMocked.getSoftwareVersion()).thenReturn(new SoftwareVersion("distributed-coordinator-ed-brAgent",
                "CXC 201 2039/1", "2", "date", "Agent for Distributed Coordinator ED", "Database",  softwareSemanticVersion.split("-")[0].trim(), sofwareCommercialVersion.split("-")[0].trim()));
        Mockito.when(restoreExecutionActionsMocked.getBackupName()).thenReturn(backupName);
        dcedAgentBehaviour.executeRestore(restoreExecutionActionsMocked);
        Mockito.verify(restoreExecutionActionsMocked, Mockito.times(1)).restoreComplete(true, message);
        assertFalse(Paths.get(downloadLocation).toFile().exists());
    }

    @Test
    public void executeRestore_throwsException_getFailureMessage() throws Exception {
        final String backupName = "myTestBackup";
        final String failure_message = "The DCED service failed to complete restore of backup: myTestBackup, Cause: exception";
        final RestoreExecutionActions restoreExecutionActionsMocked = Mockito.mock(RestoreExecutionActions.class);
        Mockito.when(restoreExecutionActionsMocked.getBackupName()).thenReturn(backupName);
        Mockito.when(restoreExecutionActionsMocked.getFragmentList()).thenThrow(new ArrayIndexOutOfBoundsException("exception"));
        Mockito.when(restoreExecutionActionsMocked.getSoftwareVersion()).thenReturn(new SoftwareVersion("distributed-coordinator-ed-brAgent",
                "CXC 201 2039/1", "2", "date", "Agent for Distributed Coordinator ED", "Database",  softwareSemanticVersion.split("-")[0].trim(), sofwareCommercialVersion.split("-")[0].trim()));
        dcedAgentBehaviour.executeRestore(restoreExecutionActionsMocked);
        Mockito.verify(restoreExecutionActionsMocked, Mockito.times(1)).restoreComplete(false, failure_message);
    }

    @Test
    public void executeRestore_softwareVersion() throws Exception {
        final String backupName = "myTestBackup";
        final String failure_message = "Restore of backup myTestBackup failed due to software version incompatibility";
        final String success_message = "The DCED service has completed restore of backup: myTestBackup";
        final RestoreExecutionActions restoreExecutionActionsMocked = Mockito.mock(RestoreExecutionActions.class);
        Mockito.when(restoreExecutionActionsMocked.getBackupName()).thenReturn(backupName);
        dcedAgentBehaviour.getSoftwareVersion();
        // software Version empty
        Mockito.when(restoreExecutionActionsMocked.getSoftwareVersion()).thenReturn(null);
        dcedAgentBehaviour.executeRestore(restoreExecutionActionsMocked);
        Mockito.verify(restoreExecutionActionsMocked, Mockito.times(1)).restoreComplete(false, failure_message);

        // product name mismatch
        Mockito.when(restoreExecutionActionsMocked.getSoftwareVersion())
                .thenReturn(new SoftwareVersion("wrong", "CXC 201 2039/1", "2", "date", "Agent for Distributed Coordinator ED", "Database",  softwareSemanticVersion.split("-")[0].trim(), sofwareCommercialVersion.split("-")[0].trim()));
        dcedAgentBehaviour.executeRestore(restoreExecutionActionsMocked);
        Mockito.verify(restoreExecutionActionsMocked, Mockito.times(2)).restoreComplete(false, failure_message);

        // product number mismatch
        Mockito.when(restoreExecutionActionsMocked.getSoftwareVersion()).thenReturn(
                new SoftwareVersion("distributed-coordinator-ed-brAgent", "wrong", "2", "date", "Agent for Distributed Coordinator ED", "Database",  softwareSemanticVersion.split("-")[0].trim(), sofwareCommercialVersion.split("-")[0].trim()));
        dcedAgentBehaviour.executeRestore(restoreExecutionActionsMocked);
        Mockito.verify(restoreExecutionActionsMocked, Mockito.times(3)).restoreComplete(false, failure_message);

        // revision mismatch
        Mockito.when(restoreExecutionActionsMocked.getSoftwareVersion()).thenReturn(new SoftwareVersion("distributed-coordinator-ed-brAgent",
                "CXC 201 2039/1", "wrong", "date", "Agent for Distributed Coordinator ED", "Database",  softwareSemanticVersion.split("-")[0].trim(), sofwareCommercialVersion.split("-")[0].trim()));
        dcedAgentBehaviour.executeRestore(restoreExecutionActionsMocked);
        Mockito.verify(restoreExecutionActionsMocked, Mockito.times(4)).restoreComplete(false, failure_message);

        // productionDate mismatch
        Mockito.when(restoreExecutionActionsMocked.getSoftwareVersion()).thenReturn(new SoftwareVersion("distributed-coordinator-ed-brAgent",
                "CXC 201 2039/1", "2", "wrong", "Agent for Distributed Coordinator ED", "Database",  softwareSemanticVersion.split("-")[0].trim(), sofwareCommercialVersion.split("-")[0].trim()));
        dcedAgentBehaviour.executeRestore(restoreExecutionActionsMocked);
        Mockito.verify(restoreExecutionActionsMocked, Mockito.times(1)).restoreComplete(true, success_message);

        // description mismatch
        Mockito.when(restoreExecutionActionsMocked.getSoftwareVersion())
                .thenReturn(new SoftwareVersion("distributed-coordinator-ed-brAgent", "CXC 201 2039/1", "2", "date", "wrong", "Database",  softwareSemanticVersion.split("-")[0].trim(), sofwareCommercialVersion.split("-")[0].trim()));
        dcedAgentBehaviour.executeRestore(restoreExecutionActionsMocked);
        Mockito.verify(restoreExecutionActionsMocked, Mockito.times(2)).restoreComplete(true, success_message);

        // type mismatch
        Mockito.when(restoreExecutionActionsMocked.getSoftwareVersion()).thenReturn(new SoftwareVersion("distributed-coordinator-ed-brAgent",
                "CXC 201 2039/1", "2", "date", "Agent for Distributed Coordinator ED", "wrong",  softwareSemanticVersion.split("-")[0].trim(), sofwareCommercialVersion.split("-")[0].trim()));
        dcedAgentBehaviour.executeRestore(restoreExecutionActionsMocked);
        Mockito.verify(restoreExecutionActionsMocked, Mockito.times(5)).restoreComplete(false, failure_message);
    }

}
