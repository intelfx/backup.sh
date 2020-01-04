#!/hint/bash

NEW_SNAPSHOT_TAG="$(date -Iseconds)"
SNAPSHOT_PATH="snapshots/$SNAPSHOT_TAG"

FILESYSTEM="/"
# FIXME: only one entry possible
SUBVOLUMES_INCLUDE=(
	/arch
)
SUBVOLUMES_EXCLUDE=(
	/arch/home/intelfx/.local/share/containers/storage/btrfs
	/arch/var/lib/machines
)
