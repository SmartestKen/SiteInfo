#!/bin/bash

# assume /home/public/temp as the src location

# root_setup -> download git repo directly to /temp
# https://unix.stackexchange.com/questions/272197/why-cant-mv-deal-with-existence-of-same-name-directory-in-destination
# https://unix.stackexchange.com/questions/24395/rewrite-existing-file-so-that-it-gets-replaced-by!=w-version-atomically-only-o
# https://serverfault.com/questions/676221/is-mv-with-wildcard-still-atomic/676231
updateLoop() {
    
    # assume a full executable copy at /temp (and git already setup)
    # assume nothing about /tempCopy
    rm -f /temp/siteFilter.txt
    # startup need to use siteFilter for mitm init
    >/temp/siteFilter.txt
    /temp/startup.sh 
    /temp/sync.sh
    /temp/enforceTimer.sh
    
    # for github upload
    cd /temp/
    eval $(ssh-agent -s)    
    ssh-add /temp/.ssh/id_rsa
    
    shopt -s nullglob
    is_correct_time=0

    # initialization for enqueue
    # dequeue set to only update the lastest, hence any enqueue will copy everything
    collection=("init.sh" "mitmproxy_config.py" "default.txt" "session.txt" "startup.sh" "sync.sh" "enforceTimer.sh" "recover.sh" "update.sh" "github_instruction.sh" "user_startup.sh")
    folder_stat=-1
    last_check_date=-1
    
    rm -rf /tempCopy/.stage
    mkdir /tempCopy/.stage
    rm -rf /tempCopy/.trash
    mkdir /tempCopy/.trash
    
    
    
    # initialization for planner
    check_pt=-1

    
    while true
    do
        # avoid bios time hack
        if [[ $is_correct_time = 0 ]]
        then
            internet_time=`wget -qSO- --max-redirect=0 google.com 2>&1`
            if [[ $? = 8 ]]
            then
                date -s "$(grep Date: <<< "$internet_time" | cut -d' ' -f5-8)Z" >/dev/null
                is_correct_time=1
            # retry 10 seconds later
            else
                sleep 10
            fi                

            
        else

            time=(`date +"%s %w %m/%d/%Y"`)
            cur_time=${time[0]}
            cur_day=${time[1]}
            cur_date=${time[2]}
            
      
      
      
            # enqueue part


            
            
            
            folder_new_stat=`stat -c %Y /home/public/temp/`  
            # i.e. always add at the startup
            if [[ $? = 0  &&  $folder_new_stat != $folder_stat ]]
            then
            
                for file in "${collection[@]}"
                do
                    if [[ -f "/home/public/temp/$file" ]]
                    then
                        # if fail to copy (including not a regular file), stop and remove file
                        if ! cp "/home/public/temp/$file" /tempCopy/.stage/
                        then
                            echo "fail to copy $file at `date`" >>/tempCopy/log.txt
                            mv "/tempCopy/.stage/$file" /tempCopy/.trash/
                            continue
                        fi
                        # copy to stage succeed, make .sh executable
                        if [[ "${file#*.}" = "sh" ]]
                        then
                            chmod 744 "/tempCopy/.stage/$file"
                        fi
                    fi
                done

                if [[ "$(ls -A /tempCopy/.stage/)" ]]
                then
                    # any internal manipulation within those files/folders that are rm -rf at the beginning 
                    # do not need to check validty
                    # dequeue/modification part
                    if [[ $cur_date != $last_check_date ]]
                    then
                        allow_time=`date +%s --date="$cur_date+2day 8:00"`
                        last_check_date=$cur_date
                    fi
                    # test mode
                    allow_time=`date +%s --date="10:00"`
                    
                    # at beginning, allow_time folder may already exist from previous run. Hence 
                    # cannot combine two if (without adding code complexity)
                    if [[ -d /tempCopy/$allow_time ]]
                    then
                        mv /tempCopy/.stage/* /tempCopy/$allow_time/
                    else
                        mv /tempCopy/.stage/ /tempCopy/$allow_time
                        mkdir /tempCopy/.stage/
                    fi
                fi
                    
                folder_stat=$folder_new_stat    
            fi  
            


            


                
            # have to loop every time for removing purpose, cannot use checkpoint
            most_uptodate_dir=-1
            # assume nullglob
            for time in /tempCopy/*/
            do
                # string trim syntax ##,#,%%,% (remove the last slash, then everything 
                # till the second to last slash)
                # https://aty.sdsu.edu/bibliog/latex/debian/bash.html
                time="${time%/}"
                time="${time##*/}"
                
                # put same folder in /home/public/temp_remove
                # will activate the option to remove from the queue
                # the same directory will never be created again, so no need to care about thing in temp_remove
                if [ -d "/home/public/temp_remove/$time" ]
                then
                    mv /tempCopy/$time /tempCopy/.trash/
                    continue
                fi
            
                if [ $time -le $cur_time ]
                then
                    mv /tempCopy/$most_uptodate_dir/ /tempCopy/.trash/
                    most_uptodate_dir=$time   
                fi
            done
            
            
            if [ $most_uptodate_dir != -1 ]
            then

                # flags
                if [ -f /tempCopy/$most_uptodate_dir/session.txt ]
                then
                    # removal requires item wise
                    # for manual replacement, remove planner item, add planner item, remove siteFilter.txt
                    # if break before the third stage, always encounter remove again
                    # if after, then everything still works, hence the entire logic is safe
                    rm -rf /tempCopy/.trash/sessions
                    mv /temp/sessions /tempCopy/.trash/
                    mkdir /temp/sessions
                    cur_session_name=''
                    content=''
                    declare -a refs
                    isrefsession=0
                    echo "-----------------------------"
                    while read -r line
                    do
                        case $line in @*)
                            if [[ $cur_session_name != '' ]]
                            then
                                echo "name is $cur_session_name"
                                echo "$content"
                                if [[ $isrefsession = 1 ]]
                                then
                                    refs[${tokens[4]}]=$content
                                    isrefsession=0
                                fi
                                printf "%s" "$content" >/tempCopy/.trash/temp_session
                                mv /tempCopy/.trash/temp_session /temp/sessions/$cur_session_name
                            fi
                            content=''
                            read -ra tokens <<<$line
                            # 1->day 2->start 3->end
                            # basic validity check
                            if [[ "${tokens[1]}" =~ ^[0-6]$ && "${tokens[2]}" =~ ^[0-2]?[0-9]:[0-5][0-9]$ && "${tokens[3]}" =~ ^[0-2]?[0-9]:[0-5][0-9]$ ]]
                            then
                                if [[ ${tokens[1]} -ge $cur_day ]]
                                then
                                    day_diff=$((tokens[1]-cur_day))
                                else
                                    day_diff=$((tokens[1]+7-cur_day))
                                fi
                            
                                start=`date +%s --date="+${day_diff}day ${tokens[2]}"`
                                if [[ $? != 0 ]]
                                then
                                    cur_session_name=''
                                    continue
                                fi                                    
                                

 
                                
                                if [[ ${tokens[3]} != "24:00" ]]
                                then
                                    end=`date +%s --date="+${day_diff}day ${tokens[3]}"`
                                    if [[ $? != 0 ]]
                                    then
                                        cur_session_name=''
                                        continue
                                    fi
                                else
                                    end=`date +%s --date="+$((day_diff+1))day 00:00"`
                                fi
            
                                echo "start $start end $end"
                                # validity confirmed
                                cur_session_name="${start}_${end}_${tokens[1]}_${tokens[2]}_${tokens[3]}"
                                if [[ ${tokens[4]} =~ ^ref[0-9]$ ]]
                                then
                                    if [[ -v refs[${tokens[4]}] ]]
                                    then
                                        # ref token already set
                                        echo "name is $cur_session_name with ${tokens[4]}"
                                        printf "%s" "${refs[${tokens[4]}]}" >/tempCopy/.trash/temp_session
                                        mv /tempCopy/.trash/temp_session /temp/sessions/$cur_session_name
                                        cur_session_name=''
                                    else
                                        # new ref session
                                        isrefsession=1
                                    fi
                                fi
                                
                                continue
                                
                            else
                                cur_session_name=''
                                continue
                            fi
                        esac

                        # normal content line
                        if [[ $cur_session_name != '' ]]
                        then
                            content=$content$'\n'"$line"
                        fi
                    done < "/tempCopy/$most_uptodate_dir/session.txt"
                    
                    
                    echo "ref1 
                            ${refs[ref1]}"
                    echo "ref2
                            ${refs[ref2]}"
                    if [[ $cur_session_name != '' ]]
                    then
                        # if self is the first ref, then no one needs that. else already dealt at reading the session, hence no need to consider isrefsession here
                        echo "name is $cur_session_name"
                        printf "%s" "$content" >/tempCopy/.trash/temp_session
                        mv /tempCopy/.trash/temp_session /temp/sessions/$cur_session_name
                    fi
                    echo "-----------------------------"
                    mv /tempCopy/$most_uptodate_dir/session.txt /tempCopy/.trash/
                    check_pt=-1
                fi
                
                if [[ $check_pt != -1 && -f /tempCopy/$most_uptodate_dir/default.txt ]]
                then
                    check_pt=-1
                fi
                    
                    
                [[ -f /tempCopy/$most_uptodate_dir/sync.sh ]]
                sync_flag=$?
                [[ -f /tempCopy/$most_uptodate_dir/enforceTimer.sh ]]
                enforceTimer_flag=$?
                
                if [[ "$(ls -A /tempCopy/$most_uptodate_dir/)" ]]
                then
                    mv /tempCopy/$most_uptodate_dir/* /temp/
                fi
                # remove after update
                mv /tempCopy/$most_uptodate_dir /tempCopy/.trash/
                
                # execute new ones, no need to reset the flags
                # as they will be auto reset
                if [ $sync_flag = 0 ]
                then
                    /temp/sync.sh
                    # sync.sh will kill the ssh-agent, hence need to restart
                    eval $(ssh-agent -s)    
                    ssh-add /temp/.ssh/id_rsa
                fi
                
                if [ $enforceTimer_flag = 0 ]
                then
                    /temp/enforceTimer.sh 
                fi
                
                
                git add --ignore-errors /temp/
                git commit -m "$most_uptodate_dir" -q >/dev/null
                # commits from init service only
                git push -f origin master -q
                echo "last updated at `date`" >>/tempCopy/log.txt
            fi

            
            
            # planner part
            # assume same day, no overlap (otherwise unexpected behavior), not necessarily sorted
            # assume 0-6.tt and default.txt exist in /temp
            # end_of_date always valid as the first branch will be triggered at boot
            # first line will always be the first session (or empty), so no need to init is_removing
            
            # [ ) can only active when start -le cur && cur -lt end
            is_outdated=1
            for session in /temp/sessions/*
            do
                session="${session##*/}"
                # same name comparison is sufficient, if jump in, then no changes should happen to fiel name, if jump out, then not active anyway
                if [[ -f /home/public/temp_remove/$session ]]
                then
                    echo "I remove $session"
                    mv /temp/sessions/$session /tempCopy/.trash/
                    # active_session auto initialize to '', so no need to init at beginning
                    # given any active_session, first branch first -> removal still currently active
                    # second branch first -> expired -> active session name will be renewed in
                    # next section (so no bug)
                    if [[ $session = $active_session ]]
                    then
                        check_pt=-1
                    fi
                    continue
                fi

                

                # assume no sessio overlap, otherwise may miss
                if [[ $is_outdated = 1 ]]
                then
                    IFS='_' read -ra tokens <<<$session
                    # ensure that cur_time -lt end
                    if [[ $cur_time -ge ${tokens[1]} ]]
                    then
                        increment=$(((cur_time-tokens[1])/604800+1))
                        end=$((tokens[1]+increment*604800))
                        start=$((tokens[0]+increment*604800))
                        mv /temp/sessions/$session /temp/sessions/${start}_${end}_${tokens[2]}_${tokens[3]}_${tokens[4]}
                        echo "from ${tokens[0]}_${tokens[1]} to ${start}_${end}"
                    else
                        is_outdated=0
                    fi
                fi

                
            done
            if [[ -f /home/public/temp_remove/default.txt ]]
            then
                echo "I remove default"
                >/tempCopy/.trash/default.txt
                mv /tempCopy/.trash/default.txt /temp/default.txt
                # other sessions have absolute file name and hence no need to remove
                rm -f /home/public/temp_remove/default.txt
                if [[ $active_session = 'default' ]]
                then
                    check_pt=-1
                fi
            fi
                    
            
            # then the first item always the right thing to load or to set the next check_pt (as all end now have to be bigger than cur_time) (i.e. first start is always a good start)
            # only load per day, for the unloaded, load today and see
            # remove * * cur_day,,,(i.e. do not match the epoch)
            if [[ $cur_time -ge $check_pt ]]
            then
                is_loaded=0
                # if no session, no need to check again till reset to -1 (i.e. new update comes)
                check_pt=9999999999
                
                for session in /temp/sessions/*
                do
                    session="${session##*/}"
                    # Setting IFS on the same line as the read with no semicolon or other separator, as opposed to in # a separate command, scopes it to that command
                    IFS='_' read -ra tokens <<<$session

                    # end is now always -lt cur_time, only need to check whether start -le cur_time
                    if [[ $cur_time -ge ${tokens[0]} ]]
                    then
                        cat /temp/default.txt /temp/sessions/$session >/temp/siteFilter.txt
                        touch /temp/mitmproxy_config.py
                        check_pt=${tokens[1]}
                        echo "I load $session, check_pt is $check_pt"
                        active_session=$session
                        is_loaded=1
                        break
                    else
                        check_pt=${tokens[0]}
                        break
                    fi
                done
                
                # put it here in case no sessions
                if [[ $is_loaded = 0 ]]
                then
                    cp /temp/default.txt /temp/siteFilter.txt
                    touch /temp/mitmproxy_config.py
                    echo "I load default, check_pt is $check_pt"
                    active_session='default'
                fi
            fi
      
            sleep 20
        fi
    done
}                


for pid in $(pidof -x "init.sh")
do
    if [ $pid != $$ ] 
    then
        kill $pid
    fi 
done

pkill ssh-agent
updateLoop &
