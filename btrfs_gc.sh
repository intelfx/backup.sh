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

log "garbage collecting obsolete subvolumes (post restore) for Btrfs filesystem '$FILESYSTEM'"

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
	dbg "will delete snapshot '$s'"
done

if (( "${#SUBVOLUMES[@]}" )); then
	"${BTRFS_SUBVOLUME_DELETE[@]}" "${SUBVOLUMES[@]}"
else
	log "no subvolumes to delete"
fi

find "$OLD_DIR" -mindepth 1 -xdev -depth -type d -empty -exec rm -vd {} \+
