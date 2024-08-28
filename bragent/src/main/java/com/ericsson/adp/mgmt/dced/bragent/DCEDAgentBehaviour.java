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

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Stream;

import org.apache.commons.lang3.exception.ExceptionUtils;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.ericsson.adp.mgmt.bro.api.agent.AgentBehavior;
import com.ericsson.adp.mgmt.bro.api.agent.BackupExecutionActions;
import com.ericsson.adp.mgmt.bro.api.agent.RestoreExecutionActions;
import com.ericsson.adp.mgmt.bro.api.fragment.BackupFragmentInformation;
import com.ericsson.adp.mgmt.bro.api.fragment.FragmentInformation;
import com.ericsson.adp.mgmt.bro.api.registration.RegistrationInformation;
import com.ericsson.adp.mgmt.bro.api.registration.SoftwareVersion;
import com.ericsson.adp.mgmt.dced.bragent.exception.FileException;
import com.ericsson.adp.mgmt.dced.bragent.v2.DcedBackupHandler;
import com.ericsson.adp.mgmt.dced.bragent.v2.DcedRestoreMergeHandler;

import com.ericsson.adp.mgmt.control.BackendType;
import com.ericsson.adp.mgmt.metadata.AgentFeature;

import java.util.ArrayList;
import java.util.EnumSet;
import java.util.stream.Collectors;
/**
 * DCED Agent behavior implements BroApi agent Behavior
 */
@Service
public class DCEDAgentBehaviour implements AgentBehavior {

    private static final Logger log = LogManager.getLogger(DCEDAgentBehaviour.class);
    private SoftwareVersion softwareVersion;

    @Value("${dced.agent.softwareVersion.description}")
    private String softwareVersionDescription;
    @Value("${dced.agent.softwareVersion.productionDate}")
    private String softwareVersionProductionDate;
    @Value("${dced.agent.softwareVersion.type}")
    private String softwareVersionType;
    @Value("${dced.agent.softwareVersion.productName}")
    private String softwareVersionProductName;
    @Value("${dced.agent.softwareVersion.productNumber}")
    private String softwareVersionProductNumber;
    @Value("${dced.agent.softwareVersion.revision}")
    private String softwareVersionRevision;
    @Value("${dced.agent.softwareVersion.semanticVersion}")
    private String softwareSemanticVersion;
    @Value("${dced.agent.softwareVersion.commercialVersion}")
    private String sofwareCommercialVersion;
    @Value("${dced.agent.id}")
    private String agentId;
    @Value("${dced.agent.scope}")
    private String scope;
    @Value("${dced.agent.apiVersion}")
    private String apiVersion;

    @Value("${dced.agent.download.location}")
    private String downloadLocation;

    @Value("${dced.agent.fragment.backup.data.path}")
    private String backupFilePath;

    @Autowired
    private FragmentFactory fragmentFactory;
    @Autowired
    private DcedBackupHandler dcedBackupHandler;
    @Autowired
    private DcedRestoreMergeHandler dcedRestoreHandler;

    @Override
    public RegistrationInformation getRegistrationInformation() {
        /* TODO */
        final ArrayList<String> agentFeatureList1 = new ArrayList<>();
        agentFeatureList1.add("PLAINTEXT");
        agentFeatureList1.add("TLS");
        agentFeatureList1.add("MTLS");
        agentFeatureList1.add("MULTIPLE_BACKUP_TYPES");
        final ArrayList<AgentFeature> agentFeatureList = new ArrayList<>(EnumSet.allOf(AgentFeature.class).stream().filter(a -> agentFeatureList1.contains(a.toString())).collect(
                Collectors.toList()));
        this.softwareVersion = new SoftwareVersion(softwareVersionProductName.trim(), softwareVersionProductNumber.trim(), softwareVersionRevision.trim(),
                softwareVersionProductionDate.trim(), softwareVersionDescription.trim(), softwareVersionType.trim(), softwareSemanticVersion.split("-")[0].trim(), sofwareCommercialVersion.split("-")[0].trim());
        return new RegistrationInformation(agentId.trim(), scope.trim(), apiVersion.trim(), this.getSoftwareVersion(), agentFeatureList, BackendType.BRO);
    }

