#!/bin/ksh  

# Comment the line below for debug if you want to see
# system error messages when running "ksh -x".

#exec 2> /dev/null

# Written by 

################ Usage: logmanager -[zrcd] #####################
# -z compress and move log files that are no longer needed
# -r remove log files that are no longer needed 
# -c checkpoint only mode; executes rcrmqobj & rcdmqobj; 
#    but does not move or compress files.
# -d display current state of log files without
#    any sort of checkpoint or clean-up. Default.
# Features:
# - Loops for multiple Queue Managers on same server
# - Options to compress or remove old logs.
# - Simulates 1000 transactions to force a checkpoint.
################################################################

################ Execution Requirements ########################
# 1.  Set environment variables below.  Also, set line 1 of this
#     script to the location of your Korn Shell.
# 2.  Create the directory corresponding to MQOLDLOGS environment 
#     variable.
# 3.  Create a queue called "TEST.$QMGR" (where $QMGR is the
#     Queue Manager Name)on each queue manager to be managed.
# 4.  Schedule logmanager via cron or some other scheduler. 
#     Remember to redirect output to either a log or
#     the bit bucket.
# 5.  Execute the script manually to make sure it works in your
#     environment.  Some versions of the Korn Shell may not be 
#     supported, however I have attempted to write this using
#     the most widely available KSH syntax.
################################################################

################ Set Environment Variables #####################
# MQQMGRRO0T - location of "qmgrs" directory
# QMGRS_TO_MANAGE - space delimited array of linear logged qmgrs
#   on this server that need to be managed, e.g.
#   QMGRS_TO_MANAGE='QMGRA QMGRB QMGRC'
# MQOLDLOGS - where to store old logs; make sure this
#   directory exists.
# MQEXROOT - where MQ binaries can be found for this OS
export MQQMGRROOT=/var/mqm
export QMGRS_TO_MANAGE=$(dspmq |grep Running |sed -e 's/).*$//' -e 's/^.*(//')
export MQOLDLOGS=$MQQMGRROOT/oldlogs
export MQEXROOT=/opt/mqm/bin
################################################################

############### Initialize Variables ###########################
integer INT_OLDEST_FILE_NEEDED_FOR_RESTART=0
integer INT_OLDEST_FILE_NEEDED_FOR_MEDIA=0
integer INT_OLDEST_FILE_NEEDED=0
integer INT_OLDEST_FILE_PRESENT=0
integer INT_NEWEST_FILE_PRESENT=0
integer INT_HIGHEST_TO_DISCARD=0
integer FILE_DIFF=0
integer FILES_IN_DIR=0
################################################################

######################### Functions ############################

checkpoint() {

# Attempt to repair objects before recording them. 
# This was a recommendation from the listserv because
# if you take a media image of a bad object then you
# will end up restoring a bad object in recovery. 

print "$qmgrname: Attempting to recreate objects." 
#$MQEXROOT/rcrmqobj -m $qmgrname -z -t q '*'
$MQEXROOT/rcrmqobj -m $qmgrname -z -t all '*'
RCRMQOBJ_RETURN=$?

# Check return codes so that it can be reported
# whether a successful checkpoint was executed 
# prior to log cleanup.

case $RCRMQOBJ_RETURN in
40|49) print "$qmgrname: Queue Manager not available"
       print "$qmgrname: \tUnable to execute rcrmqobj."
       print "$qmgrname: \tRecreate Objects not performed."
       # Don't attempt to record media image
       ;;
69)    print "$qmgrname: Storage not available."
       print "$qmgrname: \tUnable to execute rcrmqobj."
       print "$qmgrname: \tRecreate Objects not performed."
       # Don't attempt to record media image
       ;;
0)     print "$qmgrname: Recreate Objects completed successfully"
       recordmedia
       ;;
*)     print "$qmgrname: Recreate Objects may have not completed successfully."
       print "$qmgrname: \tCheck Return Code ($RCRMQOBJ_RETURN) in MQ Series"
       print "$qmgrname: \tSystem Administration manual."
       recordmedia
       ;;
esac

}

