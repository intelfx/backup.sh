#!/bin/bash -e

. ${BASH_SOURCE%/*}/backup_lib.sh || exit

#
# config
#

(( $# >= 1 )) || die "btrfs_list.sh: bad arguments ($*): expecting <config>"
CONFIG="$1"
shift 1

load_config "$CONFIG" "$@"

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

SNAPSHOT_NAME_REGEX="^$MOUNT_DIR/$(btrfs_snapshot_path "([^/]+)")$"
< <(printf "%s\n" "${SNAPSHOTS[@]}" | sed -r "s|$SNAPSHOT_NAME_REGEX|\\1|") readarray -t NAMES

printf "%s\n" "${NAMES[@]}"
