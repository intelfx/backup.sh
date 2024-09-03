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
# main
#

log "running ${#RUN_JOBS[@]} backup jobs"

declare -A SKIPPED_JOBS
declare -A FAILED_JOBS
declare -a PRUNE_JOBS

declare -a LOG_SKIP
declare -a LOG_MINOR
declare -a LOG_MAJOR

run_job() {
	local job="$1" verb rc

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

	if [[ ${has_prune+set} ]]; then
		# add job to the list of jobs to be pruned.
		# do it early -- if anything happens to the main job,
		# we'll want to log the (skipped) prune as well
		PRUNE_JOBS+=( "$job" )
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

	if [[ ${job_source+set} ]]; then
		if [[ ${SKIPPED_JOBS[$job_source]+set} ]]; then
			warn "skipping '$verb' on job '$job' because its source job '$job_source' was skipped"
			SKIPPED_JOBS[$job]=1
			LOG_SKIP+=( "$job ($verb)" )
			return
		fi
		if [[ ${FAILED_JOBS[$job_source]+set} ]]; then
			warn "skipping '$verb' on job '$job' because its source job '$job_source' has failed"
			SKIPPED_JOBS[$job]=1
			LOG_SKIP+=( "$job ($verb)" )
			return
		fi
	fi

	local c rc
	for c in "${job_conditions[@]}"; do
		if ! has_condition "$c"; then
			err "failing '$verb' on job '$job' because of invalid condition: '$c'"
			FAILED_JOBS[$job]=1
			LOG_MAJOR+=( "$job ($verb)" )
			return
		fi
		if check_condition "$c"; rc=$?; (( rc > 1 )); then
			err "failing '$verb' on job '$job' because of error evaluating condition: '$c'"
			FAILED_JOBS[$job]=1
			LOG_MAJOR+=( "$job ($verb)" )
			return
		elif (( rc != 0 )); then
			warn "skipping '$verb' on job '$job' because condition '$c' is unmet"
			SKIPPED_JOBS[$job]=1
			LOG_SKIP+=( "$job ($verb)" )
			return
		fi
	done

	invoke "$verb" "$job" && rc=0 || rc=$?

	if (( rc == 0 )); then
		:
	elif (( rc == BSH_SKIP_RC )); then
		warn "skipping '$verb' on job '$job'"
		SKIPPED_JOBS[$job]=1
		LOG_SKIP+=( "$job ($verb)" )
		return
	else
		err "failed to '$verb' job '$job'"
		FAILED_JOBS[$job]=1
		LOG_MAJOR+=( "$job ($verb)" )
		return
	fi
}

prune_job() {
	local job="$1" verb="prune" rc

	if [[ ${SKIPPED_JOBS[$job]+set} ]]; then
		warn "skipping '$verb' on job '$job' because the main job was skipped"
		LOG_SKIP+=( "$job ($verb)" )
		return
	fi
	if [[ ${FAILED_JOBS[$job]+set} ]]; then
		warn "skipping '$verb' on job '$job' because the main job has failed"
		LOG_SKIP+=( "$job ($verb)" )
		return
	fi

	invoke "$verb" "$job" && rc=0 || rc=$?

	if (( rc == 0 )); then
		:
	elif (( rc == BSH_SKIP_RC )); then
		warn "skipping '$verb' on job '$job'"
		LOG_SKIP+=( "$job ($verb)" )
	else
		warn "failed to '$verb' job '$job'"
		LOG_MINOR+=( "$job ($verb)" )
	fi
}

for j in "${RUN_JOBS[@]}"; do
	run_job "$j"
done

for j in "${PRUNE_JOBS[@]}"; do
	prune_job "$j"
done

if (( ${#LOG_SKIP[@]} )); then
	warn "skipped ${#LOG_SKIP[@]} jobs:"
	for j in "${LOG_SKIP[@]}"; do
		say " * $j"
	done
fi

if (( ${#LOG_MINOR[@]} )); then
	warn "failed ${#LOG_MINOR[@]} jobs (non-fatal):"
	for j in "${LOG_MINOR[@]}"; do
		say " * $j"
	done
fi

if (( ${#LOG_MAJOR[@]} )); then
	err "failed ${#LOG_MAJOR[@]} jobs:"
	for j in "${LOG_MAJOR[@]}"; do
		say " * $j"
	done
	exit 1
fi

log "all done"
