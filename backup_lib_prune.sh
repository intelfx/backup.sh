#!/hint/bash


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
	# arguments: desc log_max_age log_age_unit max_age bucket
	state_var="state_$(echo -n "$desc" | tr -cs [a-zA-Z0-9] '_')"
	declare -g -A "$state_var"
	declare -n state="$state_var"

	local min="$(date -d "$max_age" -Iseconds)"
	local min_epoch="$(epoch "$min")"
	if (( snap_epoch < min_epoch )); then
		log "rule: $desc: backup $snap is older than $log_max_age ${log_age_unit}s (snap=$snap, min=$min), skipping"
		return
	fi

	local bucket="$($bucket_f "$snap")"
	if (( state[$bucket] >= count )); then
		log "rule: $desc: backup $snap is in excess of allowed $count backups in bucket $bucket (already ${state[$bucket]:-0}), skipping"
		return
	fi

	log "rule: $desc: backup $snap is within allowed $count backups in bucket $bucket (already ${state[$bucket]:-0}), keeping"
	keep=1
	(( ++state[$bucket] ))
}

d_keep_minutely() {
	local ts="$(epoch "$1")"
	local bucket="$(( ts - ts % (every * 60) ))"
	date -d "@$bucket" -Iminutes
}
prune_keep_minutely() {
	local every=1 count=0 minutes=0
	load_args "$@"
	(( every > 0 )) || die "$FUNCNAME: bad every: ${every}"
	(( count > 0 )) || die "$FUNCNAME: bad count: ${count}"
	(( minutes > 0 )) || die "$FUNCNAME: bad minutes: ${hours}"
	local desc="$FUNCNAME $*" log_max_age="$minutes" log_age_unit="minute"
	# roll back to beginning of the minute, then subtract minutes
	local max_age="$(now -Iminutes) -$minutes minutes"
	local bucket_f=d_keep_minutely
	_prune_keep_within_timeframe
}

d_keep_hourly() {
	local ts="$(epoch "$1")"
	local bucket="$(( ts - ts % (every * 3600) ))"
	date -d "@$bucket" -Ihours
}
prune_keep_hourly() {
	local every=1 count=0 hours=0
	load_args "$@"
	(( every > 0 )) || die "$FUNCNAME: bad every: ${every}"
	(( count > 0 )) || die "$FUNCNAME: bad count: ${count}"
	(( hours > 0 )) || die "$FUNCNAME: bad hours: ${hours}"
	local desc="$FUNCNAME $*" log_max_age="$hours" log_age_unit="hour"
	# roll back to 0 minutes, then subtract hours
	local max_age="$(now -Ihours) -$hours hours"
	local bucket_f=d_keep_hourly
	_prune_keep_within_timeframe
}

d_keep_daily() {
	local ts="$(epoch "$1")"
	local bucket="$(( ts - ts % (every * 3600 * 24) ))"
	date -d "@$bucket" -Idate
}
prune_keep_daily() {
	local every=1 count=0 days=0
	load_args "$@"
	(( every > 0 )) || die "$FUNCNAME: bad every: ${every}"
	(( count > 0 )) || die "$FUNCNAME: bad count: ${count}"
	(( days > 0 )) || die "$FUNCNAME: bad hours: ${hours}"
	local desc="$FUNCNAME $*" log_max_age="$days" log_age_unit="day"
	# roll back to 00:00:00, then subtract days
	local max_age="$(now -Idate) -$days days"
	local bucket_f=d_keep_daily
	_prune_keep_within_timeframe
}

d_keep_weekly() {
	# TODO: support divisors (a bucket every X weeks)
	local ts="$1"
	date -d "$ts" '+%YW%W'
}
prune_keep_weekly() {
	local count=0 weeks=0
	load_args "$@"
	(( count > 0 )) || die "$FUNCNAME: bad count: ${count}"
	(( weeks > 0 )) || die "$FUNCNAME: bad weeks: ${weeks}"
	# roll back to 00:00:00, then roll back to last Monday, then subtract weeks
	local desc="$FUNCNAME $*" log_max_age="$weeks" log_age_unit="week"
	local max_age="$(now -Idate) last Monday -$weeks weeks"
	local bucket_f=d_keep_weekly
	_prune_keep_within_timeframe
}

