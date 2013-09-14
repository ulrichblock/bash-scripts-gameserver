#!/bin/bash

if [ "${2}" == "v" ]; then
    VERBOSE=1
else
    VERBOSE=0
fi
function red_msg() {
    if [ $VERBOSE == 1 ]; then echo -e "\\033[31;1m${@}\033[0m"; fi
}
function green_msg() {
    if [ $VERBOSE == 1 ]; then echo -e "\\033[32;1m${@}\033[0m"; fi
}
function error_end() {
    VERBOSE=1
    red_msg $@
    exit 1
}

IPTABLES=$(which iptables)
if [ "${IPTABLES}" == "" ]; then error_end "Kann IPtables nicht finden"; fi

function status() {
    VERBOSE=1
    green_msg "Filter Tabelle:"
    $IPTABLES -L -vn
    green_msg "Nat Tabelle:"
    $IPTABLES -t nat -L -vn
    green_msg "Mangle Tabelle:"
    $IPTABLES -t mangle -L -vn
}

function stop_iptables() {
    green_msg "Stoppe IPTables"
    flush_iptables
    green_msg "Standard Regeln setzen"
    $IPTABLES -P INPUT ACCEPT
    $IPTABLES -P OUTPUT ACCEPT
    $IPTABLES -P FORWARD ACCEPT
}

function flush_iptables() {
    green_msg "Alles flushen"
    $IPTABLES -F
    $IPTABLES -t nat -F
    $IPTABLES -t mangle -F
    $IPTABLES -X
    $IPTABLES -t nat -X
    $IPTABLES -t mangle -X
}

