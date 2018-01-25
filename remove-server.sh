#!/usr/bin/ksh     
# MBNA America - Distributed Operation
# Author - Truc To 
# Remove decom from MBNA centralized servers
# version 1.0 02/24/2004
    
#####################  Global variables  ############################
TAP="/admin1/tap/bin/tap -Z"
GETTO="/admin1/tap/bin/getto -Z"
DATE=$(/usr/bin/date +%b%d%y)
SNAME=$(/usr/bin/uname -n)
LOG="/admin1/decommission/bin/test/logs/decom$DATE"
NOCHANGE="## NO CHANGE MADE: "
CHANGE="** CHANGE MADE: "



#########################  FUNCTIONS  ###############################

### yesno function  ###
#----------------------
function yesno 
{
if tty -s; then
	sleep 1
	print -n "Please enter [yes] to proceed or [no] to exit: " >`tty`
else
	print "Please enter [yes] to proceed or [no] to exit: "
fi
read ANS

case "$ANS" in
	[Yy]|[Yy][Ee][Ss] ) 
	print "You have selected $ANS to continue. Continuing........ \n \n"
	sleep 3 ;;

	* ) 
	print "You have selected $ANS to not continue. Exiting......."
	rm removelist
	sleep 3
	exit ;;
esac
}


### determine os and assigning file path fuction ###
#----------------------------------------------------
function checkrun 
{
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
        print "Remove decom host from INTERNAL servers ....\n"
        remove2        # Call function to cleanup on individual host 
	;;

	spjs522a|spjs568a )
	print "******************  This server name is $SNAME ********************** \n"
        print "After this script finish, if not already done so,"
	print "Please run it again on a spbs server "
        print "To remove entry for the Production environment"
	print "********************************************************************** \n"
        sleep 3
        print "Procceed.... \n " 
        print "Remove decom host from PSN servers ....\n"
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


### Readme Notes function ###
#----------------------------
function readme
{
clear
cat README
print ""
yesno
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
	print "This is Sun server $SNAME \n"
    elif [ $OS = "HP-UX" ]
        then 
	HOSTFILE="/etc/hosts"
	ETCDIR="/etc/"
	AWK="/usr/bin/awk"
	GREP="/usr/bin/grep"
	CP="/usr/bin/cp"
	MV="/usr/bin/mv"
	SED="/usr/bin/sed"    
	print "This is HPUX server $SNAME \n"
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
        print "The following hosts will be remove from MBNA environment: " 
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
print "___________________________________________________"
print "## Remove entry $i from print spooler files"
print "___________________________________________________"

UUCPFILE="/admin1/setup/uucp/.rhosts"

if [ "$(grep $i $UUCPFILE)" = "" ]
    then
        print "$NOCHANGE the decom server $i is not in the $UUCPFILE file " 
    else
        print "$CHANGE the decom server $i is in the $UUCPFILE file " 
        print "Cleanup server $i ? \n " 

       	yesno   ## call function yesno

        $CP  -p $UUCPFILE $UUCPFILE.$DATE
        $GREP -v $i $UUCPFILE.$DATE  > $UUCPFILE
        print "The original $UUCPFILE file was saved as $UUCPFILE.$DATE  " 
fi
}


### Remove NFS  ###
#-------------------
function rmnfs
{
print "_________________________________"
print "## Remove NFS mount point $i"
print "_________________________________"

NFSFILE="/admin1/NFS/mounts"
NEWMOUNT="/admin1/NFS/new_mounts"

$GREP $i $NFSFILE/* |sed -e 's|^.*/||' -e 's|:.*$||' >/tmp/nfs.out
if [ -s /tmp/nfs.out ]
   then
        print "$CHANGE The following mounts will be remove for server $i  "
        cat /tmp/nfs.out
	print ""

       	yesno   ## call function yesno

        print "See $NEWMOUNT for detail "
                for ii in $(cat /tmp/nfs.out)
                do
                echo "-$i" >> $NEWMOUNT/$ii
                done
   else
        print "$NOCHANGE There is no NFS mount to remove for $i "
fi
}


