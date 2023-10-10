#!/hint/bash

#
# options
#

_usage() {
	cat <<EOF
$_usage_common_syntax run-all [JOBS...]
$_usage_common_options
run-all options:
	JOBS...			Name(s) of backup job(s) to run
				(if unspecified, all jobs will be considered)
EOF
}


#
# config
#

config_get_global JOBS
for arg in "${VERB_ARGS[@]}"; do
	for j in "${JOBS[@]}"; do
		if [[ "$arg" == "$j" ]]; then
			continue 2
		fi
	done

	err "invalid job: '$arg'"
	exit 1
done
if (( ${#VERB_ARGS[@]} )); then
	RUN_JOBS=( "${VERB_ARGS[@]}" )
else
	RUN_JOBS=( "${JOBS[@]}" )
fi

# TODO: tsort jobs


#
# functions
#

check_power() {
	local rc f name
	for f in /sys/class/power_supply/*/online; do
		if ! [[ -r "$f" ]]; then continue; fi
		name="$f"; name="${name%/online}"; name="${name##*/}"
		if (( $(< "$f" ) )); then
			log "check_power: result=yes ($name is online)"
			return 0
		fi
	done
	log "check_power: result=no"
	return 1
}

jqs() {
	local input="$1"
	shift
	<<<"$input" jq "$@"
}

check_internet_connected() {
	local state_json

	if ! state_json="$(busctl get-property --json=short org.freedesktop.NetworkManager /org/freedesktop/NetworkManager org.freedesktop.NetworkManager State)"; then
		err "check_internet: failed to query NetworkManager"
		return 0  # assume connected
	fi

	if ! [[ "$(jqs "$state_json" -r '.type')" == u ]]; then
		err "check_internet: bad reply (unexpected type): '$state_json'"
		return 0  # assume not metered
	fi
	case "$(jqs "$state_json" -r '.data')" in
	0|50|60|70)  # NM_STATE_UNKNOWN, NM_STATE_CONNECTED_{LOCAL,SITE,GLOBAL}
		log "check_internet: json=$state_json result=yes (connected)"
		return 0  # connected
		;;
	10|20|30|40)  # NM_STATE_ASLEEP, NM_STATE_DISCONNECT{ED,ING}, ...
		log "check_internet: json=$state_json result=no (not connected)"
		return 1  # not connected
		;;
	*)
		err "check_internet: bad reply (unexpected data): $state_json"
		return 0  # assume connected
		;;
	esac
}

check_internet_metered() {
	local metered_json

	if ! metered_json="$(busctl get-property --json=short org.freedesktop.NetworkManager /org/freedesktop/NetworkManager org.freedesktop.NetworkManager Metered)"; then
		err "check_internet: failed to query NetworkManager"
		return 0  # assume not metered
	fi
	if ! [[ "$(jqs "$metered_json" -r '.type')" == u ]]; then
		err "check_internet: bad reply (unexpected type): '$metered_json'"
		return 0  # assume not metered
	fi
	case "$(jqs "$metered_json" -r '.data')" in
	0|2|4)  # NM_METERED_UNKNOWN, NM_METERED_NO, NM_METERED_GUESS_NO
		log "check_internet: json=$metered_json result=yes (not metered)"
		return 0  # not metered
		;;
	1|3)  # NM_METERED_YES | NM_METERED_GUESS_YES
		log "check_internet: json=$metered_json result=no (metered)"
		return 1  # metered
		;;
	*)
		err "check_internet: bad reply (unexpected data): $metered_json"
		return 0  # assume not metered
		;;
	esac
}

check_internet() {
	check_internet_connected && check_internet_metered
}

has_condition() {
	command -v "check_$1" &>/dev/null
}

check_condition() {
	# TODO: implement caching of some sort (maybe?)
	"check_$1"
}


#
# main
#

log "running ${#RUN_JOBS[@]} backup jobs"

declare -A SKIPPED_JOBS
declare -A FAILED_JOBS
declare -a PRUNE_JOBS

run_job() {
	local job="$1" verb
	if config_get_job "$job" --optional --rc --rename SOURCE SOURCE_JOB_NAME; then
		local job_source="$SOURCE_JOB_NAME"
	fi
	if config_get_job "$job" --optional --rc SCHEDULE_RULES; then
		local has_schedule=1
	fi
	if config_get_job "$job" --optional --rc PRUNE_RULES; then
		local has_prune=1
	fi
	if config_get_job "$job" --optional --rc CONDITIONS; then
		local job_conditions=( "${CONDITIONS[@]}" )
	else
		local job_conditions=()
	fi

	if [[ ${job_source+set} ]]; then
		if [[ ${SKIPPED_JOBS[$job_source]+set} ]]; then
			warn "skipping job '$job' because its source job '$source_job' was skipped"
			SKIPPED_JOBS[$job]=1
			return
		fi
		if [[ ${FAILED_JOBS[$job_source]+set} ]]; then
			warn "skipping job '$job' because its source job '$source_job' has failed"
			SKIPPED_JOBS[$job]=1
			return
		fi
	fi

	if [[ ${job_source+set} && ${has_schedule+set} && ${has_prune+set} ]]; then
		verb=consume
	elif [[ ${has_schedule+set} ]]; then
		verb=schedule
		if [[ ${job_source+set} ]]; then
			# TODO: collect parent job output
			warn "unimplemented: job '$job' has a source and verb=\"schedule\"; this will likely fail"
		fi
	else
		verb=create
		if [[ ${job_source+set} ]]; then
			# TODO: collect parent job output
			warn "unimplemented: job '$job' has a source and verb=\"create\"; this will likely fail"
		fi
	fi

	local c
	for c in "${job_conditions[@]}"; do
		if ! has_condition "$c"; then
			err "invalid condition in job '$job': '$c'"
			FAILED_JOBS[$job]=1
			return
		fi
		if ! check_condition "$c"; then
			warn "skipping job '$job' because condition '$c' is unmet"
			SKIPPED_JOBS[$job]=1
			return
		fi
	done

	if invoke "$verb" "$job"; then
		:
	else
		rc=$?
		warn "failed to '$verb' job '$job'"
		FAILED_JOBS[$job]=1
		return
	fi

	if [[ ${has_prune+set} ]]; then
		PRUNE_JOBS+=( "$job" )
	fi
}

prune_job() {
	local job="$1" verb="prune"

	if invoke "$verb" "$job"; then
		:
	else
		rc=$?
		warn "failed to '$verb' job '$job'"
		FAILED_JOBS[$job]=1
	fi
}

for j in "${RUN_JOBS[@]}"; do
	run_job "$j"
done

for j in "${PRUNE_JOBS[@]}"; do
	prune_job "$j"
done

if (( ${#SKIPPED_JOBS[@]} )); then
	warn "skipped "${#SKIPPED_JOBS} jobs:""
	for j in "${RUN_JOBS[@]}"; do
		if [[ ${SKIPPED_JOBS[$j]+set} ]]; then
			say " * $j"
		fi
	done
fi

if (( ${#FAILED_JOBS[@]} )); then
	err "failed ${#FAILED_JOBS[@]} jobs:"
	for j in "${RUN_JOBS[@]}"; do
		if [[ ${FAILED_JOBS[$j]+set} ]]; then
			say " * $j"
		fi
	done
	exit 1
fi

log "all done"
