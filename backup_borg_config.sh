#!/hint/bash

BORG_CREATE=(
	borg create
	--progress
	--stats
	--files-cache ctime,size
	--compression zstd
	--exclude-caches
	--keep-exclude-tags
)
BORG_REPO="operator@intelfx.name:/mnt/data/Backups/Hosts/$(hostname)/borg"
borg_snapshot_tag() {
	local tag="$1"
	echo "$(hostname)-${tag}"
}
export BORG_PASSCOMMAND="unsudo pass misc/borg"
