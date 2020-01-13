#!/hint/bash

(( $# == 0 )) || die "cfg_prune_btrfs.sh: extra arguments ($*): not expecting anything"

local config="$configdir/cfg_btrfs.sh"

PRUNE_LIST=( btrfs_list.sh $config )
PRUNE_DELETE=( btrfs_delete.sh $config )

PRUNE_RULES=(
	"keep_recent min_age=$(( 4*3600 ))" # 4 hours
	"keep_hourly count=1 hours=24"
	"keep_daily count=1 days=7"
	"keep_weekly count=1 weeks=4"
	"keep_monthly count=1 months=12"
	"keep_yearly count=1 years=10"
	delete=1
)