d_keep_monthly() {
	# TODO: support divisors (a bucket every X months)
	local ts="$1"
	date -d "$ts" "+%Y-%m"
}
prune_keep_monthly() {
	local count=0 months=0
	load_args "$@"
	(( count > 0 )) || die "prune_keep_monthly: bad count: ${count}"
	(( months > 0 )) || die "prune_keep_monthly: bad months: ${months}"
	# roll back to 1st of current month, then subtract months
	local desc="$FUNCNAME $*" log_max_age="$months" log_age_unit="month"
	local max_age="$(date -d "$NOW" '+%Y-%m-01') -$months months"
	local bucket_f=d_keep_monthly
	_prune_keep_within_timeframe
}

d_keep_yearly() {
	local ts="$1"
	local year="$(date -d "$ts" "+%Y")"
	echo "$(( year - year % every ))"
}
prune_keep_yearly() {
	local every=1 count=0 years=0
	load_args "$@"
	(( every > 0 )) || die "prune_keep_yearly: bad every: ${years}"
	(( count > 0 )) || die "prune_keep_yearly: bad count: ${count}"
	(( years > 0 )) || die "prune_keep_yearly: bad years: ${years}"
	local desc="$FUNCNAME $*" log_max_age="$years" log_age_unit="year"
	local max_age="$(date -d "$NOW" '+%Y-01-01') -$years years"
	local bucket_f=d_keep_yearly
	_prune_keep_within_timeframe
}


#
# subroutines, cont.
#

prune_set_verdict() {
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

prune_try_rule() {
	local keep=0 delete=0
	local rule=( $rule ) # split words
	dbg "rule: $(printf "'%s' " "${rule[@]}")"

	if ! [[ "${rule[0]}" == *=* ]]; then
		"prune_${rule[0]}" "${rule[@]:1}"
	else
		load_args "${rule[@]}"
	fi

	if (( keep )); then
		prune_set_verdict "keep" "${rule[*]}"
	fi
	if (( delete )); then
		prune_set_verdict "delete" "${rule[*]}"
	fi
}

prune_try_backup() {
	local snap_age="$(( NOW_EPOCH - snap_epoch ))"
	if (( snap_age < 0 )); then
		die "bad backup timestamp, aborting: snap=$snap ($snap_epoch), now=$NOW ($NOW_EPOCH), age=$snap_age < 0"
	fi

	log "trying backup: $snap ($snap_epoch), age=$snap_age"

	# only the first matched rule is used to generate a verdict, but we still run all rules to update their state
	local rule verdict="" verdict_rule=""
	for rule in "$@"; do
		prune_try_rule
	done

	case "$verdict" in
	keep)
		log "verdict: $snap = RETAIN (rule: $verdict_rule)"
		;;
	delete)
		log "verdict: $snap = PRUNE (rule: $verdict_rule)"
		prune_callback "$snap"
		;;
	"")
		die "nothing matched: $snap"
		;;
	*)
		die "bad verdict: $snap = $verdict"
		;;
	esac
}

prune_load_backups() {
	while read snap; do
		# assume that snapshot IDs are valid (ISO 8601) timestamps
		snap_epoch="$(epoch "$snap")"
		BACKUPS+=( "$snap_epoch $snap" )
	done < <( "$@" )

	# backups are tried recent-first, as this aligns with daily/weekly/monthly rule semantics
	# (that is, keep the most recent backup in a given timeframe)
	# TODO: might want to implement configurable order
	sort_array BACKUPS -r -n -k1
}

prune_try_backups() {
	for line in "${BACKUPS[@]}"; do
		read snap_epoch snap <<< "$line"
		prune_try_backup "$@"
	done
}
