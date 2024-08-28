#!/bin/bash
set -ex
curl --url https://storage.googleapis.com/container-structure-test/v0.3.0/container-structure-test --output .bob/container-structure-test \
&& chmod +x .bob/container-structure-test
