#!/hint/bash

#
# options
#

_usage() {
	cat <<EOF
$_usage_common_syntax delete <JOB> <ARCHIVE...>
$_usage_common_options
delete options:
	ARCHIVE...		Name(s) of the Borg archive(s) to delete
EOF
}

__verb_expect_args_ge 2
SNAPSHOT_IDS=( "${VERB_ARGS[@]:1}" )


#
# config
#

config_get_job "$JOB_NAME" BORG_REPO
config_get_job_f "$JOB_NAME" borg_snapshot_tag borg_exports
borg_exports


#
# main
#

log "deleting ${#SNAPSHOT_IDS[@]} archive(s) from Borg repository '$BORG_REPO'"

if ! (( ${#SNAPSHOT_IDS[@]} )); then
	warn "nothing to delete"
	exit 0
fi

SNAPSHOT_TAGS=()
for id in "${SNAPSHOT_IDS[@]}"; do
	tag="$(borg_snapshot_tag "$id")"
	log "deleting archive '$tag'"
	SNAPSHOT_TAGS+=( "$tag" )
done

"${BORG_DELETE[@]}" \
	"$BORG_REPO" \
	"${SNAPSHOT_TAGS[@]}"