recordmedia() {

# Record Media Image
print "$qmgrname: Attempting to record media image." 

$MQEXROOT/rcdmqimg -m $qmgrname -z -t all '*'
RCDMQOBJ_RETURN=$?

# Again, check return codes.
case $RCDMQOBJ_RETURN in
40|49) print "$qmgrname: Queue Manager not available"
       print "$qmgrname: \tUnable to execute rcdmqobj."
       print "$qmgrname: \tRecord Media Image not performed."
       ;;
69)    print "$qmgrname: Storage not available."
       print "$qmgrname: \tUnable to execute rcdmqobj."
       print "$qmgrname: \tRecord Media Image not performed."
       ;;
0)     print "$qmgrname: Record Media Image completed successfully"
       ;;
*)     print "$qmgrname: Record Media Image may have not completed successfully."
       print "$qmgrname: \tCheck Return Code ($RCDMQOBJ_RETURN) in MQ Series"
       print "$qmgrname: \tSystem Administration manual"
       ;;
esac


# Put 500 messages to a test queue.  Then get them from the same queue.
# This will cause MQ to experience a 1000 transactions which are required
# for a checkpoint to occur.

integer LOOP_COUNT=0
while ((LOOP_COUNT < 1001))
do
print "S"| $MQEXROOT/../samp/bin/amqsput TEST.$qmgrname $qmgrname > /dev/null 2>&1 
((LOOP_COUNT = LOOP_COUNT + 1))
done
$MQEXROOT/../samp/bin/amqsget TEST.$qmgrname $qmgrname > /dev/null 2>&1 

}

