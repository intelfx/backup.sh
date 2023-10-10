#!/hint/bash

#
# options
#

_usage() {
	cat <<EOF
$_usage_common_syntax unmount <TARGET-DIR>
$_usage_common_options
EOF
}

__verb_expect_args 1
TARGET_DIR="${VERB_ARGS[0]}"


#
# main
#

log "cleaning up mountpoint tree under '$TARGET_DIR'"
if ! [[ -d "$TARGET_DIR" ]]; then
	die "bad target directory to unmount: '$TARGET_DIR'"
fi

</proc/self/mountinfo awk "{ print \$5 }" \
| ( grep -E "^$TARGET_DIR(/|$)" || true ) \
| sort -r \
| readarray -t MOUNTPOINTS

for m in "${MOUNTPOINTS[@]}"; do
	log "unmounting '$m'"
	umount -l "$m"
done

TARGET_FILE="$(find "$TARGET_DIR" -type f -print -quit)"
if [[ "$TARGET_FILE" ]]; then
	die "files are left in '$TARGET_DIR' after unmounting -- aborting"
fi

log "removing '$TARGET_DIR'"
rm -r "$TARGET_DIR"
