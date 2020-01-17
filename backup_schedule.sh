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

log "scheduling a backup using ${#SCHEDULE_RULES[@]} rule(s) in $CONFIG"

BACKUPS=()
prune_load_backups "${SCHEDULE_LIST[@]}"

# first, try all existing backups without storing results to fill the buckets
prune_callback() {
	:
}
prune_try_backups "${SCHEDULE_RULES[@]}"

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
	exec "${SCHEDULE_CREATE[@]}"
else
	log "no new backups need to be created at $NOW"
fi
