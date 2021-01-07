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

# *.recreate, *.checkpoint, *.checkpoint.N or any combination
GARBAGE_REGEX='(?!$)(\.recreate)?(\.checkpoint(\.[0-9]+)?)?$'
# if the '*' ends up in the trailing position, we will inadvertently match garbage along actual archives
SNAPSHOT_TAG_GLOB="$(borg_snapshot_tag "*")"
SNAPSHOT_ID_REGEX="^$(borg_snapshot_tag "(.*)")$"

log "listing snapshots matching '$SNAPSHOT_TAG_GLOB' in Borg repository '$BORG_REPO'"
"${BORG_LIST[@]}" \
	--glob-archives "$SNAPSHOT_TAG_GLOB" \
	--format '{barchive}{NUL}' \
	"$BORG_REPO" \
| ( grep -z -vP "$GARBAGE_REGEX" || true ) \
| readarray -d '' -t SNAPSHOT_TAGS

print_array "${SNAPSHOT_TAGS[@]}" \
| sed -nr "s|$SNAPSHOT_ID_REGEX|\\1|p" \
| readarray -t SNAPSHOT_IDS

label "Borg archives:"
print_array "${SNAPSHOT_IDS[@]}"
