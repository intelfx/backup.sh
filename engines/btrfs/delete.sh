#!/hint/bash

#
# options
#

_usage() {
	cat <<EOF
$_usage_common_syntax delete <JOB> <SNAPSHOT...>
$_usage_common_options
delete options:
	SNAPSHOT...		Name(s) of the btrfs snapshot(s) to delete
EOF
}

__verb_expect_args_ge 2
SNAPSHOT_IDS=( "${VERB_ARGS[@]:1}" )


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

log "deleting ${#SNAPSHOT_IDS[@]} snapshot tree(s) from Btrfs filesystem '$BTRFS_FILESYSTEM'"

if ! (( ${#SNAPSHOT_IDS[@]} )); then
	warn "nothing to delete"
	exit 0
fi

MOUNT_DIR="$(mktemp -d)"
cleanup_add "rm -df '$MOUNT_DIR'"

btrfs_remount_id5_to "$BTRFS_FILESYSTEM" "$MOUNT_DIR"
cleanup_add "umount -l '$MOUNT_DIR'"

SUBVOLUMES=()
SNAPSHOT_DIRS=()
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

	"${SUBVOLUMES_LIST_CMD[@]}" | sort -r | readarray -t -O "${#SUBVOLUMES[@]}" SUBVOLUMES
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

find "${SNAPSHOT_DIRS[@]}" -xdev -depth -type d -empty -exec rm -vd {} \;
