#!/bin/bash

# run as root, assume standard user k5shao
# echo "root:123" | sudo chpasswd
# use apt list --installed | grep "name" to see if removal can be done


# 2 actions (hide menus + password) to grub2 will make it secure. optionally hidden timeout = 0 to avoid popup

# -------- browser, redshift, git and dns server

wget -O /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" > /etc/apt/sources.list.d/brave-browser-release.list

apt update -y 

apt install -y brave-browser redshift git



apt install -y --no-install-recommends resolvconf

echo "
# Cloudflare/Google DNS server
nameserver 1.1.1.1
nameserver 2606:4700:4700::1111
nameserver 8.8.8.8
nameserver 2001:4860:4860::8888
" > /etc/resolvconf/resolv.conf.d/head

resolvconf -u


# ---------- grub and init.sh (and ensure ethernet on startup)

# https://superuser.com/questions/126795/how-to-start-networking-on-a-wired-interface-before-logon-in-ubuntu-desktop-edit
ename=`ls /sys/class/net | grep ^e`
echo "
auto $ename
iface $ename inet dhcp" >> /etc/network/interfaces


wget https://raw.githubusercontent.com/SmartestKen/public/master/init.sh  -O /init.sh -q
chmod 744 /init.sh

echo '
[Unit]
After=network.target
After=network-online.target
[Service]
Type=forking
ExecStart=/init.sh
[Install]
WantedBy=multi-user.target' > /etc/systemd/system/init.service

systemctl enable init



# secure grub
# https://askubuntu.com/questions/656951/how-to-prevent-changes-in-the-grub-menu
read -p "add --unrestricted at the end of '--class gnu-linux --class gnu --class os' in /etc/grub.d/10_linux"
read -p "append the following (!! including cat) to /etc/grub.d/00_header with random password
cat << EOF
set superusers='root'
password root randompassword
export superusers
EOF"
chmod 711 /etc/grub.d/00_header
update-grub

#---------------removal (leave prohibit to k5shao_setup)

# fonts-noto-cjk 
apt purge -y fonts-droid-fallback vlc* okular* firefox* packagekit* kdeconnect* gwenview* k3b* muon* kwallet* libpam-kwallet* skanlite* kcalc* partitionmanager* plasma-vault* kubuntu-notification-helper* whoopsie* bluez* plasma-discover*


apt autoremove -y
apt autoclean -y
apt clean -y


#--------------- blocking starts
usermod -p '!' root
deluser k5shao sudo
read -p "ready to reboot"
reboot
