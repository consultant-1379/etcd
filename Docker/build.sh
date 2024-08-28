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
    zypper -n --installroot "$rootdir" install --no-recommends catatonit util-linux gawk procps grep tar gzip sed shadow
    zypper -n --installroot "$rootdir" install --no-recommends curl

    echo "250422:x:250422:250422:An Identity for eric-data-distributed-coordinator-ed:/home/dced:/bin/bash" >> "$rootdir/etc/passwd"
    echo "250422:!::0:::::" >> "$rootdir/etc/shadow"

    curl -4 -kLo $COMPONENT.tar.gz "https://arm.sero.gic.ericsson.se/artifactory/proj-adp-eric-data-dced-scripts-generic-local/$FLAVOUR.tar.gz"
    tar -C "$rootdir"/usr/local/bin/ -xzf $COMPONENT.tar.gz  --strip-components=1 $FLAVOUR/etcd
    tar -C "$rootdir"/usr/local/bin/ -xzf $COMPONENT.tar.gz  --strip-components=1 $FLAVOUR/etcdctl

    curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
    chmod +x ./kubectl
    mv ./kubectl "$rootdir"/usr/local/bin

    mkdir -p "$rootdir"/usr/local/bin/scripts
    mkdir -p "$rootdir"/usr/local/bin/health
    mkdir -p "$rootdir"/opt/redirect

    cp -r Docker/automation_scripts/* "$rootdir"/usr/local/bin/scripts/
    cp automation_scripts/common_logging.sh "$rootdir"/usr/local/bin/scripts/
    cp -r Docker/stdout-redirect-config/stdout-redirect-config.yaml "$rootdir"/etc/stdout-redirect-config.yaml
    cp -r Docker/health/* "$rootdir"/usr/local/bin/health/
    cp httpprobe/build/bin/httpprobe "$rootdir"/usr/local/bin/health/httpprobe_main

    mkdir -p "$rootdir"/home/dced
    chown -R 250422:250422 "$rootdir"/usr/local/bin
    chown -R 250422:250422 "$rootdir"/home/dced
    chmod -R g+rwx "$rootdir"/usr/local/bin

    chmod -R g+rwx "$rootdir"/home/dced
    chown -R root:10000 "$rootdir"/usr/local/bin/scripts
    chown -R root:10000 "$rootdir"/usr/local/bin/health
    chmod -R 755 "$rootdir"/usr/local/bin/scripts
    chmod -R 755 "$rootdir"/usr/local/bin/health

    cp Docker/stdout-redirect "$rootdir"/opt/redirect/stdout-redirect
    chown -R 250422:250422 "$rootdir"/opt/redirect/stdout-redirect

    # Save info about the packages
    rpm --root "$rootdir" -qa > "$rootdir"/.app-rpms

    buildah config \
        --label com.ericsson.product-number="CXC2012038" \
        --label org.opencontainers.image.title="Distributed Coordinator ED" \
        --label org.opencontainers.image.created=$IMAGE_CREATED \
        --label org.opencontainers.image.revision=$IMAGE_REVISION \
        --label org.opencontainers.image.vendor="Ericsson" \
        --label org.opencontainers.image.version=$IMAGE_VERSION \
        --user 250422 \
        --env COMPONENT \
        --env COMPONENT_VERSION \
        --env FLAVOUR \
        --entrypoint '["/usr/local/bin/etcd"]' "$container"

    rm -Rf /usr/bin/pip $COMPONENT.tar.gz
    zypper clean --all
    zypper rm -y tar gzip zypper > /dev/null
    rm -rf /root/.cache/pip/
    rm -rf /usr/lib64/python3.6/ensurepip

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

    buildah commit -f docker "$container" "$DCED_REGISTRY:$IMAGE_VERSION"
    buildah images

    #Copy the image to the local docker-daemon
    skopeo copy \
        containers-storage:"$DCED_REGISTRY:$IMAGE_VERSION" \
        docker-daemon:"$DCED_REGISTRY:$IMAGE_VERSION"
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

    #install the required tools
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