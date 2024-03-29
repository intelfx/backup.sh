#!/hint/bash

#
# options
#

_usage() {
	cat <<EOF
$_usage_common_syntax create <JOB> [SNAPSHOT-NAME]
$_usage_common_options
create options:
	SNAPSHOT-NAME		Optional name of the btrfs snapshot to create
				(if unspecified, config default is used)
EOF
}

__verb_expect_args_one_of 1 2
SNAPSHOT_ID=( "${VERB_ARGS[@]:1}" )


#
# config
#

config_get_job "$JOB_NAME" \
	--rename FILESYSTEM BTRFS_FILESYSTEM \
	--rename SUBVOLUMES_INCLUDE BTRFS_SUBVOLUMES_INCLUDE \
	--rename SUBVOLUMES_EXCLUDE BTRFS_SUBVOLUMES_EXCLUDE \
	--rename --function snapshot_id btrfs_snapshot_id \
	--rename --function snapshot_path btrfs_snapshot_path \

if ! [[ ${SNAPSHOT_ID+set} ]]; then
	SNAPSHOT_ID="$(btrfs_snapshot_id)"
fi
SNAPSHOT_PATH="$(btrfs_snapshot_path "$SNAPSHOT_ID")"


#
# main
#

log "creating a recursive snapshot of Btrfs filesystem '$BTRFS_FILESYSTEM' under '$SNAPSHOT_PATH'"

btrfs_setup_signals
btrfs_setup_from_path MOUNT_DIR "$BTRFS_FILESYSTEM"

if [[ -e "$MOUNT_DIR/$SNAPSHOT_PATH" ]]; then
	die "snapshot already exists: '$SNAPSHOT_PATH'"
fi

SUBVOLUMES_LIST_CMD=(
	"${BTRFS_SUBVOLUME_FIND_PHYSICAL[@]}"
)
for s in ${BTRFS_SUBVOLUMES_INCLUDE[@]}; do
	SUBVOLUMES_LIST_CMD+=( "$MOUNT_DIR$s" )
done

SUBVOLUMES_FILTER_CMD=(
	grep -vE
)
for s in "${BTRFS_SUBVOLUMES_EXCLUDE[@]}"; do
	SUBVOLUMES_FILTER_CMD+=( -e "^$s(/|$)" )
done

if ! (( ${#BTRFS_SUBVOLUMES_EXCLUDE[@]} )); then
	SUBVOLUMES_FILTER_CMD=( cat )
fi

"${SUBVOLUMES_LIST_CMD[@]}" | "${SUBVOLUMES_FILTER_CMD[@]}" | sort -u | readarray -t SUBVOLUMES

for s in "${SUBVOLUMES[@]}"; do
	s="${s##/}"
	SUBVOLUME_DIR="$MOUNT_DIR/$s"
	SNAPSHOT_DIR="$MOUNT_DIR/$SNAPSHOT_PATH/$s/snapshot"

	dbg "snapshotting subvolume '$s' from '$SUBVOLUME_DIR' to '$SNAPSHOT_DIR'"

	mkdir -p "${SNAPSHOT_DIR%/*}"
	"${BTRFS_SUBVOLUME_SNAPSHOT[@]}" "$SUBVOLUME_DIR" "$SNAPSHOT_DIR" >&2
done

log "Created snapshot: $SNAPSHOT_ID"

# do not annoy the user with the same ID again
if ! stderr_is_stdout; then
	echo "$SNAPSHOT_ID"
fi
