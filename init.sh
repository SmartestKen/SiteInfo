#!/bin/bash

# assume /home/public/temp as the src location

# root_setup -> download git repo directly to /temp
# https://unix.stackexchange.com/questions/272197/why-cant-mv-deal-with-existence-of-same-name-directory-in-destination
# https://unix.stackexchange.com/questions/24395/rewrite-existing-file-so-that-it-gets-replaced-by!=w-version-atomically-only-o
# https://serverfault.com/questions/676221/is-mv-with-wildcard-still-atomic/676231
updateLoop() {
    
    # assume a full executable copy at /temp (and git already setup)
    # assume nothing about /tempCopy
    rm -rf /temp/siteFilter.txt
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
    
    rm -rf /tempCopy/.stage
    mkdir /tempCopy/.stage
    rm -rf /tempCopy/.trash
    mkdir /tempCopy/.trash
    
    
    
    # initialization for planner
    check_pt=-1

    
    # initialization for dequeue/repo modification
    last_check_date=-1
    
    
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
                    mv /tempCopy/.stage/ /tempCopy/$cur_time
                    mkdir /tempCopy/.stage/
                fi
                    
                folder_stat=$folder_new_stat    
            fi  
            

            # any internal manipulation within those files/folders that are rm -rf at the beginning 
            # do not need to check validty
            # dequeue/modification part
            # end_of_date used for planner, but added here since only need to update daily
            if [[ $cur_date != $last_check_date ]]
            then
                threshold_pt=`date +%s --date="$cur_date 8:00"`
                before_threshold_allow_time=`date +%s --date="$cur_date-1day 00:00"`
                after_threshold_allow_time=`date +%s --date="$cur_date 00:00"`
                end_of_date=`date +%s --date="$cur_date+1day 00:00"`
                last_check_date=$cur_date
            fi
            
            if [[ $cur_time -ge $threshold_pt ]]
            then
                allow_time=$after_threshold_allow_time
            else
                allow_time=$before_threshold_allow_time
            fi
            # test mode
            # allow_time=$((cur_time-20))
                
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
            
                # sorted time, so no need to check if bigger than most_uptodate_dir
                if [ $time -le $allow_time ]
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
                    echo "-----------------------------"
                    while read -r line
                    do
                        case $line in @*)
                            if [[ $cur_session_name != '' ]]
                            then
                                echo "name is $cur_session_name"
                                printf "%s" "$content" > /temp/sessions/$cur_session_name
                                content=''
                            fi
                    
                            read -ra tokens <<<$line
                            # 1->day 2->start 3->end 4->if exp
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
                                    cur_session_name=-1
                                    continue
                                fi                                    
                                

 
                                
                                if [[ ${tokens[3]} != "24:00" ]]
                                then
                                    end=`date +%s --date="+${day_diff}day ${tokens[3]}"`
                                    if [[ $? != 0 ]]
                                    then
                                        cur_session_name=-1
                                        continue
                                    fi
                                else
                                    end=`date +%s --date="+$((day_diff+1))day 00:00"`
                                fi
            
                                echo "start $start end $end"
                                # validity confirmed
                                if [[ ${tokens[4]} = "exp" ]]
                                then
                                    cur_session_name="${start}_${end}_${tokens[1]}_${tokens[2]}_${tokens[3]}_exp"
                                else
                                    cur_session_name="${start}_${end}_${tokens[1]}_${tokens[2]}_${tokens[3]}"
                                fi
                                continue
                                
                            else
                                cur_session_name=-1
                                continue
                            fi
                        esac

                        # normal content line
                        if [[ $cur_session_name != '' ]]
                        then
                            content=$content$'\n'"$line"
                        fi
                    done < "/tempCopy/$most_uptodate_dir/session.txt"
                    
                    if [[ $cur_session_name != '' ]]
                    then
                        echo "$cur_session_name"
                        printf "%s" "$content" > /temp/sessions/$cur_session_name
                    fi
                    echo "-----------------------------"
                    mv /tempCopy/$most_uptodate_dir/session.txt /tempCopy/.trash/
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
                    rm -f /home/public/temp_remove/$session
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
                
                if [[ $is_outdated = 1 ]]
                then
                    IFS='_' read -ra tokens <<<$session
                    # ensure that cur_time -lt end
                    if [[ ${tokens[1]} -le $cur_time ]]
                    then
                        increment=$(((cur_time-tokens[1])/604800+1))
                        end=$((tokens[1]+increment*604800))
                        start=$((tokens[0]+increment*604800))
                        mv /temp/sessions/$session /temp/sessions/${start}_${end}_${tokens[2]}_${tokens[3]}_${tokens[4]}_${tokens[5]}
                    fi
                else
                    is_outdated=0
                fi
            done
            if [[ -f /home/public/temp_remove/default.txt ]]
            then
                echo "I remove default"
                >/tempCopy/.trash/default.txt
                mv /tempCopy/.trash/default.txt /temp/
                rm -f /home/public/temp_remove/default.txt
                if [[ $active_session = 'default' ]]
                then
                    check_pt=-1
                fi
            fi
                    
            
            
            
            
            
            # minimal amount of 86400 such that the end exceed the current time, add the same amount to start
            
            # then the first item always the right thing to load or to set the next check_pt (as all end now have to be bigger than cur_time) (i.e. first start is always a good start)
            # only load per day, for the unloaded, load today and see
            # remove * * cur_day,,,(i.e. do not match the epoch)
            if [[ $cur_time -ge $check_pt ]]
            then
                is_loaded=0
                experimental_flag=0
                check_pt=$end_of_date
                
                for session in /temp/sessions/*
                do
                    session="${session##*/}"
                    # Setting IFS on the same line as the read with no semicolon or other separator, as opposed to in # a separate command, scopes it to that command
                    IFS='_' read -ra tokens <<<$session

                    # end is now always -lt cur_time, only need to check whether start -le cur_time
                    if [[ $cur_time -ge ${tokens[0]} ]]
                    then
                        if [[ ${tokens[5]} = "exp" ]]
                        then
                            exp_new_stat=`stat -c %Y /home/public/temp/siteFilter.txt 2>/dev/null`
                            if [[ $? = 0 ]] && cp /home/public/temp/siteFilter.txt /tempCopy/.trash/
                            then
                                exp_stat=$exp_new_stat
                            else
                                >/tempCopy/.trash/siteFilter.txt  
                                exp_stat=-1
                            fi
                            mv /tempCopy/.trash/siteFilter.txt /temp/
                            experimental_flag=1
                            echo "experimental loaded"
                        else
                            cp /temp/sessions/$session /temp/siteFilter.txt
                            
                        fi
                        
                        touch /temp/mitmproxy_config.py
                        is_loaded=1
                        check_pt=${tokens[1]}
                        echo "I load this $session, check_pt is $check_pt"
                        active_session=$session
                        break
                    else
                        check_pt=${tokens[0]}
                        break
                    fi
                done
                
                if [[ $is_loaded = 0 ]]
                then
                    cp /temp/default.txt /temp/siteFilter.txt
                    touch /temp/mitmproxy_config.py
                    echo "I load default, check_pt is $check_pt"
                    active_session='default'
                fi
            elif [[ $experimental_flag = 1 ]] 
            then
                exp_new_stat=`stat -c %Y /home/public/temp/siteFilter.txt 2>/dev/null`
                # only expression can be inside double bracket, command has to be outside
                if [[ $? = 0 && $exp_stat != $exp_new_stat ]] && cp /home/public/temp/siteFilter.txt /tempCopy/.trash/
                then
                    # a correct version of siteFilter already loaded at beginning of session
                    # so no need to make an empty file again
                    mv /tempCopy/.trash/siteFilter.txt /temp/
                    touch /temp/mitmproxy_config.py
                    echo "I load experimental again"
                    exp_stat=$exp_new_stat
                    
                fi
            fi
      
            sleep 30
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
