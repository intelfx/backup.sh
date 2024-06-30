#!/hint/bash

#
# infra
#

has_condition() {
	command -v "check_$1" &>/dev/null
}

check_condition() {
	# TODO: implement caching of some sort (maybe?)
	"check_$1"
}

jqs() {
	local input="$1"
	shift
	<<<"$input" jq "$@"
}

#
# "power"
#

check_power() {
	local rc f name
	for f in /sys/class/power_supply/*/online; do
		if ! [[ -r "$f" ]]; then continue; fi
		name="$f"; name="${name%/online}"; name="${name##*/}"
		if (( $(< "$f" ) )); then
			log "check_power: result=yes ($name is online)"
			return 0
		fi
	done
	log "check_power: result=no"
	return 1
}

#
# "internet" (via NM)
#

check_internet_connected() {
	local state_json

	if ! state_json="$(busctl get-property --json=short org.freedesktop.NetworkManager /org/freedesktop/NetworkManager org.freedesktop.NetworkManager State)"; then
		err "check_internet: failed to query NetworkManager"
		return 0  # assume connected
	fi

	if ! [[ "$(jqs "$state_json" -r '.type')" == u ]]; then
		err "check_internet: bad reply (unexpected type): '$state_json'"
		return 0  # assume not metered
	fi
	case "$(jqs "$state_json" -r '.data')" in
	0|50|60|70)  # NM_STATE_UNKNOWN, NM_STATE_CONNECTED_{LOCAL,SITE,GLOBAL}
		log "check_internet: json=$state_json result=yes (connected)"
		return 0  # connected
		;;
	10|20|30|40)  # NM_STATE_ASLEEP, NM_STATE_DISCONNECT{ED,ING}, ...
		log "check_internet: json=$state_json result=no (not connected)"
		return 1  # not connected
		;;
	*)
		err "check_internet: bad reply (unexpected data): $state_json"
		return 0  # assume connected
		;;
	esac
}

check_internet_metered() {
	local metered_json

	if ! metered_json="$(busctl get-property --json=short org.freedesktop.NetworkManager /org/freedesktop/NetworkManager org.freedesktop.NetworkManager Metered)"; then
		err "check_internet: failed to query NetworkManager"
		return 0  # assume not metered
	fi
	if ! [[ "$(jqs "$metered_json" -r '.type')" == u ]]; then
		err "check_internet: bad reply (unexpected type): '$metered_json'"
		return 0  # assume not metered
	fi
	case "$(jqs "$metered_json" -r '.data')" in
	0|2|4)  # NM_METERED_UNKNOWN, NM_METERED_NO, NM_METERED_GUESS_NO
		log "check_internet: json=$metered_json result=yes (not metered)"
		return 0  # not metered
		;;
	1|3)  # NM_METERED_YES | NM_METERED_GUESS_YES
		log "check_internet: json=$metered_json result=no (metered)"
		return 1  # metered
		;;
	*)
		err "check_internet: bad reply (unexpected data): $metered_json"
		return 0  # assume not metered
		;;
	esac
}

check_internet() {
	check_internet_connected && check_internet_metered
}

#
# "idle" (via logind)
#

check_idle() {
	local idle_delay idle_period_start idle_period_end
	local has_idle_delay has_idle_slots
	local -a idle_slots

	if config_get_job "$job" --optional --rc IDLE_DELAY; then
		has_idle_delay=1
		idle_delay="$IDLE_DELAY"
	fi
	if config_get_job "$job" --optional --rc IDLE_SLOTS; then
		has_idle_slots=1
		idle_slots="$IDLE_SLOTS"
	fi

	if (( has_idle_delay )); then
		err "check_idle: unimplemented: IDLE_DELAY"
		return 1
	fi

	if (( has_idle_slots )); then
		err "check_idle: unimplemented: IDLE_SLOTS"
		return 1
	fi

	warn "check_idle: nothing to check"
	return 0
}
