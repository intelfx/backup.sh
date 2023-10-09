#!/hint/bash

#
# options
#

_usage() {
	cat <<EOF
$_usage_common_syntax create <JOB> [SNAPSHOT-NAME]
$_usage_common_options
create options:
	SNAPSHOT-NAME		Optional name of the source snapshot to use
				(if unspecified, config default is used)
EOF
}

__verb_expect_args_one_of 1 2
SNAPSHOT_ID=( "${VERB_ARGS[@]:1}" )


#
# config
#

config_get_job "$JOB_NAME" SOURCE_JOB_NAME BORG_REPO
config_get_job_f "$JOB_NAME" borg_snapshot_id borg_snapshot_tag borg_exports
BORG_MOUNT_DIR="/tmp/borg"
borg_exports

if ! [[ ${SNAPSHOT_ID+set} ]]; then
	SNAPSHOT_ID="$(borg_snapshot_id)"
fi
SNAPSHOT_TAG="$(borg_snapshot_tag "$SNAPSHOT_ID")"


#
# main
#

log "backing up snapshot '$SNAPSHOT_ID' to Borg repository '$BORG_REPO' as '$SNAPSHOT_TAG'"

BORG_ARGS=()

# assume that snapshot IDs are valid (ISO 8601) timestamps
SNAPSHOT_TS_UTC="$(TZ=UTC date -d "$SNAPSHOT_ID" -Iseconds)"
BORG_ARGS+=( --timestamp "${SNAPSHOT_TS_UTC%+00:00}" )

# The  mount  points  of  filesystems  or  filesystem  snapshots should be the
# same for every creation of a new archive to ensure fast operation. This is
# because the file cache that is used to determine changed files quickly uses
# absolute filenames.  If this is not possible, consider creating a bind mount
# to a stable location.
if ! mkdir "$BORG_MOUNT_DIR"; then
	die "cannot create stable mountpoint '$BORG_MOUNT_DIR' -- already exists?"
fi
cleanup_add "invoke unmount '$BORG_MOUNT_DIR'"
invoke mount "$SOURCE_JOB_NAME" "$SNAPSHOT_ID" "$BORG_MOUNT_DIR"

pushd "$BORG_MOUNT_DIR" &>/dev/null
cleanup_add "popd &>/dev/null"

"${BORG_CREATE[@]}" \
	"${BORG_ARGS[@]}" \
	"${BORG_REPO}::${SNAPSHOT_TAG}" \
	. \
	&& rc=0 || rc=$?

if (( $rc == 1 )); then
	warn "warnings when creating archive (rc=$rc), ignoring"
	exit 0
else
	exit $rc
fi
