package com.ericsson.adp.mgmt.dced.bragent.v2.utils;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.testcontainers.containers.Network;
import java.util.Arrays;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

public class EtcdContainerUtils {
    private static final Logger log = LogManager.getLogger(EtcdContainerUtils.class);

    public static EtcdContainer etcdContainer;
    static final Network network = Network.builder().id("test-etcd").build();
    static CountDownLatch latch = new CountDownLatch(1);
    static final AtomicBoolean failedToStart = new AtomicBoolean(false);
    static final EtcdContainer.LifecycleListener listener = new EtcdContainer.LifecycleListener() {
        @Override
        public void started(EtcdContainer container) {
            latch.countDown();
        }

        @Override
        public void failedToStart(EtcdContainer container, Exception exception) {
            log.error("Exception while starting etcd container: ", exception);
            failedToStart.set(true);
            latch.countDown();
        }

        @Override
        public void stopped(EtcdContainer container) {
            latch=new CountDownLatch(1);
        }
    };

    public static void setupWithSsl(boolean sslEnabled, String rootPassword) {
        etcdContainer=new EtcdContainer
                (network, listener, sslEnabled, "test-etcd",
                        "test", Arrays.asList("test"), false, rootPassword);
        start(etcdContainer);
    }

    public static void tearDown(){
        try {
            System.out.println("etcd container logs: "+etcdContainer.getLogs());
            etcdContainer.close();
        } catch (RuntimeException e) {
            log.warn("close() failed (but ignoring it)", e);
        }
    }
    private static void start(EtcdContainer container) {
        new Thread(container::start).start();

        try {
            latch.await(30, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            throw new RuntimeException(e);
        }
        if (failedToStart.get()) {
            throw new IllegalStateException("Cluster failed to start");
        }
    }


}
