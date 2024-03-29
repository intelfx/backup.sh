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

config_get_job "$JOB_NAME" \
	--rename FILESYSTEM BTRFS_FILESYSTEM \
	--rename --function snapshot_path btrfs_snapshot_path \


#
# main
#

log "listing btrfs snapshots for filesystem '$BTRFS_FILESYSTEM'"

btrfs_setup_signals
btrfs_setup_from_path MOUNT_DIR "$BTRFS_FILESYSTEM"

SNAPSHOT_GLOB="'$MOUNT_DIR/$(btrfs_snapshot_path "'*'")'"
(shopt -s nullglob; eval "print_array $SNAPSHOT_GLOB") | readarray -t SNAPSHOT_PATHS

SNAPSHOT_ID_REGEX="^$MOUNT_DIR/$(btrfs_snapshot_path "([^/]+)")$"
print_array "${SNAPSHOT_PATHS[@]}" | sed -nr "s|$SNAPSHOT_ID_REGEX|\1|p" | readarray -t SNAPSHOT_IDS

print_array "${SNAPSHOT_IDS[@]}"
