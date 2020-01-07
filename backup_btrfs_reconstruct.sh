#!/bin/bash -e

. ${BASH_SOURCE%/*}/backup_lib.sh || exit

#
# config
#

. ${BASH_SOURCE%/*}/backup_btrfs_config.sh || exit

SNAPSHOT_TAG="$1"
TARGET_DIR="$2"
SNAPSHOT_PATH="$(btrfs_snapshot_path "$SNAPSHOT_TAG")"


#
# main
#

log "Reconstructing snapshot tree for filesystem '$FILESYSTEM' at '$SNAPSHOT_PATH' to '$TARGET_DIR'"

MOUNT_DIR="$(mktemp -d)"
cleanup_add "rm -rf '$MOUNT_DIR'"

btrfs_remount_id5_to "$FILESYSTEM" "$MOUNT_DIR"
cleanup_add "umount -l '$MOUNT_DIR'"

SNAPSHOT_DIR="$MOUNT_DIR/$SNAPSHOT_PATH"
if ! [[ -d "$SNAPSHOT_DIR" ]]; then
	die "Bad snapshot directory: $SNAPSHOT_DIR (tag: $SNAPSHOT_TAG)"
fi

mkdir -p "$TARGET_DIR"

SUBVOLUMES_LIST_CMD=(
	btrfs-sub-find --relative
	"$SNAPSHOT_DIR"
)

< <( "${SUBVOLUMES_LIST_CMD[@]}" ) readarray -t SUBVOLUMES

for s in "${SUBVOLUMES[@]}"; do
	name="${s##*/}"
	if ! [[ "$name" == snapshot ]]; then
		die "Bad snapshot tree hierarchy: '$s' is a snapshot not named 'snapshot'"
	fi
	dir="${s%/*}"

	mkdir -p "$TARGET_DIR/$dir"

	log "Mounting snapshot '$SNAPSHOT_DIR/$s' to '$TARGET_DIR/$dir'"
	mount --bind --make-private "$SNAPSHOT_DIR/$s" "$TARGET_DIR/$dir"
done
