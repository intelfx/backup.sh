#!/bin/bash -e

. ${BASH_SOURCE%/*}/backup_lib.sh || exit


#
# config
#

(( $# >= 2 )) || die "bad arguments ($*): expecting <config> <snapshot id>"
CONFIG="$1"
SNAPSHOT_ID="$2"
shift 2

load_config "$CONFIG" "$@"

SNAPSHOT_PATH="$(btrfs_snapshot_path "$SNAPSHOT_ID")"


#
# main
#

log "deleting snapshot tree '$SNAPSHOT_PATH' from Btrfs filesystem '$FILESYSTEM'"

MOUNT_DIR="$(mktemp -d)"
cleanup_add "rm -rf '$MOUNT_DIR'"

btrfs_remount_id5_to "$FILESYSTEM" "$MOUNT_DIR"
cleanup_add "umount -l '$MOUNT_DIR'"

SNAPSHOT_DIR="$MOUNT_DIR/$SNAPSHOT_PATH"
if ! [[ -d "$SNAPSHOT_DIR" ]]; then
	die "bad snapshot dir: $SNAPSHOT_DIR"
fi

SUBVOLUMES_LIST_CMD=(
	btrfs-sub-find --find
	"$SNAPSHOT_DIR"
)

< <( "${SUBVOLUMES_LIST_CMD[@]}" | sort -r ) readarray -t SUBVOLUMES

for s in "${SUBVOLUMES[@]}"; do
	log "will delete snapshot '$s'"
done

if (( ${#SUBVOLUMES[@]} )); then
	btrfs sub del --verbose --commit-after "${SUBVOLUMES[@]}"
else
	warn "no subvolumes to delete for '$SNAPSHOT_ID' -- empty snapshot tree?"
fi

rm -vrf "$SNAPSHOT_DIR"
