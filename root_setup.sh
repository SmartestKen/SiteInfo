#!/bin/bash


# run as root, assume standard user k5shao

#---------------update/remove---------------

apt-get -qq update

# disable file indexer
# https://wiki.archlinux.org/index.php/Baloo
# https://askubuntu.com/questions/294736/run-a-shell-script-as-another-user-that-has-no-password
su k5shao -c "
balooctl suspend
balooctl disable"


apt-get -qq purge -y fonts-noto-cjk fonts-droid-fallback vlc okular firefox packagekit kdeconnect gwenview k3b muon kwalletmanager skanlite kcalc partitionmanager plasma-vault kubuntu-notification-helper whoopsie >/dev/null
 
rm -rf /home/k5shao/.mozilla/

su k5shao -c "
echo '[Wallet]
Enabled=false' > /home/k5shao/.config/kwalletrc

echo '[Wallet]
Enabled=false' > /home/k5shao/.kde/share/config/kwalletrc"

chmod 744 /usr/bin/fc-cache


#---------------dns server adjustment---------------


apt-get -qq install -y --no-install-recommends resolvconf >/dev/null
echo "
# Cloudflare/Google DNS server
nameserver 1.1.1.1
nameserver 2606:4700:4700::1111
nameserver 8.8.8.8
nameserver 2001:4860:4860::8888
" >> /etc/resolvconf/resolv.conf.d/head
service resolvconf restart







# need a browser to upload ssh keys
apt-get -qq install -y --no-install-recommends chromium-browser >/dev/null

rm -rf /temp /tempCopy
mkdir /temp /tempCopy
apt-get -qq install -y git >/dev/null
# nothing/--local add it to .git folder of the repository
# --global add for user (in $HOME)
# --system add in /etc/gitconfig
git config --system user.email 'k5shao@ucsd.edu'
git config --system user.name 'SmartestKen'

rm -rf /temp/.ssh
mkdir /temp/.ssh
ssh-keygen -t rsa -b 4096 -f /temp/.ssh/id_rsa
eval "$(ssh-agent)"
ssh-add /temp/.ssh/id_rsa

read -p "cat /temp/.ssh/id_rsa.pub and paste output into github.com/settings/keys, then press enter" 




#----------------------------setup init.sh----------------------------
cd /temp
git init
git remote add origin git@github.com:SmartestKen/SiteInfo.git
git fetch --all
git reset --hard origin/master
git rm -r --cached /temp -q
chmod 744 /temp/init.sh
chmod 744 /temp/startup.sh
chmod 744 /temp/sync.sh
chmod 744 /temp/enforceTimer.sh
chmod 744 /temp/recover.sh
chmod 744 /temp/update.sh

echo '
[Unit]
After=network.target
After=network-online.target
[Service]
Type=forking
ExecStart=/temp/init.sh
Restart=on-failure
RestartSec=10
[Install]
WantedBy=multi-user.target' > /etc/systemd/system/mitmproxy.service

systemctl enable mitmproxy




#----------------------------setup mitmproxy----------------------------
# python3-pip unusable without recommends
apt-get -qq install -y python3-pip >/dev/null
pip3 -qq install mitmproxy 



# use chrome to obtain mitm http certificates
source /temp/startup.sh
sleep 5
while [ ! -f /home/k5shao/Downloads/mitmproxy-ca-cert.pem ]
do
    su k5shao -c "chromium-browser 'http://mitm.it/cert/pem' &"
    sleep 10
    su k5shao -c "pkill chromium-browser*"
done
source /temp/recover.sh
# need for chrome to avoid privacy error
# download it from mitm.it
openssl x509 -in /home/k5shao/Downloads/mitmproxy-ca-cert.pem -inform PEM -out /home/k5shao/mitmproxy-ca-cert.crt

# for systemwide certificate
cp /home/k5shao/mitmproxy-ca-cert.crt /usr/local/share/ca-certificates/mitmproxy-ca-cert.crt
update-ca-certificates --fresh >/dev/null

# need to run google chrome once to create .pki
apt-get -qq install -y --no-install-recommends libnss3-tools >/dev/null
su k5shao -c "certutil -d sql:/home/k5shao/.pki/nssdb -A -t 'CP,CP,' -n mitmproxy -i /home/k5shao/mitmproxy-ca-cert.crt"




#----------------------------setup sync.sh----------------------------
rm -rf /home/public
mkdir /home/public
rm -rf /home/private
mkdir /home/private

chmod 1777 /home/public
chmod 1777 /home/private


cd /home/public
touch /home/public/.gitignore
git init
git remote add origin git@github.com:SmartestKen/public.git
git fetch --all
git reset --hard origin/master
git rm -r --cached /home/public/ -q
shopt -s dotglob
chown -R k5shao:k5shao /home/public/*
shopt -u dotglob
chown -R root:root /home/public/.git
chown root:root /home/public/.gitignore



cd /home/private
touch /home/private/.gitignore
git init
git remote add origin git@github.com:SmartestKen/private.git
git fetch --all
git reset --hard origin/master
git rm -r --cached /home/private -q
shopt -s dotglob
chown -R k5shao:k5shao /home/private/*
shopt -u dotglob
chown -R root:root /home/private/.git
chown root:root /home/private/.gitignore



#---------------other installation---------------


# k5shao startup script
su k5shao -c "
cp /temp/user_startup.sh /home/k5shao/.config/autostart-scripts/user_startup.sh
chmod 744 /home/k5shao/.config/autostart-scripts/user_startup.sh"


# use this if virtualbox
# apt-get -qq purge -y unattended-upgrades >/dev/null


# Iphone connection (libimobiledevice-utils ifuse)
# unrar needed by ark
apt-get -qq install -y --no-install-recommends libimobiledevice-utils ifuse unrar ocrmypdf pinta >/dev/null
apt-get -qq install -y nomacs redshift >/dev/null


apt-get -qq autoremove -y >/dev/null
