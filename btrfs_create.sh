#!/bin/bash -e

. ${BASH_SOURCE%/*}/backup_lib.sh || exit


#
# config
#

(( $# >= 1 )) || die "bad arguments ($*): expecting <config>"
CONFIG="$1"
shift 1

load_config "$CONFIG" "$@"

SNAPSHOT_ID="$(btrfs_snapshot_id)"
SNAPSHOT_PATH="$(btrfs_snapshot_path "$SNAPSHOT_ID")"


#
# signals
#

sigterm() {
	log "SIGTERM/SIGINT received, ignoring"
}
trap sigterm TERM INT


#
# main
#

log "creating a recursive snapshot of Btrfs filesystem '$FILESYSTEM' under '$SNAPSHOT_PATH'"

MOUNT_DIR="$(mktemp -d)"
cleanup_add "rm -df '$MOUNT_DIR'"

btrfs_remount_id5_to "$FILESYSTEM" "$MOUNT_DIR"
cleanup_add "umount -l '$MOUNT_DIR'"

SUBVOLUMES_LIST_CMD=(
	"${BTRFS_SUBVOLUME_FIND_PHYSICAL[@]}"
)
for s in ${SUBVOLUMES_INCLUDE[@]}; do
	SUBVOLUMES_LIST_CMD+=( "$MOUNT_DIR$s" )
done

SUBVOLUMES_FILTER_CMD=(
	grep -vE
)
for s in "${SUBVOLUMES_EXCLUDE[@]}"; do
	SUBVOLUMES_FILTER_CMD+=( -e "^$s(/|$)" )
done

dbg "subvolume list cmd: ${SUBVOLUMES_LIST_CMD[*]}"
dbg "subvolume filter cmd: ${SUBVOLUMES_FILTER_CMD[*]}"

"${SUBVOLUMES_LIST_CMD[@]}" \
| "${SUBVOLUMES_FILTER_CMD[@]}" \
| readarray -t SUBVOLUMES

for s in "${SUBVOLUMES[@]}"; do
	s="${s##/}"
	SUBVOLUME_DIR="$MOUNT_DIR/$s"
	SNAPSHOT_DIR="$MOUNT_DIR/$SNAPSHOT_PATH/$s/snapshot"

	dbg "snapshotting subvolume '$s' from '$SUBVOLUME_DIR' to '$SNAPSHOT_DIR'"

	mkdir -p "${SNAPSHOT_DIR%/*}"
	"${BTRFS_SUBVOLUME_SNAPSHOT[@]}" "$SUBVOLUME_DIR" "$SNAPSHOT_DIR" >&2
done

label "Snapshot id:"
echo "$SNAPSHOT_ID"
