#!/hint/bash

(( $# == 0 )) || die "cfg_btrfs.sh: extra arguments ($*): not expecting anything"

btrfs_snapshot_name() {
	date -Iseconds
}
btrfs_snapshot_path() {
	local tag="$1"
	echo "snapshots/$tag"
}

FILESYSTEM="/"
# FIXME: only one entry possible
SUBVOLUMES_INCLUDE=(
	/arch
)
SUBVOLUMES_EXCLUDE=(
	/arch/home/intelfx/.local/share/containers
	/arch/var/lib/machines
)
