#!/hint/bash

(( $# == 0 )) || die "extra arguments ($*): not expecting anything"

local config="$configdir/cfg_borg_system.sh"
PRUNE_LIST=( borg_list.sh $config )
PRUNE_DELETE=( borg_delete.sh $config )

load_config "$configdir/cfg_rules_common.sh"
PRUNE_RULES=( "${RULES_LONGTERM[@]}" )
