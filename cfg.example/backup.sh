#!/bin/bash -e

. ../backup_lib.sh || exit

cd "${BASH_SOURCE%/*}"

check_ac_power() {
	local rc
	/usr/lib/systemd/systemd-ac-power && rc=0 || rc=$?
	case "$rc" in
	0)
		log "check_ac_power: result=yes"
		;;
	*)
		log "check_ac_power: result=no"
		;;
	esac
	return $rc
}

jqs() {
	local input="$1"
	shift
	<<<"$input" jq "$@"
}

check_not_metered() {
	local metered_json="$(busctl get-property --json=short org.freedesktop.NetworkManager /org/freedesktop/NetworkManager org.freedesktop.NetworkManager Metered)"

	if ! [[ "$(jqs "$metered_json" -r '.type')" == u ]]; then
		die "check_not_metered: bad reply (type != u): $metered_json"
	fi
	case "$(jqs "$metered_json" -r '.data')" in
	0|2|4) # NM_METERED_UNKNOWN, NM_METERED_NO, NM_METERED_GUESS_NO
		log "check_not_metered: json=$metered_json result=yes (not metered)"
		return 0 # not metered
		;;
	1|3) # NM_METERED_YES | NM_METERED_GUESS_YES
		log "check_not_metered: json=$metered_json result=no (metered)"
		return 1
		;;
	*)
		die "check_metered: bad reply (data not in 0..4): $metered_json"
		;;
	esac
}

check_expensive() {
	check_ac_power && check_not_metered
}

can_backup_expensive() {
	declare -g BACKUP_EXPENSIVE
	if ! [[ "$BACKUP_EXPENSIVE" ]]; then
		if check_expensive; then
			BACKUP_EXPENSIVE=1
		else
			BACKUP_EXPENSIVE=0
		fi
	fi
	(( BACKUP_EXPENSIVE ))
}

BACKUP_EXPENSIVE=

declare -A PARSE_ARGS
PARSE_ARGS=(
	[--all]="BACKUP_EXPENSIVE"
	[-a]="BACKUP_EXPENSIVE"
)
parse_args PARSE_ARGS "$@"

log "Snapshotting btrfs"
backup_schedule.sh cfg_btrfs_schedule.sh

# TODO: abort already running expensive operations if status changes
if can_backup_expensive; then
	log "Pushing btrfs snapshots to borg"
	backup_consume.sh cfg_consume_btrfs_borg_system.sh

	log "Cleaning up borg"
	backup_prune.sh cfg_borg_system_prune.sh
fi

log "Cleaning up btrfs"
backup_prune.sh cfg_btrfs_prune.sh
