#!/bin/bash
set -x
export METRICS_EXPORTER_VERSION=1.55.0
## build_app_layer
##
##   Build application layer, same as with Dockerfile
##
build_app_layer() {
    set -x
    zypper -n --installroot "$rootdir" install --no-recommends catatonit util-linux gawk procps grep tar gzip sed shadow
    zypper -n --installroot "$rootdir" install --no-recommends curl

    #Non-Root User
    echo "124936:x:124936:124936:An Identity for eric-data-distributed-coordinator-ed-metricsexporter:/home/dcedmetricsexporter:/bin/bash" >> "$rootdir/etc/passwd"
    echo "124936:!::0:::::" >> "$rootdir/etc/shadow"

    cp Docker/metricsexporter/stdout-redirect "$rootdir"/usr/bin/stdout-redirect

    zypper addrepo -G \
            -f https://arm.sero.gic.ericsson.se/artifactory/proj-adp-metrics-exporter-released-rpm-local/eric-metrics-exporter/sles/$METRICS_EXPORTER_VERSION/ \
            "$rootdir"/METRICS-EXPORTER
    zypper refresh
    zypper -n --installroot "$rootdir" install -y eric-metrics-exporter

    cp Docker/metricsexporter/stdout-redirect-config/stdout-redirect-config.yaml "$rootdir"/etc/stdout-redirect-config.yaml

    # Save info about the packages
    rpm --root "$rootdir" -qa > "$rootdir"/.app-rpms

    buildah config \
        --label com.ericsson.product-number="CXU1010988" \
        --label org.opencontainers.image.title="Distributed Coordinator ED Metrics-Exporter" \
        --label org.opencontainers.image.created=$IMAGE_CREATED \
        --label org.opencontainers.image.revision=$IMAGE_REVISION \
        --label org.opencontainers.image.vendor="Ericsson" \
        --label org.opencontainers.image.version=$IMAGE_VERSION \
        --user 124936 \
        --port 9087 \
        --entrypoint '["/bin/bash", "-c"]' "$container"

    zypper rr "$rootdir"/METRICS-EXPORTER
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

    buildah commit -f docker "$container" "$DCED_ME_REGISTRY:$IMAGE_VERSION"
    buildah images

    # Copy the image to the local docker-daemon
    skopeo copy \
        containers-storage:"$DCED_ME_REGISTRY:$IMAGE_VERSION" \
        docker-daemon:"$DCED_ME_REGISTRY:$IMAGE_VERSION"
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