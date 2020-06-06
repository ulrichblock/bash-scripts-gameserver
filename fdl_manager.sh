#!/bin/bash

############################################################################
#                                                                          #
#  Author: Ulrich Block                                                    #
#                                                                          #
#  Kontakt:                                                                #
#  ich@ulrich-block.de                                                     #
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
############################################################################


function red_msg() {
	echo -e "\\033[31;1m${@}\033[0m"
}

function green_msg() {
	echo -e "\\033[32;1m${@}\033[0m"
}

function yellow_msg() {
	echo -e "\\033[33;1m${@}\033[0m"
}

function blue_msg() {
	echo -e "\\033[34;1m${@}\033[0m"
}

function magenta_msg() {
	echo -e "\\033[35;1m${@}\033[0m"
}

function cyan_msg() {
	echo -e "\\033[36;1m${@}\033[0m"
}

FDLVERSION="1.2.5"
FDLBINPATH=`readlink -f $0`
PATHHOME=`dirname $FDLBINPATH`

if ([ "$1" != "" ] && [ "$1" != "install" ]); then
	if [ -f /home/fdl.conf ]; then
		FDLBASEPATH=`cat /home/fdl.conf | grep "path=" | awk -F= '{print $2}'`
		if [ -z "$FDLBASEPATH" ]; then
			red_msg "You need to set the path in the /home/fdl.conf file like path=/home/fastdl"
			exit 0
		fi
		FTPUPLOADLIMIT=`cat /home/fdl.conf | grep "speed=" | awk -F= '{print $2}'`
		if [ -z "$FTPUPLOADLIMIT" ]; then
			yellow_msg "You need to set the upload speed in the /home/fdl.conf file"
			yellow_msg "Setting the Limit to 1024kb/s"
			FTPUPLOADLIMIT="1024K"
		fi
	else
		red_msg "You need to create the /home/fdl.conf and set the masterpath like path=/home/fastdl"
		red_msg "The teklabgroup (users) must have write rights to the masterpath and its subfolders"
		exit 0
	fi
fi
FDLTEMPDIR="$FDLBASEPATH/fdl_temp"
FDLCONFDIR="$FDLBASEPATH/fdl_conf"
FDLFTPDIR="$FDLCONFDIR/ftp"
FDLDATADIR="$FDLBASEPATH/fdl_data"
FDLLOGDIR="$FDLBASEPATH/fdl_log"
FDLUSER=$(echo $BASEPATH | awk -F "/" '{print $3}')
INPUTARRAY=($*)

function rootinit {
if [ "`id -u`" != 0 ]; then
 red_msg "You need to be root, to to use this function"
 exit 0
fi
}

function userinit {
if [ "`id -u`" == 0 ]; then
 red_msg "You can not run this function as root"
 exit 0
fi
}

function init {	
	FAIL=0
	if [ ! -d "$FDLBASEPATH/fdl_temp" ]; then mkdir -p $FDLBASEPATH/fdl_temp; yellow_msg "The folder $FDLBASEPATH/fdl_temp does not exist. I will try to create one for you."; FAIL=1; fi
	if [ ! -d "$FDLBASEPATH/fdl_conf" ]; then mkdir -p $FDLBASEPATH/fdl_conf ; yellow_msg "The folder $FDLBASEPATH/fdl_conf does not exist. I will try to create one for you."; FAIL=1; fi
	if [ ! -d "$FDLBASEPATH/fdl_conf/ftp" ]; then mkdir -p $FDLBASEPATH/fdl_conf/ftp ; yellow_msg "The folder $FDLBASEPATH/fdl_conf/ftp does not exist. I will try to create one for you."; FAIL=1; fi
	if [ ! -d "$FDLBASEPATH/fdl_data" ]; then mkdir -p $FDLBASEPATH/fdl_data ; yellow_msg "The folder $FDLBASEPATH/fdl_data does not exist. I will try to create one for you."; FAIL=1; fi
	if [ ! -d "$FDLBASEPATH/fdl_log" ]; then mkdir -p $FDLBASEPATH/fdl_log ; yellow_msg "The folder $FDLBASEPATH/fdl_log does not exist. I will try to create one for you."; FAIL=1; fi
	if [ "$FAIL" -gt "0" ]; then yellow_msg "Please check if the error(s) have been fixed and rerun the FDL Manager."; red_msg "shutting down"; sleep 1; exit 0; fi
}

