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

import javax.annotation.PostConstruct;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import com.ericsson.adp.mgmt.bro.api.agent.Agent;
import com.ericsson.adp.mgmt.bro.api.agent.AgentFactory;
import com.ericsson.adp.mgmt.bro.api.agent.BackupExecutionActions;
import com.ericsson.adp.mgmt.bro.api.agent.OrchestratorConnectionInformation;
import com.ericsson.adp.mgmt.bro.api.agent.RestoreExecutionActions;

/**
 * DCEDAgentFactory class responsible for defining execution actions.
 */
@Component
public class DCEDAgentFactory {

    @Value("${orchestrator.host}")
    private String orchestratorHost;
    @Value("${orchestrator.port}")
    private int orchestratorPort;
    @Value("${dced.agent.bro.siptls.ca.name}")
    private String certificationAuthorityName;
    @Value("${dced.agent.bro.siptls.ca.path}")
    private String certificateAuthorityPath;
    @Value("${dced.agent.bro.flag.grpc.siptls.security.enabled}")
    private String grpcSecurityEnabled;
    @Value("${dced.agent.bro.client.cert.file}")
    private String clientCert;
    @Value("${dced.agent.bro.client.cert.keyfile}")
    private String clientPrivateKey;

    private Agent agent;
    private BackupExecutionActions backupExecutionActions;
    private RestoreExecutionActions restoreExecutionActions;
    @Autowired
    private DCEDAgentBehaviour dcedAgentBehaviour;
    private static final String GRPC_SECURITY_ENABLED = "true";

    /**
     * Prevents external instantiation.
     */
    private DCEDAgentFactory() {
    }

    /**
     * runs at bean initialization(class instantiation)
     *
     */
    @PostConstruct
    private void createAgentAndBackupExecutions() {
        OrchestratorConnectionInformation orchestratorConnectionInformation;
        if (GRPC_SECURITY_ENABLED.equalsIgnoreCase(grpcSecurityEnabled)) {
            orchestratorConnectionInformation = new OrchestratorConnectionInformation(orchestratorHost.trim(), orchestratorPort, certificationAuthorityName.trim(),
                    certificateAuthorityPath.trim(), clientCert.trim(), clientPrivateKey.trim());
        } else {
            orchestratorConnectionInformation = new OrchestratorConnectionInformation(orchestratorHost.trim(), orchestratorPort);
        }

        agent = AgentFactory.createAgent(orchestratorConnectionInformation, dcedAgentBehaviour);
    }

    /**
     * returns an instance of @{@link BackupExecutionActions}
     *
     * @return @{@link BackupExecutionActions}
     *
     */
    public BackupExecutionActions getBackupExecutionActions() {
        return backupExecutionActions;
    }

    /**
     * returns an instance of @{@link RestoreExecutionActions}
     *
     * @return @{@link RestoreExecutionActions}
     *
     */
    public RestoreExecutionActions getRestoreExecutionActions() {
        return restoreExecutionActions;
    }

    /**
     * @return the agent
     */
    public Agent getAgent() {
        return agent;
    }

}
