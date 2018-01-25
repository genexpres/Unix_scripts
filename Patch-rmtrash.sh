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
#   i.e /admin1/tap/bin/tap -n -o:Mkdir.log  -H:Qa.list -f:Mkdir-us.sh
#
#   It will check the SunOne Patch level
#   that in compliance with MBNA standard
#
###########################################################

# exec > /tmp/xcheck.out

### Patch check Function 
#------------------------
patchcheck ()
{
if [ $SHORTNAME = as ] && [ $HOS != "HP-UX" ]
	then 
	export ISRC=/etc/init.d/iasrc.sh
	
elif [ $SHORTNAME = wb ] && [ $HOS != "HP-UX" ]
	then
	export ISRC=/etc/init.d/iwsrc.sh

else
    print "This is not a SunOne server.  Exiting ...."
    sleep 5
    exit
fi
}


### clean trash  Function
#------------------------
cleantrash ()
{
TRASHDIR=$DR/ias/trash

for trash in $(ls -1 $TRASHDIR)
do
cd $TRASHDIR/$trash
	for trash2 in $(ls -1t| tail +3)
	do
	print "remove $TRASHDIR/$trash/$trash2"
	print "remove $TRASHDIR/$trash/$trash2" >>$PATCHLOG
	rm -rf $trash2
	done
done
}


### Patch do Function 
#---------------------
patchdo ()
{
grep \^$HOST $NFILE |while IFS=, read  HO IN IC DR US NU VER J1
do
UID=$(grep $US /etc/passwd |awk -F: '{print $3}')
GID=$(grep $US /etc/passwd |awk -F: '{print $4}')
CVER=$($DR/ias/bin/patchversion |grep Current |nawk '{print $6}')

print "###########################################################################"
print "## Removing Trash for $IN in DIRECTORY $DR     " 
print "___________________________________________________________________________"

   if [ $VER = "6.5" ] 
   then
      case $CVER in
	0 )
	cleantrash
	;;

	5 )
	print "Instance $IN Patch is up-to-date  *** SKIP *** "
	print "Instance $IN Patch is up-to-date  *** SKIP *** " >>$PATCHLOG
	$DR/ias/bin/patchversion
	;;

	* )
      	print "Instance $IN in $DR may be DOWN....." 
      	print "Instance $IN in $DR may be DOWN....." >>$PATCHLOG
	cleantrash
	;;
	esac

  else
  	print "Instance $IN:  Netscape version $VER, skip patch check \n "
  	print "Instance $IN:  Netscape version $VER, skip patch check " >>$PATCHLOG
  fi

print "___________________________________________________________________________ \n \n"

done
}


#----------------
####  Main #####
#----------------

DATE=$(date +%Y%m%d)
HOST=$(uname -n)
SHORTNAME=$(uname -n |cut -c3-4)
HOS=$(uname -s)
NFILE=/appl/netscape/iasconfig.txt
PATCHLOG=/tmp/xtrash.log
rm $PATCHLOG
print "############  SUMMARY  REPORT  ###########" >$PATCHLOG

patchcheck
patchdo 
 
cat $PATCHLOG

