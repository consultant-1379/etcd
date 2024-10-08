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
package com.ericsson.adp.mgmt.dced.bragent.exception;

/**
 * FileException class
 */
public class FileException extends RuntimeException {

    private static final long serialVersionUID = 7297844534421333440L;

    /**
     *
     * @param message
     *            - message to be passed
     */
    public FileException(final String message) {
        super(message);
    }

    /**
     *
     * @param throwable
     *            - throwable object
     */
    public FileException(final Throwable throwable) {
        super(throwable);
    }
}