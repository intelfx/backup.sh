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

log "listing btrfs snapshots for filesystem '$FILESYSTEM'"

MOUNT_DIR="$(mktemp -d)"
cleanup_add "rm -rf '$MOUNT_DIR'"

btrfs_remount_id5_to "$FILESYSTEM" "$MOUNT_DIR"
cleanup_add "umount -l '$MOUNT_DIR'"

SNAPSHOT_GLOB="'$MOUNT_DIR/$(btrfs_snapshot_path "'*'")'"
< <(shopt -s nullglob; eval "print_array $SNAPSHOT_GLOB") readarray -t SNAPSHOT_PATHS

SNAPSHOT_ID_REGEX="^$MOUNT_DIR/$(btrfs_snapshot_path "([^/]+)")$"
< <(print_array "${SNAPSHOT_PATHS[@]}" | sed -nr "s|$SNAPSHOT_ID_REGEX|\\1|p") readarray -t SNAPSHOT_IDS

label "Btrfs snapshots:"
print_array "${SNAPSHOT_IDS[@]}"
