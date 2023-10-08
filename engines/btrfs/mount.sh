#!/hint/bash

#
# options
#

_usage() {
	cat <<EOF
$_usage_common_syntax mount <JOB> <SNAPSHOT> <TARGET-DIR>
$_usage_common_options
mount options:
	SNAPSHOT		Name of the btrfs snapshot to mount
	TARGET-DIR		Directory to mount the root of the hierarchy at
EOF
}

__verb_expect_args 3
SNAPSHOT_ID="${VERB_ARGS[1]}"
TARGET_DIR="${VERB_ARGS[2]}"


#
# config
#

config_get_job "$JOB_NAME" BTRFS_FILESYSTEM
config_get_job_f "$JOB_NAME" btrfs_snapshot_path

SNAPSHOT_PATH="$(btrfs_snapshot_path "$SNAPSHOT_ID")"


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

log "reconstructing snapshot tree for filesystem '$BTRFS_FILESYSTEM' at '$SNAPSHOT_PATH' to '$TARGET_DIR'"

MOUNT_DIR="$(mktemp -d)"
cleanup_add "rm -df '$MOUNT_DIR'"

btrfs_remount_id5_to "$BTRFS_FILESYSTEM" "$MOUNT_DIR"
cleanup_add "umount -l '$MOUNT_DIR'"

SNAPSHOT_DIR="$MOUNT_DIR/$SNAPSHOT_PATH"
if ! [[ -d "$SNAPSHOT_DIR" ]]; then
	die "bad snapshot dir: $SNAPSHOT_DIR (id: $SNAPSHOT_ID)"
fi

mkdir -p "$TARGET_DIR"

SUBVOLUMES_LIST_CMD=(
	btrfs-sub-find --relative
	"$SNAPSHOT_DIR"
)

"${SUBVOLUMES_LIST_CMD[@]}" | readarray -t SUBVOLUMES

for s in "${SUBVOLUMES[@]}"; do
	name="${s##*/}"
	if ! [[ "$name" == snapshot ]]; then
		die "bad snapshot tree hierarchy: '$s' is a snapshot not named 'snapshot'"
	fi
	dir="${s%/snapshot}"

	mkdir -p "$TARGET_DIR/$dir"

	log "mounting snapshot '$SNAPSHOT_DIR/$s' to '$TARGET_DIR/$dir'"
	mount --bind --make-private "$SNAPSHOT_DIR/$s" "$TARGET_DIR/$dir"
done
