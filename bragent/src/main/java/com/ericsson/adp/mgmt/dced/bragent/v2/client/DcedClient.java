package com.ericsson.adp.mgmt.dced.bragent.v2.client;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import io.etcd.jetcd.ByteSequence;
import io.etcd.jetcd.Client;
import io.grpc.netty.GrpcSslContexts;
import java.io.*;

/**
 * Class to establish connection to insecure(with certs disabled) etcd cluster
 */

@Component
@ConditionalOnProperty(name = "dced.certificates.enabled", havingValue = "false")
public class DcedClient {

    protected static final String ROOT_USER = "root";
    protected final String ACL_ROOT_PASSWORD = System.getenv("ACL_ROOT_PASSWORD");
    protected final String etcdEndpointUrl;
    protected final Integer maxInboundMessageSize;
    protected final File cacert = new File("/run/secrets/eric-data-distributed-coordinator-ed-ca/ca.crt");
    protected final File key = new File("/run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert/tls.key");
    protected final File cert = new File("/run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert/tls.crt");
    protected final File cacert_legacy = new File("/run/secrets/eric-data-distributed-coordinator-ed-ca/client-cacertbundle.pem");
    protected final File key_legacy= new File("/run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert/cliprivkey.pem");
    protected final File cert_legacy = new File("/run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert/clicert.pem");
    protected final String TLS_ENABLED = System.getenv("TLS_ENABLED");
    private static final Logger log = LogManager.getLogger(DcedClient.class);

    /**
     *
     * @param etcdEndpointUrl
     *            url of etcd cluster
     * @param maxInboundMessageSize
     *            maximum grpc message size in bytes.
     */
    public DcedClient(@Value("${dced.endpoint.url}") final String etcdEndpointUrl, @Value("${dced.agent.max.inbound.message.size}")
        final Integer maxInboundMessageSize) {
        this.etcdEndpointUrl = etcdEndpointUrl;
        this.maxInboundMessageSize = maxInboundMessageSize;
    }

    /**
     * initialize connection and authentication to etcd host
     *
     * @return an instance of @{@link Client}.
     *
     */
    public Client getClient() {
        if("true".equals(TLS_ENABLED))
        {
          try
          {
            return Client.builder().endpoints(String.format("https://%s", etcdEndpointUrl)).sslContext(GrpcSslContexts.forClient()
                .trustManager(cacert)
                .keyManager(cert, key)
                .build())
                .maxInboundMessageSize(maxInboundMessageSize).build();
          }
          catch(Exception e)
          {
            log.error("Unable to make the connection with ETCD server with endpoint "+e);
          }
        }
        else
        {
          final ByteSequence user = ByteSequence.from((ROOT_USER).getBytes());
          final ByteSequence userPass = ByteSequence.from((ACL_ROOT_PASSWORD).getBytes());
          return Client.builder().endpoints(String.format("http://%s", etcdEndpointUrl)).user(user).password(userPass)
               .maxInboundMessageSize(maxInboundMessageSize).build();
        }
        return null;
    }
}