evaluate_logs() {

CLEAN_STATUS=0

# Identify the oldest files needed to restart the queue manager
# by looking at AMQERR01.LOG for AMQ7467 and AMQ7468 messaged.  
# Note: Files are evaluated as integers.

# Oldest file needed for restart...
OLDEST_FILE_NEEDED_FOR_RESTART=`sed -ne '/AMQ7467/N' -e 's/\n/ /p' \
  $MQERROR/AMQERR0*.LOG|awk '{ print $13 }'|cut -c2-8|sort -u|tail -n 1`
((INT_OLDEST_FILE_NEEDED_FOR_RESTART = $OLDEST_FILE_NEEDED_FOR_RESTART + 0))
print "$qmgrname: S$OLDEST_FILE_NEEDED_FOR_RESTART.LOG - Oldest log needed to restart queue manager."

# Oldest file needed for media recovery...
OLDEST_FILE_NEEDED_FOR_MEDIA=`sed -ne '/AMQ7468/N' -e 's/\n/ /p' \
  $MQERROR/AMQERR0*.LOG|awk '{ print $16 }'|cut -c2-8|sort -u|tail -n 1`
((INT_OLDEST_FILE_NEEDED_FOR_MEDIA = $OLDEST_FILE_NEEDED_FOR_MEDIA + 0))
print "$qmgrname: S$OLDEST_FILE_NEEDED_FOR_MEDIA.LOG - Oldest log needed for media recovery."

# Compare the two and keep the lowest number...
if ((INT_OLDEST_FILE_NEEDED_FOR_MEDIA <= $INT_OLDEST_FILE_NEEDED_FOR_RESTART ))
   then
     INT_OLDEST_FILE_NEEDED=$INT_OLDEST_FILE_NEEDED_FOR_MEDIA 
     OLDEST_FILE_NEEDED=$OLDEST_FILE_NEEDED_FOR_MEDIA 
   else
     INT_OLDEST_FILE_NEEDED=$INT_OLDEST_FILE_NEEDED_FOR_RESTART
     OLDEST_FILE_NEEDED=$OLDEST_FILE_NEEDED_FOR_RESTART
fi

print "$qmgrname: S$OLDEST_FILE_NEEDED.LOG - Oldest log needed."

# Generate an array listing all files in active log directory
# with the oldest file being the last item in the array
set -A LOG_FILES_PRESENT $(ls -l $MQACTIVE | grep -v "Z*.Z"|\
   awk '{print $9}' | cut -c2-8 | sort -r)

# Count the number of items in the array so that the position
# of the last item (oldest file present) is known.
count=-1
for item in ${LOG_FILES_PRESENT[*]} 
do
  ((count = count + 1))
done
((INT_OLDEST_FILE_PRESENT = ${LOG_FILES_PRESENT[$count]} + 0))
((INT_NEWEST_FILE_PRESENT = ${LOG_FILES_PRESENT[0]} + 0))

# If only two active logs are needed after checkpoint 
# then make sure that three are kept, ie... keep 
# one or two of the inactive logs.

((FILE_DIFF = $INT_NEWEST_FILE_PRESENT - $INT_OLDEST_FILE_NEEDED))
((FILES_IN_DIR = $INT_NEWEST_FILE_PRESENT - $INT_OLDEST_FILE_PRESENT + 1))
((FILES_ACTIVE = $FILE_DIFF +1)) 
((INT_HIGHEST_TO_DISCARD = $INT_OLDEST_FILE_NEEDED - 1))

if (($FILE_DIFF == 1))
then
 print "$qmgrname: Only $FILES_ACTIVE active logs in directory."
 ((INT_HIGHEST_TO_DISCARD = $INT_HIGHEST_TO_DISCARD - 1))
 ((INT_OLDEST_FILE_NEEDED = $INT_OLDEST_FILE_NEEDED - 1))
 print "$qmgrname: \tKeeping one inactive log."
elif (($FILE_DIFF == 0)) 
then
print "$qmgrname: Only $FILES_ACTIVE active log in directory."
 ((INT_HIGHEST_TO_DISCARD = $INT_HIGHEST_TO_DISCARD - 2))
 ((INT_OLDEST_FILE_NEEDED = $INT_OLDEST_FILE_NEEDED - 2)) 
 print "$qmgrname: \tKeeping two inactive logs."
else
 print "$qmgrname: There are $FILES_IN_DIR logs in directory. $FILES_ACTIVE are active."
fi

# If approaching roll-over then don't clean up. The last log 
# is S9999999.LOG.

if (($INT_NEWEST_FILE_PRESENT > 9999500))
then
 print "$qmgrname: Approaching Roll Over."
 print "$qmgrname: \t499 Sequence numbers left."
 print "$qmgrname: \tNo logs will be cleaned up."
 CLEAN_STATUS=1
fi 

# If oldest file needed is oldest file present  
# in the directory then there is nothing to do. 

if (($INT_OLDEST_FILE_NEEDED == $INT_OLDEST_FILE_PRESENT))
then
  print "$qmgrname: Oldest log needed is oldest log in directory."
  print "$qmgrname: \tNo logs will be cleaned up."
  CLEAN_STATUS=1
fi

print "$qmgrname: Logs $INT_OLDEST_FILE_NEEDED thru $INT_NEWEST_FILE_PRESENT will be kept."
if (($INT_OLDEST_FILE_PRESENT <= $INT_HIGHEST_TO_DISCARD ))
then
  print "$qmgrname: Logs $INT_OLDEST_FILE_PRESENT thru $INT_HIGHEST_TO_DISCARD will be processed."
fi
}

#################### Begin execution ###########################

for qmgrname in $QMGRS_TO_MANAGE
  do  

export MQERROR=$MQQMGRROOT/qmgrs/$qmgrname/errors
export MQACTIVE=$MQQMGRROOT/log/$qmgrname/active

#export MQERROR=/tmp/qmgrs/$qmgrname/errors
#export MQACTIVE=/tmp/log/$qmgrname/active
  
print "$qmgrname: Begin log management. `date`" 

# First, make sure this is indeed a linear logged
# queue manager.

ISLINEAR=`grep "LogType" ${MQQMGRROOT}/qmgrs/$qmgrname/qm.ini |\
   awk -F"=" '{print $2}'`

if [[ $ISLINEAR = "CIRCULAR" ]]  
then
  print "$qmgrname: Logs are not linear."
  print "======================================================= \n"

elif [[ $ISLINEAR != "LINEAR" ]] && [[ $ISLINEAR != "CIRCULAR" ]]
then
  print "$qmgrname: ${MQQMGRROOT}/qmgrs/$qmgrname/qm.ini - Invalid Path"
  print "$qmgrname: \tCheck MQQMGRROOT and QMGRS_TO_MANAGE"
else

