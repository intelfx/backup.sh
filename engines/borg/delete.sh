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

config_get_job "$JOB_NAME" \
	--rename REPO BORG_REPO \
	--rename --function snapshot_tag borg_snapshot_tag \
	--rename --function exports borg_exports \

borg_exports


#
# main
#

borg_setup

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
	"${SNAPSHOT_TAGS[@]}" \
	&& rc=0 || rc=$?

if (( $rc == 0 )); then
	:
elif (( $rc == 1 )); then
	warn "warnings when deleting archives (rc=$rc), ignoring"
else
	err "errors when deleting archives (rc=$rc)"
	exit $rc
fi
