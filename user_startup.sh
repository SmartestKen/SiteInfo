#!/bin/bash
 
 
# https://superuser.com/questions/586077/how-to-run-a-script-at-boot-time-for-normal-user
# https://askubuntu.com/questions/24916/how-do-i-remap-certain-keys-or-devices
# use xev for keycode/target info
# 135 "context button" is also a option
xmodmap -e "keycode 9 = Prior"
xmodmap -e "keycode 180 = Next"


# remember to adjust brightness
# xgamma -gamma 0.9
redshift -O 3200K
pkill kate
pkill nomacs
