#!/usr/bin/ksh     
# MBNA America - Distributed Operation
# Author - Truc To 
# check decom host from MBNA centralized servers 
# version 1.0 02/24/2004
    

#####################  Global variables  ############################
TAP="/admin1/tap/bin/tap -Z"
GETTO="/admin1/tap/bin/getto -Z"
DATE=$(/usr/bin/date +%b%d%y)
LOG="/admin1/decommission/bin/test/logs/checkdecom$DATE"
NOCHANGE="# NO-change: "
CHANGE="** CHANGE **: "
#########################  FUNCTIONS  ###############################

### yesno function  ###
#----------------------
function yesno 
{
print -n "Please enter [yes] to proceed:  " ; read ANS

case "$ANS" in
	[Yy]|[Yy][Ee][Ss] ) 
	print "You have selected $ANS to continue. Continuing........ \n \n"
	sleep 3 ;;
	* ) 
	print "You have selected $ANS to not continue. Exiting......."
	sleep 5
	exit ;;
esac
}


### determine os and assigning file path fuction ###
#----------------------------------------------------
function checkrun 
{
SNAME=$(/usr/bin/uname -n)

clear

case  "$SNAME" in
	spbs496a|spbs502a )
	print "******************  This server name is $SNAME ********************** \n"
 	print "After this script finish ..... "
	print "Please run it again on a spjs server to remove entry for PSN servers \n"
	print "********************************************************************** \n"
	sleep 3
	print "Procceed.... \n " 
	remove1        # Remove printspool, NFS mounts, Best1, MCSG, and netgroup entries
	print "Checking decom host on all INTERNAL servers ... \n "
        # remove2        # Call function to cleanup on individual host 
	;;

	spjs522a|spjs568a )
	print "******************  This server name is $SNAME ********************** \n"
        print "After this script finish, please run it again on a spbs server "
        print "To remove entry for the Production environment"
	print "********************************************************************** \n"
        sleep 3
        print "Procceed.... \n " 
        print "Checking decom host on all PSN servers ....\n"
	remove2       # Call function to cleanup on individual host
	;;

	* ) 
	print "*****************  SERVER $HNAME INVALID  ************************** \n"
        print "This script need to be run on either on spjs or spbs servers \n"
	print "********************************************************************** \n"
        sleep 5
        exit ;;
esac
}


### determine os and assigning file path fuction ###
#----------------------------------------------------
function getos 
{
OS=$(/usr/bin/uname -s)
DATE=$(/usr/bin/date +%b%d%y)
CAT="/usr/bin/cat"

clear

if [ $OS = "SunOS" ]
        then  
	HOSTFILE="/etc/inet/hosts"
	AWK="/usr/xpg4/bin/awk"
	GREP="/usr/xpg4/bin/grep"
	CP="/usr/xpg4/bin/cp"
	MV="/usr/xpg4/bin/mv"
	SED="/usr/xpg4/bin/sed"
	print "This is a Sun server \n"
    elif [ $OS = "HP-UX" ]
        then 
	HOSTFILE="/etc/hosts"
	ETCDIR="/etc/"
	AWK="/usr/bin/awk"
	GREP="/usr/bin/grep"
	CP="/usr/bin/cp"
	MV="/usr/bin/mv"
	SED="/usr/bin/sed"    
	print "This is a HPUX server \n"
   else 
	print "OS type can not be determine \n"
fi
}


###  INPUT  function  ###    
#-------------------------
function getinput 
{
print -n "Enter absolute path to the file that contains the list of decom hostname:  "
read hostfile
cp $hostfile removelist

if [ -f $hostfile ]
    then
	print " \n"
        print "The following decom hosts will be check for removal from MBNA environment: " 
	cat $hostfile
	print ""
       	yesno   ## call function yesno
    else
       	print "The $hostfile file does not exist \n"
        print "Please rerun the script and reinput new path.  Exitting ..."
       	sleep 3
       	exit
fi
}


### Remove  print spooler  ###
#-----------------------------
function rmprint
{
print "_________________________________________"
print "## Remove entry from print spooler files"
print "_________________________________________"

UUCPFILE="/admin1/setup/uucp/.rhosts"

if [ "$(grep $i $UUCPFILE)" = "" ]
     then
        print "$NOCHANGE the decom server $i is NOT in the $UUCPFILE file " 
     else
        print "$CHANGE the decom server $i is in the $UUCPFILE file " 
fi
}

