#!/bin/bash -e

. ${BASH_SOURCE%/*}/backup_lib.sh || exit

#
# config
#

SNAPSHOT_TAG="$NEW_SNAPSHOT_TAG"
. ${BASH_SOURCE%/*}/backup_config.sh || exit

#
# main
#

MOUNT_DIR="$(mktemp -d)"
cleanup_add "rm -rf '$MOUNT_DIR'"

btrfs_remount_id5_to "$FILESYSTEM" "$MOUNT_DIR"
cleanup_add "umount -l '$MOUNT_DIR'"

SUBVOLUMES_LIST_CMD=(
	btrfs-sub-find --physical
)
for s in ${SUBVOLUMES_INCLUDE[@]}; do
	SUBVOLUMES_LIST_CMD+=( "$MOUNT_DIR$s" )
done

SUBVOLUMES_FILTER_CMD=(
	grep -vE
)
for s in ${SUBVOLUMES_EXCLUDE[@]}; do
	SUBVOLUMES_FILTER_CMD+=( -e "^$s(/|$)" )
done

log "Subvolumes list cmd: ${SUBVOLUMES_LIST_CMD[*]}"
log "Subvolumes filter cmd: ${SUBVOLUMES_FILTER_CMD[*]}"

< <( "${SUBVOLUMES_LIST_CMD[@]}" | "${SUBVOLUMES_FILTER_CMD[@]}" ) readarray -t SUBVOLUMES

for s in "${SUBVOLUMES[@]}"; do
	s="${s##/}"
	SUBVOLUME_DIR="$MOUNT_DIR/$s"
	SNAPSHOT_DIR="$MOUNT_DIR/$SNAPSHOT_PATH/$s/snapshot"

	log "Snapshotting subvolume '$s' from '$SUBVOLUME_DIR' to '$SNAPSHOT_DIR'"

	mkdir -p "${SNAPSHOT_DIR%/*}"
	btrfs subvolume snapshot "$SUBVOLUME_DIR" "$SNAPSHOT_DIR"
done

log "Snapshot tag: $SNAPSHOT_TAG"
echo "$SNAPSHOT_TAG"
