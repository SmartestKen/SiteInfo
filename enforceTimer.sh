#!/bin/bash

# everything small but require frequent check (like font)

sdLoop() {
    while true
    do
        if ! pgrep "cdTimer.sh" >/dev/null
        then
            # pkill ignore -, so use chromium rather than chromium-browser
            pkill chromium
        fi
        
        rm -rf /home/k5shao/.fonts
        sleep 10
    done    
}


for pid in $(pidof -x "enforceTimer.sh")
do
    if [ $pid != $$ ] 
    then
        kill $pid
    fi 
done
sdLoop &
