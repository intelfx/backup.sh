#!/bin/bash -e

. ${BASH_SOURCE%/*}/backup_lib.sh || exit


#
# config
#

(( $# >= 1 )) || die "bad arguments ($*): expecting <config> <snapshot id>"
CONFIG="$1"
shift 1
SNAPSHOT_IDS=( "$@" )
shift "${#SNAPSHOT_IDS[@]}"

load_config "$CONFIG"


#
# main
#

log "deleting ${#SNAPSHOT_IDS[@]} archive(s) from Borg repository '$BORG_REPO'"

if ! (( ${#SNAPSHOT_IDS[@]} )); then
	warn "nothing to delete"
	exit 0
fi

SNAPSHOT_TAGS=()
for id in "${SNAPSHOT_IDS[@]}"; do
	tag="$(borg_snapshot_tag "$id")"
	log "deleting archive '$tag'"
	SNAPSHOT_TAGS+=( "$tag" )
done

"${BORG_DELETE[@]}" \
	"$BORG_REPO" \
	"${SNAPSHOT_TAGS[@]}"
