#!/bin/bash
# Copyright (c) 2018-2019, Joe Jocobs.
# All rights reserved. Licensed under a 3-clause BSD License.

# BEGIN CONFIG
local_backup_path="/root/backup"

borg_dir="/etc/borg"
borg_version="1.1.10"
borg_repo="$local_backup_path/borg"
borg_i386_url="https://github.com/borgbackup/borg/releases/download/$borg_version/borg-linux32"
borg_amd64_url="https://github.com/borgbackup/borg/releases/download/$borg_version/borg-linux64"
borg_aarch64_url="https://dl.bintray.com/borg-binary-builder/borg-binaries/borg-$borg_version-arm64"

blank_file_size=2147483648
blank_file="/root/2GB.blank"
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
echo "8. Install curl"
apt-get install -y curl

echo ""
echo "9. Install rsync"
apt-get install -y rsync

echo ""
echo "10. Install htop"
apt-get install -y htop

echo ""
echo "11. Install vim"
apt-get install -y vim

echo ""
echo "12. Install borg"
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
echo "13. Install pip"
apt-get install -y python-pip

echo ""
echo "14. Install b2 command line tool"
read -s -p "Enter b2 appKeyID: " b2_app_key_id
echo ""
read -s -p "Enter b2 appKey: " b2_app_key
echo ""
apt-get install -y python-setuptools
pip install --upgrade --user b2
PATH="$HOME/.local/bin:$PATH" b2 authorize-account $b2_app_key_id $b2_app_key

echo ""
echo "15. Creating .vimrc files"
vimrc="$PWD/vimrc"
root_vimrc="/root/.vimrc"
user_vimrc="$user_dir/.vimrc"

if [ ! -f $root_vimrc ]; then
    cp "$vimrc" "$root_vimrc"
fi

if [ ! -f $user_vimrc ]; then
    cp "$vimrc" "$user_vimrc"
    chown $username:$username $user_vimrc
fi

echo ""
echo "16. Set vim as selected editor"
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
echo "17. Creating 2GB blank file"
make_blank_file=1

if [ -f $blank_file ]; then
    actual_file_size=$(wc -c < $blank_file)

    if [ $actual_file_size -ge $blank_file_size ]; then
        echo "2GB blank file already exists at $blank_file"
        make_blank_file=0
    else
        rm $blank_file
    fi
fi

if [ $make_blank_file -eq 1 ]; then
    fallocate -l $blank_file_size $blank_file
fi

echo ""
echo "18. Initialising borg repo"

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

echo ""
echo "19. Add hourly borg cron job"
borg_conf="$PWD/borg.conf"
borg_script="$PWD/borg-backup.sh"
borg_example_conf="$PWD/borg.example.conf"
chmod u+x "$borg_script"

if [ ! -f "$borg_conf" ]; then
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

    read -p "Enter b2 bucket backup path: b2://" b2_backup_path
    echo ""

    cp "$borg_example_conf" "$borg_conf"
    sed -i -e "s/{borg-repo-here}/${borg_repo//\//\\\/}/g" $borg_conf
    sed -i -e "s/{b2-backup-path-here}/${b2_backup_path//\//\\\/}/g" $borg_conf
    sed -i -e "s/{borg-passphrase-here}/${borg_passphrase//\//\\\/}/g" $borg_conf
    sed -i -e "s/{local-backup-path-here}/${local_backup_path//\//\\\/}/g" $borg_conf
    chmod u+x "$borg_conf"
fi

if [ ! -f /var/spool/cron/crontabs/root ]; then
    touch /var/spool/cron/crontabs/root
fi

cron=$(crontab -l)

if [[ $cron != *"$borg_script"* ]]; then
    crontab -l | { cat; echo "0 */4 * * * $borg_script"; } | crontab -
fi
