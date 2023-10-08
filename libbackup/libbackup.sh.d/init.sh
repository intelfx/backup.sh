#!/hint/bash

export BSH_ROOT_DIR="$(realpath -qm --strip "$BASH_SOURCE/../../..")"
export PATH="$BSH_ROOT_DIR/lib:$PATH"

LIBSH_LOG_PREFIX="$(realpath -qe --strip --relative-to="$BSH_ROOT_DIR" "${BASH_SOURCE[2]}")"

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
