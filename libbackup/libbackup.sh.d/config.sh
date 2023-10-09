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
		err "configuration path not specified"
		return 1
	else
		err "configuration path does not exist: $arg"
		return 1
	fi

	configfile="$(realpath -qe --strip -- "$configfile")"
	export BSH_CONFIG_FILE="$(basename "$configfile")"
	export BSH_CONFIG_DIR="$(dirname "$configfile")"
}

__config_file_name() {
	local __file="$1"

	if [[ $__file == /* ]]; then
		die "Absolute configuration paths not allowed: $__file"
	elif [[ $__file == *..* ]]; then
		die "\"..\" in configuration paths not allowed: $__file"
	fi

	(cd "$BSH_CONFIG_DIR"; realpath -q --strip -- "$__file")
}

__config_load_file() {
	local __file="$1"

	source "$(__config_file_name "$__file")"
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

__config_declare_mangle_rename() {
	local src="$1" dest="$2"
	sed -r "s|^(declare) ((-[a-zA-Z0-9-]+ )+)${src}=(.+)$|\1 -g \2${dest}=\4|"
}

__config_declare_mangle_strip_f() {
	local prefix="$1"
	sed -r "s|^${prefix}_(.+) \(\) *$|\1 ()|"
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

config_get_job_optional() {
	local __job="$1" __vars=( "${@:2}" ) __rc

	if (( ${#__vars[@]} )); then
		local __vars_data
		__vars_data="$(
			set -eo pipefail
			__config_load_job "$__job"
			# TODO: support mixing and matching variables
			#       from the global config (prefixed) and
			#       from the job config (non-prefixed)
			if [[ $__config_load_job__has_file ]]; then
				for __var in "${__vars[@]}"; do
					if ! [[ ${!__var+set} ]]; then exit 1; fi
				done
				declare -p "${__vars[@]}" | __config_declare_mangle
			else
				for __var in "${__vars[@]}"; do
					__var="${__job}_${__var}"
					if ! [[ ${!__var+set} ]]; then exit 1; fi
				done
				declare -p "${__vars[@]/#/${__job}_}" | __config_declare_mangle_strip "$__job"
			fi
		)" || return
		eval "$__vars_data"
	else
		err "config_get_job: unimplemented: getting all variables"
		return 1
	fi
}

config_get_job_as() {
	local __job="$1" __pairs=( "${@:2}" )

	local __vars_data
	__vars_data="$(
		set -eo pipefail
		__config_load_job "$__job"
		# TODO: support mixing and matching variables
		#       from the global config (prefixed) and
		#       from the job config (non-prefixed)
		while (( ${#__pairs[@]} )); do
			__var="${__pairs[0]}"
			__rename="${__pairs[1]}"
			__pairs=( "${__pairs[@]:2}" )
			if [[ $__config_load_job__has_file ]]; then
				declare -p "${__var}" | __config_declare_mangle_rename "${__var}" "${__rename}"
			else
				declare -p "${__job}_${__var}" | __config_declare_mangle_rename "${__job}_${__var}" "${__rename}"
			fi
		done
	)"
	eval "$__vars_data"
}

config_get_job_f() {
	local __job="$1" __vars=( "${@:2}" )

	if (( ${#__vars[@]} )); then
		local __vars_data
		__vars_data="$(
			set -eo pipefail
			__config_load_job "$__job"
			# TODO: support mixing and matching functions
			#       from the global config (prefixed) and
			#       from the job config (non-prefixed)
			if [[ $__config_load_job__has_file ]]; then
				declare -pf "${__vars[@]}"
			else
				declare -pf "${__vars[@]/#/${__job}_}" | __config_declare_mangle_strip_f "$__job"
			fi
		)"
		eval "$__vars_data"
	else
		err "config_get_job_f: unimplemented: getting all functions"
		return 1
	fi
}

config_source() {
	__config_load_file "$1"
}

config_file() {
	__config_file_name "$1"
}
