#!/bin/ksh
create_dump_files()
{
  echo "Creating Temporary Datafiles of $dump_size bytes"
  xx=$dump_size
  > /tmp/dump.file.1
  > /tmp/dump.file.2
  while [ $xx -gt 0 ]
  do
    echo "\0137\0137\c" >> /tmp/dump.file.1
    echo "\0245\0245\c" >> /tmp/dump.file.2
    xx=$(($xx-2))
    if [ $(($xx%500)) -eq 0 ]
    then
      echo "\r$xx\c"
    fi
  done
}

get_disks()
{
>/tmp/disks.1
>/tmp/disks.2
>/tmp/disks.3

/usr/sbin/format < /dev/null | grep -v configured >/tmp/disks.1
/usr/xpg4/bin/egrep "[0-9]+\." /tmp/disks.1 | awk '{print $2}' | grep -v c0t0d0 | grep -v c0t8d0 > /tmp/disks.2
for i in `cat /tmp/disks.2`
do
echo "/dev/rdsk/${i}s2" >>/tmp/disks.3
done
   mv /tmp/disks.3 /tmp/disks.input
   cat /tmp/disks.input
}

wipe_proc()
{
  wipe_disk $x 1  
  wipe_disk $x 2
  wipe_disk $x 3  
  wipe_disk $x 4
}

wipe_disk()
{
shortdisk=`basename $1`
shortname=`echo $shortdisk| awk -F"s" '{print $1}'`
fulldisk=$1
pass=$2

#blkspd=`diskinfo -v /dev/rdsk/${shortdisk} | grep "blocks per disk" | awk -F: '{printf("%d",$2)}'`
blkspd=`format -d ${shortname} -f /tmp/format.input | grep -v label | grep -i backup | awk '{print $9}'`
numwrites=$(($blkspd/$dump_size*512))
counter=0
totalwrts=$numwrites
starttime=$SECONDS
while [ $numwrites -gt 0 ]
do
  cat /tmp/dump.file.${pass}
  numwrites=`expr $numwrites - 1`
  if [ $counter -le 0 ]
  then
     rate=`echo "$starttime $SECONDS $totalwrts $numwrites" | awk '{printf("%7.2f",( $3 - $4 ) / ( $2 - $1 ))}'`
     ETA=`echo "$rate $numwrites" | awk '{printf("%7.2f", ( $2 / $1 ) / 60 / 60 )}'`
     echo "Pass ${pass}+${numwrites}+${rate}+${ETA}" > /tmp/${shortdisk}.status
     counter=20
  fi
  counter=`expr $counter - 1`
done | dd of=$fulldisk bs=$dump_size
rm /tmp/${shortdisk}.status
}

status()
{
  tput clear
  echo "Disk Wipe Status"
  echo "==================================================="
  for x in `cat /tmp/disks.input`
  do
    xdisk=`basename $x`
    if [ ! -f /tmp/${xdisk}.status ]
    then
         echo "Completed" > /tmp/${xdisk}.status
    fi
    echo "$xdisk+`cat /tmp/${xdisk}.status`" | awk -F+ '{printf("%-10s %-7s %-9d writes/left, %10.2f writes/sec, %8s ETA\n",$1,$2,$3,$4,$5)}'
  done
}
echo "p" >/tmp/format.input
echo "p" >>/tmp/format.input

#dump_size=16534

dump_size=640
dump_size=$(($dump_size*1024))

#create_dump_files
get_disks
for x in `cat /tmp/disks.input`
do
  wipe_proc $x  &
done
while [ 1 ] 
do
status
sleep 10
done
