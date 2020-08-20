#!/bin/bash
for pid in $(pidof -x "startup.sh")
do
    if [ $pid != $$ ] 
    then
        kill $pid
    fi 
done
# block direct file transfer/preview through usb
chmod 700 /media
# if/then -> something to be done only at first run
# else -> something to be done only at rerun
# outside -> shared

sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1
sysctl -w net.ipv4.conf.all.send_redirects=0



iptables -t nat -A OUTPUT -p tcp -m owner ! --uid-owner root --dport 80 -j REDIRECT --to-port 8080
iptables -t nat -A OUTPUT -p tcp -m owner ! --uid-owner root --dport 443 -j REDIRECT --to-port 8080
ip6tables -t nat -A OUTPUT -p tcp -m owner ! --uid-owner root --dport 80 -j REDIRECT --to-port 8080
ip6tables -t nat -A OUTPUT -p tcp -m owner ! --uid-owner root --dport 443 -j REDIRECT --to-port 8080


iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8080
ip6tables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
ip6tables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8080

iptables -A OUTPUT -p udp -m owner ! --uid-owner root --dport 80 -j DROP
iptables -A OUTPUT -p udp -m owner ! --uid-owner root --dport 443 -j DROP
ip6tables -A OUTPUT -p udp -m owner ! --uid-owner root --dport 80 -j DROP
ip6tables -A OUTPUT -p udp -m owner ! --uid-owner root --dport 443 -j DROP

iptables -A FORWARD -p udp --dport 80 -j DROP
iptables -A FORWARD -p udp --dport 443 -j DROP
ip6tables -A FORWARD -p udp --dport 80 -j DROP
ip6tables -A FORWARD -p udp --dport 443 -j DROP

# why apt is blocked
# https://superuser.com/questions/1351606/iptables-trying-to-understand-rule-giving-access-to-synaptic?rq=1
# block ssh
iptables -A OUTPUT -p tcp -m owner ! --uid-owner root --dport 22 -j DROP
ip6tables -A OUTPUT -p tcp -m owner ! --uid-owner root --dport 22 -j DROP

# block google cloud request (from chromium)
iptables -A OUTPUT -p tcp -m owner ! --uid-owner root --dport 5228 -j DROP
ip6tables -A OUTPUT -p tcp -m owner ! --uid-owner root --dport 5228 -j DROP

iptables -A OUTPUT -p udp -m owner ! --uid-owner root --dport 5228 -j DROP
ip6tables -A OUTPUT -p udp -m owner ! --uid-owner root --dport 5228 -j DROP
# block vnc default port
iptables -A OUTPUT -p tcp -m owner ! --uid-owner root --dport 5900 -j DROP
ip6tables -A OUTPUT -p tcp -m owner ! --uid-owner root --dport 5900 -j DROP

# ensure only one instance
pkill mitmdump
# run mitmproxy on startup
mitmdump --mode transparent --set block_global=false --set stream_large_bodies=1 --set ssl_insecure=true --set stream_websockets=true -s /temp/mitmproxy_config.py -q & 


# for debug purpose, use the following instead
# mitmdump --mode transparent --set block_global=false --set stream_large_bodies=1 --set stream_websockets=true -s /home/k5shao/Desktop/mitmproxy_config.py -q & 
