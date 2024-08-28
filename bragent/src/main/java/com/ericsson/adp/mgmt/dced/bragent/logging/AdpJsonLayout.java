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

import java.nio.charset.Charset;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.Map;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;

import org.apache.commons.lang3.exception.ExceptionUtils;
import org.apache.logging.log4j.core.LogEvent;
import org.apache.logging.log4j.core.config.plugins.Plugin;
import org.apache.logging.log4j.core.config.plugins.PluginAttribute;
import org.apache.logging.log4j.core.config.plugins.PluginElement;
import org.apache.logging.log4j.core.config.plugins.PluginFactory;
import org.apache.logging.log4j.core.impl.Log4jLogEvent;
import org.apache.logging.log4j.core.layout.AbstractStringLayout;
import org.apache.logging.log4j.core.util.KeyValuePair;
import org.apache.logging.log4j.util.Strings;
import org.springframework.util.StringUtils;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.ObjectWriter;

/**
 * Simple log4j2 Layout implementation class to provides log in ADP json format
 */
@Plugin(name = "AdpJsonLayout", category = "Core", elementType = "layout", printObject = true)
public class AdpJsonLayout extends AbstractStringLayout {

    private static final String TIMESTAMP = "timestamp";
    private static final String SEVERITY = "severity";
    private static final String DEFAULT_EOL = "\r\n";
    private static final String COMPACT_EOL = Strings.EMPTY;
    private ObjectMapper objectMapper = new ObjectMapper();
    private KeyValuePair[] fields;
    private RewriteField[] renameFields;
    private String eol;
    private boolean compact;
    private DateTimeFormatter dateFormat;
    private static final String FUNCTION = "function";
    private static final String CATEGORY = "category";
    private static final String PROC = "proc_id";
    private static final String UL = "ul_id";

    /**
     * method to create the json layout
     *
     * @param charset
     *            - utf 8 charset
     * @param fields
     *            - array of key value pair
     * @param renameFields
     *            - array of rename fields
     * @param compact
     *            - compact passed or not
     * @param eventEol
     *            - enable the eventEol or not
     */
    public AdpJsonLayout(final Charset charset, final KeyValuePair[] fields, final RewriteField[] renameFields, final boolean compact,
                         final boolean eventEol) {

        super(charset);
        this.objectMapper = new ObjectMapper();
        this.renameFields = renameFields;
        this.fields = fields;
        this.compact = compact;
        this.eol = compact && !eventEol ? COMPACT_EOL : DEFAULT_EOL;
    }

    /**
     * Method to create the json layout
     *
     * @param compact
     *            - compact passed or not
     * @param eventEol
     *            - enable the eventEol or not
     * @param fields
     *            - array of key value pair
     * @param renameFields
     *            - array of rename fields
     * @param charset
     *            - utf 8 charset
     * @return - AdpJsonLayout
     */
    @PluginFactory
    public static AdpJsonLayout createLayout(

                                             @PluginAttribute("compact") final boolean compact, @PluginAttribute("eventEol") final boolean eventEol,
                                             @PluginElement("KeyValuePair") final KeyValuePair[] fields,
                                             @PluginElement("RewriteField") final RewriteField[] renameFields,
                                             @PluginAttribute(value = "charset", defaultString = "UTF-8") final Charset charset) {

        return new AdpJsonLayout(charset, fields, renameFields, compact, eventEol);
    }

    private static LogEvent convertToLog4jEvent(final LogEvent event) {
        return event instanceof Log4jLogEvent ? event : Log4jLogEvent.createMemento(event);
    }

    /*
     * @Return a map with all the in the KeyValuePair resolved
     */
    private Map<String, Object> resolvefields() {
        final Map<String, Object> fieldsMap = new LinkedHashMap<>(fields.length);

        // resolve each of the fields
        for (final KeyValuePair pair : fields) {
            final String value = pair.getValue();
            final String key = pair.getKey();

            if (key.equalsIgnoreCase(TIMESTAMP)) {
                // Resolve value
                dateFormat = getDateFormatInstance(value);
                ZoneId zone = ZoneId.systemDefault();
                ZonedDateTime dateTime = ZonedDateTime.now(zone);
                fieldsMap.put(key, dateTime.format(dateFormat));
            } else {
                // Plain text value
                fieldsMap.put(key, value);
            }
        }
        return fieldsMap;
    }

