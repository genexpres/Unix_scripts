create_dump_files()
{
  echo "Creating Temporary Datafiles of $dump_size bytes"
  xx=$dump_size
  > /tmp/wipe/dump.file.1
  > /tmp/wipe/dump.file.2
  > /tmp/wipe/dump.file.3
  > /tmp/wipe/dump.file.4
  while [ $xx -gt 0 ]
  do
    echo "\0137\0137\c" >> /tmp/wipe/dump.file.1
    echo "\0245\0245\c" >> /tmp/wipe/dump.file.2
    echo "\0137\0137\c" >> /tmp/wipe/dump.file.3
    echo "\0245\0245\c" >> /tmp/wipe/dump.file.4
    xx=$(($xx-2))
    if [ $(($xx%500)) -eq 0 ]
    then
      echo "\r$xx\c"
    fi
  done
}

get_disks()
{
   > /tmp/disks.?

   lspv | awk '$3 ~ /None/{print $1}' > /tmp/disks.1 
   mv /tmp/disks.1 /tmp/disks.input
   vi /tmp/disks.input
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
fulldisk=$1
pass=$2

#blkspd=`diskinfo -v /dev/rdsk/${shortdisk} | grep "blocks per disk" | awk -F: '{printf("%d",$2)}'`
case $1 in
   hdisk0 | hdisk18)
      blkspd=$((17344*1024*1024)) ;;
                 *)
      blkspd=$((34752*1024*1024)) ;;
esac
numwrites=$(($blkspd/$dump_size))
counter=0
totalwrts=$numwrites
starttime=$SECONDS
while [ $numwrites -gt 0 ]
do
  cat /tmp/wipe/dump.file.${pass}
  numwrites=`expr $numwrites - 1`
  if [ $counter -le 0 ]
  then
     rate=`echo "$starttime $SECONDS $totalwrts $numwrites" | awk '{printf("%7.2f",( $3 - $4 ) / ( $2 - $1 ))}'`
     ETA=`echo "$rate $numwrites" | awk '{printf("%7.2f", ( $2 / $1 ) / 60 / 60 )}'`
     echo "Pass ${pass}+${numwrites}+${rate}+${ETA}" > /tmp/${shortdisk}.status
     counter=20
  fi
  counter=`expr $counter - 1`
done | dd of=/dev/$fulldisk bs=$dump_size
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

#dump_size=16534
dump_size=1024
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
