#!/hint/bash

export PATH="$JOB_VERB_DIR/_lib/btrfs-tools:$PATH"

BTRFS_SUBVOLUME_SNAPSHOT=(
	btrfs subvolume snapshot -r
)
BTRFS_SUBVOLUME_DELETE=(
	btrfs subvolume delete --verbose --commit-after
)
BTRFS_SUBVOLUME_FIND=(
	btrfs-sub-find --find
)
BTRFS_SUBVOLUME_FIND_PHYSICAL=(
	btrfs-sub-find --physical
)

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
		cur="$(dn "$cur")"
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

btrfs_setup_signals() {
	sigterm() {
		log "Signal received, ignoring"
	}
	trap sigterm TERM INT HUP
}

# $1: mount directory variable name (output)
# $2: btrfs filesystem path
btrfs_setup_from_path() {
	declare -n mount_dir="$1"
	local btrfs_path="$2"

	mount_dir="$(mktemp -d)"
	cleanup_add "rm -df '$mount_dir'"

	btrfs_remount_id5_to "$btrfs_path" "$mount_dir"
	cleanup_add "umount -l '$mount_dir'"
}
