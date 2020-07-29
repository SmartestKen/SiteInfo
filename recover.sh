#!/bin/bash

# stop iptables rules, mitm, sync.
if [ "${1:-None}" = "all" ]
then
    pkill sync.sh
    pkill ssh-agent
    pkill enforceTimer.sh
fi

iptables -X
ip6tables -X
iptables -t nat -X
ip6tables -t nat -X
iptables -t mangle -X
ip6tables -t mangle -X
iptables -F
ip6tables -F
iptables -t nat -F
ip6tables -t nat -F
iptables -t mangle -F
ip6tables -t mangle -F

pkill init.sh
pkill startup.sh
chmod 755 /media
pkill mitmdump





