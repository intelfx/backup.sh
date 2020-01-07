#!/bin/bash -e

. ${BASH_SOURCE%/*}/backup_lib.sh || exit

#
# config
#

. ${BASH_SOURCE%/*}/backup_btrfs_config.sh || exit

#
# main
#

log "Listing snapshots for filesystem '$FILESYSTEM' matching '$(btrfs_snapshot_path '*')'"

MOUNT_DIR="$(mktemp -d)"
cleanup_add "rm -rf '$MOUNT_DIR'"

btrfs_remount_id5_to "$FILESYSTEM" "$MOUNT_DIR"
cleanup_add "umount -l '$MOUNT_DIR'"

SNAPSHOT_GLOB="'$MOUNT_DIR/$(btrfs_snapshot_path "'*'")'"
< <(eval "printf '%s\n' $SNAPSHOT_GLOB") readarray -t SNAPSHOTS

SNAPSHOT_TAG_REGEX="^$MOUNT_DIR/$(btrfs_snapshot_path "([^/]+)")$"
< <(printf "%s\n" "${SNAPSHOTS[@]}" | sed -r "s|$SNAPSHOT_TAG_REGEX|\\1|") readarray -t TAGS

printf "%s\n" "${TAGS[@]}"
