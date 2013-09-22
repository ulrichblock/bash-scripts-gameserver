#!/bin/bash 

############################################################################
#                                                                          #
#  Counter-Strike Source/GO  and TF 2 (HL2) Server Script                  #
#                                                                          #
#  Author:                                                                 #
#  Ulrich Block                                                            #
#                                                                          #
#  Kontakt:                                                                #
#  ulblock at gmx.de                                                       #
#  www.ulrich-block.de                                                     #
#                                                                          #
#  This program is free software: you can redistribute it and/or modify    #
#  it under the terms of the GNU General Public License as published by    #
#  the Free Software Foundation, either version 3 of the License, or       #
#  (at your option) any later version.                                     #
#                                                                          #
#  This program is distributed in the hope that it will be useful,         #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of          #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           #
#  GNU General Public License for more details.                            #
#                                                                          #
#  You should have received a copy of the GNU General Public License       #
#  along with this program.  If not, see http://www.gnu.org/licenses/      #
#                                                                          #
#  Gebrauch: ./css.sh {start|stop|restart|update|console|check}            #
#                                                                          #
#  start/restart/stop: Server An und aus schalten                          #
#                                                                          #
#  update: Mit dem Steam Updatetool den Server aktualisieren               #
#                                                                          #
#  console: Wechselt auf die Counter-Strike Serverkonsole                  #
#        Mit strg+a + d die Konsole wieder in den Hintergrund schicken     #
#                                                                          #
############################################################################

function init {
# Absoluter Pfad zum Server
DIR="/Verzeichnis/zum/Server"

# Startscript des Servers
DEAMON="srcds_run"

# Externe IP unter der der Server erreichbar sein soll
IP="Die.IP.vom.Server"

# Port auf den der Server lauschen soll
PORT="PortvomServer"

# Client Port des Servers
CLIENTPORT="28000"

# Falls SourceTV genutzt wird, wird der SourceTV Server auf diesem Port gestartet
TVPT="29000"

# Slot Anzahl
MPLAYERS="20"

# Startmap
MAP="de_dust2"

# Source TV aktivieren
SOURCETV=1

# Team Fortress 2 - tf, Counter-Strike: Source - cstrike, Counter-Strike: Global Offensive - csgo
GAME="csgo"
if [ "$GAME" == "csgo" ]; then
    # Dieser Teil ist nur fuer CS:GO
    GAMETYPE=0
    GAMEMODE=1
    MAPGROUP="mg_bomb"
    TICK=66
    CSGO="-tickrate $TICK +game_type $GAMETYPE +game_mode $GAMEMODE +mapgroup $MAPGROUP "
else
    CSGO=""
fi

PARAMS="-game $GAME -ip $IP -port $PORT +tv_port $TVPT +clientport $CLIENTPORT +maxplayers $MPLAYERS +map $MAP +tv_enable $SOURCETV $CSGO"

SCREENNAME="css"

if [ "`whoami`" = "root" ]; then
    echo "Verantwortungsvolle Admins starten Gameserver nicht mit root! Allen anderen ist es untersagt!"
    exit 0
fi
if [ -z "$DIR" ]; then
    echo "Es wurde nichts bei der Variable DIR angegeben."
    exit 0
fi
if [ -z "$DEAMON" ]; then
    echo "Es wurde nichts bei der Variable DEAMON angegeben."
    exit 0
fi
if [ -z "$PARAMS" ]; then
    echo "Es wurde nichts bei der Variable PARAMS angegeben."
    exit 0
fi
if [ -z "$SCREENNAME" ]; then
    echo "Es wurde nichts bei der Variable SCREENNAME angegeben."
    exit 0
fi
if [ -z "$IP" ]; then
    echo "Es wurde nichts bei der Variable IP angegeben."
    exit 0
fi
if [ -z "$PORT" ]; then
    echo "Es wurde nichts bei der Variable PORT angegeben."
    exit 0
fi
}

function start_server {
    if [[ `screen -ls | grep $SCREENNAME` ]]; then
        echo "Der Server läuft bereits unter dem Screentab $SCREENNAME"
    else
        echo "Starte $SCREENNAME"
        if [ -d $DIR ]; then
           cd $DIR
           screen -d -m -S $SCREENNAME ./$DEAMON $PARAMS
        else 
           echo "Das Serververzeichnis wurde nicht angegeben"
        fi
    fi
} 

function stop_server {
    if [[ `screen -ls | grep $SCREENNAME` ]]; then
        echo -n "Stoppe $SCREENNAME"
        kill `screen -ls | grep $SCREENNAME | awk -F . '{print $1}'| awk '{print $1}'`
        echo " ... done."
    else
        echo "Konnte den Screentab $SCREENNAME nicht finden"
    fi
}

function update_server {
	if [ -f ~/steamcmd.sh ]; then
		stop_server
		echo "Update"
		cd
		if [ "$GAME" == "csgo" ]; then
			./steamcmd.sh +login anonymous +app_update 740 +force_install_dir $DIR validate +quit
		elif  [ "$GAME" == "cstrike" ]; then
			./steamcmd.sh +login anonymous +app_update 232330 +force_install_dir $DIR validate +quit
		elif  [ "$GAME" == "tf" ]; then
			./steamcmd.sh +login anonymous +app_update 232250 +force_install_dir $DIR validate +quit
		else
			echo "Falscher Wert für die Variable GAME!"
		fi
		start_server
	else
		echo "Konnte die Datei steamcmd.sh nicht im Homeverzeichnis finden!"
	fi
}

function wrong_input {
    echo "Usage: $0 {start|stop|restart|update|console|check}"
    exit 1
}

function get_screen {
    screen -r $SCREENNAME
}

# Veraltet:
#function check_ping {
#    if [ "`/usr/bin/quakestat -a2s $IP:$PORT | grep -v ADDRESS | awk '{ print $2 }' | awk -F/ ' { print $1}'`" = "DOWN" ]; then
#        sleep 10
#        if [ "`/usr/bin/quakestat -a2s $IP:$PORT | grep -v ADDRESS | awk '{ print $2 }' | awk -F/ ' { print $1}'`" = "DOWN" ]; then
#            stop_server
#            start_server
#        fi
#    fi
#}

function check_ping {
    if [[ "`printf '\xFF\xFF\xFF\xFF\x54\x53\x6F\x75\x72\x63\x65\x20\x45\x6E\x67\x69\x6E\x65\x20\x51\x75\x65\x72\x79\x00' | netcat -u -w 1 $IP $PORT`" == "" ]]; then
        sleep 10
        if [[ "`printf '\xFF\xFF\xFF\xFF\x54\x53\x6F\x75\x72\x63\x65\x20\x45\x6E\x67\x69\x6E\x65\x20\x51\x75\x65\x72\x79\x00' | netcat -u -w 1 $IP $PORT`" == "" ]]; then
            stop_server
            start_server
        fi
    fi
}

init

case "$1" in
    start)
        start_server
    ;;

    stop)
        stop_server
    ;;

    restart)
        stop_server
        start_server
    ;;

    update)
        update_server
    ;;

    console)
        get_screen
    ;;

    check)
        check_ping
    ;; 
 
    *)
        wrong_input
    ;;
esac
exit 0