    @Override
    public void executeBackup(final BackupExecutionActions backupExecutionActions) {
        boolean success = false;
        String message;
        try {
            for (final BackupFragmentInformation fragment : createBackup()) {
                backupExecutionActions.sendBackup(fragment);
            }
            success = true;
            message = "The DCED service has completed a backup for " + backupExecutionActions.getBackupName().trim()
                    + " and the data has been sent to the orchestrator";
            log.info(message);
        } catch (final Exception e) {
            message = "The DCED service failed to complete a backup " + backupExecutionActions.getBackupName().trim() + " Cause: " + e.getMessage()
                    + " The DCED service will not retry to send the backup";
            log.error(message);
            log.error(ExceptionUtils.getStackTrace(e));

        }
        backupExecutionActions.backupComplete(success, message);
        deleteFileAfterAction(backupFilePath.trim());
    }

    @Override
    public void executeRestore(final RestoreExecutionActions restoreExecutionActions) {

        boolean success = false;
        String message;
        try {
            if (isCompatibleSoftwareVersion(restoreExecutionActions.getSoftwareVersion())) {
                final List<FragmentInformation> fragmentList = restoreExecutionActions.getFragmentList();
                for (final FragmentInformation fragmentInformation : fragmentList) {
                    restoreExecutionActions.downloadFragment(fragmentInformation, downloadLocation);
                    message = "Restoring data from fragment: " + fragmentInformation.getFragmentId().trim();
                    log.info(message);
                    dcedRestoreHandler.restoreFromFile(downloadLocation.trim());
                }
                success = true;
                message = "The DCED service has completed restore of backup: " + restoreExecutionActions.getBackupName().trim();
                log.info(message);
            } else {
                message = "Restore of backup " + restoreExecutionActions.getBackupName().trim() + " failed due to software version incompatibility";
                log.error(message);

            }
        } catch (final Exception e) {
            message = "The DCED service failed to complete restore of backup: " + restoreExecutionActions.getBackupName().trim() + ", Cause: "
                    + e.getMessage();
            log.error(message);
            log.error(ExceptionUtils.getStackTrace(e));
        }

        restoreExecutionActions.restoreComplete(success, message);
        deleteFileAfterAction(downloadLocation.trim());

    }

    /**
     * @return the softwareVersion
     */
    public SoftwareVersion getSoftwareVersion() {
        return softwareVersion;
    }

    private void deleteFileAfterAction(final String filePath) {
        final Path deleteFilePath = Paths.get(filePath);
        if (deleteFilePath.toFile().exists()) {
            try (Stream<Path> files = Files.walk(deleteFilePath)) {
                if (deleteFilePath.toFile().isDirectory()) {
                    files.sorted(Comparator.reverseOrder()).map(Path::toFile).forEach(File::delete);
                } else {
                    Files.delete(deleteFilePath);
                }
            } catch (final IOException ioException) {
                log.error(String.format("IOException occurred while deleting file: %s", ioException.getMessage()));
                throw new FileException(ioException);

            }
        }

    }

    private List<BackupFragmentInformation> createBackup() {
        // handler call
        dcedBackupHandler.backupToFile();
        return fragmentFactory.getFragmentList();
    }

    private Boolean isCompatibleSoftwareVersion(final SoftwareVersion softwareVersion) {

        if (softwareVersion == null) {
            log.error("Backup Software Version is not set");
            return false;
        }

        if (!(this.softwareVersion.getProductName().trim().equals(softwareVersion.getProductName())
                || "distributor-coordinator-ed".equals(softwareVersion.getProductName().trim()))) {
            log.error("Product Name does not match: expected {} but got {}", this.softwareVersion.getProductName().trim(), softwareVersion.getProductName().trim());
            return false;
        }

        if (!(this.softwareVersion.getProductNumber().trim().equals(softwareVersion.getProductNumber().trim()) || "1".equals(softwareVersion.getProductNumber().trim()))) {
            log.error("Product Number does not match: expected {} but got {} ", this.softwareVersion.getProductNumber(),
                    softwareVersion.getProductNumber());
            return false;
        }

        if (!(this.softwareVersion.getRevision().equals(softwareVersion.getRevision().trim()) || "revision number".equals(softwareVersion.getRevision().trim()))) {
            log.error("Revision does not match: expected {} but got {} ", this.softwareVersion.getRevision().trim(), softwareVersion.getRevision().trim());
            return false;
        }

        if (!(this.softwareVersion.getType().trim().equals(softwareVersion.getType().trim()) || "database".equals(softwareVersion.getType().trim()))) {
            log.error("Type does not match: expected {} but got {} ", this.softwareVersion.getType().trim(), softwareVersion.getType().trim());
            return false;
        }

        return true;
    }

}
