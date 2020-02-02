#!/hint/bash

set -e -o pipefail

. lib.sh || exit

#
# initialization
#

LIBSH_LOG_PREFIX="${BASH_SOURCE[0]##*/}"

if [[ "$BACKUP_SH" ]]; then
	warn "already loaded, not loading again"
	return
fi

BACKUP_SH="$(dirname "$BASH_SOURCE")"
if ! [[ -e "$BACKUP_SH/backup_lib.sh" ]]; then
	die "Cannot infer backup.sh root: '$BACKUP_SH'"
fi
export PATH="$BACKUP_SH:$PATH"

LIBSH_LOG_PREFIX="${BASH_SOURCE[1]##*/}"


#
# subroutines
#

CLEANUP_CMDS=()
cleanup_add() {
	CLEANUP_CMDS+=( "$@" )
}
cleanup_do() {
	local rc="$?"
	dbg "exit code: $rc"
	dbg "starting cleanup"
	local i cmd
	for (( i=${#CLEANUP_CMDS[@]}-1; i>=0; --i )); do
		cmd="${CLEANUP_CMDS[$i]}"
		dbg "cleanup: $cmd"
		eval "$cmd" || warn "cleanup failed (rc=$?): $cmd"
	done
	dbg "done cleaning up"
	CLEANUP_CMDS=()
	return "$rc"
}
trap cleanup_do EXIT TERM INT HUP


lock_file() {
	declare -g -A BACKUP_SH_LOCKED_FILES

	local file filepath fd
	for file; do
		# resolve path because we use it as a key
		filepath="$(realpath -qe "$file")"
		fd="${BACKUP_SH_LOCKED_FILES["$filepath"]}"
		if [[ "$fd" ]]; then
			dbg "lock_file: $file: already locked (fd=$fd), skipping"
			continue
		fi
		fd=
		exec {fd}<"$filepath"
		if ! flock --exclusive --nonblock "$fd"; then
			die "lock_file: $file: cannot lock, exiting"
		fi
		dbg "lock_file: $file: acquired lock (fd=$fd)"
		BACKUP_SH_LOCKED_FILES["$filepath"]="$fd"
	done
}


load_config() {
	local config="$1"
	shift 1

	if ! [[ -f "$config" && -r "$config" ]]; then
		die "bad config: '$config'"
	fi

	# Lock all sourced configuration files for the duration of the backup run
	# to avoid any possibility of concurrent writes to backup storage
	lock_file "$config"

	local configdir="$(dirname "$(realpath -qe "$config")")"
	. "$config" "$@"
}

load_config_var() {
	local var="$1"
	shift

	# load_config() is executed in a subshell, lock the config explicitly
	# in the parent process (see above)
	lock_file "$1"
	eval "$(load_config "$@" && declare -p "$var" | sed -r 's|^declare|& -g|')"
}

load_config_var2() {
	local dest="$1" src="$2"
	shift 2

	# load_config() is executed in a subshell, lock the config explicitly
	# in the parent process (see above)
	lock_file "$1"
	eval "$(load_config "$@" && declare -p "$src" | sed -r -e 's|^declare|& -g|' -e "s| $src=| $dest=|")"
}

btrfs_remount_id5_to() {
	local src="$1"
	local targetdir="$2"

	if ! [[ -e "$src" ]]; then
		err "btrfs_remount_id5_to: src does not exist: '$src'"
		return 1
	fi

	local cur="$src"
	local fstype device options
	while [[ "$cur" ]]; do
		dbg "btrfs_remount_id5_to: checking '$cur'"
		if </proc/self/mountinfo awk "BEGIN { rc=1 } \$5 == \"$cur\" { rc=0 } END { exit rc }"; then
			fstype="$(</proc/self/mountinfo awk "\$5 == \"$cur\" { print \$9 }")"
			device="$(</proc/self/mountinfo awk "\$5 == \"$cur\" { print \$10 }")"
			options="$(</proc/self/mountinfo awk "\$5 == \"$cur\" { print \$11 }")"
			break
		fi
		cur="${cur%/*}"
	done

	if ! [[ "$fstype" && "$device" ]]; then
		err "btrfs_remount_id5_to: could not find a mountpoint for '$src'"
		return 1
	fi
	dbg "btrfs_remount_id5_to: found mountpoint for '$src': device=$device, fstype=$fstype"
	if [[ "$fstype" != btrfs ]]; then
		err "btrfs_remount_id5_to: src '$src' belongs to '$cur' which is $fstype != btrfs"
		return 1
	fi
	if ! [[ -b "$device" ]]; then
		err "btrfs_remount_id5_to: src '$src' is mounted from '$device' which is not a block special"
		return 1
	fi

	# cleanup subvolid= and subvol= options
	# subvol can contain arbitrary characters including comma
	# thankfully, it is typically the last mount option, so we simply remove everything after subvol=
	# (FIXME: ensure btrfs actually guarantee that subvol= is emitted last)
	target_options="$(<<<"$options" sed -r -e 's|,?subvol=.*$||' -e 's|,?subvolid=[^,]*||')"

	if <<<"$target_options" grep -E '(subvol|subvolid)='; then
		err "btrfs_remount_id5_to: could not cleanup mount options for '$cur': '$options'"
		return 1
	fi

	target_options="$target_options,subvolid=5"

	dbg "btrfs_remount_id5_to: mounting root subvolume of '$device' on '$targetdir with '$target_options'"
	mount --make-private "$device" "$targetdir" -t btrfs -o "$target_options"
}

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

function now() {
	date -d "$NOW" "$@"
}

function ssh_unattended() {
	local dir="$1"
	local ssh=(
		ssh
		-o IdentitiesOnly=yes
		-o IdentityAgent=none
		-o StrictHostKeyChecking=accept-new
		-o UserKnownHostsFile="$dir/known_hosts"
	)

	local pub priv
	for pub in "$dir"/id_*.pub; do
		priv="${pub%.pub}"
		if [[ -e "$pub" && -e "$priv" ]]; then
			ssh+=( -i "$priv" )
		fi
	done

	# TODO: escape properly
	echo "${ssh[*]}"
}


#
# variables
#

NOW="$(date -Iseconds)"
NOW_EPOCH="$(epoch "$NOW")"

OPERATION="${BASH_SOURCE[1]##*/}"
