package com.ericsson.adp.mgmt.dced.bragent.v2.client;

import java.io.File;

import javax.net.ssl.SSLException;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.beans.factory.config.ConfigurableBeanFactory;
import org.springframework.context.annotation.*;

import com.ericsson.adp.mgmt.dced.bragent.v2.exception.NotConnectedException;

import io.etcd.jetcd.Client;
import io.grpc.netty.GrpcSslContexts;
import io.netty.handler.ssl.SslContext;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * Class to establish connection to secured(with certs enabled) etcd cluster
 */
@Component
@Scope(value=ConfigurableBeanFactory.SCOPE_PROTOTYPE, proxyMode=ScopedProxyMode.TARGET_CLASS)
@ConditionalOnProperty(name = "dced.certificates.enabled", havingValue = "true")
public class DcedTlsClient extends DcedClient {

    private static final Logger log = LogManager.getLogger(DcedTlsClient.class);
    private String certAuthorityFilePath;
    private String clientCertFilePath;
    private String clientCertKeyFilePath;
    private final String SIP_TLS_CA_SECRET = System.getenv("SIP_TLS_CA_SECRET");
    boolean fileExists;

    /**
     *
     * @param etcdEndpointUrl
     *            url of etcd cluster
     * @param certAuthorityFilePath
     *            name of CA file
     * @param clientCertFilePath
     *            name of client certificate file
     * @param clientCertKeyFilePath
     *            name of client certificate key file
     * @param maxInboundMessageSize
     *            maximum grpc message size in bytes.
     */
    public DcedTlsClient(@Value("${dced.endpoint.url}") final String etcdEndpointUrl, @Value("${dced.ca.file}") String certAuthorityFilePath,
                         @Value("${dced.client.cert.file}") String clientCertFilePath,
                         @Value("${dced.client.cert.keyfile}") String clientCertKeyFilePath,
                         @Value("${dced.agent.max.inbound.message.size}") final Integer maxInboundMessageSize) {
        super(etcdEndpointUrl, maxInboundMessageSize);
        fileExists = Files.exists(Paths.get("/run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert/tls.crt"));
        if (fileExists){
            this.clientCertFilePath = "/run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert/tls.crt";
            this.clientCertKeyFilePath = "/run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert/tls.key";
            this.certAuthorityFilePath = "/run/secrets/"+SIP_TLS_CA_SECRET+"/ca.crt";
        }
        else{
            this.certAuthorityFilePath="/run/secrets/"+SIP_TLS_CA_SECRET+"/cacertbundle.pem";
            this.clientCertFilePath = "/run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert/clicert.pem";
            this.clientCertKeyFilePath = "/run/secrets/eric-data-distributed-coordinator-ed-etcdctl-client-cert/cliprivkey.pem";
        }
    }

    /**
     * initialize connection and authentication to etcd host
     *
     * @return an instance of @{@link Client}.
     *
     */
    @Override
    public Client getClient() {
        try {
            final SslContext sslContext = GrpcSslContexts.forClient().trustManager(new File(certAuthorityFilePath))
                    .keyManager(new File(clientCertFilePath), new File(clientCertKeyFilePath)).build();
            return returnEtcdClient(sslContext);
        } catch (final SSLException sslException) {
            log.error(String.format("SSLException occurred while connecting to dced: %s", sslException.getMessage()));
            throw new NotConnectedException(sslException);
        }
    }

    private Client returnEtcdClient(final SslContext sslContext) {
        return Client.builder().endpoints(String.format("https://%s", etcdEndpointUrl)).sslContext(sslContext)
                .authority(etcdEndpointUrl.split(":")[0]).maxInboundMessageSize(maxInboundMessageSize).build();
    }
}