### Remove NFS  ###
#-------------------
function rmnfs
{
print "__________________________"
print "## Remove NFS mount point"
print "__________________________"

NFSFILE="/admin1/NFS/mounts"
NEWMOUNT="/admin1/NFS/new_mounts"

$GREP $i $NFSFILE/* |sed -e 's|^.*/||' -e 's|:.*$||' >/tmp/nfs.out
if [ -s /tmp/nfs.out ]
    then
        print "$CHANGE The following NFS mounts need to be remove for server $i  "
        cat /tmp/nfs.out
    else
        print "$NOCHANGE There is no NFS mount to remove for $i "
fi
}

### Remove Netgroup entry   ###
#--------------------------------
function rmnetgroup
{
print "____________________"
print "## Remove netgroup "
print "____________________"

NGBIN=/admin1/netgroup/bin
NETMATCH=$($NGBIN/ngmatch.sh $i)

if [ -n "$NETMATCH" ]
     then
        print "$CHANGE The entry $i will be remove from netgroup files "
     else
        print "$NOCHANGE There is no entry $i in netgroup file  "
fi
}

### Remove best1 function   ###
#------------------------------
function rmbest1
{
print "______________________"
print "## Remove best1 file"
print "______________________"

BESTFILE="/appl/patrol/custom/best1/.rhosts"

for ibest1 in spbs502a spbs496a
do
BESTMATCH=$($GETTO -n $ibest1 "grep $i $BESTFILE |cut -c1-9")
   if [ -n "$BESTMATCH" ]
	then 
	print "$CHANGE The following entry $BESTMATCH will be remove from $ibest1:$BESTFILE "
	else
	print "$NOCHANGE There is no $i entry in  $ibest1:$BESTFILE file "
   fi
done
}

### Remove MC Serviceguard   ###
#-------------------------------
function rmmcsg
{
print "_______________________________"
print "## Remove MCserviceguard file "
print "_______________________________"

SGFILE="/etc/cmcluster/nfs/nfs_global.conf"
SGFILEDATE="/etc/cmcluster/nfs/nfs_global.conf.$DATE"

for imcsg in spfs665a spfs667a spfs672a spfs673a spfs674a spfs675a
do
SGMATCH=$($GETTO -n $imcsg "grep $i $SGFILE")
IMBNA="$i.mbnainternational.com"
   if [ -n "$SGMATCH" ]
   then
   echo $SGMATCH > /tmp/mcsg.tmp
   print "$CHANGE The following $i entry will be remove from $imcsg:$SGFILE "
   cat  /tmp/mcsg.tmp
   print ""
   else
   print "$NOCHANGE There is no $i entry in $imcsg:$SGFILE file "
   fi
done
}


### Remove host function 1   ###
#-----------------------------------
function changereport  
{
grep CHANGE  $LOG.$CKSUM.log  >/tmp/change.rpt
sleep 3
clear
pg -p "=======================================
The above changes are noted on the log 
==========================================
" /tmp/change.rpt

rm /tmp/change.rpt
rm removelist

print "\n
*******************************************************************************************

Check $LOG.$CKSUM for detail output
Please procceed to run remove-server.sh script to cleanup the decom hostname as appropriate

*******************************************************************************************

"

}

### Remove host function 1   ###
#-----------------------------------
function remove1 
{

for removefunc in rmprint rmnfs rmnetgroup rmbest1 rmmcsg
do
	for i in $(cat $hostfile)
	do
		$removefunc  # Call individual remove functions
	done
print "\n"
done
}

###  Remove host function 2  ###
#-------------------------------
function remove2 
{
BINDIR="/admin1/decommission/bin/test/bin"

print
# $TAP -m -H:ORlist  -S:removelist -f:$BINDIR/remove-local.txt
$TAP -m  -S:removelist -f:$BINDIR/remove-local.sh
}


#----------------------------------------------------
#################  Main function  ###################
#----------------------------------------------------

getos			# check server and set env
getinput		# input decomhost file

#We use a while loop because "tee" buffers the data for too long
checkrun 2>&1 | while read line; do  #call function checkrun
	CKSUM=$(/usr/bin/cksum $hostfile |$AWK '{print $1}' )
	echo "$line"
	echo "$line" >> $LOG.$CKSUM.log
	done

changereport	# extract report from log file and print banner

exit
