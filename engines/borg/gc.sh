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

config_get_job "$JOB_NAME" BORG_REPO
config_get_job_f "$JOB_NAME" borg_snapshot_tag borg_exports
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

for s in "${SNAPSHOT_TAGS[@]}"; do
	dbg "will delete archive '$s'"
done

if (( ${#SNAPSHOT_TAGS[@]} )); then
	"${BORG_DELETE[@]}" \
		"$BORG_REPO" \
		"${SNAPSHOT_TAGS[@]}"
else
	log "no archives to delete"
fi