function upates {
	yellow_msg "Checking for updates"
	CURRENTFDLVERSION=`wget -q -O - http://programme.ulrich-block.de/fdl_version.php?f=current`
	if [ -z $CURRENTFDLVERSION ]; then
		red_msg "The licenceserver did not reply the current FDL Manager version. Please contact the author"
		echo "`date`: The licenceserver did not reply the current FDL Manager version. Please contact the author" >> $FDLLOGDIR/fdl.log 
	elif [ "$FDLVERSION" != "$CURRENTFDLVERSION" ]; then
		cd $PATHHOME
		if [ -f $PATHHOME/fdl_manager.tar ]; then
			rm $PATHHOME/fdl_manager.tar
		fi
		wget -q http://programme.ulrich-block.de/download/`uname -m`/fdl_manager.tar
		if [ -f fdl_manager.tar ]; then
			mv $PATHHOME/$0 $PATHHOME/$0.old.$FDLVERSION
			tar xf fdl_manager.tar
			rm fdl_manager.tar
			chmod +x fdl_manager
			echo "`date`: Updated the FDL Manager" >> $FDLLOGDIR/fdl.log
			green_msg "Updated the FDL Manager. Please rerun the FDL Manager"
			exit 0
		else
			red_msg "Could not download the new version"
		fi
	else
		green_msg "FDL Manager is up to date"
	fi
	cd $FDLCONFDIR
	ls fdl-*.list | awk -F "-" '{print $2}' | awk -F "." '{print $1}' | while read LISTTYPE; do
		LOCALVERSION=`head -n 1 fdl-$LISTTYPE.list`
		CURRENTVERSION=`wget -q -O - http://programme.ulrich-block.de/fdl_version.php?g=$LISTTYPE`
		if [ "$CURRENTVERSION" == "" ]; then
			red_msg "Getting the version for the filelist for game $LISTTYPE failed. Please contact the author"
			echo "`date`: Getting the version for the filelist for game $LISTTYPE failed. Please contact the author" >> $FDLLOGDIR/fdl.log 
		elif [ "$LOCALVERSION" != "$CURRENTVERSION" ]; then
			if [ -f fdl-$LISTTYPE.list ]; then
				mv fdl-$LISTTYPE.list fdl-$LISTTYPE.list.old
			fi
			wget -q http://programme.ulrich-block.de/download/fdl/fdl-$LISTTYPE.list
			green_msg "Updated filelist for the game $LISTTYPE"
			echo "`date`: Updated filelist for the game $LISTTYPE" >> $FDLLOGDIR/fdl.log 
		else
			green_msg "The filelist for the game $LISTTYPE is up to date"
		fi		
	done
}

