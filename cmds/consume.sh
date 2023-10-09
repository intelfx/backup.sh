#!/hint/bash

__verb_load_libs "$VERB_DIR" prune

#
# options
#

_usage() {
	cat <<EOF
$_usage_common_syntax consume <JOB>
$_usage_common_options
EOF
}

__verb_expect_args 1
# rename $JOB_NAME for consistency
TARGET_JOB_NAME="$JOB_NAME"


#
# config
#

PRODUCER_PRUNE_EARLY=0
PRODUCER_PRUNE_LATE=0

config_get_job "$TARGET_JOB_NAME" \
	--rename SOURCE SOURCE_JOB_NAME \
	--optional PRODUCER_PRUNE_EARLY \
	--optional PRODUCER_PRUNE_LATE \
	PRUNE_RULES SCHEDULE_RULES \


#
# main
#

log "consuming backups from $SOURCE_JOB_NAME to $TARGET_JOB_NAME"

# early prune
if (( PRODUCER_PRUNE_EARLY )); then
	log "pruning obsolete source snapshots before transfer"
	invoke prune "$SOURCE_JOB_NAME"
fi

#
# Calculate the backup set to transfer.
# Normally, single backup jobs are triggered via schedule and cleaned up via prune:
#
#     schedule -> btrfs -> prune
#
# Jobs can be manually chained:
#
#     schedule -> btrfs -> prune; $ID -> borg -> prune
#
# Or, better yet, with another scheduler being in charge of the decision whether
# the second job is interested in the snapshot:
#
#     schedule -> btrfs -> prune; schedule($ID) -> borg -> prune
#
# The consume operation sits in between two jobs, replacing scheduler for the
# second job and prune for the first job:
#
#     schedule -> btrfs -> consume -> borg -> prune
#
# As such, consume in its simplest form is:
# - list source backups
# - list destination backups
# - find source backups not in destination (candidates)
# - for each candidate; backup from source to destination
# - prune source
#
# A slightly more useful consume would try to virtually schedule each candidate backup
# (to account for the fact that the consumer may have stricter scheduling than the producer):
# - list source backups
# - list destination backups
# - find source backups not in destination (candidates)
# - for each candidate; schedule to destination and backup from source
# - prune source
#
# Scheduling can be done naively (calling schedule script) but it will result in calling destination list N times.
# We can prepare the scheduler context once and try all candidates in succession.
#
# Next up, we should consider behavior when the consume backlog is large.
# In this case, we are likely to consume multiple backups that will be immediately
# pruned from the destination after the consume completes. To solve this we can
# simulate a prune on the destination and avoid consuming backups that would fail it:
# - list source backups
# - list destination backups
# - find source backups not in destination (candidates)
# - for each candidate; schedule to destination (scheduled candidates)
# - merge destination backups and scheduled candidates (synthetic destination)
# - prune synthetic destination (save pruned list)
# - find candidates not in pruned list (final candidates)
# - for each final candidate; backup from source to destination
# - prune source
#
# TODO: prove that this algorithm is equivalent to scheduling and creating (and pruning consumer after) every archive separately

#
# $CONSUME_STATUS: summary table
# S: in source
# D: in destination
# C: candidate for transfer
# H: scheduled for transfer
# R: retained after test prune
# F: final candidate
#
declare -A CONSUME_STATUS
CONSUME_STATUS_DEFAULT="sdchrf"

consume_flag() {
	local flag="$1"
	shift

	flag_lower="$(echo "$flag" | tr "[A-Z]" "[a-z]")"
	flag_upper="$(echo "$flag" | tr "[a-z]" "[A-Z]")"

	local id flags
	for id; do
		flags="${CONSUME_STATUS[$id]:-"$CONSUME_STATUS_DEFAULT"}"
		flags="${flags/$flag_lower/$flag_upper}"
		CONSUME_STATUS["$id"]="$flags"
	done
}


#
# Load backup lists
#

declare -a SOURCE_IDS DESTINATION_IDS
invoke list "$SOURCE_JOB_NAME" | sort | readarray -t SOURCE_IDS
invoke list "$TARGET_JOB_NAME" | sort | readarray -t DESTINATION_IDS

consume_flag "S" "${SOURCE_IDS[@]}"
consume_flag "D" "${DESTINATION_IDS[@]}"

log "computing transfer list"

#
# Compute initial candidates
#

comm -23 \
	<(print_array "${SOURCE_IDS[@]}") \
	<(print_array "${DESTINATION_IDS[@]}") \
