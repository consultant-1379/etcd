package com.ericsson.adp.mgmt.dced.bragent.v2.utils;

import com.github.dockerjava.api.DockerClient;

import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.function.Consumer;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testcontainers.DockerClientFactory;
import org.testcontainers.containers.*;
import org.testcontainers.containers.output.OutputFrame;
import org.testcontainers.containers.output.WaitingConsumer;
import org.testcontainers.containers.wait.strategy.AbstractWaitStrategy;
import org.testcontainers.containers.wait.strategy.WaitStrategy;
import org.testcontainers.utility.LogUtils;

public class EtcdContainer implements AutoCloseable {

    interface LifecycleListener {
        void started(EtcdContainer container);

        void failedToStart(EtcdContainer container, Exception exception);

        void stopped(EtcdContainer container);
    }

    private static final Logger LOGGER = LoggerFactory.getLogger(EtcdContainer.class);
    private static final int ETCD_CLIENT_PORT = 2379;
    private static final int ETCD_PEER_PORT = 2380;
    private static final String ETCD_DATA_DIR = "/data.etcd";

    public static final String ETCD_DOCKER_IMAGE_NAME = "gcr.io/etcd-development/etcd:v3.5.12";

    private final String endpoint;
    private final boolean ssl;
    private final FixedHostPortGenericContainer<?> container;
    private final LifecycleListener listener;
    private final Path dataDirectory;
    private final String rootPassword;


    public EtcdContainer(
            Network network,
            LifecycleListener listener,
            boolean ssl,
            String clusterName,
            String endpoint,
            List<String> endpoints,
            boolean restartable,
            String rootPassword) {

        this.endpoint = endpoint;
        this.ssl = ssl;
        this.listener = listener;
        this.rootPassword=rootPassword;

        final String name = endpoint;
        final List<String> command = new ArrayList<>();

        this.container = new FixedHostPortGenericContainer<>(ETCD_DOCKER_IMAGE_NAME);
        this.container.withExposedPorts(ETCD_CLIENT_PORT, ETCD_PEER_PORT);
        this.container.withNetwork(network);
        this.container.withNetworkAliases(name);
        this.container.waitingFor(waitStrategy());
        this.container.withLogConsumer(logConsumer());

        command.add("etcd");
        command.add("--name");
        command.add(name);
        command.add("--advertise-client-urls");
        command.add((ssl ? "https" : "http") + "://0.0.0.0:" + ETCD_CLIENT_PORT);
        command.add("--listen-client-urls");
        command.add((ssl ? "https" : "http") + "://0.0.0.0:" + ETCD_CLIENT_PORT);

        if (restartable) {
            dataDirectory = createDataDirectory(name);
            container.addFileSystemBind(dataDirectory.toString(),
                    ETCD_DATA_DIR, BindMode.READ_WRITE, SelinuxContext.SHARED);
            command.add("--data-dir");
            command.add(ETCD_DATA_DIR);
        } else {
            dataDirectory = null;
        }

        if (ssl) {
            this.container.withClasspathResourceMapping(
                    "server.pem",
                    "/etc/ssl/etcd/server.pem",
                    BindMode.READ_ONLY,
                    SelinuxContext.SHARED);

            this.container.withClasspathResourceMapping(
                    "server-key.pem",
                    "/etc/ssl/etcd/server-key.pem",
                    BindMode.READ_ONLY,
                    SelinuxContext.SHARED);
            this.container.withClasspathResourceMapping(
                    "cacertbundle.pem",
                    "/etc/ssl/etcd/cacertbundle.pem",
                    BindMode.READ_ONLY,
                    SelinuxContext.SHARED);
            this.container.withClasspathResourceMapping(
                    "clicert.pem",
                    "/etc/ssl/etcd/etcdctl-cert.pem",
                    BindMode.READ_ONLY,
                    SelinuxContext.SHARED);
            this.container.withClasspathResourceMapping(
                    "cliprivkey.pem",
                    "/etc/ssl/etcd/etcdctl-key.pem",
                    BindMode.READ_ONLY,
                    SelinuxContext.SHARED);

            command.add("--trusted-ca-file");
            command.add("/etc/ssl/etcd/cacertbundle.pem");
            command.add("--cert-file");
            command.add("/etc/ssl/etcd/server.pem");
            command.add("--key-file");
            command.add("/etc/ssl/etcd/server-key.pem");
            command.add("--client-cert-auth");

            this.container.withEnv("ETCDCTL_CERT", "/etc/ssl/etcd/etcdctl-cert.pem");
            this.container.withEnv("ETCDCTL_KEY", "/etc/ssl/etcd/etcdctl-key.pem");
        }

        if (endpoints.size() > 1) {
            command.add("--initial-advertise-peer-urls");
            command.add("http://" + name + ":" + ETCD_PEER_PORT);
            command.add("--listen-peer-urls");
            command.add("http://0.0.0.0:" + ETCD_PEER_PORT);
            command.add("--initial-cluster-token");
            command.add(clusterName);
            command.add("--initial-cluster");
            command.add(endpoints.stream().map(e -> e + "=" + "http://" + e + ":" + ETCD_PEER_PORT).collect(Collectors.joining(",")));
            command.add("--initial-cluster-state");
            command.add("new");
        }

        if (!command.isEmpty()) {
            this.container.withCommand(command.toArray(new String[command.size()]));
            this.container.withEnv("ETCDCTL_API", "3");
            this.container.withEnv("ETCD_LOG_LEVEL", "debug");
        }
    }

