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

__config_dir_name() {
	local __file="$1" __path
	__path="$(__config_canonicalize "$__file")"
	if ! [[ -d "$__path" ]]; then
		die "configuration directory does not exist: $__file"
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

__config_load0() {
	if ! [[ ${__fnames_defined0+set} ]]; then
		declare -g -a __fnames_defined0
		declare -F | readarray -t __fnames_defined0
		# strip everything before the last space character
		__fnames_defined0=( "${__fnames_defined0[@]##* }" )
	fi
}

__config_load1() {
	if ! [[ ${__fnames_defined1+set} ]]; then
		declare -g -a __fnames_defined1
		declare -F | readarray -t __fnames_defined1
		# strip everything before the last space character
		__fnames_defined1=( "${__fnames_defined1[@]##* }" )

		declare -g -a __fnames_defined
		# get functions that were defined in the config
		printf "%s\n" "${__fnames_defined1[@]}" \
		| grep -Fvxf <(printf "%s\n" "${__fnames_defined0[@]}") \
		| readarray -t __fnames_defined
	fi
}

__config_extract_dependencies() {
	__config_load1

	local __src="$1"
	local __flines=() __fwords=() __fnames_used __f

	# mark this function as processed (loop avoidance)
	declare -g -A __fnames_visited
	__fnames_visited[$__src]=1

	# read the function definition
	declare -f "$__src" | readarray -t __flines

	# chop the name, the opening brace and the closing brace
	[[ "${__flines[0]}" == "$__src () " &&
	   "${__flines[1]}" == "{ " &&
	   "${__flines[-1]}" == "}" ]] || { err "Internal error: malformed function definition: $__src"; return 1; }
	(( ${#__flines[@]} > 3 )) || return 0
	__flines=( "${__flines[@]:2:${#__flines[@]}-3}" )

	# get function names used in the definition
	printf "%s\n" "${__flines[@]}" \
	| { grep -Eo '[A-Za-z_][A-Za-z0-9_]*' || true; } \
	| { grep -Fxf <(printf "%s\n" "${__fnames_defined[@]}") || true; } \
	| readarray -t __fnames_used
	[[ ${__fnames_used+set} ]] || return 0

	for __f in "${__fnames_used[@]}"; do
		# avoid loops
		if [[ ${__fnames_visited[$__f]+set} ]]; then
			continue
		fi
		# recursively extract dependencies
		__config_extract_dependencies "$__f" || return 1
		# emit this function
		declare -f "$__f"
	done
}

# return 1 if errors were encountered (output must be discarded)
# return 2 if rc-required optional variables were missing
__config_extract() {
	local __prefix="$1" __err= __warn=
	shift 1

	local __src= __dest= __is_function= __is_rename= __is_optional=
	local __want_rc= __declare_cmd=() __mangle_cmd=
	while (( $# )); do
		case "$1" in
		-r|--rename) __is_rename=1; shift 1 ;;
		-o|--optional) __is_optional=1; shift 1 ;;
		-f|--function) __is_function=1; shift 1 ;;
		--rc) __want_rc=1; shift 1 ;;
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
						__err=1
						err "$__config_load_file__last: function $__src not found"
					elif [[ $__want_rc ]]; then
						__warn=1
					fi
					continue
				fi
				__declare_cmd=( declare -f )
				__mangle_cmd=__config_declare_mangle_f
				__config_extract_dependencies "$__src" || __err=1
			else
				if ! [[ ${!__src+set} ]]; then
					if ! [[ $__is_optional ]]; then
						__err=1
						err "$__config_load_file__last: variable $__src not found"
					elif [[ $__want_rc ]]; then
						__warn=1
					fi
					continue
				fi
				__declare_cmd=( declare -p )
				__mangle_cmd=__config_declare_mangle
			fi

			"${__declare_cmd[@]}" "$__src" | "$__mangle_cmd" "$__src" "$__dest" || __err=1

			# reset flags; others vars are assigned unconditionally
			__is_function=
			__is_rename=
			__is_optional=
			__want_rc=
		esac
	done

	if (( __err )); then return 1; fi
	if (( __warn )); then return 2; fi
	return 0
}

config_get_global() {
	local __vars=( "$@" )

	if (( ${#__vars[@]} )); then
		local __vars_data __rc
		__vars_data="$(
			set -eo pipefail
			__config_load0
			__config_load_global
			__config_extract "" "${__vars[@]}"
		)" || __rc=$?
		(( __rc == 0 || __rc == 2 )) || return 1
		eval "$__vars_data"
	else
		err "config_get_global: unimplemented: getting all variables"
		return 1
	fi
	(( __rc == 0 )) || return 1
}

config_get_job() {
	local __job="$1" __vars=( "${@:2}" )

	if (( ${#__vars[@]} )); then
		local __vars_data __rc
		__vars_data="$(
			set -eo pipefail
			__config_load0
			__config_load_job "$__job"
			# TODO: support mixing and matching variables
			#       from the global config (prefixed) and
			#       from the job config (non-prefixed)
			if [[ $__config_load_job__has_file ]]; then
				__config_extract "" "${__vars[@]}"
			else
				__config_extract "${__job}_" "${__vars[@]}"
			fi
		)" || __rc=$?
		(( __rc == 0 || __rc == 2 )) || return 1
		eval "$__vars_data"
	else
		err "config_get_job: unimplemented: getting all variables"
		return 1
	fi
	(( __rc == 0 )) || return 1
}

config_source() {
	__config_load_file "$1"
}

config_file() {
	__config_file_name "$1"
}

config_dir() {
	__config_dir_name "$1"
}
