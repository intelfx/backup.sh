#!/bin/bash -e

. ${BASH_SOURCE%/*}/backup_lib.sh || exit


#
# config
#

(( $# >= 1 )) || die "bad arguments ($*): expecting <config>"
CONFIG="$1"
shift 1

load_config "$CONFIG" "$@"

SNAPSHOT_ID="$(borg_snapshot_id)"
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
cleanup_add "backup_unmount.sh '$BORG_MOUNT_DIR'"

"${BORG_MOUNT_CMD[@]}" "$SNAPSHOT_ID" "$BORG_MOUNT_DIR"
# cleanup above

pushd "$BORG_MOUNT_DIR"
cleanup_add "popd"

"${BORG_CREATE[@]}" \
	"${BORG_ARGS[@]}" \
	"${BORG_REPO}::${SNAPSHOT_TAG}" \
	.
