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
# signals
#

sigterm() {
	log "SIGTERM/SIGINT received, ignoring"
}
trap sigterm TERM INT


#
# main
#

log "cleaning up obsolete subvolumes (post restore) for Btrfs filesystem '$BTRFS_FILESYSTEM'"

MOUNT_DIR="$(mktemp -d)"
cleanup_add "rm -df '$MOUNT_DIR'"

btrfs_remount_id5_to "$BTRFS_FILESYSTEM" "$MOUNT_DIR"
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

log "cleaning up empty snapshot directories for Btrfs filesystem '$BTRFS_FILESYSTEM'"

SNAPSHOT_GLOB="'$MOUNT_DIR/$(btrfs_snapshot_path "'*'")'"
eval "printf '%s\n' $SNAPSHOT_GLOB" | readarray -t SNAPSHOT_DIRS

find "${SNAPSHOT_DIRS[@]}" -xdev -depth -type d -empty -exec rm -vd {} \;
