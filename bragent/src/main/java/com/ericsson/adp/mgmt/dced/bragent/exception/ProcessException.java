package com.ericsson.adp.mgmt.dced.bragent.exception;

/**
 *
 */
public class ProcessException extends RuntimeException {
    /**
     *
     */
    private static final long serialVersionUID = -2627004816339049436L;

    /**
     *
     * @param message
     *            - message to be passed
     */
    public ProcessException(final String message) {
        super(message);
    }

    /**
     *
     * @param throwable
     *            - throwable object
     */
    public ProcessException(final Throwable throwable) {
        super(throwable);
    }
}
