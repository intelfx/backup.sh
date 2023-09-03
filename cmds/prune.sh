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

log "pruning backups using ${#PRUNE_RULES[@]} rule(s) in $CONFIG"

BACKUPS=()
prune_load_backups BACKUPS "$CONFIG" "$@"
# backups are tried recent-first, as this aligns with daily/weekly/monthly rule semantics
# (that is, keep the most recent backup in a given timeframe)
# TODO: might want to implement configurable order
prune_sort_backups BACKUPS -r

PRUNE=()
prune_callback() {
	PRUNE+=( "$@" )
}
prune_try_backups BACKUPS "${PRUNE_RULES[@]}"

if (( ${#PRUNE[@]} )); then
	log "pruning ${#PRUNE[@]} backup(s)"
	invoke delete "$CONFIG" "${PRUNE[@]}"
else
	log "nothing to prune"
fi
