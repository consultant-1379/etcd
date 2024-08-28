/**------------------------------------------------------------------------------
 *******************************************************************************
 * COPYRIGHT Ericsson 2020
 *
 * The copyright to the computer program(s) herein is the property of
 * Ericsson Inc. The programs may be used and/or copied only with written
 * permission from Ericsson Inc. or in accordance with the terms and
 * conditions stipulated in the agreement/contract under which the
 * program(s) have been supplied.
 *******************************************************************************
 *------------------------------------------------------------------------------*/
package com.ericsson.adp.mgmt.dced.bragent.v2.util;

import java.util.Base64;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Objects;

import io.etcd.jetcd.ByteSequence;

/**
 * Utility class to convert map from JSON to jetcd ByteSequence
 */
public class RestorationDataMapper extends HashMap<String, String> {
    private static final long serialVersionUID = 1L;
    private LinkedHashMap<ByteSequence, ByteSequence> restorationData = new LinkedHashMap<>();

    @Override
    public String put(final String key, final String value) {
        restorationData.put(ByteSequence.from(key.getBytes()), getDecodedByteSequence(value));
        return value;
    }

    /**
     * Decodes Values from Base64and returns Bytesequence.
     *
     * @param value
     *            - Base64
     * @return - ByteSequence
     */
    private ByteSequence getDecodedByteSequence(final String value) {
        return ByteSequence.from(Base64.getMimeDecoder().decode(value));
    }

    public LinkedHashMap<ByteSequence, ByteSequence> getDataToRestore() {
        return restorationData;
    }

    @Override
    public boolean equals(final Object o) {
        if (this == o) {
            return true;
        }
        if (!(o instanceof RestorationDataMapper)) {
            return false;
        }
        if (!super.equals(o)) {
            return false;
        }
        final RestorationDataMapper that = (RestorationDataMapper) o;
        return restorationData.equals(that.restorationData);
    }

    @Override
    public int hashCode() {
        return Objects.hash(super.hashCode(), restorationData);
    }

}
