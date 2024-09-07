#!/hint/bash

shopt -s extglob

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

function _prune_log() {
	if (( PRUNE_SILENT )); then
		dbg "$@"
	else
		log "$@"
	fi
}


#
# prune rules
#

prune_keep_recent() {
	local min_age=0
	load_args "$@"
	(( min_age > 0 )) || die "prune_keep_recent: bad min_age: ${min_age}"

	if (( snap_age < min_age )); then
		#dbg "rule: prune_keep_recent $*: backup $snap is newer than ${min_age} seconds (snap=$snap, now=$NOW), keeping"
		keep=1
	fi
}

prune_delete_old() {
	local max_age=0
	load_args "$@"
	(( max_age > 0 )) || die "prune_delete_old: bad max_age: ${max_age}"

	if (( snap_age > max_age )); then
		#dbg "rule: prune_delete_old $*: backup $snap is older than ${max_age} seconds (snap=$snap, now=$NOW), deleting"
		delete=1
	fi
}

prune_state_var() {
	local method="$1"
	echo "__prune_state${PRUNE_STATE:+__${PRUNE_STATE}}__${method//+(!([a-zA-Z0-9]))/_}"
}

prune_state_reset() {
	local var
	for var in "${!__prune_state__@}"; do
		unset "$var"
	done
}

_prune_parse_max_age() {
	if (( minutes > 0 )); then
		# roll back to beginning of the minute, then subtract minutes
		max_age="$(now -Iminutes) -$minutes minutes"
		log_max_age="$minutes"
		log_age_unit="min"
	elif (( hours > 0 )); then
		# roll back to 0 minutes, then subtract hours
		max_age="$(now -Ihours) -$hours hours"
		log_max_age="$hours"
		log_age_unit="hour"
	elif (( days > 0 )); then
		# roll back to 00:00:00, then subtract days
		max_age="$(now -Idate) -$days days"
		log_max_age="$days"
		log_age_unit="day"
	elif (( weeks > 0 )); then
		# roll back to 00:00:00, then roll back to last Monday, then subtract weeks
		max_age="$(now -Idate) last Monday -$weeks weeks"
		log_max_age="$weeks"
		log_age-unit="week"
	elif (( months > 0 )); then
		# roll back to 1st of current month, then subtract months
		max_age="$(date -d "$NOW" '+%Y-%m-01') -$months months"
		log_max_age="$months"
		log_age_unit="month"
	elif (( years > 0 )); then
		max_age="$(date -d "$NOW" '+%Y-01-01') -$years years"
		log_max_age="$years"
		log_age_unit="year"
	fi
}
_prune_keep_within_timeframe() {
	# arguments: desc log_max_age log_age_unit max_age bucket
	state_var="$(prune_state_var "$desc")"
	declare -g -A "$state_var"
	declare -n state="$state_var"

	local min min_epoch=0
	if [[ "$max_age" ]]; then
		min="$(date -d "$max_age" -Iseconds)"
		min_epoch="$(epoch "$min")"
	fi
	if (( snap_epoch < min_epoch )); then
		#dbg "rule: $desc: backup $snap is older than $log_max_age ${log_age_unit}s (snap=$snap, min=$min), skipping"
		return
	fi

	local bucket="$($bucket_f "$snap")"
	if (( state[$bucket] >= count )); then
		#dbg "rule: $desc: backup $snap is in excess of allowed $count backups in bucket $bucket (already ${state[$bucket]:-0}), skipping"
		return
	fi

	#dbg "rule: $desc: backup $snap is within allowed $count backups in bucket $bucket (already ${state[$bucket]:-0}), keeping"
	keep=1
	(( ++state[$bucket] ))
}

d_keep_minutely() {
	local ts="$(epoch_adjusted "$1")"
	local bucket="$(( ts - ts % (every * 60) ))"
	date -d "@$bucket" -Iminutes
}
prune_keep_minutely() {
	local every=1 count=0
	local minutes=0 hours=0 days=0 weeks=0 months=0 years=0
	load_args "$@"
	(( every > 0 )) || die "$FUNCNAME: bad every: ${every}"
	(( count > 0 )) || die "$FUNCNAME: bad count: ${count}"
	local desc="$FUNCNAME $*"
	local max_age log_max_age log_age_unit
	_prune_parse_max_age
	local bucket_f=d_keep_minutely
	_prune_keep_within_timeframe
}

d_keep_hourly() {
	local ts="$(epoch_adjusted "$1")"
	local bucket="$(( ts - ts % (every * 3600) ))"
	date -d "@$bucket" -Ihours
}
prune_keep_hourly() {
	local every=1 count=0
	local minutes=0 hours=0 days=0 weeks=0 months=0 years=0
	load_args "$@"
	(( every > 0 )) || die "$FUNCNAME: bad every: ${every}"
	(( count > 0 )) || die "$FUNCNAME: bad count: ${count}"
	local desc="$FUNCNAME $*"
	local max_age log_max_age log_age_unit
	_prune_parse_max_age
	local bucket_f=d_keep_hourly
	_prune_keep_within_timeframe
}

