#!/hint/bash

# this configuration accepts different arguments for different operations
(( $# <= 1 )) || die "bad arguments($*): expecting nothing or <snapshot id>"

local config="$configdir/cfg_borg_system.sh"
SCHEDULE_LIST=( borg_list.sh "$config" )
SCHEDULE_CREATE=( borg_create.sh "$config" "$@" )

load_config "$configdir/cfg_rules_common.sh"
SCHEDULE_RULES=( "${RULES_SCHEDULE[@]}" )
