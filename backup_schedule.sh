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

PRUNE_SILENT=1

log "scheduling a backup using ${#SCHEDULE_RULES[@]} rule(s) in $CONFIG"

BACKUPS=()
prune_load_backups BACKUPS "$CONFIG" "$@"
# backups are tried oldest-first for consistency (so that we try all backups
# including the one being scheduled in a single order)
# TODO: prove this is correct
prune_sort_backups BACKUPS

# first, try all existing backups without storing results to fill the buckets
prune_try_backups BACKUPS "${SCHEDULE_RULES[@]}"

# then, try to see if we can fit the to-be-created backup into any bucket
scheduled=1
prune_callback() {
	scheduled=0
}
snap="$NOW"
snap_epoch="$NOW_EPOCH"
prune_try_backup "${SCHEDULE_RULES[@]}"

if (( scheduled )); then
	log "a new backup is accepted at $NOW"
	invoke create "$CONFIG" "$@"
else
	log "no new backups need to be created at $NOW"
fi
