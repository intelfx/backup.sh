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
	# FIXME: expecting that name == timestamp
	snap_ts="$snap"
	if ! snap_epoch="$(epoch "$snap_ts")"; then
		warn "cannot parse backup name as timestamp, skipping: $snap"
		continue
	fi
	BACKUPS+=( "$snap_epoch $snap_ts $snap" )
done < <("${PRUNE_LIST[@]}")

# backups are tried recent-first, as this aligns with daily/weekly/monthly rule semantics
# (that is, keep the most recent backup in a given timeframe)
# TODO: might want to implement configurable order
sort_array BACKUPS -r -n -k1

for line in "${BACKUPS[@]}"; do
	read snap_epoch snap_ts snap <<< "$line"
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
