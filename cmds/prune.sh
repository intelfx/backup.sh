#!/hint/bash

#
# options
#

_usage() {
	cat <<EOF
$_usage_common_syntax prune <JOB>
$_usage_common_options
EOF
}

__verb_expect_args 1


#
# config
#

config_get_job "$JOB_NAME" PRUNE_RULES


#
# main
#

log "pruning backups using ${#PRUNE_RULES[@]} rule(s) in $JOB_NAME"

BACKUPS=()
prune_load_backups BACKUPS "$JOB_NAME"
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
	invoke delete "$JOB_NAME" "${PRUNE[@]}"
else
	log "nothing to prune"
fi
