#!/hint/bash

config_setup() {
	local arg="$1"
	local configfile

	if [[ -d "$arg" ]]; then
		configfile="$arg/Backupfile"
		if ! [[ -f "$configfile" ]]; then
			err "configuration directory specified but Backupfile does not exist: $arg"
			return 1
		fi
	elif [[ -f "$arg" ]]; then
		configfile="$arg"
	elif [[ -z "$arg" ]]; then
		err "configuration path not specifiee"
		return 1
	else
		err "configuration path does not exist: $arg"
		return 1
	fi
	export BSH_CONFIG_FILE="$(realpath -qe --strip "$configfile")"
	export BSH_CONFIG_DIR="$(dirname "$BSH_CONFIG_FILE")"
}

__config_load_file() {
	local __file="$1"

	cd "$BSH_CONFIG_DIR"
	source "$__file"
}

__config_load_global() {
	__config_load_file "$BSH_CONFIG_FILE"
}

__config_load_job() {
	local __job="$1"
	unset __config_load_job__has_file

	__config_load_global
	if [[ "${JOBS_FILES["$__job"]+set}" ]]; then
		local __job_file="${JOBS_FILES["$__job"]}"
		if ! [[ -f "$__job_file" ]]; then
			err "Configuration file for job $__job invalid: $__job_file"
			return 1
		fi
		__config_load_file "$__job_file"
		__config_load_job__has_file=1
	fi

}

__config_declare_mangle() {
	sed -r 's|^declare|& -g|'
}

__config_declare_mangle_strip() {
	local prefix="$1"
	sed -r "s|^(declare) ((-[a-zA-Z0-9-]+ )+)${prefix}_(.+)$|\1 -g \2\4|"
}

config_get_global() {
	local __vars=( "$@" )

	if (( ${#__vars[@]} )); then
		local __vars_data
		__vars_data="$(
			set -eo pipefail
			__config_load_global
			declare -p "${__vars[@]}" | __config_declare_mangle
		)"
		eval "$__vars_data"
	else
		err "config_get_global: unimplemented: getting all variables"
		return 1
	fi
}

config_get_job() {
	local __job="$1" __vars=( "${@:2}" )

	if (( ${#__vars[@]} )); then
		local __vars_data
		__vars_data="$(
			set -eo pipefail
			__config_load_job "$__job"
			# TODO: support mixing and matching variables
			#       from the global config (prefixed) and
			#       from the job config (non-prefixed)
			if [[ $__config_load_job__has_file ]]; then
				declare -p "${__vars[@]}" | __config_declare_mangle
			else
				declare -p "${__vars[@]/#/${__job}_}" | __config_declare_mangle_strip "$__job"
			fi
		)"
		eval "$__vars_data"
	else
		err "config_get_job: unimplemented: getting all variables"
		return 1
	fi
}
