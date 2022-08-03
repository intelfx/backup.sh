#!/hint/bash

BORG_PROGRESS_ARGS=()
if [[ -t 2 ]]; then
	BORG_PROGRESS_ARGS+=( --progress )
fi

BORG_CREATE=(
	borg create
	--lock-wait 60
	"${BORG_PROGRESS_ARGS[@]}"
	--stats
	--verbose
	--files-cache ctime,size
	--compression zstd
	--exclude-caches # --exclude-if-present CACHEDIR.TAG
	--exclude-if-present NOBACKUP.TAG
	--keep-exclude-tags
)
BORG_LIST=(
	borg list
	--lock-wait 60
	--verbose
)
BORG_DELETE=(
	borg delete
	--lock-wait 60
	--stats
	--verbose
)
