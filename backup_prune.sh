#!/bin/bash -e

. ${BASH_SOURCE%/*}/backup_lib.sh || exit
. ${BASH_SOURCE%/*}/backup_lib_prune.sh || exit


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

BACKUPS=()
PRUNE=()
prune_callback() {
	PRUNE+=( "$@" )
}

while read snap; do
	# assume that snapshot IDs are valid (ISO 8601) timestamps
	snap_epoch="$(epoch "$snap")"
	BACKUPS+=( "$snap_epoch $snap" )
done < <("${PRUNE_LIST[@]}")

# backups are tried recent-first, as this aligns with daily/weekly/monthly rule semantics
# (that is, keep the most recent backup in a given timeframe)
# TODO: might want to implement configurable order
sort_array BACKUPS -r -n -k1

for line in "${BACKUPS[@]}"; do
	read snap_epoch snap <<< "$line"
	prune_try_backup
done

if (( ${#PRUNE[@]} )); then
	say "Backups to prune:"
	printf "%s\n" "${PRUNE[@]}"
fi

for snap in "${PRUNE[@]}"; do
	log "pruning backup: $snap"
	"${PRUNE_DELETE[@]}" "$snap"
done
