#!/bin/bash -e

. ${BASH_SOURCE%/*}/backup_lib.sh || exit


#
# config
#

(( $# >= 2 )) || die "bad arguments ($*): expecting <config> <snapshot id>"
CONFIG="$1"
shift 1
SNAPSHOT_IDS=( "$@" )
shift "${#SNAPSHOT_IDS[@]}"

load_config "$CONFIG"


#
# main
#


log "deleting ${#SNAPSHOT_IDS[@]} snapshot tree(s) from Btrfs filesystem '$FILESYSTEM'"

if ! (( ${#SNAPSHOT_IDS[@]} )); then
	warn "nothing to delete"
	exit 0
fi

MOUNT_DIR="$(mktemp -d)"
cleanup_add "rm -rf '$MOUNT_DIR'"

btrfs_remount_id5_to "$FILESYSTEM" "$MOUNT_DIR"
cleanup_add "umount -l '$MOUNT_DIR'"

for id in "${SNAPSHOT_IDS[@]}"; do
	path="$(btrfs_snapshot_path "$id")"
	log "deleting snapshot tree '$path'"

	dir="$MOUNT_DIR/$path"
	if ! [[ -d "$dir" ]]; then
		die "bad snapshot dir: $dir"
	fi

	SUBVOLUMES_LIST_CMD=(
		"${BTRFS_SUBVOLUME_FIND[@]}"
		"$dir"
	)

	< <( "${SUBVOLUMES_LIST_CMD[@]}" | sort -r ) readarray -t -O "${#SUBVOLUMES[@]}" SUBVOLUMES
	SNAPSHOT_DIRS+=( "$dir" )
done

for s in "${SUBVOLUMES[@]}"; do
	dbg "will delete snapshot '$s'"
done

if (( ${#SUBVOLUMES[@]} )); then
	"${BTRFS_SUBVOLUME_DELETE[@]}" "${SUBVOLUMES[@]}"
else
	warn "no subvolumes to delete -- empty snapshot tree(s)?"
fi

find "${SNAPSHOT_DIRS[@]}" -mindepth 1 -xdev -depth -type d -empty -exec rm -vd {} +
