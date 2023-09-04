#!/bin/bash

# load lib.sh

source "${BASH_SOURCE%/*}/../lib/lib.sh" || return

# load libbackup

__libbackup="${BASH_SOURCE}.d"
if ! [[ -d "$__libbackup" ]]; then
	echo "libbackup.sh: libbackup.sh.d does not exist!" >&2
	return 1
fi
source "$__libbackup/init.sh" || return
for __libbackup_file in "$__libbackup"/*.sh; do
	if [[ "$__libbackup_file" != "$__libbackup/init.sh" ]]; then
		source "$__libbackup_file" || return
	fi
done
unset __libbackup __libbackup_file