    private DateTimeFormatter getDateFormatInstance(final String value) {
        if (StringUtils.isEmpty(dateFormat)) {
            dateFormat =  DateTimeFormatter.ofPattern(value);
        }
        return dateFormat;
    }

    /*
     * Return a map with all the RewriteKey elements replaced
     */
    private Map<String, Object> rewritefields(final Map<String, Object> fieldsMap, final LogEvent logEvent) {
        // convert array to Map
        final Map<String, Object> dummyMap = new LinkedHashMap<>(fields.length);
        final Map<String, String> renameMap = new LinkedHashMap<>();
        for (final RewriteField pair : renameFields) {
            renameMap.put(pair.getOldKey(), pair.getNewKey());
        }

        // rewrite all the keys
        dummyMap.putAll(objectMapper.convertValue(logEvent, Map.class));

        for (final Map.Entry<String, Object> entry : dummyMap.entrySet()) {

            final Object value = entry.getValue();
            final String key = entry.getKey();

            // convert nested objects
            if (value instanceof LinkedHashMap) {
                final LinkedHashMap<String, Object> c1 = (LinkedHashMap<String, Object>) value;
                for (final Map.Entry<String, Object> subentry : c1.entrySet()) {
                    final String newKey = key + "_" + subentry.getKey();
                    if (renameMap.containsKey(newKey)) {
                       if (renameMap.get(newKey).equalsIgnoreCase(SEVERITY)) {
                          fieldsMap.put(renameMap.get(newKey), subentry.getValue().toString().toLowerCase());
                        }
                        else {
                        fieldsMap.put(renameMap.get(newKey), subentry.getValue());
                        }
                    }
                }
            } else if (renameMap.containsKey(key)) {
                fieldsMap.put(renameMap.get(key), value);
            }
        }
        return fieldsMap;
    }

    @Override
    public String toSerializable(final LogEvent event) {

        ObjectWriter writer;
        String json = "";
        try {
            if (compact) {
                writer = objectMapper.writer();
            } else {
                writer = objectMapper.writerWithDefaultPrettyPrinter();
            }
            final LogEvent myEvent = convertToLog4jEvent(event);
            Map<String, Object> loggedFieldsMap = rewritefields(resolvefields(),myEvent);
            Map<String, Object> optionalHashMap = new LinkedHashMap<>();
            Map<String, Object> mandatoryHashMap = new LinkedHashMap<>();
            for (Map.Entry<String, Object> link : loggedFieldsMap.entrySet()) {
              if(link.getKey().equalsIgnoreCase(FUNCTION) || link.getKey().equalsIgnoreCase(CATEGORY) || link.getKey().equalsIgnoreCase(PROC) || link.getKey().equalsIgnoreCase(UL)) {
                optionalHashMap.put(link.getKey(),link.getValue());
                }
              else if(link.getKey().equalsIgnoreCase("version") || link.getKey().equalsIgnoreCase(TIMESTAMP) || link.getKey().equalsIgnoreCase("service_id")|| link.getKey().equalsIgnoreCase("SEVERITY")|| link.getKey().equalsIgnoreCase("message")){
                mandatoryHashMap.put(link.getKey(),link.getValue());
                }
            }
            Map<String, Object> linkedMap = new LinkedHashMap<>();
            linkedMap.put("metadata",optionalHashMap);
            Map<String, Object> combinedMap = new LinkedHashMap<>();
            combinedMap.putAll(mandatoryHashMap);
            combinedMap.putAll(linkedMap);
            json = writer.writeValueAsString(combinedMap) + this.eol;
        } catch (final Exception e) {
            final java.util.logging.Logger log = java.util.logging.Logger.getLogger(AdpJsonLayout.class.getName());
            log.warning(String.format("Can't serialize log Event message %s", ExceptionUtils.getStackTrace(e)));

        }

        markEvent();
        return json;
    }

}