function hl2 {
	FOLDERS=$(dirname $FILTEREDFILES)
	FILENAME=$(basename $FILTEREDFILES)
	if [ ! -d $FDLDATADIR/$GAMETYPE/$NAMEFDL/$FOLDERS ]; then
		mkdir -p $FDLDATADIR/$GAMETYPE/$NAMEFDL/$FOLDERS
	fi
	if [ -f "$FDLDATADIR/$GAMETYPE/$NAMEFDL/$FILTEREDFILES.stat" ]; then
		yellow_msg "Checking if $FILENAME needs to be updated"
		if [ "`cat \"$FDLDATADIR/$GAMETYPE/$NAMEFDL/$FILTEREDFILES.stat\" | head -n 1`" != "`nice -n +19 stat -L -c \"%y %s\" \"$FILTEREDFILES\" | awk '{print $1}'`" ]; then
			nice -n +19 rm "$FDLDATADIR/$GAMETYPE/$NAMEFDL/$FILTEREDFILES.stat" 
			if [ -f "$FDLDATADIR/$GAMETYPE/$NAMEFDL/$FILTEREDFILES.bz2" ]; then
				nice -n +19 rm "$FDLDATADIR/$GAMETYPE/$NAMEFDL/$FILTEREDFILES.bz2"
			fi
			if [ "$LINKS" == "1" ]; then
				nice -n +19 cp "$FILTEREDFILES" "$FDLDATADIR/$GAMETYPE/$NAMEFDL/$FILTEREDFILES"
				nice -n +19 stat -L -c "%y %s" "$FDLDATADIR/$GAMETYPE/$NAMEFDL/$FILTEREDFILES" | awk '{print $1}' > "$FDLDATADIR/$GAMETYPE/$NAMEFDL/$FILTEREDFILES.stat"
				nice -n +19 bzip2 -s -q -9 "$FDLDATADIR/$GAMETYPE/$NAMEFDL/$FILTEREDFILES"
			else
				nice -n +19 bzip2 -k -s -q -9 "$FILTEREDFILES" 
				nice -n +19 mv "$FILTEREDFILES.bz2" "$FDLDATADIR/$GAMETYPE/$NAMEFDL/$FILTEREDFILES.bz2"
				nice -n +19 stat -L -c "%y %s" "$FILTEREDFILES" | awk '{print $1}' > "$FDLDATADIR/$GAMETYPE/$NAMEFDL/$FILTEREDFILES.stat"
			fi
			chmod 660 "$FDLDATADIR/$GAMETYPE/$NAMEFDL/$FILTEREDFILES.bz2" "$FDLDATADIR/$GAMETYPE/$NAMEFDL/$FILTEREDFILES.stat"
			echo "wput -q --limit-rate=$FTPUPLOADLIMIT \"$FILTEREDFILES.bz2\" $FTPDATA/$NAMEFDL/" >> $FDLTEMPDIR/$CUSTOMER-$NAMEFDL-$FOLDERNAME.sh
			echo "`date`: (User $CUSTOMER): Updated $NAMEFDL file `basename $FILTEREDFILES`" >> $FDLLOGDIR/hl2.log 
		else
			echo "wput -nv -q --limit-rate=$FTPUPLOADLIMIT \"$FILTEREDFILES.bz2\" $FTPDATA/$NAMEFDL/" >> $FDLTEMPDIR/$CUSTOMER-$NAMEFDL-$FOLDERNAME.sh
			echo "`date`: (User $CUSTOMER): $NAMEFDL file $FILENAME checked" >> $FDLLOGDIR/hl2.log 
		fi
		yellow_msg "Keep on looking for more files."
	else
		echo "Found new file: $FILENAME"
		if [ "$LINKS" == "1" ]; then
			nice -n +19 cp "$FILTEREDFILES" "$FDLDATADIR/$GAMETYPE/$NAMEFDL/$FILTEREDFILES"
			nice -n +19 stat -L -c "%y %s" "$FDLDATADIR/$GAMETYPE/$NAMEFDL/$FILTEREDFILES" | awk '{print $1}' > "$FDLDATADIR/$GAMETYPE/$NAMEFDL/$FILTEREDFILES.stat"
			nice -n +19 bzip2 -s -q -9 "$FDLDATADIR/$GAMETYPE/$NAMEFDL/$FILTEREDFILES"
		else
			nice -n +19 bzip2 -k -s -q -9 "$FILTEREDFILES" 
			nice -n +19 mv "$FILTEREDFILES.bz2" "$FDLDATADIR/$GAMETYPE/$NAMEFDL/$FILTEREDFILES.bz2"
			nice -n +19 stat -L -c "%y %s" "$FILTEREDFILES" | awk '{print $1}' > "$FDLDATADIR/$GAMETYPE/$NAMEFDL/$FILTEREDFILES.stat"
		fi
		chmod 660 "$FDLDATADIR/$GAMETYPE/$NAMEFDL/$FILTEREDFILES.bz2" "$FDLDATADIR/$GAMETYPE/$NAMEFDL/$FILTEREDFILES.stat"
		echo "wput -q --dont-continue --limit-rate=$FTPUPLOADLIMIT \"$FILTEREDFILES.bz2\" $FTPDATA/$NAMEFDL/" >> $FDLTEMPDIR/$CUSTOMER-$NAMEFDL-$FOLDERNAME.sh
		echo "`date`: (User $CUSTOMER): Added $NAMEFDL file `basename \"$FILTEREDFILES\"`" >> $FDLLOGDIR/hl2.log
		yellow_msg "Keep on looking for more files."
	fi
	if [ "`id -u`" == "0" ]; then
		FDLUSER=$(ls $FDLDATADIR | awk -F "/" '{print $2}')
		chown -R $FDLUSER:users $FDLBASEPATH
	fi
}

