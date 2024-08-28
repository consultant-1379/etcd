#!/bin/bash

REPOSITORY_URL=""
PACKAGE=""
TARGET_DIR=""
FILE_NAME=""

while [ "$#" -gt 0 ]
do
    case $1 in
        -r|--repository) REPOSITORY_URL="$2"; shift;;
        -p|--package) PACKAGE="$2"; shift;;
        -d|--target-dir) TARGET_DIR="$2"; shift;;
        -f|--file-name) FILE_NAME="$2"; shift;;
    esac
    shift
done

cd "$TARGET_DIR" && \
curl -O -H "X-JFrog-Art-Api:${ARM_TOKEN}" "$REPOSITORY_URL/$PACKAGE/$FILE_NAME" && \
tar -xvf "$FILE_NAME" && \
rm "$FILE_NAME"