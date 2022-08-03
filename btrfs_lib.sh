#!/hint/bash

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
