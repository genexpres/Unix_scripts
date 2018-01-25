#!/usr/bin/ksh  
###########################################################
#
#   @(#)   Name: check netscape patche - US version
#   @(#)   Revision Number: 1.2
#   @(#)   Last Revision: 9/3/04
#   @(#)   Source: /admin1/DO_core/engdev/Sunone
#   @(#)   Author: Truc To
#
#   This script should be executed from the local server
#   or
#   This script can also be executed from adminserver combine with tap
#   i.e /admin1/tap/bin/tap -n -o:patch.log  -H:server.list -f:Patch-check.sh
#
#   It will check the SunOne Patch level
#   that is in compliance with MBNA standard
#
###########################################################

# exec > /tmp/patchcheck.out

### clean trash  Function
#------------------------
checktrash ()
{
if [ $SHORTNAME = as ]
then
TRASHDIR=$DR/ias/trash

	for trash in $(ls -1 $TRASHDIR)
	do
	TRASHDIR2=$TRASHDIR/$trash
	cd $TRASHDIR2
	print "## TRASH-ALERT: The following trash directories can be remove ## "
	print $TRASHDIR2
        	for trash2 in $(ls -1t| tail +3)
        	do
       		print $trash2
        	done
	done
else
	print "Web server... skip trash check"
fi
}

### file check Function
#------------------------
checkfile ()
{
if [ $SHORTNAME = wb ] && [ -f $DR/ias/gxlib/libgxnsapi6.so.pre-6.5.1.2 ]
then
        print "**** $DR/ias/gxlib/libgxnsapi6.so.pre-6.5.1.2 EXIST **** \n"
 	elif [ $SHORTNAME = as ]
        then 
        print "## AS server.... skip libgxnxapi6.so  file check "

        else
        print "$DR/ias/gxlib/libgxnsapi6.so.pre-6.5.1.2 does not exist \n"
fi
}


## Function to check if user and directory exist
#-------------------------------------------------
checkserver ()
{
HOST=$(uname -n)
SHORTNAME=$(uname -n |cut -c3-4)

if [ $SHORTNAME = as ] || [ $SHORTNAME = wb ]
then 
NFILE=/appl/netscape/iasconfig.txt
	grep \^$HOST $NFILE |while IFS=, read  HO IN IC DR US NU VER J1 
	do
	print "###########################################################################"
	print "## checking $IN in DIRECTORY $DR  " 
	print "___________________________________________________________________________ "

	  if [ $VER = "6.5" ]
	  then
	  CVER=$($DR/ias/bin/patchversion |grep Current)
	  print "INSTANCE: $IN  ## Netscape $VER $CVER"
	  print "INSTANCE: $IN  ## Netscape $VER $CVER" >>$CHECKLOG
	  print "DIRECTORY: $DR "

	  checkfile
	  checktrash

	  else 
	  print "INSTANCE: $IN    Netscape version $VER, *** SKIP **** \n"
	  print "INSTANCE: $IN    Netscape version $VER, *** SKIP **** " >>$CHECKLOG
	  fi

	print "____________________________________________________________________________ \n \n"

	done
else
	print "there is no SunOne config file on this server"
	fi
}

#----------------
####  Main #####
#----------------
CHECKLOG=/tmp/checklog.txt
rm $CHECKLOG
print "############  SUMMARY  REPORT  ###########" >$CHECKLOG

checkserver

cat $CHECKLOG
