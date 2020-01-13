#!/bin/bash -e

. ${BASH_SOURCE%/*}/backup_lib.sh || exit

#
# config
#

(( $# >= 1 )) || die "bad arguments ($*): expecting <config>"
CONFIG="$1"
shift 1

load_config "$CONFIG" "$@"


#
# main
#

log "cleaning up obsolete subvolumes after restoring a snapshot for filesystem '$FILESYSTEM'"

MOUNT_DIR="$(mktemp -d)"
cleanup_add "rm -rf '$MOUNT_DIR'"

btrfs_remount_id5_to "$FILESYSTEM" "$MOUNT_DIR"
cleanup_add "umount -l '$MOUNT_DIR'"

OLD_DIR="$MOUNT_DIR/old"
if ! [[ -d "$OLD_DIR" ]]; then
	warn "no old snapshots to delete: '$OLD_DIR' is not a directory"
	return 0
fi

SUBVOLUMES_LIST_CMD=(
	btrfs-sub-find --find
	"$OLD_DIR"
)

< <( "${SUBVOLUMES_LIST_CMD[@]}" | sort -r ) readarray -t SUBVOLUMES

for s in "${SUBVOLUMES[@]}"; do
	log "will delete snapshot '$s'"
done

btrfs sub del --verbose --commit-after "${SUBVOLUMES[@]}"