d_keep_daily() {
	local ts="$(epoch_adjusted "$1")"
	local bucket="$(( ts - ts % (every * 3600 * 24) ))"
	date -d "@$bucket" -Idate
}
prune_keep_daily() {
	local every=1 count=0
	local minutes=0 hours=0 days=0 weeks=0 months=0 years=0
	load_args "$@"
	(( every > 0 )) || die "$FUNCNAME: bad every: ${every}"
	(( count > 0 )) || die "$FUNCNAME: bad count: ${count}"
	local desc="$FUNCNAME $*"
	local max_age log_max_age log_age_unit
	_prune_parse_max_age
	local bucket_f=d_keep_daily
	_prune_keep_within_timeframe
}

d_keep_weekly() {
	# TODO: support divisors (a bucket every X weeks)
	local ts="$1"
	date -d "$ts" '+%YW%W'
}
prune_keep_weekly() {
	local count=0
	local minutes=0 hours=0 days=0 weeks=0 months=0 years=0
	load_args "$@"
	(( every != 1 )) || die "$FUNCNAME: bad every: ${every}"
	(( count > 0 )) || die "$FUNCNAME: bad count: ${count}"
	local desc="$FUNCNAME $*"
	local max_age log_max_age log_age_unit
	_prune_parse_max_age
	local bucket_f=d_keep_weekly
	_prune_keep_within_timeframe
}

d_keep_monthly() {
	# TODO: support divisors (a bucket every X months)
	local ts="$1"
	date -d "$ts" "+%Y-%m"
}
prune_keep_monthly() {
	local count=0
	local minutes=0 hours=0 days=0 weeks=0 months=0 years=0
	load_args "$@"
	(( every != 1 )) || die "$FUNCNAME: bad every: ${every}"
	(( count > 0 )) || die "$FUNCNAME: bad count: ${count}"
	local desc="$FUNCNAME $*"
	local max_age log_max_age log_age_unit
	_prune_parse_max_age
	local bucket_f=d_keep_monthly
	_prune_keep_within_timeframe
}

d_keep_yearly() {
	local ts="$1"
	local year="$(date -d "$ts" "+%Y")"
	echo "$(( year - year % every ))"
}
prune_keep_yearly() {
	local every=1 count=0
	local minutes=0 hours=0 days=0 weeks=0 months=0 years=0
	load_args "$@"
	(( every > 0 )) || die "$FUNCNAME: bad every: ${years}"
	(( count > 0 )) || die "$FUNCNAME: bad count: ${count}"
	local desc="$FUNCNAME $*"
	local max_age log_max_age log_age_unit
	_prune_parse_max_age
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
	#dbg "rule: $(printf "'%s' " "${rule[@]}")"

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

	#dbg "trying backup: $snap ($snap_epoch), age=$snap_age"

	# only the first matched rule is used to generate a verdict, but we still run all rules to update their state
	local rule verdict="" verdict_rule=""
	for rule in "$@"; do
		prune_try_rule
	done

	case "$verdict" in
	keep)
		_prune_log "verdict: $snap = RETAIN (rule: $verdict_rule)"
		if [[ $has_retain_callback ]]; then
			retain_callback "$snap"
		fi
		;;
	delete)
		_prune_log "verdict: $snap = PRUNE (rule: $verdict_rule)"
		if [[ $has_prune_callback ]]; then
			prune_callback "$snap"
		fi
		;;
	"")
		die "nothing matched: $snap"
		;;
	*)
		die "bad verdict: $snap = $verdict"
		;;
	esac
}

_prune_add_backup() {
	local snap_epoch
	# assume that snapshot IDs are valid (ISO 8601) timestamps
	snap_epoch="$(epoch "$snap")"
	backups+=( "$snap_epoch $snap" )
}

_prune_sort_backups() {
	sort_array backups -n -k1 "$@"
}

prune_reset() {
	declare -n backups="$1"
	backups=()
	prune_state_reset
}

prune_load_backups() {
	declare -n backups="$1"
	shift
	local snap
	invoke list "$@" | while read snap; do
		_prune_add_backup
	done
}

prune_add_backups() {
	declare -n backups="$1"
	shift
	local snap
	for snap in "$@"; do
		_prune_add_backup
	done
}

prune_sort_backups() {
	declare -n backups="$1"
	shift
	_prune_sort_backups "$@"
}

prune_get_backups() {
	declare -n backups="$1"
	shift
	print_array "${backups[@]}" | cut -d' ' -f2
}

prune_try_backups() {
	declare -n backups="$1"
	shift
	local has_retain_callback has_prune_callback
	if type -t retain_callback &>/dev/null; then has_retain_callback=1; fi
	if type -t prune_callback &>/dev/null; then has_prune_callback=1; fi
	local snap snap_epoch
	for line in "${backups[@]}"; do
		read snap_epoch snap <<< "$line"
		prune_try_backup "$@"
	done
}
