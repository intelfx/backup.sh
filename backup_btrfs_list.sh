#!/bin/bash -e

. ${BASH_SOURCE%/*}/backup_lib.sh || exit

#
# config
#

FILESYSTEM="$1"
SNAPSHOT_TAG="{{tag}}"
. ${BASH_SOURCE%/*}/backup_config.sh || exit

#
# main
#

log "Listing snapshots for filesystem '$FILESYSTEM' matching '$SNAPSHOT_PATH'"

MOUNT_DIR="$(mktemp -d)"
cleanup_add "rm -rf '$MOUNT_DIR'"

btrfs_remount_id5_to "$FILESYSTEM" "$MOUNT_DIR"
cleanup_add "umount -l '$MOUNT_DIR'"

SNAPSHOT_TEMPLATE="$MOUNT_DIR/$SNAPSHOT_PATH/"
SNAPSHOT_GLOB="'${SNAPSHOT_TEMPLATE/"{{tag}}"/"'*'"}'"
< <(eval "printf '%s\n' $SNAPSHOT_GLOB") readarray -t SNAPSHOTS

SNAPSHOT_TAG_REGEX="^${SNAPSHOT_TEMPLATE/"{{tag}}"/"([^/]+)"}$"
< <(printf "%s\n" "${SNAPSHOTS[@]}" | sed -r "s|$SNAPSHOT_TAG_REGEX|\\1|") readarray -t TAGS

printf "%s\n" "${TAGS[@]}"
