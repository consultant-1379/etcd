/**------------------------------------------------------------------------------
 *******************************************************************************
 * COPYRIGHT Ericsson 2019
 *
 * The copyright to the computer program(s) herein is the property of
 * Ericsson Inc. The programs may be used and/or copied only with written
 * permission from Ericsson Inc. or in accordance with the terms and
 * conditions stipulated in the agreement/contract under which the
 * program(s) have been supplied.
 *******************************************************************************
 *------------------------------------------------------------------------------*/
package com.ericsson.adp.mgmt.dced.bragent.logging;

import org.apache.logging.log4j.core.config.Node;
import org.apache.logging.log4j.core.config.plugins.Plugin;
import org.apache.logging.log4j.core.config.plugins.PluginBuilderAttribute;
import org.apache.logging.log4j.core.config.plugins.PluginBuilderFactory;
import org.apache.logging.log4j.core.util.Builder;

/**
 * RewriteField pair configuration item. Similar to org.apache.logging.log4j.core.util.KeyValuePair
 */
@Plugin(name = "RewriteField", category = Node.CATEGORY, printObject = true)
public final class RewriteField {

    private final String oldKey;
    private final String newKey;

    /**
     *
     * @param oldKey
     *            - old key
     * @param newKey
     *            - new key
     */
    public RewriteField(final String oldKey, final String newKey) {
        this.oldKey = oldKey;
        this.newKey = newKey;
    }

    /**
     * @return the old key.
     */
    public String getOldKey() {
        return oldKey;
    }

    /**
     * @return The new Key.
     */
    public String getNewKey() {
        return newKey;
    }

    /**
     * rewrite file builder
     *
     * @return - RewriteFieldBuilder
     */
    @PluginBuilderFactory
    public static RewriteFieldBuilder newBuilder() {
        return new RewriteFieldBuilder();
    }

    /**
     * inner Class to create the reWrite file builder
     */
    public static class RewriteFieldBuilder implements Builder<RewriteField> {

        @PluginBuilderAttribute
        private String oldKey;

        @PluginBuilderAttribute
        private String newKey;

        /**
         *
         * @param oldKey
         *            - old key to rewrite
         * @return - RewriteFieldBuilder
         */
        public RewriteFieldBuilder setOldKey(final String oldKey) {
            this.oldKey = oldKey;
            return this;
        }

        /**
         *
         * @param newKey
         *            - key to rewrite
         * @return - RewriteFieldBuilder
         */
        public RewriteFieldBuilder setNewKey(final String newKey) {
            this.newKey = newKey;
            return this;
        }

        @Override
        public RewriteField build() {
            return new RewriteField(oldKey, newKey);
        }

    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result + ((oldKey == null) ? 0 : oldKey.hashCode());
        result = prime * result + ((newKey == null) ? 0 : newKey.hashCode());
        return result;
    }

    @Override
    public boolean equals(final Object obj) {
        if (this == obj) {
            return true;
        }
        if (obj == null) {
            return false;
        }
        if (getClass() != obj.getClass()) {
            return false;
        }
        final RewriteField other = (RewriteField) obj;
        if (oldKey == null) {
            if (other.oldKey != null) {
                return false;
            }
        } else if (!oldKey.equals(other.oldKey)) {
            return false;
        }
        if (newKey == null) {
            if (other.newKey != null) {
                return false;
            }
        } else if (!newKey.equals(other.newKey)) {
            return false;
        }
        return true;
    }
}
