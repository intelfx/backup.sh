#!/hint/bash

(( $# == 0 )) || die "cfg_btrfs.sh: extra arguments ($*): not expecting anything"

btrfs_snapshot_id() {
	echo "$NOW"
}
btrfs_snapshot_path() {
	local id="$1"
	echo "snapshots/$id"
}

BTRFS_SUBVOLUME_SNAPSHOT=(
	btrfs sub snap -r
)
BTRFS_SUBVOLUME_DELETE=(
	btrfs sub del --verbose --commit-after
)
BTRFS_SUBVOLUME_FIND=(
	btrfs-sub-find --find
)
BTRFS_SUBVOLUME_FIND_PHYSICAL=(
	btrfs-sub-find --physical
)

FILESYSTEM="/"
# FIXME: only one entry possible
SUBVOLUMES_INCLUDE=(
	/arch
)
SUBVOLUMES_EXCLUDE=(
	/arch/home/intelfx/.local/share/containers
	/arch/var/lib/machines
)
