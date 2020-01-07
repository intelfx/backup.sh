#!/bin/bash -e

. ${BASH_SOURCE%/*}/backup_lib.sh || exit

#
# config
#

TARGET_DIR="$1"

log "Cleaning up snapshot tree under '$TARGET_DIR'"
if ! [[ -d "$TARGET_DIR" ]]; then
	die "Bad target directory to unmount: '$TARGET_DIR'"
fi

< <(</proc/self/mountinfo awk "{ print \$5 }" | grep -E "^$TARGET_DIR(/|$)" | sort -r) readarray -t MOUNTPOINTS

for m in "${MOUNTPOINTS[@]}"; do
	log "Unmounting '$m'"
	umount -l "$m"
done

TARGET_FILE="$(find "$TARGET_DIR" -type f -print -quit)"
if [[ "$TARGET_FILE" ]]; then
	err "Files are left in '$TARGET_DIR' after unmounting -- aborting"
	exit 1
fi
log "Removing '$TARGET_DIR'"
rm -vr "$TARGET_DIR"