function start_iptables() {
    flush_iptables

    green_msg "Log Regeln erstellen"
    $IPTABLES -N droplog
    $IPTABLES -I droplog -p TCP -j LOG -m limit --limit 20/min --log-prefix="DROP TCP-Packet: " --log-level crit
    $IPTABLES -I droplog -p UDP -j LOG -m limit --limit 20/min --log-prefix="DROP UDP-Packet: " --log-level crit
    $IPTABLES -I droplog -p ICMP -j LOG -m limit --limit 20/min --log-prefix="DROP ICMP-Packet: " --log-level crit

    green_msg "Standard Policies: Alles Droppen"
    $IPTABLES -P INPUT DROP
    $IPTABLES -P OUTPUT DROP
    $IPTABLES -P FORWARD DROP

    $IPTABLES -N DROPIPS
    $IPTABLES -A DROPIPS -j LOG -m limit --limit 1/min --log-prefix 'DROPIPS: ' --log-level 4
    $IPTABLES -A DROPIPS -j DROP

    green_msg "Vermeintlich gespoofte IPs droppen"
    $IPTABLES -A INPUT -s 10.0.0.0/8 -j DROP
    $IPTABLES -A INPUT -s 169.254.0.0/16 -j DROP
    $IPTABLES -A INPUT -s 172.16.0.0/12 -j DROP
    $IPTABLES -A INPUT -s 127.0.0.0/8 -j DROP
    $IPTABLES -A INPUT -s 224.0.0.0/4 -j DROP
    $IPTABLES -A INPUT -d 224.0.0.0/4 -j DROP
    $IPTABLES -A INPUT -s 240.0.0.0/5 -j DROP
    $IPTABLES -A INPUT -d 240.0.0.0/5 -j DROP
    $IPTABLES -A INPUT -s 0.0.0.0/8 -j DROP
    $IPTABLES -A INPUT -d 0.0.0.0/8 -j DROP
    $IPTABLES -A INPUT -d 239.255.255.0/24 -j DROP
    $IPTABLES -A INPUT -d 255.255.255.255 -j DROP

    green_msg "Korrupte Pakete droppen"
    $IPTABLES -A INPUT -m state --state INVALID -j DROP
    $IPTABLES -A OUTPUT -m state --state INVALID -j DROP

    green_msg "Pakete mit fehlerhaften Status Droppen"
    $IPTABLES -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
    $IPTABLES -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
    $IPTABLES -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
    $IPTABLES -A INPUT -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
    $IPTABLES -A INPUT -p tcp --tcp-flags ACK,FIN FIN -j DROP
    $IPTABLES -A INPUT -p tcp --tcp-flags ACK,PSH PSH -j DROP
    $IPTABLES -A INPUT -p tcp --tcp-flags ACK,URG URG -j DROP

    green_msg "Auf dem Loopback Device alles erlauben"
    $IPTABLES -A INPUT -i lo -j ACCEPT
    $IPTABLES -A OUTPUT -o lo -j ACCEPT

    green_msg "Aktivieren vom Connection Tracking"
    $IPTABLES -A OUTPUT -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
    $IPTABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT


    green_msg "Ausgehende Verbindungen erlauben"

    green_msg "ICMP aka Ping"
    $IPTABLES -I OUTPUT -o eth0 -p ICMP --icmp-type echo-reply -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
    $IPTABLES -I INPUT -i eth0 -p ICMP --icmp-type echo-reply -m state --state ESTABLISHED,RELATED -j ACCEPT

    green_msg "FTP Port 21"
    $IPTABLES -I OUTPUT -o eth0 -p TCP --sport 1024:65535 --dport 21 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
    $IPTABLES -I INPUT -i eth0 -p TCP --sport 21 --dport 1024:65535 -m state --state ESTABLISHED,RELATED -j ACCEPT

    green_msg "FTP Port 21"
    $IPTABLES -I OUTPUT -o eth0 -p TCP --sport 1024:65535 --dport 21 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
    $IPTABLES -I INPUT -i eth0 -p TCP --sport 21 --dport 1024:65535 -m state --state ESTABLISHED,RELATED -j ACCEPT
    $IPTABLES -I OUTPUT -o eth0 -p TCP --sport 49152:65535 --dport 20 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
    $IPTABLES -I INPUT -i eth0 -p TCP --sport 20 --dport 49152:65535 -m state --state ESTABLISHED,RELATED -j ACCEPT

    green_msg "SSH Port 22"
    $IPTABLES -I OUTPUT -o eth0 -p TCP --sport 1024:65535 --dport 22 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
    $IPTABLES -I INPUT -i eth0 -p TCP --sport 22 --dport 1024:65535 -m state --state ESTABLISHED,RELATED -j ACCEPT

    green_msg "HTTP Port 80"
    $IPTABLES -I OUTPUT -o eth0 -p TCP --sport 1024:65535 --dport 80 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
    $IPTABLES -I INPUT -i eth0 -p TCP --sport 80 --dport 1024:65535 -m state --state ESTABLISHED,RELATED -j ACCEPT

    green_msg "Eingehende Verbindungen erlauben"
    green_msg "FTP Port 21"
    $IPTABLES -I INPUT -i eth0 -p TCP --sport 1024:65535 --dport 21 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
    $IPTABLES -I OUTPUT -o eth0 -p TCP --sport 21 --dport 1024:65535 -m state --state ESTABLISHED,RELATED -j ACCEPT
    $IPTABLES -I INPUT -i eth0 -p TCP --sport 1024:65535 --dport 65525:65535 -m state --state NEW -j ACCEPT
    $IPTABLES -I INPUT -i eth0 -p TCP --sport 1024:65535 --dport 20 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
    $IPTABLES -I OUTPUT -o eth0 -p TCP --sport 49152:65535 --dport 1024:65535 -m state --state ESTABLISHED,RELATED -j ACCEPT
    $IPTABLES -I OUTPUT -o eth0 -p TCP --sport 20 --dport 1024:65535 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT


    green_msg "SSH Port 22"
    $IPTABLES -I INPUT -i eth0 -p TCP --sport 1024:65535 --dport 22 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
    $IPTABLES -I OUTPUT -o eth0 -p TCP --sport 22 --dport 1024:65535 -m state --state ESTABLISHED,RELATED -j ACCEPT

    green_msg "ICMP Ping"
    $IPTABLES -I INPUT -i eth0 -p ICMP --icmp-type echo-request -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
    $IPTABLES -I OUTPUT -o eth0 -p ICMP --icmp-type echo-request -m state --state ESTABLISHED,RELATED -j ACCEPT

     green_msg "Teamspeak 3"
    $IPTABLES -A INPUT -p tcp --dport 2008 -j ACCEPT
    $IPTABLES -A OUTPUT -p tcp --dport 2008 -j ACCEPT
    $IPTABLES -A OUTPUT -p udp --dport 2010 -j ACCEPT
    $IPTABLES -A INPUT -p tcp --dport 41144 -j ACCEPT
    $IPTABLES -A OUTPUT -p tcp --dport 41144 -j ACCEPT
    $IPTABLES -A INPUT -p tcp --dport 10011 -j ACCEPT
    $IPTABLES -A OUTPUT -p tcp --dport 10011 -j ACCEPT
    $IPTABLES -A INPUT -p tcp --dport 30033 -j ACCEPT
    $IPTABLES -A OUTPUT -p tcp --dport 30033 -j ACCEPT
    TSPORTS=(9987 9988 9989 9990 9991 9992 9993 9994 9995 9996)
    for PORT in ${TSPORTS[@]}; do
        green_msg "TS3: ${PORT}"
        $IPTABLES -A INPUT -p udp --dport $PORT -j ACCEPT
        $IPTABLES -A OUTPUT -p udp --dport $PORT -j ACCEPT
    done

     green_msg "Valve"
    $IPTABLES -A INPUT -i eth0 -m state --state NEW -p tcp --dport 6000:6003 -j ACCEPT
    $IPTABLES -A INPUT -i eth0 -m state --state NEW -p tcp --dport 7001:7002 -j ACCEPT
    $IPTABLES -A INPUT -i eth0 -m state --state NEW -p udp --dport 27005 -j ACCEPT
    $IPTABLES -A INPUT -i eth0 -m state --state NEW -p udp --dport 27010 -j ACCEPT
    $IPTABLES -A INPUT -p udp -m udp --sport 27000:27030 --dport 1025:65355 -j ACCEPT
    $IPTABLES -A INPUT -p udp -m udp --sport 4380 --dport 1025:65355 -j ACCEPT

    GSPORTS=(27015 27145 27245)
    for PORT in ${GSPORTS[@]}; do
        green_msg "Gameserver: ${PORT}"
        $IPTABLES -A INPUT -p udp --dport $PORT -m length --length 0:32 -j LOG --log-prefix "SRCDS-XSQUERY " --log-ip-options -m limit --limit 1/m --limit-burst 1
        $IPTABLES -A INPUT -p udp --dport $PORT -m length --length 0:32 -j DROP
        $IPTABLES -A INPUT -p udp --dport $PORT -m length --length 2521:65535 -j LOG --log-prefix "SRCDS-XLFRAG " --log-ip-options -m limit --limit 1/m --limit-burst 1
        $IPTABLES -A INPUT -p udp --dport $PORT -m length --length 2521:65535 -j DROP
        #-m hashlimit --hashlimit-mode dstport,dstip --hashlimit-name StopFlood --hashlimit 2400/s --hashlimit-burst 480
        $IPTABLES -A INPUT -p udp --dport $PORT -m state --state ESTABLISH -j ACCEPT
        $IPTABLES -A INPUT -p udp --dport $PORT -m state --state NEW -m hashlimit --hashlimit-mode srcip --hashlimit-name StopDoS --hashlimit 1/s --hashlimit-burst 3 -j ACCEPT

        #$IPTABLES -A INPUT -i eth0 -m state --state NEW -p udp --dport $PORT -j ACCEPT
        $IPTABLES -A INPUT -i eth0 -p tcp -m tcp --dport $PORT -m hashlimit --hashlimit-upto 1/Min --hashlimit-burst 1 --hashlimit-mode srcip,dstip,dstport --hashlimit-name RCONLIMIT -j ACCEPT
    done

    green_msg "SYN Flood stoppen"
    $IPTABLES -A FORWARD -p tcp --syn -m limit --limit 1/s -j ACCEPT

    green_msg "Portscan erschweren"
    $IPTABLES -A FORWARD -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 2/s -j ACCEPT

    green_msg "ICMP Ping limitieren"
    $IPTABLES -A FORWARD -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT

    green_msg "Bestehende Verbindungen online lassen"
    $IPTABLES -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    $IPTABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    green_msg "Garbage uebergeben wenn nicht erlaubt"
    $IPTABLES -A INPUT -m state --state INVALID -j droplog

    green_msg "Alles verbieten was bisher erlaubt war"
    $IPTABLES -A INPUT -j droplog
    $IPTABLES -A OUTPUT -j droplog
    $IPTABLES -A FORWARD -j droplog
}

case "$1" in
    start)
        start_iptables
    ;;
    stop)
        stop_iptables
    ;;
    test)
        start_iptables
        sleep 60
        stop_iptables
    ;;
    status)
        status
    ;;
    *)
        error_end "Usage: $(basename $0) start|stop|status|test (v)"
    ;;
esac
exit 0
