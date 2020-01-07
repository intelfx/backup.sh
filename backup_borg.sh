#!/bin/bash -e

. ${BASH_SOURCE%/*}/backup_lib.sh || exit

#
# config
#

. ${BASH_SOURCE%/*}/backup_borg_config.sh || exit

SNAPSHOT_TAG="$1"
BORG_TAG="$(borg_snapshot_tag "$SNAPSHOT_TAG")"

#
# main
#

BORG_ARGS=()

# parse timestamp as ISO 8601
if SNAPSHOT_TS_UTC="$(TZ=UTC date -d "$SNAPSHOT_TAG" -Iseconds)"; then
	BORG_ARGS+=( --timestamp "${SNAPSHOT_TS_UTC%+00:00}" )
else
	warn "Cannot parse tag '$SNAPSHOT_TAG' as ISO 8601 timestamp -- not setting Borg timestamp!"
fi

RECONSTRUCT_DIR="$(mktemp -d)"
# The  mount  points  of  filesystems  or  filesystem  snapshots should be the
# same for every creation of a new archive to ensure fast operation. This is
# because the file cache that is used to determine changed files quickly uses
# absolute filenames.  If this is not possible, consider creating a bind mount
# to a stable location.
RECONSTRUCT_DIR="/tmp/borg"
if ! mkdir "$RECONSTRUCT_DIR"; then
	die "Cannot create stable mountpoint '$RECONSTRUCT_DIR' -- already exists?"
fi
cleanup_add "rm -rf '$RECONSTRUCT_DIR'"

${BASH_SOURCE%/*}/backup_btrfs_reconstruct.sh "$SNAPSHOT_TAG" "$RECONSTRUCT_DIR"
cleanup_add "${BASH_SOURCE%/*}/backup_cleanup_unmount.sh '$RECONSTRUCT_DIR'"

pushd "$RECONSTRUCT_DIR"
cleanup_add "popd"

log "Backing up snapshot '$SNAPSHOT_TAG' using Borg to '$BORG_REPO' as '$BORG_TAG'"
"${BORG_CREATE[@]}" \
	"${BORG_ARGS[@]}" \
	"${BORG_REPO}::${BORG_TAG}" \
	.
