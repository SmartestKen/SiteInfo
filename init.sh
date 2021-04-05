#!/bin/bash 


timerLoop() {

    internet_time=`wget -qSO- --max-redirect=0 google.com 2>&1`
    if [[ $? = 8 ]]
    then
        date -s "$(grep Date: <<< "$internet_time" | cut -d' ' -f5-8)Z" >/dev/null
    else
        date -s "21:00" >/dev/null
    fi  


    while true
    do
        cur_time=`date +"%H:%M"`
        if [[ $cur_time < "07:31" || $cur_time > "20:59" ]]
        then
            shutdown -h now
        fi
        sleep 10
    done

}



for pid in $(pidof -x "init.sh")
do
    if [ $pid != $$ ] 
    then
        kill $pid
    fi 
done

timerLoop &
