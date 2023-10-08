#!/hint/bash

#
# options
#

_usage() {
	cat <<EOF
$_usage_common_syntax gc <JOB>
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
# main
#

log "cleaning up obsolete subvolumes (post restore) for Btrfs filesystem '$BTRFS_FILESYSTEM'"

btrfs_setup_signals
btrfs_setup_from_path MOUNT_DIR "$BTRFS_FILESYSTEM"

OLD_DIR="$MOUNT_DIR/old"
mkdir -p "$OLD_DIR"

SUBVOLUMES_LIST_CMD=(
	"${BTRFS_SUBVOLUME_FIND[@]}"
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

find "$OLD_DIR" -xdev -depth -type d -empty -exec rm -vd {} \;

log "cleaning up empty snapshot directories for Btrfs filesystem '$BTRFS_FILESYSTEM'"

SNAPSHOT_GLOB="'$MOUNT_DIR/$(btrfs_snapshot_path "'*'")'"
eval "printf '%s\n' $SNAPSHOT_GLOB" | readarray -t SNAPSHOT_DIRS

# HACK: find -xdev will still match snapshot roots, so snapshots of
#       empty subvolumes will get caught in the crossfire.
#       Thus, explicitly unmatch "snapshot" directories. The drawback
#       is that an empty dir after a subvolume whose basename was "snapshot"
#       will also be ignored.
find "${SNAPSHOT_DIRS[@]}" -xdev -depth -type d -not -name snapshot -empty -exec rm -vd {} \;
