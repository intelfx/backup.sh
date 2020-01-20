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
prune_load_backups "${PRUNE_LIST[@]}"

PRUNE=()
prune_callback() {
	PRUNE+=( "$@" )
}
prune_try_backups "${PRUNE_RULES[@]}"

if (( ${#PRUNE[@]} )); then
	log "pruning ${#PRUNE[@]} backup(s)"
	"${PRUNE_DELETE[@]}" "${PRUNE[@]}"

	say "Pruned ids:"
	print_array "${PRUNE[@]}"
else
	log "nothing to prune"
fi
