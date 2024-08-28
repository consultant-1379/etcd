package com.ericsson.adp.mgmt.dced.bragent.v2.exception;

/**
 * Exeception to handle JSON
 */
public class JsonException extends RuntimeException {
    private static final long serialVersionUID = 3490793924874584659L;

    /**
     *
     * @param throwable
     *            - throwable object
     */
    public JsonException(final Throwable throwable) {
        super(throwable);
    }
}
