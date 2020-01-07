#!/hint/bash

(( $# == 1 )) || die "cfg_borg_system.sh: bad arguments($*): expecting <source snapshot name>"
BORG_SNAPSHOT_NAME="$1"

BORG_CREATE=(
	borg create
	--progress
	--stats
	--files-cache ctime,size
	--compression zstd
	--exclude-caches
	--patterns-from "$configdir/cfg_borg_system_patterns.txt"
	--keep-exclude-tags
)
BORG_REPO="operator@intelfx.name:/mnt/data/Backups/Hosts/$(hostname)/borg"

# The directory where the archive source will be mounted at
# This must be stable because borg caches absolute pathes
BORG_MOUNT_DIR="/tmp/borg"
BORG_MOUNT_CMD=( btrfs_mount.sh "$configdir/cfg_btrfs.sh" )

borg_snapshot_name() {
	echo "$BORG_SNAPSHOT_NAME"
}
borg_snapshot_tag() {
	local name="$1"
	echo "$(hostname)-${name}"
}
export BORG_PASSCOMMAND="unsudo pass misc/borg"
