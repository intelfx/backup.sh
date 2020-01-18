#!/bin/bash -e

. ${BASH_SOURCE%/*}/backup_lib.sh || exit


#
# config
#

(( $# >= 1 )) || die "bad arguments ($*): expecting <config>"
CONFIG="$1"
shift 1

load_config "$CONFIG" "$@"


#
# main
#

SNAPSHOT_TAG_GLOB="$(borg_snapshot_tag "*")"
SNAPSHOT_ID_REGEX="^$(borg_snapshot_tag "(.*)")$"

log "listing snapshots matching '$SNAPSHOT_TAG_GLOB' in Borg repository '$BORG_REPO'"
< <("${BORG_LIST[@]}" \
	--glob-archives "$SNAPSHOT_TAG_GLOB" \
	--format '{barchive}{NUL}' \
) readarray -d '' -t SNAPSHOT_TAGS

< <( \
	printf "%s\n" "${SNAPSHOT_TAGS[@]}" | sed -nr "s|$SNAPSHOT_ID_REGEX|\\1|p" \
) readarray -t SNAPSHOT_IDS

say "Borg archives:"
if (( ${#SNAPSHOT_IDS[@]} )); then
	printf "%s\n" "${SNAPSHOT_IDS[@]}"
fi
