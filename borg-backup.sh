#!/bin/bash
# Copyright (c) 2018-2019, Joe Jocobs.
# All rights reserved. Licensed under a 3-clause BSD License.
#
# Based on: https://borgbackup.readthedocs.io/en/stable/quickstart.html#automating-backups

log_dir="/var/log/borg"
log_file="$log_dir/$(date -Iseconds).log"
err_log_file=${log_file/.log/"-ERROR.log"}
warn_log_file=${log_file/.log/"-WARNING.log"}

# some helpers and error handling:
info() { echo -e "\n$( date -Iseconds ) $*\n\n" >> $log_file; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

# ensure logdir exists
if [ ! -d $log_dir ]; then
    mkdir $log_dir
fi

# ensure logfile exists (it shouldn't)
if [ ! -f $log_file ]; then
    touch $log_file
fi

# load conf
borg_conf="$(dirname $0)/borg.conf"
info "Loading conf: $borg_conf"
source "$borg_conf" >> $log_file 2>&1
source_exit=$?

if [ $source_exit -ne 0]; then
    info "conf loading failed: $source_exit"
    mv "$log_file" $"err_log_file"
    exit 2
fi

# ensure borg repo as been initialised
if [ ! -f "$BORG_REPO/config" ] || [ ! -d "$BORG_REPO/data" ]; then
    info "borg repo not found in $BORG_REPO"
    mv "$log_file" "$err_log_file"
    exit 2
fi

# backup /etc, /home, /root and /var
info "Starting backup"

borg create                             \
    --verbose                           \
    --filter AME                        \
    --list                              \
    --stats                             \
    --show-rc                           \
    --compression lzma                  \
    --exclude-caches                    \
    --exclude '/home/*/.cache/*'        \
    --exclude '/root/backup/*'          \
    --exclude 're:^/var/cache/(?!bind)' \
    --exclude '/var/tmp/*'              \
                                        \
    ::'{hostname}-{now}'                \
    /etc                                \
    /home                               \
    /root                               \
    /var                                \
    >> $log_file 2>&1

backup_exit=$?

# use the `prune` subcommand to maintain 4-hourly backups for a month (30 days),
# daily backups for a year (365 days), weekly backups for 2.5 years (130 weeks)
# and monthly backups for 5 years (60 months).
info "Pruning repository"

borg prune                          \
    --list                          \
    --prefix '{hostname}-'          \
    --show-rc                       \
    --keep-within   30d             \
    --keep-daily    365             \
    --keep-weekly   130             \
    --keep-monthly  60              \
    >> $log_file 2>&1

prune_exit=$?

# upload backups to b2
info "Uploading backup to b2"

PATH="$HOME/.local/bin:$PATH" b2 sync \
    --replaceNewer                    \
    "$LOCAL_BACKUP_PATH/"             \
    "$B2_BACKUP_PATH/"                \
    >> $log_file 2>&1

b2_sync_exit=$?

# echo info messages of backup and prune exit status
if [ $backup_exit -eq 0 ]; then
    info "Backup completed successfully"
elif [ $backup_exit -eq 1 ]; then
    info "Backup completed with warnings"
else
    info "Backup completed with errors"
fi

if [ $prune_exit -eq 0 ]; then
    info "Prune completed successfully"
elif [ $prune_exit -eq 1 ]; then
    info "Prune completed with warnings"
else
    info "Prune completed with errors"
fi

if [ $b2_sync_exit -eq 0 ]; then
    info "b2 sync completed successfully"
else
    info "b2 sync completed with warnings/errors"
fi

# use highest exit code as global exit code
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))
global_exit=$(( b2_sync_exit > global_exit ? b2_sync_exit : global_exit ))

# rename log file if there are errors or warnings
if [ $global_exit -eq 1 ]; then
    mv "$log_file" "$warn_log_file"
elif [ $global_exit -ne 0 ]; then
    mv "$log_file" "$err_log_file"
fi

exit $global_exit
