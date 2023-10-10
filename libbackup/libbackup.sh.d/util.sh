#!/hint/bash

BSH_SKIP_RC=43

function make_ssh_cmd() {
	local dir="$1"
	local ssh=(
		ssh
		-o BatchMode=yes
		-o IdentitiesOnly=yes
		-o IdentityAgent=none
		-o StrictHostKeyChecking=accept-new
		-o UserKnownHostsFile="$dir/known_hosts"
	)

	local pub priv
	for pub in "$dir"/id_*.pub; do
		priv="${pub%.pub}"
		if [[ -e "$pub" && -e "$priv" ]]; then
			ssh+=( -i "$priv" )
		fi
	done

	echo "${ssh[@]@Q}"
}