    public void start() {
        LOGGER.debug("starting etcd container {} with command: {}",
                endpoint, String.join(" ", container.getCommandParts()));

        try {
            this.container.start();
            enableAuth();
            this.listener.started(this);

            if (dataDirectory != null) {
                // needed in order to properly clean resources during shutdown
                setDataDirectoryPermissions("o+rwx");
            }

        } catch (Exception exception) {
            this.listener.failedToStart(this, exception);
        }
    }

    public void restart() {
        if (dataDirectory == null) {
            throw new IllegalStateException("Container not restartable, please create it with restartable=true");
        }
        LOGGER.debug("restarting etcd container {} with command: {}",
                endpoint, String.join(" ", container.getCommandParts()));

        final int port = this.container.getMappedPort(ETCD_CLIENT_PORT);
        this.container.stop();
        this.container.withExposedPorts(ETCD_PEER_PORT);
        this.container.withFixedExposedPort(port, ETCD_CLIENT_PORT);
        this.container.start();
    }

    @Override
    public void close() {
        if (this.container != null) {
            this.container.stop();
        }
        if (dataDirectory != null && Files.exists(dataDirectory)) {
            deleteDataDirectory(dataDirectory);
        }
        this.listener.stopped(this);
    }

    public URI clientEndpoint() {
        final String host = container.getContainerIpAddress();
        final int port = container.getMappedPort(ETCD_CLIENT_PORT);
        return newURI(host, port);
    }

    public URI peerEndpoint() {
        final String host = container.getContainerIpAddress();
        final int port = container.getMappedPort(ETCD_PEER_PORT);
        return newURI(host, port);
    }
    public String getLogs(){
        return this.container.getLogs();
    }

    // ****************
    // helpers
    // ****************

    private URI newURI(final String host, final int port) {
        try {
            return new URI(ssl ? "https" : "http", null, host, port, null, null, null);
        } catch (URISyntaxException e) {
            throw new IllegalArgumentException("URISyntaxException should never happen here", e);
        }
    }

    private WaitStrategy waitStrategy() {
        return new AbstractWaitStrategy() {
            @Override
            protected void waitUntilReady() {
                final DockerClient client = DockerClientFactory.instance().client();
                final WaitingConsumer waitingConsumer = new WaitingConsumer();

                LogUtils.followOutput(client, waitStrategyTarget.getContainerId(), waitingConsumer);

                try {
                    waitingConsumer.waitUntil(
                            f -> f.getUtf8String().contains("ready to serve client requests"),
                            startupTimeout.getSeconds(),
                            TimeUnit.SECONDS,
                            1
                    );
                } catch (TimeoutException e) {
                    throw new ContainerLaunchException("Timed out");
                }
            }
        };
    }

    private Consumer<OutputFrame> logConsumer() {
        final Logger logger = LoggerFactory.getLogger(EtcdContainer.class);

        return outputFrame -> {
            final OutputFrame.OutputType outputType = outputFrame.getType();
            final String utf8String = outputFrame.getUtf8String().replaceAll("((\\r?\\n)|(\\r))$", "");

            switch (outputType) {
                case END:
                    break;
                case STDOUT:
                case STDERR:
                    logger.debug("{}{}: {}", endpoint, outputType, utf8String);
                    break;
                default:
                    throw new IllegalArgumentException("Unexpected outputType " + outputType);
            }
        };
    }

    private void setDataDirectoryPermissions(String permissions) {
        try {
            this.container.execInContainer("chmod", permissions, "-R", ETCD_DATA_DIR);
        } catch (Exception e) {
            throw new ContainerLaunchException("Error changing permission to etcd data directory", e);
        }
    }

    private void enableAuth() {
        try {
            Container.ExecResult addRootUser =this.container.execInContainer( "etcdctl",
                    "--insecure-skip-tls-verify=true", "user", "add",
                    String.format("root:%s", this.rootPassword));

            Container.ExecResult enable=this.container.execInContainer("etcdctl",
                    "--insecure-skip-tls-verify=true", "auth", "enable");
        } catch (Exception e) {
            throw new ContainerLaunchException("Error enabling auth", e);
        }
    }
    public String containerId(){
        return this.container.getContainerId();
    }
    private static Path createDataDirectory(String name) {
        try {
            final Path path = Files.createTempDirectory("jetcd_test_" + name + "_");
            // https://github.com/etcd-io/jetcd/issues/489
            // Resolve symlink (/var -> /private/var) to don't fail for Mac OS because of docker thing with /var/folders
            return path.toRealPath();
        } catch (IOException e) {
            throw new ContainerLaunchException("Error creating data directory", e);
        }
    }

    private static void deleteDataDirectory(Path dir) {
        try (Stream<Path> stream = Files.walk(dir)) {
            stream.sorted(Comparator.reverseOrder()).forEach(p -> p.toFile().delete());
        } catch (IOException e) {
            LOGGER.error("Error deleting directory " + dir.toString(), e);
        }
    }
}

