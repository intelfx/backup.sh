#!/hint/bash

RULES=(
	"keep_minutely every=15 count=1 minutes=$(( 4*60 ))" # 4 hours
	"keep_hourly count=1 hours=24"
	"keep_daily count=1 days=7"
	"keep_weekly count=1 weeks=4"
	"keep_monthly count=1 months=12"
	"keep_yearly count=1 years=10"
	delete=1
)
