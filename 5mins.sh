#!/bin/bash
#
# Copyright (c) 2018-2019, Joe Jacobs
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
borg_dir="/etc/borg"
borg_version="1.1.10"
borg_i386_url="https://github.com/borgbackup/borg/releases/download/${borg_version}/borg-linux32"
borg_amd64_url="https://github.com/borgbackup/borg/releases/download/${borg_version}/borg-linux64"
borg_aarch64_url="https://dl.bintray.com/borg-binary-builder/borg-binaries/borg-${borg_version}-arm64"

blank_file="/root/2GB.blank"

vimrc_contents="filetype plugin on
\nfiletype plugin indent on
\nsyntax on
\n
\nset smartindent
\nset tabstop=4
\nset shiftwidth=4
\nset expandtab
\nset linespace=7
\n
\nhi ColorColumn ctermbg=lightgrey guibg=lightgrey
\nlet &colorcolumn=join(range(81,90),\",\")
\nset number
\nset ruler"
# END CONFIG

echo "1. Change root password"
passwd

echo ""
echo "2. Update and upgrade"
apt-get update
apt-get upgrade -y

echo ""
echo "3. Install fail2ban"
apt-get install -y fail2ban

echo ""
echo "4. Create new default user"
echo -n "Enter new username: "
read username
user_dir="/home/${username}"

if [ -d ${user_dir} ]; then
    echo "User ${username} already exists"
else
    adduser ${username}
fi

echo ""
echo "5. Lock down SSH"
sed -i -e 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
service ssh restart

echo ""
echo "6. Set up firewall"
apt-get install -y ufw
ufw allow 22
ufw enable

echo ""
echo "7. Set timezone"
dpkg-reconfigure tzdata

echo ""
echo "8. Install rsync"
apt-get install -y rsync

echo ""
echo "9. Install htop"
apt-get install -y htop

echo ""
echo "10. Install vim"
apt-get install -y vim

echo ""
echo "11. Install borg"
borg_bin="${borg_dir}/borg-${borg_version}"
arch=`uname -m`

if [ ${arch} == 'aarch64' ]; then
    borg_url=${borg_aarch64_url}
elif [ ${arch} == 'x86_64' ] || [ ${arch} == 'amd64' ]; then
    borg_url=${borg_amd64_url}
else
    borg_url=${borg_i386_url}
fi

mkdir -p ${borg_dir}

if [ ! -f ${borg_bin} ]; then
    curl -L -o ${borg_bin} ${borg_url}
fi

chmod +x ${borg_bin}

if [ -f /usr/bin/borg ]; then
    rm /usr/bin/borg
fi

ln -s ${borg_bin} /usr/bin/borg

echo ""
echo "12. Creating .vimrc files"
root_vimrc="/root/.vimrc"
user_vimrc="${user_dir}/.vimrc"

if [ ! -f ${root_vimrc} ]; then
    echo -e ${vimrc_contents} > ${root_vimrc}
fi

if [ ! -f ${user_vimrc} ]; then
    echo -e ${vimrc_contents} > ${user_vimrc}
    chown ${username}:${username} ${user_vimrc}
fi

echo ""
echo "13. Set vim as selected editor"
root_selected_editor="/root/.selected_editor"
user_selected_editor="${user_dir}/.selected_editor"

if [ ! -f ${root_selected_editor} ]; then
    echo 'SELECTED_EDITOR="/usr/bin/vim"' > ${root_selected_editor}
fi

if [ ! -f ${user_selected_editor} ]; then
    echo 'SELECTED_EDITOR="/usr/bin/vim"' > ${user_selected_editor}
    chown ${username}:${username} ${user_selected_editor}
fi

echo ""
echo "14. Creating 2GB blank file"
if [ ! -f ${blank_file} ]; then
    fallocate -l 2G ${blank_file}
fi