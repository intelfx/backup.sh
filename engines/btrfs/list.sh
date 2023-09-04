#!/hint/bash

#
# options
#

_usage() {
	cat <<EOF
$_usage_common_syntax list <JOB>
$_usage_common_options
EOF
}

__verb_expect_args 1


#
# config
#

config_get_job "$JOB_NAME" BTRFS_FILESYSTEM
config_get_job_f "$JOB_NAME" btrfs_snapshot_path


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

log "listing btrfs snapshots for filesystem '$BTRFS_FILESYSTEM'"

MOUNT_DIR="$(mktemp -d)"
cleanup_add "rm -df '$MOUNT_DIR'"

btrfs_remount_id5_to "$BTRFS_FILESYSTEM" "$MOUNT_DIR"
cleanup_add "umount -l '$MOUNT_DIR'"

SNAPSHOT_GLOB="'$MOUNT_DIR/$(btrfs_snapshot_path "'*'")'"
(shopt -s nullglob; eval "print_array $SNAPSHOT_GLOB") | readarray -t SNAPSHOT_PATHS

SNAPSHOT_ID_REGEX="^$MOUNT_DIR/$(btrfs_snapshot_path "([^/]+)")$"
print_array "${SNAPSHOT_PATHS[@]}" | sed -nr "s|$SNAPSHOT_ID_REGEX|\\1|p" | readarray -t SNAPSHOT_IDS

label "Btrfs snapshots:"
print_array "${SNAPSHOT_IDS[@]}"
