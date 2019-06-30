#!/bin/bash
# Copyright (c) 2018-2019, Joe Jocobs.
# All rights reserved. Licensed under a 3-clause BSD License.

# BEGIN CONFIG
borg_dir="/etc/borg"
borg_version="1.1.10"
borg_repo="/root/backup/borg"
borg_script_file="/root/borg-backup.sh"
borg_i386_url="https://github.com/borgbackup/borg/releases/download/$borg_version/borg-linux32"
borg_amd64_url="https://github.com/borgbackup/borg/releases/download/$borg_version/borg-linux64"
borg_aarch64_url="https://dl.bintray.com/borg-binary-builder/borg-binaries/borg-$borg_version-arm64"
borg_script_url="https://gist.githubusercontent.com/joejacobs/1cb08a5d1a925874e709a77cf9e33900/raw/borg-backup.sh"

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
read -p "Enter new username: " username
user_dir="/home/$username"

if [ -d $user_dir ]; then
    echo "User $username already exists"
else
    adduser $username
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
borg_bin="$borg_dir/borg-$borg_version"
arch="$(uname -m)"

if [ $arch == 'aarch64' ]; then
    borg_url="$borg_aarch64_url"
elif [ $arch == 'x86_64' ] || [ $arch == 'amd64' ]; then
    borg_url="$borg_amd64_url"
else
    borg_url="$borg_i386_url"
fi

mkdir -p $borg_dir

if [ ! -f $borg_bin ]; then
    curl -L -o $borg_bin $borg_url
fi

chmod +x $borg_bin

if [ -f /usr/bin/borg ]; then
    rm /usr/bin/borg
fi

ln -s $borg_bin /usr/bin/borg

echo ""
echo "12. Creating .vimrc files"
root_vimrc="/root/.vimrc"
user_vimrc="$user_dir/.vimrc"

if [ ! -f $root_vimrc ]; then
    echo -e $vimrc_contents > $root_vimrc
fi

if [ ! -f $user_vimrc ]; then
    echo -e $vimrc_contents > $user_vimrc
    chown $username:$username $user_vimrc
fi

echo ""
echo "13. Set vim as selected editor"
root_selected_editor="/root/.selected_editor"
user_selected_editor="$user_dir/.selected_editor"

if [ ! -f $root_selected_editor ]; then
    echo 'SELECTED_EDITOR="/usr/bin/vim"' > $root_selected_editor
fi

if [ ! -f $user_selected_editor ]; then
    echo 'SELECTED_EDITOR="/usr/bin/vim"' > $user_selected_editor
    chown $username:$username $user_selected_editor
fi

echo ""
echo "14. Creating 2GB blank file"
if [ -f $blank_file ]; then
    echo "2GB blank file already exists at $blank_file"
else
    fallocate -l 2G $blank_file
fi

echo ""
echo "15. Initialising borg repo"

if [ -f "$borg_repo/config" ] && [ -d "$borg_repo/data" ]; then
    echo "borg repo already initialised at $borg_repo"
else
    read -s -p "Enter borg passphrase: " borg_passphrase
    echo ""
    read -s -p "Re-enter borg passphrase: " confirm_passphrase
    echo ""

    if [ $borg_passphrase != $confirm_passphrase ]; then
        echo 'Passphrases do not match'
        exit 2
    fi

    export BORG_PASSPHRASE=$borg_passphrase
    borg init -e repokey-blake2 --make-parent-dirs $borg_repo
    borg key export $borg_repo /root/borg.key
fi

if [ ! -f $borg_script_file ]; then
    if [ -z $borg_passphrase ]; then
        read -s -p "Enter borg passphrase: " borg_passphrase
        echo ""
        read -s -p "Re-enter borg passphrase: " confirm_passphrase
        echo ""

        if [ $borg_passphrase != $confirm_passphrase ]; then
            echo 'Passphrases do not match'
            exit 2
        fi
    fi

    curl -L -o $borg_script_file $borg_script_url
    sed -i -e "s/{borg-repo-here}/${borg_repo//\//\\\/}/g" $borg_script_file
    sed -i -e "s/{borg-passphrase-here}/${borg_passphrase//\//\\\/}/g" $borg_script_file
fi

chmod u+x $borg_script_file

echo ""
echo "16. Add hourly borg cron job"

if [ ! -f /var/spool/cron/crontabs/root ]; then
    touch /var/spool/cron/crontabs/root
fi

cron=$(crontab -l)

if [[ $cron != *"$borg_script_file"* ]]; then
    crontab -l | { cat; echo "0 * * * * $borg_script_file"; } | crontab -
fi
