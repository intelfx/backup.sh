#!/hint/bash

function label() {
	if [[ -t 1 ]]; then
		say "$@"
	fi
}

function log_array() {
	local fun="$1" title="$2"
	shift 2
	"$fun" "$title: $#"
	local arg
	for arg; do
		log "- $arg"
	done
}
