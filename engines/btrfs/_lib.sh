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

BTRFS_AWK_PROG='
function issubdir(rootdir, subdir) {
	if (rootdir == "/") {
		rootdir_t = rootdir
	} else {
		rootdir_t = rootdir "/"
	}

	if (rootdir == subdir) {
		return 1
	} else if (index(subdir, rootdir_t) == 1) {
		return 1
	} else {
		return 0
	}
}
BEGIN {
	best=0
}
issubdir($5, dirname) {
	sep=0
	for (i = 7; i <= NF; ++i) {
		if ($i == "-") {
			sep = i
			break
		}
	}
	if (sep == 0) { exit 1 }

	if (length($5) >= best) {
		best=length($5)
		mountpoint=$5
		fstype=$(sep+1)
		device=$(sep+2)
		options=$(sep+3)
	}
}
END {
	if (best > 0) {
		print "mountpoint=\"" mountpoint "\""
		print "fstype=\"" fstype "\""
		print "device=\"" device "\""
		print "options=\"" options "\""
		exit 0
	} else {
		exit 1
	}
}
'
btrfs_remount_id5_to() {
	local src="$1"
	local targetdir="$2"

	if ! [[ -e "$src" ]]; then
		err "btrfs_remount_id5_to: src does not exist: '$src'"
		return 1
	fi

	local vars mountpoint fstype device options
	if vars="$(awk -v "dirname=$src" "$BTRFS_AWK_PROG" /proc/self/mountinfo)"; then
		eval "$vars"
	fi

	if ! [[ "$fstype" && "$device" ]]; then
		err "btrfs_remount_id5_to: could not find a mountpoint for '$src'"
		return 1
	fi
	dbg "btrfs_remount_id5_to: found mountpoint for '$src': mountpoint=$mountpoint, device=$device, fstype=$fstype, options=$options"
	if [[ "$fstype" != btrfs ]]; then
		err "btrfs_remount_id5_to: src '$src' belongs to '$mountpoint' which is $fstype != btrfs"
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
		err "btrfs_remount_id5_to: could not cleanup mount options for '$mountpoint': '$options'"
		return 1
	fi

	target_options="$target_options,subvolid=5"

	dbg "btrfs_remount_id5_to: mounting root subvolume of '$device' on '$targetdir' with '$target_options'"
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
