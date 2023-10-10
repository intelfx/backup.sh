#!/hint/bash

#
# options
#

_usage() {
	cat <<EOF
$_usage_common_syntax gc <JOB>
$_usage_common_options
EOF
}

__verb_expect_args 1

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

log "garbage collecting obsolete archives (checkpoints) from Borg repository '$BORG_REPO'"

# *.recreate, *.checkpoint, *.checkpoint.N or any combination
GARBAGE_REGEX='(?!$)(\.recreate)?(\.checkpoint(\.[0-9]+)?)?$'
# same as above
SNAPSHOT_TAG_GLOB="$(borg_snapshot_tag "*").*"

"${BORG_LIST[@]}" \
	--glob-archives "$SNAPSHOT_TAG_GLOB" \
	--format '{barchive}{NUL}' \
	--consider-checkpoints \
	"$BORG_REPO" \
| ( grep -z -P "$GARBAGE_REGEX" || true ) \
| readarray -d '' -t SNAPSHOT_TAGS

if ! (( ${#SNAPSHOT_IDS[@]} )); then
	log "no archives to delete"
	exit 0
fi

for s in "${SNAPSHOT_TAGS[@]}"; do
	log "will delete archive '$s'"
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
