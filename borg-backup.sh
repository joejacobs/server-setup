#!/bin/bash
#
# Copyright (c) 2019, Joe Jacobs
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of the copyright holder nor the names of its
#       contributors may be used to endorse or promote products derived from
#       this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
    --compression lz4               \
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