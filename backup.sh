#!/bin/bash -e

. lib.sh || exit

cd "${BASH_SOURCE%/*}"

log "Snapshotting btrfs"
./backup_schedule.sh cfg_schedule_btrfs.sh

log "Pushing btrfs snapshots to borg"
./backup_consume.sh cfg_consume_btrfs_borg_system.sh

log "Cleaning up"
./backup_prune.sh cfg_prune_borg_system.sh
./backup_prune.sh cfg_prune_btrfs.sh
