#!/bin/bash
#
# Copyright (c) 2018-2019, Joe Jacobs
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright notice,
#       this list of conditions and the following disclaimer in the documentation
#       and/or other materials provided with the distribution.
#     * Neither the name of the copyright holder nor the names of its contributors
#       may be used to endorse or promote products derived from this software
#       without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

echo "1. Change root password."
passwd

echo ""
echo "2. Update and upgrade."
apt-get update
apt-get upgrade -y

echo ""
echo "3. Install fail2ban."
apt-get install -y fail2ban

echo ""
echo "4. Create new default user."
echo -n "Enter new username: "
read username
adduser ${username}

echo ""
echo "5. Lock down SSH."
sed -i -e 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
service ssh restart

echo ""
echo "6. Set up firewall."
apt-get install -y ufw
ufw allow 22
ufw enable

echo ""
echo "7. Set timezone."
dpkg-reconfigure tzdata

echo ""
echo "8. Install rsync."
apt-get install -y rsync

echo ""
echo "9. Install htop."
apt-get install -y htop

echo ""
echo "10. Install vim."
apt-get install -y vim

echo ""
echo "11. Creating .vimrc files"
echo "syntax on" > ~/.vimrc
echo "filetype plugin indent on" >> ~/.vimrc
echo "set expandtab" >> ~/.vimrc
echo "set shiftwidth=4" >> ~/.vimrc
echo "set softtabstop=4" >> ~/.vimrc
echo "syntax on" > /home/${username}/.vimrc
echo "filetype plugin indent on" >> /home/${username}/.vimrc
echo "set expandtab" >> /home/${username}/.vimrc
echo "set shiftwidth=4" >> /home/${username}/.vimrc
echo "set softtabstop=4" >> /home/${username}/.vimrc
chown ${username}:${username} /home/${username}/.vimrc

echo ""
echo "12. Creating 2GB blank file"
fallocate -l 2G ~/2GB.blank