function hl1 {
	FILENAME=$(basename $FILTEREDFILES)
	echo "FILTEREDFILES=$FILTEREDFILES" >> $FDLTEMPDIR/$CUSTOMER-$NAMEFDL-$FOLDERNAME.sh
	echo "FILENAME=$FILENAME" >> $FDLTEMPDIR/$CUSTOMER-$NAMEFDL-$FOLDERNAME.sh
	echo 'if [ "`wput -nv --limit-rate=$FTPUPLOADLIMIT \"$FILTEREDFILES\" $FTPDATA/$NAMEFDL/ | grep \"Skipping file\"`" != "" ]; then
	wput -qN --limit-rate=$FTPUPLOADLIMIT "$FILTEREDFILES" $FTPDATA/$NAMEFDL/
	echo "`date`: (User $CUSTOMER): $NAMEFDL file $FILENAME checked" >> $FDLLOGDIR/hl1.log 
else
	echo "`date`: (User $CUSTOMER): $NAMEFDL file $FILENAME uploaded" >> $FDLLOGDIR/hl1.log 
fi' >> $FDLTEMPDIR/$CUSTOMER-$NAMEFDL-$FOLDERNAME.sh
}

function folderallowed {
	for i in ${DISALLOWEDFOLDER[@]}; do
		if [ "$i" == "$1" ]; then
			echo "1"
		fi
	done
}

function startsync {
	if [ "$GAMETYPE" == "hl1" ]; then
		if [ "`grep \"$FILTEREDFILES\" $FDLCONFDIR/fdl-$NAMEFDL.list`" == "" ]; then
			hl1
		fi
	elif [ "$GAMETYPE" == "hl2" ]; then
		if [ "`grep \"$FILTEREDFILES\" $FDLCONFDIR/fdl-$NAMEFDL.list`" == "" ]; then
			hl2
		fi
	fi
}

