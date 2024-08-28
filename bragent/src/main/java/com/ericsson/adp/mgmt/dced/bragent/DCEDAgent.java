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

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Starts the DCED Backup and Restore Agent.
 */
@SpringBootApplication
public class DCEDAgent {

    private static final Logger log = LogManager.getLogger(DCEDAgent.class);

    private static ExecutorService executorService;


    /**
    *
    * @param args
    *              - command line args
    */
    public static void main(final String[] args) {

        keepApplicationAlive();
        SpringApplication.run(DCEDAgent.class, args);
    }

    public static ExecutorService getExecutorService() {
        return executorService;
    }

    /**
     * Kills agent if required.
     */
    public static void killAgent() {
        log.info("Terminating agent");
        executorService.shutdownNow();
        executorService = null;
    }

    private static void keepApplicationAlive() {
        executorService = Executors.newSingleThreadExecutor();
        executorService.execute(() -> log.info("Keeping DCEDAgent alive"));
    }

}
