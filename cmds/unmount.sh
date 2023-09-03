#!/bin/bash -e

. ${BASH_SOURCE%/*}/backup_lib.sh || exit


#
# config
#

TARGET_DIR="$1"


#
# main
#

log "cleaning up mountpoint tree under '$TARGET_DIR'"
if ! [[ -d "$TARGET_DIR" ]]; then
	die "bad target directory to unmount: '$TARGET_DIR'"
fi

</proc/self/mountinfo awk "{ print \$5 }" \
| grep -E "^$TARGET_DIR(/|$)" \
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
rm -vr "$TARGET_DIR"
