#!/bin/bash

. "${BASH_SOURCE%/*}/libbackup/libbackup.sh" || exit

_usage() {
	cat <<EOF
Usage: $0 [-c|--config CONFIG] VERB [JOB] [ARGS...]

Global options:
	-c|--config CONFIG 	Path to main configuration file or directory

Common verbs:
	ls-jobs			List all available jobs (no arguments expected)
	ls-verbs JOB		List all available verbs for a job
	ls JOB 			List backups of a job

Available verbs are defined by the job.
EOF
}

ARG_CONFIG_DEFAULT="$BSH_ROOT_DIR/cfg"
declare -A GLOBAL_OPTIONS=(
	[getopt]="+"
	[-c|--config]="ARG_CONFIG"
	[--]="ARGS"
)
parse_args GLOBAL_OPTIONS "$@"

if ! (( ${#ARGS[@]} >= 1 )); then
	usage "not enough arguments"
fi

config_setup "${ARG_CONFIG:-$ARG_CONFIG_DEFAULT}"

VERB="$1"
VERB_ARGS=( "${@:2}" )
LIBSH_LOG_PREFIX+=": $VERB"
set --

__verb_expect_args() {
	if ! (( ${#VERB_ARGS[@]} == $1 )); then
		usage "expected $1 argument(s)"
	fi
}

__verb_expect_args_ge() {
	if ! (( ${#VERB_ARGS[@]} >= $1 )); then
		usage "expected $1 or more argument(s)"
	fi
}

__verb_check_job() {
	local job="$1"
	local j
	config_get_global JOBS
	for j in "${JOBS[@]}"; do
		if [[ "$job" == "$j" ]]; then
			return 0
		fi
	done

	err "invalid job: '$job'"
	return 1
}

___verb_load_lib_dir() {
	local dir="$1" f
	for f in "$dir"/*.sh; do
		if ! [[ -e "$f" ]]; then continue; fi
		source "$f"
	done
}

__verb_load_libs() {
	local dir="$1" verb="$2"
	local f

	if [[ -f "$dir/_lib.sh" ]]; then
		source "$dir/_lib.sh"
	elif [[ -d "$dir/_lib" ]]; then
		___verb_load_lib_dir "$dir/_lib"
	fi
	if [[ -f "$dir/_${verb}_lib.sh" ]]; then
		source "$dir/_${verb}_lib.sh"
	elif [[ -d "$dir/_${verb}_lib" ]]; then
		___verb_load_lib_dir "$dir/_${verb}_lib"
	fi
}

if [[ $VERB == ls-jobs ]]; then
	__verb_expect_args 0

	config_get_global JOBS
	print_array "${JOBS[@]}"

elif [[ $VERB == ls-verbs ]]; then
	__verb_expect_args 1
	__verb_check_job "${VERB_ARGS[0]}"

	JOB_NAME="${VERB_ARGS[0]}"
	config_get_job_as "$JOB_NAME" TYPE JOB_TYPE

	declare -A VERBS_SKIP=(
		[consume]=1
		[prune]=1
		[schedule]=1
	)
	declare -A VERBS
	for f in "$VERB_DIR"/*.sh "$(engine_verb_dir "$JOB_TYPE")"/*.sh; do
		if ! [[ -e "$f" ]]; then continue; fi
		f="${f##*/}"
		f="${f%.sh}"
		if [[ ${VERBS_SKIP[$f]+set} ]]; then continue; fi
		if [[ $f == _* ]]; then continue; fi
		VERBS[$f]=1
	done
	print_array "${!VERBS[@]}" | sort

elif [[ -e "$VERB_DIR/$VERB.sh" ]]; then
	__verb_load_libs "$VERB_DIR" "$VERB"
	source "$VERB_DIR/$VERB.sh"

else
	__verb_expect_args_ge 1
	__verb_check_job "${VERB_ARGS[0]}"

	JOB_NAME="${VERB_ARGS[0]}"

	config_get_job_as "$JOB_NAME" TYPE JOB_TYPE

	JOB_VERB_DIR="$(engine_verb_dir "$JOB_TYPE")"
	if [[ -e "$JOB_VERB_DIR/$VERB.sh" ]]; then
		__verb_load_libs "$JOB_VERB_DIR" "$VERB"
		source "$JOB_VERB_DIR/$VERB.sh"
	else
		usage "invalid verb"
	fi
fi
