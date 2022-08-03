#!/bin/bash -e

. ${BASH_SOURCE%/*}/backup_lib.sh || exit

if ! (( $# >= 1 )); then
	die "$0: bad arguments ($*), usage: $0 <verb> [config] [args...]"
fi

VERB="$1"

if [[ -e "$BACKUP_SH/backup_${VERB}.sh" ]]; then
	shift 1
	exec "$BACKUP_SH/backup_${VERB}.sh" "$@"
else
	if ! (( $# >= 2 )); then
		die "$0: bad arguments ($*), usage: $0 <verb> <config> [args...]"
	fi
	CONFIG="$2"
	shift 2
	load_config_var --unlocked TYPE "$CONFIG"
	if [[ -e "$BACKUP_SH/${TYPE}_${VERB}.sh" ]]; then
		exec "$BACKUP_SH/${TYPE}_${VERB}.sh" "$CONFIG" "$@"
	else
		die "$0: unknown verb '$VERB' for engine '$ENGINE'"
	fi
fi
