#!/hint/bash

(( $# == 0 )) || die "cfg_schedule_btrfs.sh: extra arguments ($*): not expecting anything"

local config="$configdir/cfg_btrfs.sh"
SCHEDULE_LIST=( btrfs_list.sh $config )
SCHEDULE_CREATE=( btrfs_create.sh $config )

load_config "$configdir/cfg_rules_common.sh"
SCHEDULE_RULES=( "${RULES[@]}" )
