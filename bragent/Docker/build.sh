#!/bin/bash
set -x
export COMPONENT="etcd"
export COMPONENT_VERSION="v3.5.12"
export FLAVOUR="$COMPONENT-$COMPONENT_VERSION-linux-amd64"
## build_app_layer
##
##   Build application layer, same as with Dockerfile
##
build_app_layer() {
    set -x
    zypper -n --installroot "$rootdir" install --no-recommends java-11-openjdk-headless util-linux gawk procps grep tar gzip sed shadow
    zypper -n --installroot "$rootdir" install --no-recommends curl

    #Non-Root User
    echo "125854:x:125854:125854:An Identity for eric-data-distributed-coordinator-ed-agent:/home/bragent:/bin/bash" >> "$rootdir/etc/passwd"
    echo "125854:!::0:::::" >> "$rootdir/etc/shadow"

    curl -kLo $COMPONENT.tar.gz "https://arm.sero.gic.ericsson.se/artifactory/proj-adp-eric-data-dced-scripts-generic-local/$FLAVOUR.tar.gz"
    tar -C "$rootdir"/usr/local/bin/ -xzf $COMPONENT.tar.gz  --strip-components=1 $FLAVOUR/etcdctl

    mkdir -p "$rootdir"/bragent/health
    mkdir -p "$rootdir"/opt/redirect

    cp bragent/Docker/target/bragent-0.0.1-SNAPSHOT.jar "$rootdir"/bragent/
    cp bragent/Docker/startBrAgent.sh "$rootdir"/bragent/
    cp automation_scripts/common_logging.sh "$rootdir"/bragent/
    cp bragent/Docker/certMonitoring.sh "$rootdir"/bragent/
    cp -r bragent/Docker/health/* "$rootdir"/bragent/health/
    cp bragent/Docker/stdout-redirect-config/stdout-redirect-config.yaml "$rootdir"/etc/stdout-redirect-config.yaml
    cp -r httpprobe/build/bin/httpprobe "$rootdir"/bragent/health/httpprobe_main

    cp bragent/Docker/stdout-redirect "$rootdir"/opt/redirect/stdout-redirect
    chown -R 125854:125854 "$rootdir"/opt/redirect/stdout-redirect

    chown -R 125854:125854 "$rootdir"/bragent
    chmod -R g+rwx "$rootdir"/bragent
    chmod -R 755 "$rootdir"/bragent/health
    chmod -R 755 "$rootdir"/bragent/certMonitoring.sh

    # Save info about the packages
    rpm --root "$rootdir" -qa > "$rootdir"/.app-rpms

    buildah config \
        --label com.ericsson.product-number="CXC1742753" \
        --label org.opencontainers.image.title="Distributed Coordinator ED BrAgent" \
        --label org.opencontainers.image.created=$IMAGE_CREATED \
        --label org.opencontainers.image.revision=$IMAGE_REVISION \
        --label org.opencontainers.image.vendor="Ericsson" \
        --label org.opencontainers.image.version=$IMAGE_VERSION \
        --user 125854 \
        --env COMPONENT \
        --env COMPONENT_VERSION \
        --env FLAVOUR \
        --workingdir='/bragent' \
        "$container"

    rm -rf $COMPONENT.tar.gz
    zypper clean --all
    set +x
}

## mount_microcbo_container
##
## Create a container from microcbo
##
## The root directory is available with $rootdir
##
mount_microcbo_container() {
    set -x
    zypper ar --no-check --gpgcheck-strict -f "${CBO_REPO}/${CBO_VERSION}" CBO_REPO

    zypper ar --no-check --gpgcheck-strict -f "${CBO_REPO}/${CBO_VERSION}_devel" COMMON_BASE_OS_SLES_REPO_DEVEL

    zypper --gpg-auto-import-keys refresh

    container=$(buildah from --authfile armdocker-config.json "$MICROCBO_IMAGE")
    rootdir=$(buildah mount "$container")
    mkdir -p "$rootdir/proc/" "$rootdir/dev/"
    mount -t proc /proc "$rootdir/proc/"
    mount --rbind /dev "$rootdir/dev/"
    set +x
}

## upload_image
##
##   commit and upload the created application image
##
upload_image() {
    set -x
    umount "$rootdir/proc/"
    umount -l "$rootdir/dev/"

    buildah commit -f docker "$container" "$DCED_BRA_REGISTRY:$IMAGE_VERSION"
    buildah images

    # Copy the image to the local docker-daemon
    skopeo copy \
        containers-storage:"$DCED_BRA_REGISTRY:$IMAGE_VERSION" \
        docker-daemon:"$DCED_BRA_REGISTRY:$IMAGE_VERSION"
    set +x
}

## create_builder
##
##   Create builder layer
##
create_builder() {
    set -x
    zypper ar --no-check --gpgcheck-strict -f "${CBO_DEVENV_REPO}/${CBO_VERSION}" CBO_DEVENV
    zypper --gpg-auto-import-keys refresh
    zypper install -y --no-recommends tar gzip curl sed shadow

    # install the required tools
    zypper -n install --no-recommends -l buildah skopeo util-linux
    sed -i 's/^driver =.*/driver="vfs"/' /etc/containers/storage.conf
    zypper rr CBO_DEVENV
    set +x
}

# exit on error
set -o errexit -o pipefail
trap 'echo "ERROR: Interrupted" >&2; exit 1' SIGINT
set +x

# Main functions
create_builder
mount_microcbo_container
build_app_layer
upload_image