### Remove Netgroup entry   ###
#------------------------------
function rmnetgroup
{
print "________________________________"
print "## Remove netgroup for $i "
print "________________________________"

NGBIN=/admin1/netgroup/bin
NETMATCH=$($NGBIN/ngmatch.sh $i)

if [ -n "$NETMATCH" ]
    then
        print "$CHANGE The entry  $i will be remove: $NETMATCH "

	yesno	## call function yesno

        $NGBIN/ngmatch.sh $i |tr '/:/' '   '| read key name host
	echo "$DATE  Netgroup remove:	$key $name $host" >restore/netgroup.$DATE
        $NGBIN/netgroupmod.sh -d "$name" "$host"
    else
        print "$NOCHANGE There is no entry $i in netgroup file  "
fi
}


### Remove best1 function   ###
#------------------------------
function rmbest1
{
print "__________________________________"
print "## Remove best1 file for $i"
print "__________________________________"

BESTFILE="/appl/patrol/custom/best1/.rhosts"

for ibest1 in spbs502a spbs496a
do
BESTMATCH=$($GETTO -n $ibest1 "grep $i $BESTFILE |cut -c1-9")
   if [ -n "$BESTMATCH" ]
      then 
	print "$CHANGE The following entry $BESTMATCH will be remove from $ibest1:$BESTFILE "

	yesno	#call function yesno

        $GETTO -n $ibest1 "
        	$CP -p $BESTFILE $BESTFILE.$DATE
        	$GREP  -v $i $BESTFILE.$DATE > $BESTFILE
        	# $CHOWN bgsuser:csmadm $BESTFILE
        	# $CHMOD 640 $BESTFILE
        	"
	print "The original $BESTFILE was saved as $BESTFILE.$DATE "
     else
	print "$NOCHANGE There is no $i entry in  $ibest1:$BESTFILE file "
  fi
done
}


### Remove MC Serviceguard   ###
#-------------------------------
function rmmcsg
{
print "______________________________"
print "## Remove MCserviceguard file "
print "______________________________"

SGFILE="/etc/cmcluster/nfs/nfs_global.conf"
SGFILEDATE="/etc/cmcluster/nfs/nfs_global.conf.$DATE"

for imcsg in spfs665a spfs667a spfs672a spfs673a spfs674a spfs675a
do
SGMATCH=$($GETTO -n $imcsg "grep $i $SGFILE")
IMBNA="$i.mbnainternational.com"

   if [ -n "$SGMATCH" ]
   then
   echo $SGMATCH > /tmp/mcsg.tmp
   print "$CHANGE The $i entry will be remove from $imcsg:$SGFILE "
   cat  /tmp/mcsg.tmp
   print ""

   yesno	#call function yesno

   $GETTO -n $imcsg "
     $CP -p $SGFILE $SGFILEDATE
     $SED -e 's|:$IMBNA||g' -e 's|$IMBNA:||g' -e 's|\"\"|\" \"|g' $SGFILEDATE > $SGFILE 
     "
   print "The original $SGFILE was saved as $SGFILE.$DATE "
   else
   print "$NOCHANGE There is no $i entry in $imcsg:$SGFILE file "
   fi

done
}


### Remove host function 1   ###
#-------------------------------
function remove1 
{

for removefunc in rmprint rmnfs rmnetgroup rmbest1 rmmcsg
do
	for i in $(cat $hostfile)
	do
	$removefunc
	done
print "\n\n"
done
}


###  Remove host function 2  ###
#-------------------------------
function remove2 
{
BINDIR="/admin1/decommission/bin/test/bin"
$TAP -m  -S:removelist -f:$BINDIR/remove-local.sh
# $TAP -m -H:ORlist  -S:removelist -f:$BINDIR/remove-local.sh
}


###  call checkrun  ###
#----------------------
function callcheckrun
{
CKSUM=$(/usr/bin/cksum removelist |$AWK '{print $1}' )

checkrun 2>&1 | while read line; do

	#We use a while loop because "tee" buffers the data for too long
	 echo "$line"
	 echo "$line" >> $LOG.$CKSUM.log
done
}


###  print banner  ###
#---------------------
function printbanner   
{
print "
*************************************************************************************

Check $LOG.$CKSUM.log for detail output

*************************************************************************************
"
rm removelist
}


#----------------------------------------------------
#################  Main function  ###################
#----------------------------------------------------
readme			# Readme notes
getos			# check server and set env
getinput		# input decomhost file
callcheckrun		# check and run the script 
printbanner		# print banner


exit
