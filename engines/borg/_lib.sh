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
	"${BORG_PROGRESS_ARGS[@]}"
	--stats
	--verbose
)


borg_setup() {
	# HACK: check if `borg --show-rc` is supported
	if "${BORG_CREATE[@]:0:1}" --help |& grep -q -- '--lock-rc'; then
		BORG_LOCK_RC="$BSH_SKIP_RC"
		BORG_CREATE=(
			"${BORG_CREATE[@]:0:2}"
			--lock-rc "$BORG_LOCK_RC"
			"${BORG_CREATE[@]:2}"
		)
		BORG_LIST=(
			"${BORG_LIST[@]:0:2}"
			--lock-rc "$BORG_LOCK_RC"
			"${BORG_LIST[@]:2}"
		)
		BORG_DELETE=(
			"${BORG_DELETE[@]:0:2}"
			--lock-rc "$BORG_LOCK_RC"
			"${BORG_DELETE[@]:2}"
		)
	else
		unset BORG_LOCK_RC
	fi
}
