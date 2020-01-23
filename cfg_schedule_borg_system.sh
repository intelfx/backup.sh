#!/hint/bash

# this configuration accepts different arguments for different operations
case "$OPERATION" in
backup_schedule.sh)
	(( $# == 1 )) || die "bad arguments($*): expecting <snapshot id>"

	local config="$configdir/cfg_borg_system.sh"
	SCHEDULE_LIST=( borg_list.sh "$config" )
	SCHEDULE_CREATE=( borg_create.sh "$config" "$1" )
	;;
*)
	(( $# == 0 )) || die "extra arguments($*): not expecting anything"
	;;
esac

load_config "$configdir/cfg_rules_common.sh"
SCHEDULE_RULES=( "${RULES_SCHEDULE[@]}" )