function fastdownload {
	FOLDERNAME=$(echo $SERVERFOLDERS | awk -F/ '{print $5}')
	CUSTOMER=$(echo $SERVERFOLDERS | awk -F/ '{print $3}')
	if [ -f $PATHHOME/cfg/fdl_config.cfg ]; then
		FTPDATA=`cat $PATHHOME/cfg/fdl_config.cfg | tr -d ' ' | grep -v "#" | grep "ftpdata=" | awk -F= '{print $2}'| head -n 1`
		DISALLOWEDFOLDER=(`cat $PATHHOME/cfg/fdl_config.cfg | grep -v "#" | grep "skipfolders=" | awk -F= '{print $2}'| head -n 1`)
	elif ([ -f $FDLFTPDIR/$CUSTOMER.cfg ] && [ ! -f $PATHHOME/cfg/fdl_config.cfg ]); then
		FTPDATA=`cat $FDLFTPDIR/$CUSTOMER.cfg | grep -v "#" | grep "ftpdata=" | awk -F= '{print $2}' | head -n 1`
		DISALLOWEDFOLDER=(`cat $FDLFTPDIR/$CUSTOMER.cfg | grep -v "#" | grep "skipfolders=" | awk -F= '{print $2}'| head -n 1`)
	else
		echo ""
		red_msg "Error:"
		red_msg "No config file available"
		yellow_msg "You can use \"./fdl_manager refreshftp\" to create a template file."
		exit 0
	fi
	if [ "$DISALLOWEDOVERRIDE" == "1" ]; then
		DISALLOWEDFOLDER=""
	fi
	if [ "`folderallowed $FOLDERNAME`" != "1" ]; then
		GAMETYPE=""
		if [ "`find $SERVERFOLDERS -maxdepth 2 -name srcds_run`" != "" ]; then
			if [ "`find $SERVERFOLDERS -maxdepth 2 -name steam.inf | grep -v \"valve\" | wc -l`" == "1" ]; then
				INFSTEAM=$(find $SERVERFOLDERS -maxdepth 2 -name steam.inf)
			fi
			GAMETYPE="hl2"
			HLBIN=$(find $SERVERFOLDERS -maxdepth 2 -name srcds_run)
			HLBINDIR=$(dirname $HLBIN)
			cd $HLBINDIR			
			if [ "`find -mindepth 1 -maxdepth 1 -type d | grep -v \"reslists\|bin\|hl2\|appcache\" | wc -l`" == "1" ]; then
				NAMESTEAM=`find -mindepth 1 -maxdepth 1 -type d | grep -v "reslists\|bin\|hl2\|appcache" | sed 's/.\///g'`
			else
				echo "No known server could be found"
			fi
			if [ "$NAMESTEAM" != "" ]; then
				if [ "$NAMESTEAM" == "cstrike" ]; then
					NAMEFDL="css"
				elif [ "$NAMESTEAM" == "dod" ]; then
				NAMEFDL="dods"
				else
					NAMEFDL="$NAMESTEAM"
				fi
			fi
			echo "Found HL2 based server $NAMEFDL in $FOLDERNAME"
		elif [ "`find $SERVERFOLDERS -maxdepth 1 -name hlds_run`" != "" ]; then
			if [ "`find $SERVERFOLDERS -maxdepth 2 -name steam.inf | grep -v \"valve\" | wc -l`" == "1" ]; then
				INFSTEAM=`find $SERVERFOLDERS -maxdepth 2 -name steam.inf | grep -v \"valve\"`
			elif [ "`find $SERVERFOLDERS -mindepth 1 -maxdepth 1 -name czero`" != "" ]; then
				INFSTEAM=`find $SERVERFOLDERS/czero/ -maxdepth 1 -name steam.inf`
			else
				red_msg "This type of server is not supported"
				exit 0
			fi
			GAMETYPE="hl1"
			HLBIN=`find $SERVERFOLDERS -maxdepth 1 -name hlds_run`
			HLBINDIR=`dirname $HLBIN`
			cd $HLBINDIR
			if [ "`find -mindepth 1 -maxdepth 1 -type d | grep -v \"valve\|reslists\" | wc -l`" == "1" ]; then
				NAMESTEAM=`find -mindepth 1 -maxdepth 1 -type d | grep -v "valve\|reslists" | sed 's/.\///g'`
				NAMEFDL=`find -mindepth 1 -maxdepth 1 -type d | grep -v "valve\|reslists" | sed 's/.\///g'`
			elif [ "`find -mindepth 1 -maxdepth 1 -type d | grep -v \"valve\|reslists\|cstrike\" | wc -l`" == "1" ]; then
				NAMESTEAM=`find -mindepth 1 -maxdepth 1 -type d | grep -v "valve\|reslists\|cstrike" | sed 's/.\///g'`
				NAMEFDL=`find -mindepth 1 -maxdepth 1 -type d | grep -v "valve\|reslists\|cstrike" | sed 's/.\///g'`
			else
				red_msg "No known server could be found"
			fi
			green_msg "Found HL1 based server $NAMESTEAM in $FOLDERNAME"
		fi
		if [ -n $NAMEFDL ]; then
			echo "Entering Modfolder: `find $SERVERFOLDERS -maxdepth 2 -type d -name \"$NAMESTEAM\"` and creating filelist of that directory"
			cd `find $SERVERFOLDERS -maxdepth 2 -type d -name "$NAMESTEAM"`
			if [ -f $FDLTEMPDIR/$CUSTOMER-$FOLDERNAME.temp ]; then
				rm $FDLTEMPDIR/$CUSTOMER-$FOLDERNAME.temp
			fi
			if [ -f $FDLTEMPDIR/$CUSTOMER-$FOLDERNAME-l.temp ]; then
				rm $FDLTEMPDIR/$CUSTOMER-$FOLDERNAME-l.temp
			fi
			if [ ! -f $FDLCONFDIR/fdl-$NAMEFDL.list ]; then
				red_msg "Filelist for $NAMEFDL does not exist"
				SKIPFOLDER=1
			else
				SKIPFOLDER=0
			fi
			if [ -f $FDLTEMPDIR/$CUSTOMER-$NAMEFDL-$FOLDERNAME.sh ]; then
				rm $FDLTEMPDIR/$CUSTOMER-$NAMEFDL-$FOLDERNAME.sh
			fi
			touch $FDLTEMPDIR/$CUSTOMER-$NAMEFDL-$FOLDERNAME.sh
			echo "#!/bin/bash" > $FDLTEMPDIR/$CUSTOMER-$NAMEFDL-$FOLDERNAME.sh
			if [ "$GAMETYPE" == "hl1" ]; then
				echo "cd `find $SERVERFOLDERS -maxdepth 2 -type d -name \"$NAMESTEAM\"`" >> $FDLTEMPDIR/$CUSTOMER-$NAMEFDL-$FOLDERNAME.sh
				echo "FTPDATA=$FTPDATA" >> $FDLTEMPDIR/$CUSTOMER-$NAMEFDL-$FOLDERNAME.sh
				echo "NAMEFDL=$NAMEFDL" >> $FDLTEMPDIR/$CUSTOMER-$NAMEFDL-$FOLDERNAME.sh
				echo "FDLLOGDIR=$FDLLOGDIR" >> $FDLTEMPDIR/$CUSTOMER-$NAMEFDL-$FOLDERNAME.sh
				echo "FTPUPLOADLIMIT=$FTPUPLOADLIMIT" >> $FDLTEMPDIR/$CUSTOMER-$NAMEFDL-$FOLDERNAME.sh
				echo "CUSTOMER=$CUSTOMER" >> $FDLTEMPDIR/$CUSTOMER-$NAMEFDL-$FOLDERNAME.sh
				SEARCHFOLDERS=""
			elif [ "$GAMETYPE" == "hl2" ]; then
				echo "cd $FDLDATADIR/hl2" >> $FDLTEMPDIR/$CUSTOMER-$NAMEFDL-$FOLDERNAME.sh
				if [ ! -d $FDLDATADIR/$GAMETYPE ]; then
					mkdir -p $FDLDATADIR/$GAMETYPE
					chmod 770 $FDLDATADIR/$GAMETYPE
				fi
				SEARCHFOLDERS="particles/ maps/ materials/ resource/ models/ sound/"
			fi
			echo "comparing serverfiles with the serverfilelist"
			if [ "$SKIPFOLDER" != "1" ]; then
				PATTERN=".inf\|.log\|.txt\|.cfg\|.vdf\|.cache\|.dem\|.db\|.dat\|.ztmp\|log\|logs\|download\|downloads\|DownloadLists/\|metamod/\|amxmodx/\|hl/\|hl2/\|cfg/\|addons/\|bin/\|classes/"
#				find $SEARCHFOLDERS -type f | grep -v "$PATTERN" > $FDLTEMPDIR/$CUSTOMER-$NAMEFDL.tmp
#				diff $FDLTEMPDIR/$CUSTOMER-$NAMEFDL.tmp $FDLCONFDIR/fdl-$NAMEFDL.list  | grep "^<" | sed 's/< //' | while read FILTEREDFILES; do
				find $SEARCHFOLDERS -type f | grep -v "$PATTERN" | while read FILTEREDFILES; do
					startsync
				done
#				find $SEARCHFOLDERS -type l | grep -v "$PATTERN" > $FDLTEMPDIR/$CUSTOMER-$NAMEFDL.tmp
#				diff $FDLTEMPDIR/$CUSTOMER-$NAMEFDL.tmp $FDLCONFDIR/fdl-$NAMEFDL.list  | grep "^<" | sed 's/< //' | while read FILTEREDFILES; do
				find $SEARCHFOLDERS -type l | grep -v "$PATTERN" | while read FILTEREDFILES; do		
					LINKS="1"
					startsync
				done
				chmod -R 770 $FDLDATADIR/ > /dev/null 2>&1
				cd $FDLTEMPDIR
				echo "syncronising custom files with fast download server"
				echo "rm $FDLTEMPDIR/$CUSTOMER-$NAMEFDL-$FOLDERNAME.sh" >> $FDLTEMPDIR/$CUSTOMER-$NAMEFDL-$FOLDERNAME.sh
				chmod +x $CUSTOMER-$NAMEFDL-$FOLDERNAME.sh
				screen -dmS $CUSTOMER ./$CUSTOMER-$NAMEFDL-$FOLDERNAME.sh
			else
				red_msg "I could not find gameserverdata for the folder $FOLDERNAME"
			fi
		fi
	else
		yellow_msg "Skipping server: $FOLDERNAME"
	fi
}