case $1 in
-r)# Remove Option

   # Remove all files between the oldest_needed_minus_one 
   # and the oldest present ($INT_OLDEST_FILE_PRESENT).
   
   checkpoint
   evaluate_logs

   if [[ $CLEAN_STATUS = "0" ]]
   then
     while (($INT_OLDEST_FILE_PRESENT <= $INT_HIGHEST_TO_DISCARD))
     do
		if (($INT_OLDEST_FILE_PRESENT >= 0)) && (($INT_OLDEST_FILE_PRESENT <= 9))
            then
              rm -f "$MQACTIVE/S000000$INT_OLDEST_FILE_PRESENT.LOG"
              ((INT_OLDEST_FILE_PRESENT = $INT_OLDEST_FILE_PRESENT + 1))
            elif (($INT_OLDEST_FILE_PRESENT >= 10)) && (($INT_OLDEST_FILE_PRESENT <= 99))
            then
              rm -f "$MQACTIVE/S00000$INT_OLDEST_FILE_PRESENT.LOG"
              ((INT_OLDEST_FILE_PRESENT = $INT_OLDEST_FILE_PRESENT + 1))
            elif (($INT_OLDEST_FILE_PRESENT >= 100)) && (($INT_OLDEST_FILE_PRESENT <= 999))
            then
              rm -f "$MQACTIVE/S0000$INT_OLDEST_FILE_PRESENT.LOG"
              ((INT_OLDEST_FILE_PRESENT = $INT_OLDEST_FILE_PRESENT + 1))
            elif (($INT_OLDEST_FILE_PRESENT >= 1000)) && (($INT_OLDEST_FILE_PRESENT <= 9999))
            then
              rm -f "$MQACTIVE/S000$INT_OLDEST_FILE_PRESENT.LOG"
              ((INT_OLDEST_FILE_PRESENT = $INT_OLDEST_FILE_PRESENT + 1))
            elif (($INT_OLDEST_FILE_PRESENT >= 10000)) && (($INT_OLDEST_FILE_PRESENT <= 99999))
            then
              rm -f "$MQACTIVE/S00$INT_OLDEST_FILE_PRESENT.LOG"
              ((INT_OLDEST_FILE_PRESENT = $INT_OLDEST_FILE_PRESENT + 1))
            elif (($INT_OLDEST_FILE_PRESENT >= 100000)) && (($INT_OLDEST_FILE_PRESENT <= 999999))
            then
  	        rm -f "$MQACTIVE/S0$INT_OLDEST_FILE_PRESENT.LOG"
              ((INT_OLDEST_FILE_PRESENT = $INT_OLDEST_FILE_PRESENT + 1))
            elif (($INT_OLDEST_FILE_PRESENT >= 1000000)) && (($INT_OLDEST_FILE_PRESENT <= 9999999))
            then
		  rm -f "$MQACTIVE/S$INT_OLDEST_FILE_PRESENT.LOG"
              ((INT_OLDEST_FILE_PRESENT = $INT_OLDEST_FILE_PRESENT + 1))
            else
              print "Error"
            fi
     done 
     print "$qmgrname: Done. Logs removed."     
   else
     print "$qmgrname: Done. Logs not removed."
   fi
   ;;

