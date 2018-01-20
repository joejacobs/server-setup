#/bin/bash

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
adduser $username

echo ""
echo "5. Lock down SSH."
sed -i -e 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
service ssh restart

echo ""
echo "6. Set up firewall."
apt-get install -y ufw
ufw allow 22
ufw enable