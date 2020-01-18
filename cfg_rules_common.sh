#!/hint/bash

RULES_LONGTERM=(
	"keep_minutely every=15 count=1 minutes=$(( 8*60 ))" # 8 hours
	"keep_hourly count=1 hours=24"
	"keep_daily count=1 days=7"
	"keep_weekly count=1 weeks=4"
	"keep_monthly count=1 months=12"
	"keep_yearly count=1 years=10"
	delete=1
)

# TODO: implement and utilize "consumed" rules to fast-track removal of snapshots
#       that were pushed to longterm storage, while retaining those snapshots
#       that were not (for some reason).
RULES_SHORTTERM=(
	"keep_minutely every=15 count=1 minutes=$(( 8*60 ))" # 8 hours
	"keep_hourly count=1 hours=24"
	"keep_daily count=1 days=7"
	delete=1
)

# basically you only need the most relaxed rule that applies to the most recent backups here
RULES_SCHEDULE=(
	"keep_minutely every=15 count=1 minutes=$(( 8*60 ))" # 8 hours
	delete=1
)
