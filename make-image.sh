#!/bin/bash

set -e

DATE="${DOCKER_IMAGE:-2023-05-03}"
DEBIAN="${DEBIAN:-bullseye}"

DOCKER_IMAGE="${DOCKER_IMAGE:-raspios-lite-${DEBIAN}}:${DATE}"

IMAGE="${DATE}-raspios-${DEBIAN}-arm64-lite.img"

echo "Downloading ${IMAGE}.xz"

curl -L -C - -O https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-${DATE}/${IMAGE}.xz

echo "Extracting ${IMAGE}.xz"

xz -fkd ${IMAGE}.xz

FSDATA=$(sfdisk -J ${IMAGE} | jq '.partitiontable')

SECTORSIZE=$(jq '.sectorsize' <<< "${FSDATA}")

PARTITIONS=$(jq -r '[.partitions[] | select(.type == "83")]' <<< "${FSDATA}")

NODES=($(jq -r '. | map(.node) | join(" ")' <<< "${PARTITIONS}"))

STARTS=($(jq -r '. | map(.start) | join(" ")' <<< "${PARTITIONS}"))

SIZES=($(jq -r '. | map(.size) | join(" ")' <<< "${PARTITIONS}"))

for i in "${!NODES[@]}";
do
    echo "Copying ${NODES[$i]}: ${STARTS[$i]} - ${SIZES[$i]}"

    dd if=${IMAGE} of=${NODES[$i]} skip=${STARTS[$i]} count=${SIZES[$i]} status=progress

    echo "Mounting ${NODES[$i]}"

    ROOT=$(mktemp -d)

    e2fsck -fy ${NODES[$i]}
    fuse2fs -o fakeroot,ro ${NODES[$i]} ${ROOT}
    echo "Successfully mounted ${NODES[$i]} at ${ROOT}"

    echo "Building docker image ${DOCKER_IMAGE}"
    docker build -t ${DOCKER_IMAGE} -f Dockerfile --platform linux/arm64/v8 ${ROOT}

    fusermount -u ${ROOT}
    echo "Successfully unmounted ${ROOT}"

    rmdir ${ROOT}
    echo "Successfully removed ${ROOT}"

    exit 0 # stop at first ext4 partition
done

echo Could not find any ext4 partitions
exit 1
