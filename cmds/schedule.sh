#!/hint/bash

__verb_load_libs "$VERB_DIR" prune

#
# options
#

_usage() {
	cat <<EOF
$_usage_common_syntax schedule <JOB>
$_usage_common_options
EOF
}

__verb_expect_args 1


#
# config
#

config_get_job "$JOB_NAME" SCHEDULE_RULES


#
# main
#

PRUNE_SILENT=1

log "scheduling a backup using ${#SCHEDULE_RULES[@]} rule(s) in $JOB_NAME"

BACKUPS=()
prune_load_backups BACKUPS "$JOB_NAME"
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
prune_try_backup "$NOW_EPOCH" "$NOW" "${SCHEDULE_RULES[@]}"

if (( scheduled )); then
	log "a new backup is accepted at $NOW"
	invoke create "$JOB_NAME" "$NOW"
else
	log "no new backups need to be created at $NOW"
fi
