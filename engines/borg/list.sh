#!/hint/bash

#
# options
#

_usage() {
	cat <<EOF
$_usage_common_syntax list <JOB>
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

# *.recreate, *.checkpoint, *.checkpoint.N or any combination
GARBAGE_REGEX='(?!$)(\.recreate)?(\.checkpoint(\.[0-9]+)?)?$'
# if the '*' ends up in the trailing position, we will inadvertently match garbage along actual archives
SNAPSHOT_TAG_GLOB="$(borg_snapshot_tag "*")"
SNAPSHOT_ID_REGEX="^$(borg_snapshot_tag "(.*)")$"

log "listing snapshots matching '$SNAPSHOT_TAG_GLOB' in Borg repository '$BORG_REPO'"
"${BORG_LIST[@]}" \
	--glob-archives "$SNAPSHOT_TAG_GLOB" \
	--format '{barchive}{NUL}' \
	"$BORG_REPO" \
| ( grep -z -vP "$GARBAGE_REGEX" || true ) \
| readarray -d '' -t SNAPSHOT_TAGS

print_array "${SNAPSHOT_TAGS[@]}" \
| sed -nr "s|$SNAPSHOT_ID_REGEX|\\1|p" \
| readarray -t SNAPSHOT_IDS

print_array "${SNAPSHOT_IDS[@]}"
