#!/hint/bash

(( $# == 0 )) || die "cfg_prune_btrfs.sh: extra arguments ($*): not expecting anything"

local config="$configdir/cfg_btrfs.sh"
PRUNE_LIST=( btrfs_list.sh $config )
PRUNE_DELETE=( btrfs_delete.sh $config )

load_config "$configdir/cfg_rules_common.sh"
PRUNE_RULES=( "${RULES_SHORTTERM[@]}" )
