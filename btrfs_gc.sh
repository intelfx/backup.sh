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
# signals
#

sigterm() {
	log "SIGTERM/SIGINT received, ignoring"
}
trap sigterm TERM INT


#
# main
#

log "cleaning up obsolete subvolumes (post restore) for Btrfs filesystem '$FILESYSTEM'"

MOUNT_DIR="$(mktemp -d)"
cleanup_add "rm -df '$MOUNT_DIR'"

btrfs_remount_id5_to "$FILESYSTEM" "$MOUNT_DIR"
cleanup_add "umount -l '$MOUNT_DIR'"

OLD_DIR="$MOUNT_DIR/old"
mkdir -p "$OLD_DIR"

SUBVOLUMES_LIST_CMD=(
	btrfs-sub-find --find
	"$OLD_DIR"
)

"${SUBVOLUMES_LIST_CMD[@]}" | sort -r | readarray -t SUBVOLUMES

for s in "${SUBVOLUMES[@]}"; do
	dbg "will delete snapshot '$s'"
done

if (( "${#SUBVOLUMES[@]}" )); then
	"${BTRFS_SUBVOLUME_DELETE[@]}" "${SUBVOLUMES[@]}"
else
	log "no subvolumes to delete"
fi

find "$OLD_DIR" -mindepth 1 -xdev -depth -type d -empty -exec rm -vd {} \;


log "cleaning up empty snapshot directories for Btrfs filesystem '$FILESYSTEM'"

SNAPSHOT_GLOB="'$MOUNT_DIR/$(btrfs_snapshot_path "'*'")'"
eval "printf '%s\n' $SNAPSHOT_GLOB" | readarray -t SNAPSHOT_DIRS

find "${SNAPSHOT_DIRS[@]}" -xdev -depth -type d -empty -exec rm -vd {} \;
