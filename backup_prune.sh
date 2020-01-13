#!/bin/bash -e

. ${BASH_SOURCE%/*}/backup_lib.sh || exit


#
# config
#

(( $# >= 1 )) || die "btrfs_create.sh: bad arguments ($*): expecting <config>"
CONFIG="$1"
shift 1

load_config "$CONFIG" "$@"


#
# subroutines
#

function load_args() {
	local arg name value
	for arg; do
		if ! [[ "$arg" == *=* ]]; then
			err "invalid rule argument: '$arg' (not an assignment)"
			return 1
		fi

		name="${arg%%=*}"
		value="${arg#*=}"

		declare -n param="$name"
		if ! [[ "${param+1}" == 1 ]]; then
			err "invalid rule argument: '$arg' (attempting to set an undeclared parameter '$name')"
			return 1
		fi
		param="$value"
	done
}


#
# prune rules
#

prune_keep_recent() {
	local min_age=0
	load_args "$@"
	(( min_age > 0 )) || die "prune_keep_recent: bad min_age: ${min_age}"

	if (( snap_age < min_age )); then
		keep=1
	fi
}

prune_delete_old() {
	local max_age=0
	load_args "$@"
	(( max_age > 0 )) || die "prune_delete_old: bad max_age: ${max_age}"

	if (( snap_age > max_age )); then
		delete=1
	fi
}

_prune_keep_within_timeframe() {
	local desc="$1" count="$2" discriminator="$3" min_ts="$4" max_age="$5" age_unit_name="$6"

	# @name is stringified rule arguments, append rule name
	desc="${FUNCNAME[1]} $desc"
	state_var="state_$(echo -n "$desc" | tr -cs [a-zA-Z0-9] '_')"
	declare -g -A "$state_var"
	declare -n state="$state_var"

	local min_sec="$(ts "$min_ts")"
	if (( snap_sec < min_sec )); then
		log "rule: $desc: backup $snap is older than $max_age ${age_unit_name}s (snap=$snap_ts ($snap_sec), min=$min_ts ($min_sec)), skipping"
		return
	fi

	local bucket="$(date -d "$snap_ts" "$discriminator")"
	if (( state[$bucket] >= count )); then
		log "rule: $desc: backup $snap is in excess of allowed $count backups in bucket $bucket (already ${state[$bucket]:-0}), skipping"
		return
	fi

	log "rule: $desc: backup $snap is within allowed $count backups in bucket $bucket (already ${state[$bucket]:-0}), keeping"
	keep=1
	(( ++state[$bucket] ))
}

prune_keep_hourly() {
	local count=0 hours=0
	load_args "$@"
	(( count > 0 )) || die "prune_keep_hourly: bad count: ${count}"
	(( hours > 0 )) || die "prune_keep_hourly: bad hours: ${hours}"
	local min_ts="$(date -d "$NOW -$hours hours" -Iseconds)"
	_prune_keep_within_timeframe "$FUNCNAME $*" "$count" "+%Y-%m-%dT%H:00" "$min_ts" "$hours" "hour"
}

prune_keep_daily() {
	local count=0 days=0
	load_args "$@"
	(( count > 0 )) || die "prune_keep_daily: bad count: ${count}"
	(( days > 0 )) || die "prune_keep_daily: bad days: ${days}"
	local min_ts="$(date -d "$NOW -$days days" -Iseconds)"
	_prune_keep_within_timeframe "$FUNCNAME $*" "$count" "+%Y-%m-%d" "$min_ts" "$days" "day"
}

prune_keep_weekly() {
	local count=0 weeks=0
	load_args "$@"
	(( count > 0 )) || die "prune_keep_weekly: bad count: ${count}"
	(( weeks > 0 )) || die "prune_keep_weekly: bad weeks: ${weeks}"
	local min_ts="$(date -d "$NOW -$weeks weeks" -Iseconds)"
	_prune_keep_within_timeframe "$FUNCNAME $*" "$count" "+%Y,%W" "$min_ts" "$weeks" "week"
}

prune_keep_monthly() {
	local count=0 months=0
	load_args "$@"
	(( count > 0 )) || die "prune_keep_monthly: bad count: ${count}"
	(( months > 0 )) || die "prune_keep_monthly: bad months: ${months}"
	local min_ts="$(date -d "$NOW -$months months" -Iseconds)"
	_prune_keep_within_timeframe "$FUNCNAME $*" "$count" "+%Y-%m" "$min_ts" "$months" "month"
}

prune_keep_yearly() {
	local count=0 years=0
	load_args "$@"
	(( count > 0 )) || die "prune_keep_yearly: bad count: ${count}"
	(( years > 0 )) || die "prune_keep_yearly: bad years: ${years}"
	local min_ts="$(date -d "$NOW -$years years" -Iseconds)"
	_prune_keep_within_timeframe "$FUNCNAME $*" "$count" "+%Y" "$min_ts" "$years" "year"
}


#
# main
#

# backups are tried recent-first, as this aligns with daily/weekly/monthly rule semantics
# (that is, keep the most recent backup in a given timeframe)
# TODO: might want to implement configurable order
# FIXME: expecting that name == timestamp
BACKUPS=()
< <("${PRUNE_LIST[@]}" | sort -r) readarray -t BACKUPS

set_verdict() {
	local target_verdict="$1" target_rule="$2"

	# set verdict if it has not been set
	if ! [[ $verdict ]]; then
		verdict="$target_verdict"
	fi

	# record any rule that concurs with existing verdict
	if [[ $verdict == $target_verdict ]]; then
		verdict_rule="${verdict_rule:+$verdict_rule; }$target_rule"
	fi
}

PRUNE=()
for snap in "${BACKUPS[@]}"; do
	# FIXME: expecting that name == timestamp
	snap_ts="$snap"
	if ! snap_sec="$(ts "$snap_ts")"; then
		warn "cannot parse backup name as timestamp, skipping: $snap"
		continue
	fi
	snap_age="$(( NOW_SEC - snap_sec ))"
	if (( snap_age <= 0 )); then
		die "bad backup timestamp, aborting: snap=$snap ($snap_sec), now=$NOW ($NOW_SEC), age=$snap_age <= 0"
	fi

	log "trying backup: $snap ($snap_sec), age=$snap_age"
	#
	# only the first matched rule is used to generate a verdict, but we still run all rules to update their state
	#
	verdict=""
	verdict_rule=""
	for rule in "${PRUNE_RULES[@]}"; do
		keep=0
		delete=0
		rule=( $rule ) # split words
		dbg "rule: $(printf "'%s' " "${rule[@]}")"

		if ! [[ "${rule[0]}" == *=* ]]; then
			"prune_${rule[0]}" "${rule[@]:1}"
		else
			load_args "${rule[@]}"
		fi

		if (( keep )); then
			set_verdict "keep" "${rule[*]}"
		fi
		if (( delete )); then
			set_verdict "delete" "${rule[*]}"
		fi
	done

	case "$verdict" in
	keep)
		log "verdict: $snap = RETAIN (rule: $verdict_rule)"
		continue
		;;
	delete)
		log "verdict: $snap = PRUNE (rule: $verdict_rule)"
		PRUNE+=( "$snap" )
		;;
	"")
		die "nothing matched: $snap"
		;;
	*)
		die "bad verdict: $snap = $verdict"
		;;
	esac
done

if (( ${#PRUNE[@]} )); then
	say "Backups to prune:"
	printf "%s\n" "${PRUNE[@]}"
fi

for snap in "${PRUNE[@]}"; do
	log "pruning backup: $snap"
	"${PRUNE_DELETE[@]}" "$snap"
done