function allinstalls {
	find /home/$MODERUN/server -mindepth 1 -maxdepth 1 -type d -group users | while read SERVERFOLDERS; do
		fastdownload
	done
}

function specifiedinstalls {
	COUNTDIRS=${#INPUTARRAY[@]}
	if [ "$COUNTDIRS" == "1" ]; then
		echo ""
		red_msg "Error:"
		red_msg "You need to specify the folder(s)/server(s) you want to check"
	fi
	CORCOUNT=$[COUNTDIRS-1]
	DISALLOWEDOVERRIDE=1
	i=1
	while [ $i -le $CORCOUNT ]; do
		SERVERFOLDERS=/home/$MODERUN/server/${INPUTARRAY[$i]}
		if [ -d $SERVERFOLDERS ]; then
			fastdownload
		else
			echo ""
			red_msg "Error:"
			red_msg "Could not find the folder $SERVERFOLDERS"
		fi
		i=$[i+1]
	done
}

function install {
	echo "Please enter the name of the masteruser"
	echo "If the user does not exist I will create it for you"
	read INSTALLMASTER
	if [ -z $INSTALLMASTER ]; then echo "You need to enter a username"; exit 0; fi
	echo "Please enter the maximum speed for the file upload. Examples:"
	echo "1024 = 1024 B/s"
	echo "1024K = 1024 KiB/s"
	echo "1024M = 1024 MiB/s"	
	read UPSPEED
	if [ -z $UPSPEED ]; then UPSPEED="1024K" ; fi
	if [ "`grep \"$INSTALLMASTER:\" /etc/passwd | awk -F ":" '{print $1}'`" != "$INSTALLMASTER" ]; then
		if [ -d /home/$INSTALLMASTER ]; then
			useradd -g users -d /home/$INSTALLMASTER -s /bin/bash $INSTALLMASTER
		else
			useradd -g users -b /home -s /bin/bash $INSTALLMASTER
		fi
		passwd $INSTALLMASTER
	fi
	sleep 1
	echo "Creating main configfile /home/fdl.conf"
	echo "# Homepath to the masteruser
path=/home/$INSTALLMASTER

# Maximum Uploadspeed. Examples: 1024 = 1024 B/s; 1024K = 1024 KiB/s; 1024M = 1024 MiB/s
speed=$UPSPEED" > /home/fdl.conf
	sleep 1
	echo "Creating FDL Manager folders"
	if [ ! -d /home/$INSTALLMASTER/fdl_temp ]; then mkdir -p /home/$INSTALLMASTER/fdl_temp; fi
	if [ ! -d /home/$INSTALLMASTER/fdl_conf ]; then mkdir -p /home/$INSTALLMASTER/fdl_conf; fi
	if [ ! -d /home/$INSTALLMASTER/fdl_conf/ftp ]; then mkdir -p /home/$INSTALLMASTER/fdl_conf/ftp; fi
	if [ ! -d /home/$INSTALLMASTER/fdl_data ]; then mkdir -p /home/$INSTALLMASTER/fdl_data; fi
	if [ ! -d /home/$INSTALLMASTER/fdl_log ]; then mkdir -p /home/$INSTALLMASTER/fdl_log; fi
	sleep 1
	echo "Moving fdl_manager to /home/$INSTALLMASTER/"
	if [ "`readlink -f fdl_manager`" != "/home/$INSTALLMASTER/fdl_manager" ]; then
		mv fdl_manager /home/$INSTALLMASTER/fdl_manager
	fi
	sleep 1
	echo "Creating FTP configfiles for Users with gameservers in /home/$INSTALLMASTER/fdl_conf"
	find /home/*/server -maxdepth 0 -name server -type d -group users | awk -F "/" '{print $3}' | while read USERS; do
		if [ ! -f /home/$INSTALLMASTER/fdl_conf/ftp/$USERS.cfg ]; then
			echo "Found $USERS. A FTP config file with an example configuration will be created."
			echo "ftpdata=ftp://username:password@ip:port" > /home/$INSTALLMASTER/fdl_conf/ftp/$USERS.cfg
			echo "# uncomment and edit the following line and add serverfolders that should be skipped" >> /home/$INSTALLMASTER/fdl_conf/ftp/$USERS.cfg
			echo "#skipfolders=warserver1 server1 server2" >> /home/$INSTALLMASTER/fdl_conf/ftp/$USERS.cfg
			echo "Created the /home/$INSTALLMASTER/fdl_conf/ftp/$USERS.cfg file with an example configuration"
		fi
	done
	sleep 1
	echo "Downloading the filelists"
	cd /home/$INSTALLMASTER/fdl_conf
	SHORTEN=("ageofchivalry" "css" "cstrike" "czero" "dod" "dods" "garrysmod" "hl2mp" "insurgency" "left4dead2" "left4dead" "pvkii" "tf" "tfc" "zps")
	SHORTENCOUNT=${#SHORTEN[@]}
	SHORTENCOUNT=$[SHORTENCOUNT-1]
	i=0
	while [ $i -le $SHORTENCOUNT ]; do
		echo "Downloading the ${SHORTEN[$i]} filelist"
		if [ -f fdl-${SHORTEN[$i]}.list ]; then rm fdl-${SHORTEN[$i]}.list; fi
		wget -q http://programme.ulrich-block.de/download/fdl/fdl-${SHORTEN[$i]}.list
        i=$[i+1]
	done
	sleep 1
	echo "Setting Permissions for files and folders"
	chown $INSTALLMASTER:users /home/fdl.conf
	chmod 640 /home/fdl.conf
	cd /home/$INSTALLMASTER
	chmod -R 770 fdl_*
	cd /home/$INSTALLMASTER/fdl_conf
	chmod 660 *.list
	cd /home/$INSTALLMASTER/fdl_conf/ftp
	chmod 640 *.cfg
	chmod 700 /home/$INSTALLMASTER/fdl_manager
	touch /home/$INSTALLMASTER/fdl_log/hl1.log
	touch /home/$INSTALLMASTER/fdl_log/hl2.log
	touch /home/$INSTALLMASTER/fdl_log/fdl.log
	chmod 660 /home/$INSTALLMASTER/fdl_log/hl1.log /home/$INSTALLMASTER/fdl_log/hl2.log
	chown -R $INSTALLMASTER:users /home/$INSTALLMASTER
	sleep 1
	echo "Installation successfull"
}

function refreshftp {
	echo "Checking if FTP configfiles for all users exist in $FDLFTPDIR/fdl_conf"
	find /home/*/server -maxdepth 0 -name server -type d -group users | awk -F "/" '{print $3}' | while read USERS; do
		if [ ! -f $FDLFTPDIR/$USERS.cfg ]; then
			echo "FTP Config for the user $USERS could not be found. A file with an example configuration will be created."
			echo "ftpdata=ftp://username:password@ip:port" > $FDLFTPDIR/$USERS.cfg
			echo "# uncomment and edit the following line and add serverfolders that should be skipped" >> $FDLFTPDIR/$USERS.cfg
			echo "#skipfolders=warserver1 server1 server2" >> $FDLFTPDIR/$USERS.cfg
			chown $FDLUSER:users $FDLFTPDIR/$USERS.cfg
			echo "Created the $FDLFTPDIR/$USERS.cfg file with an example configuration"
		fi
	done
}

function info {
echo "
FDL Manager
Version $FDLVERSION
Ulrich Block
ulblock@gmx.de 
www.ulrich-block.de

Usage: $0 {user|folder|cron|install|refreshftp|update}"
}

case "$1" in
	cron)
		rootinit
		init
		MODERUN="*"
		upates
		allinstalls
		chown -R $FDLUSER:users /home/$FDLUSER
	;;
	user)
		userinit
		echo "Starting..."
		init
		MODERUN=`id -un`
		upates
		allinstalls
	;;
	folder)
		userinit
		echo "Starting..."
		init
		MODERUN=`id -un`
		upates
		specifiedinstalls
	;;
	install)
		rootinit
		install
	;;
	refreshftp)
		rootinit
		init
		refreshftp
	;;
	update)
		userinit
		echo "Starting..."
		init
		upates
	;;
	*)
		info
	;;	
esac
exit 0
