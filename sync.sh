#!/bin/bash 


syncLoop() {
    # eval needed to initialize ssh environment
    eval $(ssh-agent -s)
    ssh-add /temp/.ssh/id_rsa
    


    while true
    do
        cd /home/public
        find -size +75M | sed 's|^\./||g' > /home/public/.gitignore
        
        git add -A --ignore-errors /home/public/ 
        git commit -m "from sync.sh" -q >/dev/null 
        git push -f origin master -q
        if [ $? != 0 ]
        then
            git reset --mixed HEAD~
        fi
        
        
        cd /home/private
        find -size +75M | sed 's|^\./||g' > /home/private/.gitignore

        git add --ignore-errors /home/private/
        git commit -m "from sync.sh" -q >/dev/null
        git push -f origin master -q           
        if [ $? != 0 ]
        then
            git reset --mixed HEAD~
        fi
        

        su k5shao -c "/usr/bin/python3.6 /home/public/feed.py" &

        
        sleep 300
    done

}



for pid in $(pidof -x "sync.sh")
do
    if [ $pid != $$ ] 
    then
        kill $pid
    fi 
done

pkill ssh-agent
syncLoop &