| readarray -t CANDIDATE_IDS
consume_flag "C" "${CANDIDATE_IDS[@]}"


#
# Schedule candidates onto destination
#

PRUNE_SILENT=1

# first, try all existing backups without storing results to fill the buckets
BACKUPS=()
prune_add_backups BACKUPS "${DESTINATION_IDS[@]}"
# backups are tried oldest-first for consistency (so that we try all backups
# including those being scheduled in a global order)
# TODO: prove this is correct, see backup_schedule.sh
prune_sort_backups BACKUPS
prune_try_backups BACKUPS "${SCHEDULE_RULES[@]}"

# then schedule candidates and record successfully scheduled
BACKUPS=()
prune_add_backups BACKUPS "${CANDIDATE_IDS[@]}"
prune_sort_backups BACKUPS
CANDIDATE_IDS=()
retain_callback() {
	CANDIDATE_IDS+=( "$1" )
}
prune_try_backups BACKUPS "${SCHEDULE_RULES[@]}"
consume_flag "H" "${CANDIDATE_IDS[@]}"


#
# Run a test prune to see which consumed backups would be immediately pruned
#

BACKUPS=()
prune_add_backups BACKUPS "${DESTINATION_IDS[@]}"
prune_add_backups BACKUPS "${CANDIDATE_IDS[@]}"
# backups are tried recent-first, as this aligns with daily/weekly/monthly rule semantics
# (that is, keep the most recent backup in a given timeframe)
# TODO: might want to implement configurable order, see backup_prune.sh
prune_sort_backups BACKUPS -r
declare -A CANDIDATE_HASH
makeset CANDIDATE_HASH 1 "${CANDIDATE_IDS[@]}"
CANDIDATE_IDS=()
retain_callback() {
	consume_flag "R" "$1"
	if [[ "${CANDIDATE_HASH[$1]}" ]]; then
		CANDIDATE_IDS+=( "$1" )
	fi
}
prune_try_backups BACKUPS "${PRUNE_RULES[@]}"
unset CANDIDATE_HASH
consume_flag "F" "${CANDIDATE_IDS[@]}"


#
# Log final status
#

# sort all backups oldest-first for consistency
BACKUPS=()
prune_add_backups BACKUPS "${!CONSUME_STATUS[@]}"
prune_sort_backups BACKUPS
prune_get_backups BACKUPS | readarray -t ALL_IDS

dashed="$(printf '%*s' 33 | tr ' ' '-')"
log "Ready to transfer. Final status:"
log "$dashed"
log "Legend:"
log " S -- in source"
log " D -- in destination"
log " C -- candidate (S + !D)"
log " H -- scheduled for transfer (accepted by destination's schedule rules)"
log " R -- retained in destination (not going to be immediately pruned)"
log " F -- final candidate (C + H + R)"
log "$dashed"

for id in "${ALL_IDS[@]}"; do
	flags="${CONSUME_STATUS["$id"]}"
	flags="$(echo -n "$flags" | tr '[a-z]' ' ')"
	echo "$id"$'\t'"$flags"
done | column -s $'\t' -t | while read -r line; do
	log "$line"
done

log "$dashed"

log "${#CANDIDATE_IDS[@]} snapshots to transfer."

log "$dashed"


#
# Create final candidate backups
#

# sort candidates oldest-first, so that we consume backups in a global order
# from oldest to newest over multiple invocations (useful for e. g. borg caching)
BACKUPS=()
prune_add_backups BACKUPS "${CANDIDATE_IDS[@]}"
prune_sort_backups BACKUPS
prune_get_backups BACKUPS | readarray -t CANDIDATE_IDS

log "creating ${#CANDIDATE_IDS[@]} snapshots"
rc=0
for id in "${CANDIDATE_IDS[@]}"; do
	if invoke create "$TARGET_JOB_NAME" "$id"; then
		: # we cannot invert the condition above because we won't catch its return code
	else
		rc2=$?
		if (( rc == 0 )); then rc=$rc2; fi
		warn "failed to create '$id' (rc=$rc2), stopping"
		break
	fi
done
if (( rc != 0 )); then
	err "failed to create some snapshots, exiting"
	exit $rc
fi

# if we have transferred everything we wanted, perform a final prune
if (( PRODUCER_PRUNE_LATE )); then
	log "pruning obsolete source snapshots after transfer"
	invoke prune "$SOURCE_JOB_NAME"
fi
