#!/bin/bash
set -x
## create_builder
##
create_builder() {
    set -x
    zypper ar --no-check --gpgcheck-strict -f "${CBO_DEVENV_REPO}/${CBO_VERSION}" CBO_DEVENV
    zypper --gpg-auto-import-keys refresh

    #install the required tools
    zypper -n install --no-recommends -l buildah skopeo curl
    sed -i 's/^driver =.*/driver="vfs"/' /etc/containers/storage.conf
    zypper rr CBO_DEVENV
    set +x
}

##
## Create a container from the micro-CBO based image
##
## The root directory is available with $rootdir
##
mount_microcbo_container() {
    set -x
    zypper ar --no-check --gpgcheck-strict -f "${CBO_REPO}/${CBO_VERSION}" CBO_REPO

    zypper ar --no-check --gpgcheck-strict -f "${CBO_REPO}/${CBO_VERSION}_devel" COMMON_BASE_OS_SLES_REPO_DEVEL

    zypper --gpg-auto-import-keys refresh

    container=$(buildah from --authfile armdocker-config.json "${DCED_IMAGE}:${DCED_CISCAT_VERSION}")

    rootdir=$(buildah mount "$container")
    mkdir -p "$rootdir/proc/" "$rootdir/dev/"
    mount -t proc /proc "$rootdir/proc/"
    mount --rbind /dev "$rootdir/dev/"
    set +x
}

## build_app_layer
##
##   Build application layer, same as with Dockerfile
##
build_ciscat_scan_image() {
    set -x
    zypper -n --installroot "$rootdir" install --no-recommends util-linux iproute2 which rpm hostname gawk

    # Save info about the packages
    rpm --root "$rootdir" -qa > "$rootdir"/.app-rpms

    buildah config \
     --entrypoint '["/bin/bash"]' "$container"


    curl -sSf "${CBO_HARDENING_REPO}/${CBO_VERSION}/${CBO_HARDENING_ARCHIVE}" | tar xz
    chmod 755 cbo-harden.sh
    ./cbo-harden.sh "$rootdir"
    rm cbo-harden.sh

    zypper clean --all \
    zypper rm -y zypper > /dev/null
    set +x
}

## upload_image
##
##   commit and upload the created application image
##
upload_image() {
    set -x
    umount "$rootdir"/proc/
    umount -l "$rootdir"/dev/

    buildah commit -f docker "$container" "${DCED_CISCAT_IMAGE}:${DCED_CISCAT_VERSION}"
    buildah images
    buildah rm "$container"
    if (echo "${DCED_CISCAT_IMAGE}" | grep -qE '^armdocker'); then
        skopeo copy containers-storage:"${DCED_CISCAT_IMAGE}:${DCED_CISCAT_VERSION}" \
           docker-daemon:"${DCED_CISCAT_IMAGE}:${DCED_CISCAT_VERSION}"
    else
        skopeo copy containers-storage:localhost/"${DCED_CISCAT_IMAGE}:${DCED_CISCAT_VERSION}" \
            docker-daemon:"${DCED_CISCAT_IMAGE}:${DCED_CISCAT_VERSION}"
    fi
    set +x
}

# exit on error
set -o errexit -o pipefail
trap 'echo "ERROR: Interrupted" >&2; exit 1' SIGINT
set +x

# Main functions
create_builder
mount_microcbo_container
build_ciscat_scan_image
upload_image