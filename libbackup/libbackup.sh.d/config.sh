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

__config_canonicalize() {
	local __file="$1" __path

	if [[ $__file == /* ]]; then
		die "absolute configuration paths not allowed: $__file"
	elif [[ $__file == *..* ]]; then
		die "\"..\" in configuration paths not allowed: $__file"
	fi

	(cd "$BSH_CONFIG_DIR"; realpath -q --strip -- "$__file")
}

__config_file_name() {
	local __file="$1" __path
	__path="$(__config_canonicalize "$__file")"
	if ! [[ -f "$__path" ]]; then
		die "configuration file does not exist: $__file"
	fi
	echo "$__path"
}

__config_load_file() {
	local __file="$1" __path
	__path="$(__config_file_name "$__file")"
	__config_load_file__last="${__path#$BSH_CONFIG_DIR/}"
	source "$__path"
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

		__config_load_file "$__job_file"
		__config_load_job__has_file=1
	fi
}

__config_declare_mangle() {
	local __src="$1" __dest="$2"
	sed -r "1s|^(declare) ((-[a-zA-Z0-9-]+ )+)${__src}=(.+)$|\1 -g \2${__dest}=\4|"
}

__config_declare_mangle_f() {
	local __src="$1" __dest="$2"
	sed -r "1s|^${__src} \(\) *$|${__dest} ()|"
}

__config_extract() {
	local __prefix="$1" __rc=0
	shift 1

	local __src= __dest= __is_function= __is_rename= __is_optional=
	local __declare_cmd=() __mangle_cmd=
	while (( $# )); do
		case "$1" in
		-r|--rename) __is_rename=1; shift 1 ;;
		-o|--optional) __is_optional=1; shift 1 ;;
		-f|--function) __is_function=1; shift 1 ;;
		*)
			__src="${__prefix}${1}"

			if [[ $__is_rename ]]; then
				__dest="${2}"
				shift 2
			else
				__dest="${1}"
				shift 1
			fi

			if [[ $__is_function ]]; then
				if ! [[ "$(type -t $__src)" == function ]]; then
					if ! [[ $__is_optional ]]; then
						__rc=1
						err "$__config_load_file__last: function $__src not found"
					fi
					continue
				fi
				__declare_cmd=( declare -pf )
				__mangle_cmd=__config_declare_mangle_f
			else
				if ! [[ ${!__src+set} ]]; then
					if ! [[ $__is_optional ]]; then
						__rc=1
						err "$__config_load_file__last: variable $__src not found"
					fi
					continue
				fi
				__declare_cmd=( declare -p )
				__mangle_cmd=__config_declare_mangle
			fi

			"${__declare_cmd[@]}" "$__src" | "$__mangle_cmd" "$__src" "$__dest" || return 1

			# reset flags; others vars are assigned unconditionally
			__is_function=
			__is_rename=
			__is_optional=
		esac
	done

	if (( __rc )); then exit $__rc; fi
}

config_get_global() {
	local __vars=( "$@" )

	if (( ${#__vars[@]} )); then
		local __vars_data
		__vars_data="$(
			set -eo pipefail
			__config_load_global
			__config_extract "" "${__vars[@]}"
		)" || return 1
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
				__config_extract "" "${__vars[@]}"
			else
				__config_extract "${__job}_" "${__vars[@]}"
			fi
		)" || return 1
		eval "$__vars_data"
	else
		err "config_get_job: unimplemented: getting all variables"
		return 1
	fi
}

config_source() {
	__config_load_file "$1"
}

config_file() {
	__config_file_name "$1"
}