-z)# Compress and Move Option

   # Compres all the files between the oldest_needed_minus_one 
   # and the oldest present ($INT_OLDEST_FILE_PRESENT). Then 
   # move them to a storage directory.

   checkpoint
   evaluate_logs

   if [[ $CLEAN_STATUS = "0" ]]
   then
     while (($INT_OLDEST_FILE_PRESENT <= $INT_HIGHEST_TO_DISCARD))
     do
       if (($INT_OLDEST_FILE_PRESENT >= 0)) && (($INT_OLDEST_FILE_PRESENT <= 9))
       then
         mv "$MQACTIVE/S000000$INT_OLDEST_FILE_PRESENT.LOG" "$MQACTIVE/Z000000$INT_OLDEST_FILE_PRESENT.LOG"
         compress -f "$MQACTIVE/Z000000$INT_OLDEST_FILE_PRESENT.LOG"
         ((INT_OLDEST_FILE_PRESENT = $INT_OLDEST_FILE_PRESENT + 1))
       elif (($INT_OLDEST_FILE_PRESENT >= 10)) && (($INT_OLDEST_FILE_PRESENT <= 99))
       then
         mv "$MQACTIVE/S00000$INT_OLDEST_FILE_PRESENT.LOG" "$MQACTIVE/Z00000$INT_OLDEST_FILE_PRESENT.LOG"
         compress -f "$MQACTIVE/Z00000$INT_OLDEST_FILE_PRESENT.LOG"
         ((INT_OLDEST_FILE_PRESENT = $INT_OLDEST_FILE_PRESENT + 1))
       elif (($INT_OLDEST_FILE_PRESENT >= 100)) && (($INT_OLDEST_FILE_PRESENT <= 999))
       then
         mv "$MQACTIVE/S0000$INT_OLDEST_FILE_PRESENT.LOG" "$MQACTIVE/Z0000$INT_OLDEST_FILE_PRESENT.LOG"
         compress -f "$MQACTIVE/Z0000$INT_OLDEST_FILE_PRESENT.LOG"
         ((INT_OLDEST_FILE_PRESENT = $INT_OLDEST_FILE_PRESENT + 1))
       elif (($INT_OLDEST_FILE_PRESENT >= 1000)) && (($INT_OLDEST_FILE_PRESENT <= 9999))
       then
         mv "$MQACTIVE/S000$INT_OLDEST_FILE_PRESENT.LOG" "$MQACTIVE/Z000$INT_OLDEST_FILE_PRESENT.LOG"
         compress -f "$MQACTIVE/Z000$INT_OLDEST_FILE_PRESENT.LOG"
         ((INT_OLDEST_FILE_PRESENT = $INT_OLDEST_FILE_PRESENT + 1))
       elif (($INT_OLDEST_FILE_PRESENT >= 10000)) && (($INT_OLDEST_FILE_PRESENT <= 99999))
       then
         mv "$MQACTIVE/S00$INT_OLDEST_FILE_PRESENT.LOG" "$MQACTIVE/Z00$INT_OLDEST_FILE_PRESENT.LOG"
         compress -f "$MQACTIVE/Z00$INT_OLDEST_FILE_PRESENT.LOG"
         ((INT_OLDEST_FILE_PRESENT = $INT_OLDEST_FILE_PRESENT + 1))
       elif (($INT_OLDEST_FILE_PRESENT >= 100000)) && (($INT_OLDEST_FILE_PRESENT <= 999999))
       then
         mv "$MQACTIVE/S0$INT_OLDEST_FILE_PRESENT.LOG" "$MQACTIVE/Z0$INT_OLDEST_FILE_PRESENT.LOG"
         compress -f "$MQACTIVE/Z0$INT_OLDEST_FILE_PRESENT.LOG"
         ((INT_OLDEST_FILE_PRESENT = $INT_OLDEST_FILE_PRESENT + 1))
       elif (($INT_OLDEST_FILE_PRESENT >= 1000000)) && (($INT_OLDEST_FILE_PRESENT <= 9999999))
       then
         mv "$MQACTIVE/S$INT_OLDEST_FILE_PRESENT.LOG" "$MQACTIVE/Z$INT_OLDEST_FILE_PRESENT.LOG"
         compress -f "$MQACTIVE/Z$INT_OLDEST_FILE_PRESENT.LOG"
         ((INT_OLDEST_FILE_PRESENT = $INT_OLDEST_FILE_PRESENT + 1))
       else
         print "Error"
	 fi
     done
     if [[ -d $MQOLDLOGS/$qmgrname ]]
     then
       mv $MQACTIVE/*.Z $MQOLDLOGS/$qmgrname 
       print "$qmgrname: Done. Logs compressed and moved to $MQOLDLOGS/$qmgrname."
     else
       mkdir -p -m 770 $MQQMGRROOT/oldlogs/$qmgrname
       mv $MQACTIVE/*.Z $MQOLDLOGS/$qmgrname 
       print "$qmgrname: Done. Logs compressed and moved to $MQOLDLOGS/$qmgrname."
     fi
   else
     print "$qmgrname: Done. Logs not compressed/moved."
   fi 
   ;;

-c)# Checkpoint Only Option
   checkpoint
   print "$qmgrname: Done. Checkpoint only mode."
   ;;

 *)# Display Only Option (Default)
   evaluate_logs
   print "$qmgrname: Done. Display only mode."
   ;;

esac
fi
done
exit 0
