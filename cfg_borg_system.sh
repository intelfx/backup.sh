#!/hint/bash

# this configuration accepts different arguments for different operations
case "$OPERATION" in
borg_create.sh)
	(( $# == 1 )) || die "cfg_borg_system.sh: bad arguments($*): expecting <snapshot id>"
	BORG_SNAPSHOT_ID="$1"
	borg_snapshot_id() {
		echo "$BORG_SNAPSHOT_ID"
	}
	;;
*)
	(( $# == 0 )) || die "cfg_borg_system.sh: extra arguments($*): not expecting anything"
	;;
esac

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
BORG_LIST=(
	borg list
)
BORG_DELETE=(
	borg delete
	--stats
	--verbose
)
BORG_REPO="operator@intelfx.name:/mnt/data/Backups/Hosts/$(hostname)/borg"

# The directory where the archive source will be mounted at
# This must be stable because borg caches absolute pathes
BORG_MOUNT_DIR="/tmp/borg"
BORG_MOUNT_CMD=( btrfs_mount.sh "$configdir/cfg_btrfs.sh" )

borg_snapshot_tag() {
	local id="$1"
	echo "$(hostname)-${id}"
}
export BORG_PASSCOMMAND="unsudo pass misc/borg"
