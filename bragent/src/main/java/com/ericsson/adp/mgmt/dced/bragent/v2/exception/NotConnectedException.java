package com.ericsson.adp.mgmt.dced.bragent.v2.exception;

/**
 * Handles exception related to etcd - NotConnectedException
 */
public class NotConnectedException extends RuntimeException {

    /**
     *
     * @param throwable
     *         - throwable object
     */
    public NotConnectedException(final Throwable throwable) {
        super(throwable);
    }
}
