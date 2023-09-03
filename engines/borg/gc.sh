#!/bin/bash -e

. ${BASH_SOURCE%/*}/backup_lib.sh || exit
. borg_lib.sh || exit


#
# config
#

(( $# >= 1 )) || die "bad arguments ($*): expecting <config> <snapshot id>"
CONFIG="$1"
shift 1

load_config "$CONFIG" "$@"

#
# main
#

log "garbage collecting obsolete archives (checkpoints) from Borg repository '$BORG_REPO'"

# *.recreate, *.checkpoint, *.checkpoint.N or any combination
GARBAGE_REGEX='(?!$)(\.recreate)?(\.checkpoint(\.[0-9]+)?)?$'
# same as above
SNAPSHOT_TAG_GLOB="$(borg_snapshot_tag "*").*"

"${BORG_LIST[@]}" \
	--glob-archives "$SNAPSHOT_TAG_GLOB" \
	--format '{barchive}{NUL}' \
	"$BORG_REPO" \
| grep -z -P "$GARBAGE_REGEX" \
| readarray -d '' -t SNAPSHOT_TAGS

for s in "${SNAPSHOT_TAGS[@]}"; do
	dbg "will delete archive '$s'"
done

if (( ${#SNAPSHOT_TAGS[@]} )); then
	"${BORG_DELETE[@]}" \
		"$BORG_REPO" \
		"${SNAPSHOT_TAGS[@]}"
else
	log "no archives to delete"
fi

