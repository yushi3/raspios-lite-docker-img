#!/bin/bash

set -e

DATE="${DOCKER_IMAGE:-2023-05-03}"
DEBIAN="${DEBIAN:-bullseye}"

IMAGE="${DATE}-raspios-${DEBIAN}-arm64-lite.img"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

if [ ! -d "$1" ]; then
    echo "Error: directory $1 does not exist." 
    exit 1
fi

shopt -s nullglob
shopt -s dotglob

files=($1/*)

shopt -u nullglob
shopt -u dotglob

if [ ${#files[*]} -gt 0 ]; then
    echo "Error: directory $1 is not empty."
    exit 1
fi

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

    e2fsck -fy ${NODES[$i]}
    fuse2fs -o fakeroot,ro ${NODES[$i]} $1
    echo "Successfully mounted ${NODES[$i]} at $1"

    exit 0 # stop at first ext4 partition
done

echo Could not find any ext4 partitions
exit 1
