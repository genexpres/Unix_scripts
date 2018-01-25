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


### Function to check if user and directory exist
#-------------------------------------------------
checkfile ()
{
HOST=$(uname -n)
SHORTNAME=$(uname -n |cut -c3-4)

if [ $SHORTNAME = as ] || [ $SHORTNAME = wb ] 
then 
	NFILE=/appl/netscape/iasconfig.txt
	grep \^$HOST $NFILE |while IFS=, read  HO IN IC DR US NU VER J1 
	do
	  if [ $VER = "6.5" ]
	  then
	# Modify the line below for the funtion you need
	  TRASHDIR="$DR/ias/trash"
	  cd $TRASHDIR
	    for i in  $(ls -1)
	    do
	    print $TRASHDIR/$i
            cd $i 
	    ls -1t
	    print "#______________________________________________ \n \n"
	    cd ..
	    done

	  else 
	  print "INSTANCE: $IN    Netscape version $VER, *** SKIP **** \n"
	  fi
	done
else
	print "there is no SunOne config file on this server"
	fi
}

#----------------
####  Main #####
#----------------

checkfile

