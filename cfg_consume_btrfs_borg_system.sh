#!/hint/bash

(( $# == 0 )) || die "cfg_consume_btrfs_borg_system.sh: extra arguments ($*): not expecting anything"

local config="$configdir/cfg_btrfs.sh"
PRODUCER_LIST=( btrfs_list.sh "$config" )
#PRODUCER_PRUNE=( btrfs_prune.sh "$config" )
local config="$configdir/cfg_borg_system.sh"
CONSUMER_LIST=( borg_list.sh "$config" )
CONSUMER_CREATE=( borg_create.sh "$config" )

CONSUMER_SCHEDULE_CONFIG="$configdir/cfg_schedule_borg_system.sh"
CONSUMER_PRUNE_CONFIG="$configdir/cfg_prune_borg_system.sh"
