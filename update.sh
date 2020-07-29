#!/bin/bash


#-----------------make sure usb cleaned----------------

read -p "lsblk; dd if=/dev/zero of=/dev/sdX bs=1K count=2048, then press enter" 


#----------------configure/upload files----------------

sed -i '/chpasswd/d' /temp/init.sh
chmod 744 /temp/init.sh
sed -i '/chpasswd/d' /temp/startup.sh
chmod 744 /temp/startup.sh
chmod 744 /temp/sync.sh
chmod 744 /temp/enforceTimer.sh
chmod 744 /temp/recover.sh
chmod 744 /temp/update.sh


eval $(ssh-agent -s)
ssh-add /temp/.ssh/id_rsa
cd /temp
git add --ignore-errors /temp/
git commit -m "from update.sh" -q
# commits from init service only
git push -f origin master -q


# enable service
systemctl enable mitmproxy.service




# uninstall virtualbox (if exists)
apt-get -qq purge -y virtualbox* >/dev/null



# remove all trash (to prevent some root owned files)
rm -rf /home/k5shao/.local/share/Trash/files/
# remove pre-stage files
su k5shao -c "
mv /home/public/temp/siteFilter.txt /home/public/temp_remove/
rm -rf /home/public/temp/
mkdir /home/public/temp/
mv /home/public/temp_remove/siteFilter.txt /home/public/temp/
rm -rf /home/public/temp_remove/
mkdir /home/public/temp_remove/"

# clear stage files
rm -rf /tempCopy/
mkdir /tempCopy 
apt-get -qq autoremove -y >/dev/null
apt-get -qq autoclean -y >/dev/null


# k5shao startup script
su k5shao -c "
cp /temp/user_startup.sh /home/k5shao/.config/autostart-scripts/user_startup.sh
chmod 744 /home/k5shao/.config/autostart-scripts/user_startup.sh"



# restore
usermod -p '!' root
deluser k5shao sudo



# reboot
if [ "${1:-None}" != "test" ]
then
    reboot
fi


