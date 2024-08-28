#!/bin/bash
set -xe
.bob/container-structure-test -test.v -image $1 Docker/test/metadata_tests.yaml
.bob/container-structure-test -test.v -image $1 Docker/test/file_tests.yaml
