#!/hint/bash

(( $# == 0 )) || die "cfg_consume_btrfs_borg_system.sh: extra arguments ($*): not expecting anything"

PRODUCER_PRUNE_CONFIG="$configdir/cfg_btrfs_prune.sh"
CONSUMER_SCHEDULE_CONFIG="$configdir/cfg_borg_system_schedule.sh"
CONSUMER_PRUNE_CONFIG="$configdir/cfg_borg_system_prune.sh"

PRODUCER_PRUNE_EARLY=0
PRODUCER_PRUNE_LATE=0
