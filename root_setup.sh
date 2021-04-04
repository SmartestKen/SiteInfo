#!/bin/bash

# run as root, assume standard user k5shao

# 2 actions (hide menus + password) to grub2 will make it secure. optionally hidden timeout = 0 to avoid popup

# -------- browser, redshift, git and dns server, iphone connection

wget -O /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg

echo "deb [signed-by=/usr/sh c  are/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" > /etc/apt/sources.list.d/brave-browser-release.list

apt update

apt install brave-browser redshift git 
# Iphone connection (libimobiledevice-utils ifuse)
apt install -y --no-install-recommends libimobiledevice-utils ifuse


# TODO change it to fix the file
# https://superuser.com/questions/677343/how-to-make-name-server-address-permanent-in-etc-resolv-conf
# https://superuser.com/questions/442096/change-default-dns-server-in-arch-linux
echo "
# Cloudflare/Google DNS server
nameserver 1.1.1.1
nameserver 2606:4700:4700::1111
nameserver 8.8.8.8
nameserver 2001:4860:4860::8888
" >> /etc/resolvconf/resolv.conf.d/head


# ---------- grub and init.sh

wget https://raw.githubusercontent.com/SmartestKen/SiteInfo/master/init.sh  -O /init.sh -q
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
echo "add --unrestricted at the end of '--class gnu-linux --class gnu --class os' in /etc/grub.d/10_linux"
echo "add the following at the end of /etc/grub.d/00_header with random password
cat << EOF
set superusers='root'
password root randompassword
export superusers
EOF"
chmod 711 /etc/grub.d/00_header
update-grub

#---------------removal (leave prohibit to k5shao_setup)

# fonts-noto-cjk 
apt-get purge -y fonts-droid-fallback vlc okular firefox packagekit kdeconnect gwenview k3b muon kwalletmanager skanlite kcalc partitionmanager plasma-vault kubuntu-notification-helper whoopsie bluez* >/dev/null


# use this if virtualbox
# apt-get -qq purge -y unattended-upgrades >/dev/null


apt autoremove -y
apt autoclean -y
apt clean -y
