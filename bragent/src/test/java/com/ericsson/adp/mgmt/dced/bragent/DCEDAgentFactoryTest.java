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

import static org.junit.Assert.assertTrue;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.junit4.SpringJUnit4ClassRunner;

import com.ericsson.adp.mgmt.bro.api.agent.Agent;

@RunWith(SpringJUnit4ClassRunner.class)
@ContextConfiguration(classes = { DCEDAgent.class })
@TestPropertySource(locations = { "classpath:test.properties" })
public class DCEDAgentFactoryTest {

    @Autowired
    private DCEDAgentFactory dcedAgentFactory;

    @Test
    public void test() {
        assertTrue(dcedAgentFactory.getAgent() instanceof Agent);
    }

}
