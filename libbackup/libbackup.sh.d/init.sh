#!/hint/bash

export BSH_ROOT_DIR="$(realpath -qm --strip "$BASH_SOURCE/../../..")"
export PATH="$BSH_ROOT_DIR/lib:$PATH"

export BSH_ARGV0="${BSH_ARGV0-$0}"
LIBSH_LOG_PREFIX="${BSH_ARGV0##*/}"

VERB_DIR="$BSH_ROOT_DIR/cmds"
engine_verb_dir() {
	local engine="$1"
	local verb_dir="$BSH_ROOT_DIR/engines/$engine"
	if ! [[ -d "$verb_dir" ]]; then
		err "invalid backup driver: '$engine'"
		return 1
	fi
	echo "$verb_dir"
}

invoke() {
	local __cmd=(
		"$BSH_ROOT_DIR/backup.sh"
	)
	if [[ ${ARG_CONFIG+set} ]]; then
		__cmd+=( --config "$ARG_CONFIG" )
	fi

	"${__cmd[@]}" "$@"
}
