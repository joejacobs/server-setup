#!/bin/bash
# Copyright (c) 2018-2019, Joe Jocobs.
# All rights reserved. Licensed under a 3-clause BSD License.
#
# Based on: https://borgbackup.readthedocs.io/en/stable/quickstart.html#automating-backups

# BEGIN CONFIG
log_dir=/var/log/borg
log_file=${log_dir}/`date -Iseconds`.log

export BORG_REPO="{borg-repo-here}"
export BORG_PASSPHRASE="{borg-passphrase-here}"
# END CONFIG

# some helpers and error handling:
info() { echo -e "\n$( date -Iseconds ) $*\n\n" >> ${log_file}; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

# ensure logdir exists
if [ ! -d ${log_dir} ]; then
    mkdir ${log_dir}
fi

# ensure logfile exists (it shouldn't)
if [ ! -f ${log_file} ]; then
    touch ${log_file}
fi

# ensure borg repo as been initialised
if [ ! -f "${BORG_REPO}/config" ] || [ ! -d "${BORG_REPO}/data" ]; then
    info "borg repo not found in ${BORG_REPO}"
    new_log_file=${log_file/.log/"-ERROR.log"}
    mv ${log_file} ${new_log_file}
    exit 2
fi

# backup /etc, /home, /root and /var
info "Starting backup"

borg create                         \
    --verbose                       \
    --filter AME                    \
    --list                          \
    --stats                         \
    --show-rc                       \
    --compression lzma              \
    --exclude-caches                \
    --exclude '/home/*/.cache/*'    \
    --exclude '/root/backup/*'      \
    --exclude '/var/cache/*'        \
    --exclude '/var/tmp/*'          \
                                    \
    ::'{hostname}-{now}'            \
    /etc                            \
    /home                           \
    /root                           \
    /var                            \
    >> ${log_file} 2>&1

backup_exit=$?

# use the `prune` subcommand to maintain 360 hourly, 365 daily, 130 weekly and
# 60 monthly archives
info "Pruning repository"

borg prune                          \
    --list                          \
    --prefix '{hostname}-'          \
    --show-rc                       \
    --keep-hourly   360             \
    --keep-daily    365             \
    --keep-weekly   130             \
    --keep-monthly  60              \
    >> ${log_file} 2>&1

prune_exit=$?

# echo info messages of backup and prune exit status
if [ ${backup_exit} -eq 0 ]; then
    info "Backup completed successfully"
elif [ ${backup_exit} -eq 1 ]; then
    info "Backup completed with warnings"
else
    info "Backup completed with errors"
fi

if [ ${prune_exit} -eq 0 ]; then
    info "Prune completed successfully"
elif [ ${prune_exit} -eq 1 ]; then
    info "Prune completed with warnings"
else
    info "Prune completed with errors"
fi

# use highest exit code as global exit code
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

# rename log file if there are errors or warnings
if [ ${global_exit} -eq 1 ]; then
    new_log_file=${log_file/.log/"-WARNING.log"}
    mv ${log_file} ${new_log_file}
elif [ ${global_exit} -ne 0 ]; then
    new_log_file=${log_file/.log/"-ERROR.log"}
    mv ${log_file} ${new_log_file}
fi

exit ${global_exit}
