#!/hint/bash

# this configuration accepts different arguments for different operations
(( $# <= 1 )) || die "bad arguments($*): expecting nothing or <snapshot id>"

if (( $# == 1 )); then
	BORG_SNAPSHOT_ID="$1"
	borg_snapshot_id() {
		echo "$BORG_SNAPSHOT_ID"
	}
fi

BORG_CREATE=(
	borg create
	--lock-wait 60
	--progress
	--stats
	--verbose
	--files-cache ctime,size
	--compression zstd
	--exclude-caches
	--patterns-from "${BASH_SOURCE%.sh}_patterns.txt"
	--keep-exclude-tags
)
BORG_LIST=(
	borg list
	--lock-wait 60
	--verbose
)
BORG_DELETE=(
	borg delete
	--lock-wait 60
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

export BORG_PASSCOMMAND="cat /etc/backup.sh/borg_intelfx.name/pass"
export BORG_RSH="$(ssh_unattended /etc/backup.sh/borg_intelfx.name)"
