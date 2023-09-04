#!/hint/bash

function now() {
	date -d "$NOW" "$@"
}

function epoch() {
	local time="$1"
	[[ "$time" ]] || die "epoch: empty timestamp passed"
	date -d "$time" '+%s'
}

# this function outputs a pseudo-epoch adjusted for input timezone
# (meaning that 0 is at 1970-01-01 00:00 in the input timezone)
function epoch_adjusted() {
	local time="$1"
	[[ "$time" ]] || die "epoch_adjusted: empty timestamp passed"

	local zone="$(date -d "$time" '+%::z')"
	if ! [[ "$zone" =~ ^(\+|-)([0-9]{2}):([0-9]{2}):([0-9]{2})$ ]]; then
		die "epoch_adjusted: could not parse extracted timezone: time=$time, zone=$zone"
	fi
	local zone_expr="${BASH_REMATCH[1]}( ${BASH_REMATCH[2]}*3600 + ${BASH_REMATCH[3]}*60 + ${BASH_REMATCH[4]} )"
	local zone_sec="$(( $zone_expr ))"
	dbg "epoch_adjusted: zone $zone = $zone_expr = $zone_sec seconds"

	local epoch="$(date -d "$time" '+%s')"
	echo "$(( epoch + zone_sec ))"
}

NOW="$(date -Iseconds)"
NOW_EPOCH="$(epoch "$NOW")"
