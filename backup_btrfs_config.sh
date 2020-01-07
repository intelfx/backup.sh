#!/hint/bash

btrfs_snapshot_tag() {
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
	/arch/home/intelfx/.local/share/containers/storage/btrfs
	/arch/var/lib/machines
)
